= 가설추론 계층

== 가설추론(abduction) 대 연역(deduction)

고전적인 SMT는 순수하게 *연역적(deductive)*이다. 즉 주어진
논리식 $phi$ 에 대해 "$phi$ 가 충족 가능한가?"라는 질문에
답한다. 그 답은 판정(verdict) — Sat, Unsat, 또는 Unknown —
이며, 경우에 따라 증거 모형(witness model)이나 unsat core가
함께 제공된다.

*가설추론(abduction)*은 그 쌍대(dual) 질문이다. 솔버가
*해결하지 못한* 논리식 $phi$ 가 주어졌을 때, 어떤 추가
가설(hypothesis) $H$ 가 있으면 $phi$ 를 증명할 수 있을까?
구체적으로는 다음을 만족하는 최소의 $H$ 를 찾는 것이다.
$phi$ 가 목표의 부정을 표현할 때 $H union phi$ 가 unsat이
되거나, $phi'$ 이 목표 그 자체를 표현할 때 $H union phi'$
이 sat이 되도록.

```rust
pub struct AbductiveCandidate {
    pub hypothesis: Vec<Term>,
    pub justification: Justification,
    pub rank: Rank,
}
pub enum Justification {
    SldChain(Vec<HornStep>),
    TheoryGap { theory: TheoryName, missing: Term },
    QuantifierExhausted { var: Arc<Var>, body: Term },
}
```

증명 보조 도구로서의 SMT — adsmt가 지향하는 사용 사례 —
에서는, 가설추론적 후보(abductive candidate)야말로 솔버가
산출할 수 있는 가장 실행 가능한(actionable) 출력이다.
사용자(혹은 ITP 전술)는 "이것이 참인가?"를 묻고 있는 것이
아니라, "내 증명을 통과시키려면 무엇을 가정해야 하는가?"를
묻고 있는 것이다. 7장에서 본 Tier 4 격상(escalation)은 그러한
후보들을 직접 표면화한다.

== Horn 규칙과 SLD 사슬

가설추론을 위한 가장 깔끔한 환경은 *Horn 절(Horn clause)* —
최대 하나의 양성 리터럴을 가진 절 — 이다. Horn 규칙
$p_1 and p_2 and dots and p_n -> q$ 는 "$p_i$ 들이 성립하면
$q$ 도 성립한다"는 뜻이다. *사실(fact)*은 $n = 0$ 인 Horn
규칙, 즉 그저 $q$ 이다.

Horn 규칙 베이스 $R$ 과 목표 $G$ 가 주어졌을 때, *SLD
사슬(SLD chain)*은 $G$ 를, 어떤 규칙의 헤드와도 단일화할 수
없는 원자적 하위 목표들로 축약하는 유한한 후방 연쇄(backward
chaining) 단계 시퀀스이다. 그렇게 남은 하위 목표들이 곧
*가설추론적 가설(abductive hypothesis)*이다. 그것들을 가정하면
목표가 통과된다.

```rust
pub fn build_chain(goal: &Term, rules: &[HornRule], depth: usize)
    -> Option<SldChain>
{
    if depth == 0 { return None; }
    for rule in rules {
        if let Some(sigma) = unify(&rule.head, goal) {
            let mut sub_chains = Vec::new();
            let mut residual = Vec::new();
            for body_atom in &rule.body {
                let atom = apply(&sigma, body_atom);
                match build_chain(&atom, rules, depth - 1) {
                    Some(sub) => sub_chains.push(sub),
                    None => residual.push(atom),
                }
            }
            return Some(SldChain {
                steps: vec![HornStep { rule: rule.clone(), sigma }],
                sub_chains,
                residual,
            });
        }
    }
    None
}
```

잔여(residual) 원자들이란 단일화로 제거하지 못한 것들이다.
그것들이 가설추론적 가설이 된다.

== 최소화(Minimisation)

처음에 얻은 SLD 사슬이 최소(minimal)인 경우는 드물다. 단순한
후방 연쇄기는 일치되지 않은 모든 하위 목표를 누적하는데,
그중 일부는 다른 것들이나 배경 이론 공리에 의해 이미 함의되어
중복이다. adsmt의 `minimize` 패스가 잔여를 순회한다.

```rust
pub fn minimize(residual: &[Term], ctx: &TheoryContext) -> Vec<Term> {
    let mut keep: Vec<Term> = Vec::new();
    for atom in residual {
        if entailed_by(atom, &keep, ctx) { continue; }
        keep.retain(|kept| !entailed_by(kept, &[atom.clone()], ctx));
        keep.push(atom.clone());
    }
    keep
}
```

`entailed_by` 는 활성화된 이론 컨텍스트 — UF 합동(congruence),
산술 경계, BV 리터럴 평가 — 를 참조하여 중복 원자를
방출(discharge)한다. 남은 목록이 활성 이론들 하에서의 최소
커버이다.

== 순위 매기기(Ranking)

여러 개의 서로 다른 최소 가설이 같은 목표를 방출할 수 있다.
`rank` 는 후보들을 *사용자 비용(user-cost)* 대용 지표로
정렬한다. 원자 수가 적은 것이 선호되며, 더 단순한 원자가
선호되고, 이미 범위(in-scope) 안에 등장한 원자가 새로운 원자보다
선호된다.

```rust
pub fn rank(candidates: &mut Vec<AbductiveCandidate>, in_scope: &HashSet<Term>) {
    candidates.sort_by_key(|c| (
        c.hypothesis.len(),
        c.hypothesis.iter().map(term_depth).sum::<usize>(),
        c.hypothesis.iter().filter(|t| !in_scope.contains(*t)).count(),
    ));
}
```

