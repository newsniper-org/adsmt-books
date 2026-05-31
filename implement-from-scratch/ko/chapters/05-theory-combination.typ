= 이론 결합

== 결합 문제

산술과 배열 연산이 섞인 SMT 식을 생각해보자:

$ a[i] + a[j] > 0 and a[i] = -a[j] and i != j $

순수 산술 솔버도, 순수 배열 솔버도 이것을 단독으로
결정할 수 없다. 산술 솔버는 `a[i]`를 어떻게 해석할지
모른다 — 그것을 불투명한 변수로 본다. 배열 솔버는 `+`를
어떻게 해석할지 모른다 — *`i = j`라면 `a[i] = a[j]`*
같은 것은 추론할 수 있어도 양변의 합이 무엇인지는 모른다.
이 형태의 식을 결정하려면 두 솔버가 *협력*해야 한다:
각각이 *공유 변수*에 대해 알아낸 정보를 다른 쪽에 공유
하고, 모순이 나오거나 결합 모델이 존재할 때까지 그렇게
한다.

이것이 *이론 결합* 문제이다. 고전적 해법은
*Nelson-Oppen* 결합이며, 관여하는 이론들이 *안정적
무한*(stably infinite)이고 시그니처가 서로소일 때
적용 가능하다. adsmt는 *정중한 결합*(polite combination)
이라 불리는 일반화를 사용하는데, 시그니처 서로소 조건을
약간 더 많은 기구를 대가로 제거한다.

== Nelson-Oppen 한눈에 보기

Nelson-Oppen 프로토콜은 참여 이론 솔버들을 보조를 맞춰
실행한다. 공유 변수는 둘 이상의 이론이 처리하는 원자에
등장하는 변수들이다. 각 이론은:

#enum(numbering: "(1)",
  [자신이 해석할 수 있는 모든 단언 원자를 받고,],
  [자신이 도출한 공유 변수들 사이의 등식을 보고하며,],
  [다른 이론들이 도출한 등식들의 합집합을 받고,],
  [(a) `false`를 도출(불만족)하거나 (b) 새 등식이 더 이상
   나타나지 않을 때(결합에서 만족) 까지 반복한다.],
)

이 프로토콜의 정확성은 안정적 무한 조건에 기댄다: 각
이론의 모든 모델은, 단독으로 볼 때, 각 sort에서 무한히
많은 원소를 갖도록 확장될 수 있어야 한다. 두 이론 모두
오직 유한 모델만 산출한다면, 추가의 기수
(cardinality) 추론이 필요하다.

== 정중한 결합

정중한 결합은 시그니처 서로소 요구를 떼고, 기수 추론을
명시적으로 처리한다. 각 이론은 *정중함 증거*(politeness
witness)를 노출하여, sort별로 모델의 기수에 부여하는
상한(있다면)을 기술한다. 예컨대 `BV<8>` sort는 기수가
최대 $2^8 = 256$이고, `Int` sort는 $omega$이다. 결합
기구는 모든 참여 이론에 걸친 *infimum*을 골라, 결합 모델이
그 sort에서 최대 그만큼의 원소를 가진다고 단언한다.

구체적으로 각 이론은 다음을 구현한다:

```rust
pub trait Theory: Send {
    fn name(&self) -> &'static str;
    fn handles_sort(&self, ty: &Type) -> bool;
    fn assert(&mut self, lit: Literal) -> AssertResult;
    fn check(&mut self) -> CheckResult;
    fn explain(&self) -> Option<TheoryWitness>;
    fn derive_equalities(&self) -> Vec<(Term, Term)>;
    fn derive_disequalities(&self) -> Vec<(Term, Term)>;
    fn cardinality_witness(&self, sort: &Type) -> PoliteWitness;
    fn push(&mut self);
    fn pop(&mut self, levels: u32);
    fn reset(&mut self);
}
```

결합 오케스트레이터(`adsmt-theory::polite::Combination`)
는 `Vec<Box<dyn Theory>>`를 소유하고 프로토콜을 구동한다:

```rust
pub fn check(&mut self) -> CombinedCheck {
    loop {
        // 1. Per-theory check.
        for t in &mut self.theories {
            match t.check() {
                CheckResult::Unsat { witness } => return Unsat { ... },
                CheckResult::Unknown { reason } => return Unknown { ... },
                CheckResult::Sat => continue,
            }
        }
        // 2. Gather derived equalities.
        let new_eqs = self.gather_derived_equalities();
        if new_eqs.is_empty() {
            // 3. Cardinality enforcement.
            if let Some(unsat) = self.enforce_cardinality() {
                return unsat;
            }
            return Sat;
        }
        // 4. Re-broadcast new equalities.
        for (a, b) in new_eqs { self.assert(Literal::positive(mk_eq(a, b))?); }
    }
}
```

루프가 수렴하는 것은 매 라운드가 서로 다른 동치류 개수를
줄이거나 새 정보를 산출하지 못하기 때문이다.

== 기수 강제

결합 증거가 sort $sigma$에서 유한 기수 한계 $n$을
부여하는 각 sort에 대해, 오케스트레이터는 $sigma$에서
단언된 불등식들을 모으고 불등식 그래프의 최대 클릭을
계산한다. 클릭 크기가 $n$을 초과하면 결합 모델이
$sigma$에서 너무 많은 원소를 갖는 것이다 — 모순.

