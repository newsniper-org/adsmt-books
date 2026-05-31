= SAT 계층

== 아키텍처

SAT 계층의 일은 명제 CNF 식에 대한 충족 할당을
찾아내거나, 그러한 할당이 존재하지 않음을 증명하는
것이다. 솔버 나머지와의 계약은 좁다: 각 절이
`Vec<(atom, polarity)>`인 `Vec<Clause>`가 들어가고,
세 판정 — `Sat`, `Unsat`, `Unknown` — 중 하나가
나오며, `Sat` 경로에서는 충족 할당이 이론 측 검증을 위해
이용 가능하다.

adsmt는 세 가지 SAT 백엔드를 함께 공급한다: OxiZ(순수
Rust CDCL 솔버, 기본), CaDiCaL(FFI 뒤의 C++ CDCL 솔버),
그리고 `adsmt-engine::cdcl`에 내장된 fallback. fallback이
존재하는 이유는 feature-flag가 없는 빌드도 자체
완결적이도록 하기 위함이다. 프로덕션 빌드는 OxiZ를
사용한다. 이 장은 내장 CDCL 구현이 하는 일을 살펴본다.
같은 아키텍처가 외부 백엔드 어느 쪽에든 적용된다.

== CDCL 알고리즘 한눈에 보기

Conflict-Driven Clause Learning은 백트래킹 기반 명제
탐색 위에 앉는다. 기본 루프:

#enum(numbering: "(1)",
  [더 이상 단위 절(unit clause)에 의해 강제되는 할당이
   없을 때까지 현재의 부분 할당을 전파한다.],
  [전파가 충돌을 산출했다면(어떤 절이 거짓이 되었다면)
   충돌 분석을 수행한다: 함의 그래프를 거꾸로 걸어가서
   충돌의 이유를 포착하는 *학습된 절*을 찾아낸다. 그
   학습된 절을 식에 추가하고, 그것이 전파되는 수준으로
   백점프한다.],
  [그렇지 않고 모든 변수가 할당되어 있다면 `Sat`을
   반환한다.],
  [그렇지 않다면 결정 변수(휴리스틱이 어떤 것인지 고른다)를
   골라 할당하고 루프를 반복한다.],
)

두 핵심 구성요소는 *전파*(단계 1)와 *충돌 분석*(단계 2)
이다. 결정 휴리스틱(단계 4)과 재시작 정책은 2차
최적화에 해당하지만 실제 솔버 성능에 비중 있는 영향을
미친다.

== 두-감시-리터럴

순진한 전파기는 매 할당마다 모든 절을 훑어 그것이 이제
단위인지 확인한다. 절이 $n$개이고 절마다 평균 $k$개의
리터럴이 있다면 비용은 매 할당당 $O(n k)$이다.
두-감시-리터럴 기법은 분할 상환 비용을 극적으로 줄인다.

관찰: 절은 그 모든 리터럴 중 하나만 빼고 거짓 할당이
되었을 때에만 단위가 된다. 따라서 현재 감시 중인 리터럴
중 하나가 거짓이 될 때에만 그 절을 검사하면 된다. 절마다
두 개의 임의 리터럴을 "감시"로 골라두고, 각 리터럴에서
그것을 감시하는 절들로의 역인덱스를 유지한 다음, 새
할당이 들어올 때마다 그 *부정*을 감시하는 절들만
검사한다.

그러한 절을 검사할 때 다음 중 하나가 일어난다:
- 감시할 다른 비-거짓 리터럴을 찾는다(비용: 절의 리터럴을
  $O(k)$로 훑기);
- 다른 감시 리터럴이 충족되어 있음을 본다(절은 멀쩡; 건너뜀);
- 다른 감시 리터럴이 미할당임을 본다(절은 단위; 전파);
- 다른 감시 리터럴이 거짓임을 본다(충돌).

자료구조는 간단하다:

```rust
pub struct CdclState {
    pub trail: Vec<TrailEntry>,
    pub assign: HashMap<String, bool>,
    pub clause_watches: Vec<[usize; 2]>,
    pub watches: HashMap<(String, bool), Vec<usize>>,
    pub prop_head: usize,
    // … learnt-clause storage, activity tables, etc.
}
```

`prop_head` 커서는 trail을 한 번에 한 리터럴씩 진행한다.
새 trail 항목마다 `watches`에서 그 *부정*을 조회하고,
그 절들만 검사한다.

== 충돌 분석 — 1-UIP

절이 거짓이 되면 전파기는 그 인덱스를 반환한다. 충돌
분석은 함의 그래프(trail, 각 항목의 `reason`이 그것을
전파한 절을 가리킨다)를 거꾸로 걸어가, 만약 처음부터
있었다면 이 충돌을 막았을 *학습된 절*을 찾아낸다.

표준 알고리즘 — "1-UIP" — 은 정확히 하나의 리터럴만이
현재 결정 수준에 남을 때까지 충돌 절을 현재 결정 수준
리터럴들의 선행자(antecedent)와 차례로 분해(resolve)
하여 학습된 절을 산출한다. 그 단 하나의 리터럴이 *첫
번째 유일 함의점*(first unique implication point)이다.
결과 절이 학습된 절이며, *다른* 리터럴들 중 최대 결정
수준이 *백점프 수준*이다 — 그 수준으로 되돌려야 한다.