사용자는 가공되지 않은 집합이 아니라 순위가 매겨진 목록을 본다.
Lean 4 의 `smt_abduce` 전술과 LSP 코드-액션 메뉴 모두 이 순서를
존중한다. 즉, 최상위 후보는 추천 가설이며, 나머지는 사용자가
고를 수 있는 대안이다.

== 워크플로우 통합

엔진의 `check_sat` 루프 안에서 가설추론은 *간극(gap)* — 지반
추론(ground reasoning), 이론 결합(theory combination), 혹은
한정자 인스턴스화가 확정적 판정에 미치지 못하는 지점 — 에 의해
구동된다.

```rust
pub enum SatResult {
    Sat(Model),
    Unsat(UnsatCore),
    Abductive { candidates: Vec<AbductiveCandidate> },
    Unknown(UnknownReason),
}

fn abductive_escalation(state: &SolverState) -> Vec<AbductiveCandidate> {
    let mut out = Vec::new();
    if let Some(quant_gap) = state.exhausted_quantifier() {
        out.push(quantifier_to_candidate(quant_gap));
    }
    if let Some(theory_gap) = state.theory_unknown() {
        out.push(theory_gap_to_candidate(theory_gap));
    }
    if !out.is_empty() { return out; }
    let goal = state.current_goal();
    let chains = build_chains_with_horn_base(&goal, state.horn_rules(), MAX_DEPTH);
    chains.into_iter()
        .map(|chain| chain_to_candidate(chain, state.theory_context()))
        .collect()
}
```

네 가지 간극 범주 — 한정자 고갈(exhausted quantifier), 이론
미지(theory unknown), Horn-사슬 잔여(Horn-chain residual),
고전 공리 요구(classical-axiom requirement) — 는 각각 동일한
반환 경로로 후보를 공급한다. 호출자는 표시할 단일하고
균질한 `AbductiveCandidate` 목록을 받는다.

== Tier 4 — 후보를 인증서(certificate)로 승격

사용자(혹은 ITP 전술)는 가설추론적 후보를 받아들일 때, 그
가설 원자들을 단언 집합(assertion set)에 추가함으로써 그렇게
한다. `check_sat` 을 다시 호출하면 그 원자들은 이제 지반
가정(ground assumption)이 되며, 후보를 만든 사슬이 완결되고,
솔버는 확정적인 판정을 내놓는다.

인증서 형식(9장)은 가설추론적 수용(abductive acceptance)을
명시적으로 기록한다.

```text
(cert.v1
  (steps
    (step :rule abductive_assume
          :id 17
          :hypothesis ((P a) (Q b))
          :justification (sld_chain ...))
    ...))
```

하류의 ITP — Lean 4, Rocq, 또는 Isabelle — 는 이 단계를 명시적
`sorry` 형태의 자리표시자(placeholder)로 본다. 즉, 가설들에
*조건부(conditional)*인 증명이며, 가설들은 사용자가 다른 수단을
통해 방출해야 할 의무로 표면화된다. 반사(reflection) 계층
(10장)은 인증서를 ITP 친화적인 전술 스크립트로 렌더링하는데,
각 `abductive_assume` 은 사용자가 도입(introduce)할 수 있는
이름 있는 가설이 된다.

== 가설추론이 우아하게 퇴화할 때

E-매칭(E-matching)도, 이론 닫힘(theory closure)도, 가설추론적
연쇄(abductive chaining)도 쓸 만한 후보를 만들어내지 못하면,
솔버는 `Unknown(UnknownReason::AbductiveExhausted)` 를 반환한다.
이것은 일반적인 SMT의 `unknown` 보다 엄격히 더 많은 정보를
담는다. 즉 호출자는 가설추론 계층이 시도되었고 아이디어가
고갈되었다는 사실을 알게 되며, 상류의 어떤 계층이 예산 한계에
도달한 것이 아니라는 것도 안다.

대화형 정리 증명기 입장에서, "unknown이지만 내가 시도하고 폐기한
열다섯 개의 후보 가설은 다음과 같다"는 그 자체로 유용한 디버깅
출력이다. `UnknownReason::AbductiveExhausted` 변형은 시도 로그를
함께 운반하며, LSP는 "가설추론 추적 보기(show abductive trace)"
코드-액션이 달린 진단(diagnostic)으로 이를 표면화한다.

== 전술로서의 SMT에 이것이 왜 중요한가

전통적인 전술로서의 SMT(SMT-as-tactic)는 증명 보조 도구에
이진 판정만을 전달한다. 동작할 때는 좋지만, 동작하지 않을 때
사용자는 실행 가능한 피드백이 없다. 가설추론적 후보는 그 게임
규칙을 바꾼다. *실패한* 방출조차 사용자가 받아들이거나 목표를
정련하는 데 사용할 수 있는 구체적 가설들을 산출한다.

이것이 애초에 adsmt를 만든 동기이다. "오직 연역적 판정만(deductive
verdict only)" 모드도 괜찮다 — adsmt는 어느 SMT 솔버 못지않게
그 일을 잘 해낸다 — 그러나 *가설추론적 탈출구(abductive escape)*
가 있기에 기존 솔버를 감싸는 대신 새 솔버를 만들고 있는 것이다.
9장에서는 가설추론적 단계가 하류 ITP에서 복원 가능하도록 만드는
인증서 기제(certificate machinery)를 다룬다.