```rust
fn enforce_cardinality(&self) -> Option<CombinedCheck> {
    let diseqs_by_sort = self.gather_disequalities_by_sort();
    for (sort, pairs) in &diseqs_by_sort {
        let bound = self.cardinality_bound(sort);
        let Some(bound) = bound else { continue; };
        let clique = max_disequality_clique(pairs, bound + 1);
        if clique > bound {
            return Some(CombinedCheck::Unsat { /* polite witness */ });
        }
    }
    None
}
```

`max_disequality_clique`는 진행 중 최댓값이 한계를
초과하면 조기 종료하는 유계 클릭 열거이다. 실제로는
브루트포스로 충분할 만큼 작은 탐색 공간이다.

== 리터럴을 이론에 라우팅

모든 리터럴이 모든 이론에 관련 있는 것은 아니다. 결합은
피연산자 sort를 살펴 어떤 이론이 어떤 리터럴을 받아야
하는지 결정한다: 등식 리터럴 `(= a b)`는 `a.type_of()`를
처리하는 모든 이론으로 라우팅된다. 비-등식 리터럴(이론
특화 술어, 예컨대 `(> x y)`)은 그 술어를 소유하는 이론으로
간다.

```rust
pub fn assert(&mut self, lit: Literal) -> Vec<(String, AssertResult)> {
    let routing_sort = if let Some((a, _)) = lit.term.dest_eq() {
        a.type_of()
    } else {
        lit.term.type_of()
    };
    let mut out = Vec::new();
    for t in &mut self.theories {
        if t.handles_sort(&routing_sort) {
            out.push((t.name().to_string(), t.assert(lit.clone())));
        }
    }
    out
}
```

어떤 이론에서든 충돌이 발생하면 브로드캐스트가 단락되어
즉시 반환한다 — adsmt는 이 최적화를 명시적으로 안착시켰는데,
원래 초안은 한 이론이 불가능을 보고한 후에도 다른 모든
이론에 단언을 행복하게 계속하고 있었기 때문이다.

== Push와 pop

SAT 계층은 결정과 백트랙을 구동한다. 각 단언은 그것을
도입한 결정을 SAT 계층이 넘어 백트랙할 때 취소되어야 할
수 있다. 결합은 같은 것을 모든 이론에 브로드캐스트하는
`push` / `pop` 연산을 지원한다:

```rust
pub fn push(&mut self) {
    for t in &mut self.theories { t.push(); }
}
pub fn pop(&mut self, levels: u32) {
    for t in &mut self.theories { t.pop(levels); }
}
```

각 이론은 자체 스냅샷 기법을 구현한다. 예를 들어 UF는
union-find 구조를 스냅샷하고, LIA는 한계 테이블을 스냅샷
하며, 배열은 지역 불등식 테이블과 확장성(extensionality)
대기열을 스냅샷한다. 패턴은 동일하다: 각 이론이
스냅샷의 `scope_stack`을 소유하고 `pop`에서 복원한다.

== 엔진 측 라우팅

`adsmt-engine`에서 `dpllt::run_once` 함수는 단일 반복을
구동한다: 리터럴 → 결합으로 단언 → 결합 검사. 적극적
충돌 단락이 루프에 보인다:

```rust
pub fn run_once(combo: &mut Combination, literals: &[(Term, bool)]) -> LoopOutcome {
    for (atom, polarity) in literals {
        let lit = build_lit(atom, *polarity);
        for (name, r) in combo.assert(lit) {
            if let AssertResult::Conflict { witness } = r {
                return LoopOutcome::Unsat { theory: name, witness };
            }
        }
    }
    match combo.check() {
        CombinedCheck::Sat => LoopOutcome::Sat,
        CombinedCheck::Unsat { theory, witness } => LoopOutcome::Unsat { theory, witness },
        CombinedCheck::Unknown { theory, reason } => LoopOutcome::Unknown { theory, reason },
    }
}
```

이것이 SAT 계층과 이론 계층이 의사소통하는 수준이다.
SAT 계층은 자신의 현재 trail과 일치하는 리터럴 목록을
`run_once`에 준다. `run_once`는 이론들이 동의하는지,
그렇지 않다면 어떤 증거를 산출했는지를 보고한다.

== 선택적 추가물 — EGraph

adsmt의 `adsmt-theory::egraph_theory`는 `Theory`
트레이트 안에 EUF e-그래프를 감싼다. e-그래프는 해시-콘즈
(hash-consed) 항 우주와, *합동 폐포*(congruence closure)
로 증강된 union-find 구조를 유지한다: 두 함수 적용
$f(a)$와 $f(b)$가 관찰되고 $a$와 $b$가 같은 동치류에
있을 때마다, 래퍼는 $f(a)$와 $f(b)$도 병합한다. 이 폭포는
고정점까지 발화하며, 합동-폐포된 등식을 산출하여
`derive_equalities`로 노출한다.

이는 *덧셈적*이다 — UF와 EGraph는 나란히 등록될 수 있다.
EGraph는 UF가 직접적인 리터럴-쌍 입력에서만 알아채는
합동 함수 적용을 기여한다.

== 요약

이론 결합은 SMT 솔버를 SAT 솔버와 구별짓는 계층이다.
프로토콜 — 정중하거나 Nelson-Oppen — 은 솔버
구성요소들에 걸쳐 잘 정의된 협력 알고리즘이며, 각
구성요소는 작고 감사 가능하다. 다음 장은 개별 이론
솔버들을 살펴본다.