코드로(스케치):

```rust
fn analyze_1uip(clauses, state, conflict_idx) -> (Vec<Lit>, u32) {
    let current = state.decision_level;
    let mut seen = HashSet::new();
    let mut learnt = Vec::new();
    let mut count_current = 0;
    // Seed from the conflict clause.
    for lit in &clauses[conflict_idx] {
        process(lit, ...);
    }
    // Walk the trail backwards, resolving each current-level
    // seen literal against its antecedent.
    let mut idx = state.trail.len();
    while count_current > 1 {
        idx -= 1;
        // ...
    }
    // Recover the UIP and the backjump level.
    // ...
}
```

전체 구현은 adsmt의 `cdcl.rs`에서 약 100줄이며, trail
인프라가 자리잡고 나면 기계적으로 작성된다.

== VSIDS — 변수 활동도

2001년 Chaff 솔버 이후 CDCL을 지배해 온 결정 휴리스틱은
*VSIDS* — variable state independent decaying sum — 이다.
각 원자가 활동도 점수를 운반한다. 충돌이 일어날 때마다
학습된 절 안의 원자들의 활동도를 올려주고(bump), 주기적으로
모든 점수를 감쇠 계수(보통 0.95)로 곱해 최근 bump가
오래된 것을 압도하도록 한다.

```rust
pub fn bump_activity(&mut self, clause: &Clause, bump: f64) {
    for lit in clause {
        *self.activity.entry(atom_key(lit)).or_insert(0.0) += bump;
    }
}
pub fn decay_activity(&mut self, factor: f64) {
    for v in self.activity.values_mut() { *v *= factor; }
}
```

결정 선택자는 열린 절들을 훑어 최고 활동도를 가진
미할당 원자를 고른다. bump + 감쇠 주기와 결합되면, 이것은
"내가 지금 마주치고 있는 충돌에 어떤 원자가 관여하고
있는가?"의 강한 근사가 된다.

== 재시작과 Luby

CDCL은 주기적 재시작 — 현재의 결정 이력을 잊고
최상위 사실에서 탐색을 다시 시작하는 것 — 으로부터
이득을 본다. 일정이 중요하다: 순수한 기하 재시작(매 $2^k$
충돌마다)은 짧은 예산의 epoch를 다시 방문하는 수열에
비해 성능이 떨어진다. *Luby 수열* —
$1, 1, 2, 1, 1, 2, 4, 1, 1, 2, 1, 1, 2, 4, 8, dots$ —
은 무작위화된 SAT 인스턴스에서 경험적으로 승리한다.

Luby 반복은 Knuth의 reluctant-doubling 공식이며 열 줄
안에 들어간다:

```rust
fn luby_index(i: usize) -> usize {
    let mut u = 1usize;
    let mut v = 1usize;
    for _ in 0..i {
        if (u & u.wrapping_neg()) == v { u += 1; v = 1; }
        else { v *= 2; }
    }
    v
}
```

외곽 CDCL 루프는 `epoch = 0, 1, 2, ...`에 대해
`cdcl_solve(clauses, base_conflicts * luby_index(epoch))`
를 결정적 판정이 나오거나 재시작 예산이 소진될 때까지
호출한다.

== 학습된 절 관리

학습된 모든 절을 영원히 저장하면 메모리가 부풀고 전파
속도가 느려진다. 표준적 해결책: *가장 쓸모없는* 학습된
절을 주기적으로 삭제한다. "쓸모"는 절별 활동도 점수
(전파기가 그 절을 단위 선행자로 사용할 때마다 bump됨)와
*LBD*(Literal Block Distance) — 절이 학습된 순간 그
리터럴들 사이의 서로 다른 결정 수준 개수 — 로 측정된다.
낮은 LBD 절("glue clauses", LBD ≤ 6)은 삭제로부터
보호되고, 나머지는 주기적 솎아내기의 대상이 된다.

```rust
fn reduce_learnt(state, owned, input_len, threshold) {
    // Keep glue clauses unconditionally.
    let mut candidates: Vec<_> = state.learnt_activity.iter()
        .enumerate()
        .filter(|(i, _)| state.learnt_lbd[*i] > 6)
        .collect();
    candidates.sort_by(|a, b| a.1.partial_cmp(b.1).unwrap());
    // Drop the lowest-activity half.
    // ...
}
```

== 종합

CDCL 솔버는 위 기구를 모두 포함하여 약 800줄에 들어간다.
adsmt의 `cdcl.rs`가 대략 이 크기이며, 신중한 독자는 그
주 루프를 한 시간 이내에 단계별로 따라갈 수 있다. 가장
중요한 규율은 *명시적 reason 태그를 동반한 trail 기반
전파*이다. trail과 reason 구조가 올바르고 나면 다른
모든 조각이 제자리에 들어맞는다.

다음 장은 이론 결합 — SAT 위에 있어서 여러 전문화된
이론 솔버들이 공유 sort 위에서 협력하도록 하는 계층 —
으로 방향을 튼다.
