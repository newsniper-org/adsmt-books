= 한정자

== 왜 한정자가 어려운가

6장의 모든 이론은 *기저*(ground) 원자를 가정한다 — 식
안에 전칭이나 존재 한정자가 없다고 본다. 한정자를
넣으면 충족 가능성 문제는 일반적으로 결정 불가능해진다:
임의의 1차 논리식을 받아 언제나 옳은 답을 돌려주는
알고리즘은 존재하지 않는다.

대신 SMT 솔버가 하는 일은 *휴리스틱 인스턴스화*이다:
전칭 식 $forall x. phi(x)$가 단언되어 있고 식의 나머지
부분이 구체적 기저 항들을 산출한 상태라면, 그 기저 항들을
$phi(x)$에 후보 인스턴스화로 꽂아 넣어 기저 원자로
추가한다. 이렇게 하면 내부 솔버 루프의 일이 가능해진다:
원래의 양화 식이 아니라 점점 늘어나는 인스턴스화의
더미를 보게 되기 때문이다. *어떤* 항을 어떤 순서로
치환할지의 문제가 문제의 핵심이 된다.

== E-매칭

지배적 기법은 *E-매칭*이다. 발상은 이렇다: 식
$forall x. phi(x)$에 *트리거* — 속박 변수 $x$를 포함하는
$phi$의 부분 패턴 — 가 주석으로 달려 있다. 식의 기저
부분이 (등식 추론 modulo) 트리거와 매치되는 항을
산출하면 $x$를 그 일치 부분항으로 인스턴스화한다.

예를 들어 트리거 $f(g(x))$와 함께
$forall x. f(g(x)) > 0$이 주어지고 기저 항 $f(g(a))$가
이미 범위 안에 있다면 $x := a$로 인스턴스화한다.
인스턴스화된 원자 $f(g(a)) > 0$이 SAT/이론 계층에
합류한다.

```rust
pub struct Trigger {
    pub kind: TriggerKind,
    pub bound: Vec<Arc<Var>>,
}
pub enum TriggerKind {
    Single(Term),
    Multi(Vec<Term>),
}
```

매처는 *항 우주* — 식에 등장하는 기저 부분항들의 집합 —
를 훑으며 매치를 찾는다. 단일 패턴 트리거는 패턴의 강성
부분(상수와 트리거의 flex 집합에 속하지 않은 속박 변수)
이 우주 항과 일치하고 flex 부분이 치환을 받아 갈 때 우주
항과 매치된다.

```rust
fn match_one(pattern: &Term, target: &Term, bound: &[Arc<Var>])
    -> Option<Vec<(Arc<Var>, Term)>>
{
    let mut sigma = IndexMap::new();
    if extend_match(pattern, target, bound, &mut sigma) {
        Some(sigma.into_iter().collect())
    } else { None }
}
```

== Miller 패턴

*Miller 패턴*은 모든 flex 부분-적용이 $F(x_1, dots, x_n)$
형태이며 $x_i$들이 서로 다른 속박 변수인 트리거 패턴이다.
Miller 패턴은 고차 단일화의 병리 없이 선형 시간 매칭
알고리즘을 허용한다. adsmt는 Miller 패턴을 기본으로
하고, 사용자가 어쨌든 원할 이유가 있는 비-Miller 패턴을
위해 `:trigger!` 탈출구를 노출한다.

== 계층(Tier) 단계적 격상

E-매칭은 인스턴스화를 찾지 못할 수 있다: 우주가 트리거
형태의 어떤 항도 포함하지 않을 수 있기 때문이다. adsmt는
일련의 *계층*을 통해 단계적으로 격상하며, 각각이 이전
것보다 더 공격적이다:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*계층*], [*전략*]),
  [1], [항 우주에 대한 Miller E-매칭.],
  [2], [충돌-주도 인스턴스화 — 기존 기저 단언과 모순되는 인스턴스화를 고른다.],
  [3], [유계 열거 — 깊이 예산까지 후보 부분항을 열거한다.],
  [4], [가설추론적 격상 — 양화 식을 가설추론적 후보 가설로 방출한다(8장).],
)

```rust
pub fn instantiate_with_tier(var, body, universe) -> (Vec<Term>, Tier) {
    let res = instantiate_one(var, body, universe);
    if !res.is_empty() {
        return (res, Tier::One);
    }
    let res = enumerate(var, body, universe, DEFAULT_TIER3_BUDGET);
    if !res.is_empty() {
        return (res, Tier::Three);
    }
    (Vec::new(), Tier::Exhausted)
}
```

계층 2(충돌 기반)와 계층 4(가설추론)는 이웃 계층으로부터의
정보를 요구한다. 계층 4는 8장에서 다룬다.

== 트리거 학습

손으로 고른 트리거는 사용자의 책임이지만, 아무것도
주어지지 않은 경우 adsmt의 `learn_triggers` 도우미가
자동으로 덮개(covering) 집합을 고른다. 알고리즘은 본문의
적용 부분항을 깊이 순으로 훑으며, 모든 flex 변수를
덮는 가장 작은 패턴을 탐욕적으로 선택한다:

```rust
pub fn learn_triggers(body: &Term, flex: &[Arc<Var>]) -> Option<Trigger> {
    let mut candidates = Vec::new();
    collect_apps(body, &mut candidates);
    candidates.sort_by_key(term_depth);
    let mut covered = HashSet::new();
    let mut selected = Vec::new();
    for cand in candidates {
        let cand_flex = flex_vars_in(&cand, flex);
        if cand_flex.iter().all(|v| covered.contains(v)) { continue; }
        for v in &cand_flex { covered.insert(v.clone()); }
        selected.push(cand);
        if covered.len() == flex.len() { break; }
    }
    if covered.len() != flex.len() { return None; }
    if selected.len() == 1 {
        Some(Trigger::single(selected.pop().unwrap(), flex.to_vec()))
    } else {
        Some(Trigger::multi(selected, flex.to_vec()))
    }
}
```

덮개는 성공적인 E-매치가 모든 flex 변수를 인스턴스화하도록
보장한다. 탐욕적 깊이 순서는 작고 자주 매치되는 패턴을
먼저 고르는 경향이 있는 휴리스틱이다.

== E-그래프

순수 E-매처는 평평한 `TermUniverse`를 훑는다. 더 정교한
대안 — *E-그래프* — 는 합동 폐포로 증강된 해시-콘즈된
항 저장소를 유지하여, 명시적 우주 항뿐 아니라 모든
*도출된 합동* 항도 노출한다.

```rust
pub struct EGraph {
    nodes: Vec<ENode>,
    parent: Vec<ENodeId>,
    class_parents: HashMap<ENodeId, Vec<ENodeId>>,
    hash_cons: HashMap<ENodeKey, ENodeId>,
    scope_stack: Vec<EGraphSnapshot>,
}
```

`add`는 항을 그래프에 낮추고 동치류 id를 반환한다.
`merge`는 두 동치류를 통합하며 합동 폐포를 폭포처럼
일으킨다 — 두 부모 E-노드의 자식이 동치가 되면 부모들도
병합된다. `as_universe`는 그래프를 E-매처가 소비할 수
있는 평평한 `TermUniverse`로 다시 투영한다.

E-그래프 통합은 완전성을 산다: 평평한 우주가 놓친
트리거 매치를 e-그래프의 합동 폐포가 산출한다면 e-그래프가
그것을 잡는다.

== 엔진 루프에서의 한정자 인스턴스화

엔진의 `check_sat` 루프는 연속된 기저-단편 검사 사이에서
한정자 인스턴스화를 실행한다:

```rust
const QUANTIFIER_ROUNDS: usize = 3;
let mut instantiations: Vec<Term> = Vec::new();
for round in 0..QUANTIFIER_ROUNDS {
    let mut combined = self.all_literals();
    for inst in &instantiations { combined.push((inst.clone(), true)); }
    match self.check_ground(&combined) {
        SatResult::Sat => {
            let (quants, rest) = partition_quantifiers(&combined);
            if quants.is_empty() { return SatResult::Sat; }
            let universe = collect_universe(&rest);
            for (var, body) in &quants {
                for inst in instantiate_one(var, body, &universe) {
                    if !instantiations.iter().any(|t| t.alpha_eq(&inst)) {
                        instantiations.push(inst);
                    }
                }
                // Tier 2 and Tier 3 fallback...
            }
            if instantiations.len() == prev_len { return SatResult::Sat; }
        }
        other => return other,
    }
}
// Tier 4 — abductive escalation
return SatResult::Abductive { candidates: build_tier4_candidates(...) };
```

매 라운드는 새 인스턴스화를 추가할 수 있다. 결정적
판정이 나오거나, 새 인스턴스화가 나타나지 않거나(Sat),
라운드 예산이 소진(계층 4 가설추론적 격상)될 때까지
루프가 이어진다.

== 왜 "최선 노력"인가

계층 격상을 동반한 E-매칭은 *휴리스틱*이다. 식을
해소할 인스턴스화가 존재해도 그것을 찾지 못할 수 있다.
SMT 솔버 일반은 이 거래를 받아들인다: 대안 — 한정자의
완전한 처리 — 은 이론 결합과 양립 불가능하거나 사용
불가능할 만큼 비싸기 때문이다.

adsmt가 추가하는 것은 계층 4 탈출구이다: 항-수준
휴리스틱이 모두 소진되었을 때 한정자가 *가설추론적
후보*가 된다. 사용자가 보는 것은 "unknown"이 아니라
"이 가설을 받아들이면 풀 수 있다"이다. 그 가설은 어떤
특정 증거의 존재성 자체이며, 그것을 받아들이면 증명이
통과하고, 사용자(또는 하류 ITP)가 그 가정이 적절한지
결정하게 된다.

다음에는 그 가설추론 계층으로 향한다.
