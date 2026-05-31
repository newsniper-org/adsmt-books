= 인증서 AST 참조

이 부록은 `adsmt-cert` (9장)의 모든 `StepBody` 변형에 대한
참조다. 각 항목은 S-식 문법, Rust 생성자, 의존성, 그리고
검사기 규칙을 나열한다.

== 필수 12종(커널 규칙)

=== `refl`
- *Syntax*: `(step :rule refl :id <id> :term <t>)`
- *Rust*: `StepBody::Refl(t)`
- *Dependencies*: none
- *Checker*: 빈 가설 집합으로 `t = t` 를 방출한다

=== `trans`
- *Syntax*: `(step :rule trans :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::Trans { lhs, rhs }`
- *Dependencies*: two prior steps, each concluding an equality
- *Checker*: 피벗이 일치해야 한다(`(a=b)`, `(c=d)` 에서 `b == c`).
  결합된 가설로 `a = d` 를 방출한다

=== `eq_mp`
- *Syntax*: `(step :rule eq_mp :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::EqMp { lhs, rhs }`
- *Dependencies*: an equality $A = B$ and a proof of $A$
- *Checker*: 결합된 가설로 $B$ 를 방출한다

=== `abs`
- *Syntax*: `(step :rule abs :id <id> :var <var> :body <ref>)`
- *Rust*: `StepBody::Abs { var, body }`
- *Dependencies*: one prior step concluding an equality
- *Checker*: $lambda x . t_1 = lambda x . t_2$ 를 방출한다

=== `beta`
- *Syntax*: `(step :rule beta :id <id> :term <t>)`
- *Rust*: `StepBody::Beta(t)`
- *Dependencies*: none
- *Checker*: $t$ 는 $(lambda x . b) a$ 형태여야 한다.
  $(lambda x . b) a = b[x mapsto a]$ 를 방출한다

=== `deduct`
- *Syntax*: `(step :rule deduct :id <id> :hyp <ref> :conc <ref>)`
- *Rust*: `StepBody::Deduct { hyp, conc }`
- *Dependencies*: a hypothesis step and a conclusion step
- *Checker*: $A$ 가 가설 항일 때 $A => B$ 를 방출한다. 가설
  집합에서 $A$ 를 제거한다

=== `inst`
- *Syntax*: `(step :rule inst :id <id> :rule <ref> :var <var> :term <t>)`
- *Rust*: `StepBody::Inst { rule, var, term }`
- *Dependencies*: a prior step concluding a universal
- *Checker*: `var` 를 `term` 으로 치환한 본문을 방출한다

=== `inst_type`
- *Syntax*: `(step :rule inst_type :id <id> :rule <ref> :var <tyvar> :ty <ty>)`
- *Rust*: `StepBody::InstType { rule, var, ty }`
- *Dependencies*: a prior step polymorphic in `var`
- *Checker*: 타입 변수가 치환된 본문을 방출한다

=== `assume`
- *Syntax*: `(step :rule assume :id <id> :term <t>)`
- *Rust*: `StepBody::Assume(t)`
- *Dependencies*: none
- *Checker*: 가설 집합 $\{t\}$ 로 $t$ 를 방출한다

=== `theory`
- *Syntax*: `(step :rule theory :id <id> :theory <name> :witness <witness>)`
- *Rust*: `StepBody::Theory { theory, witness }`
- *Dependencies*: 증거-의존적(UF 증거는 등식들을 인용, LIA 증거는
  선형 경계를 인용, 기타)
- *Checker*: 명명된 이론의 증거 검증기로 디스패치한다

=== `instance`
- *Syntax*: `(step :rule instance :id <id> :class <c> :dict <d>)`
- *Rust*: `StepBody::Instance { class, dict }`
- *Dependencies*: 없음(인스턴스 사전은 일급 항)
- *Checker*: 사전을 클래스 타입의 항으로 방출한다

=== `assumed`
- *Syntax*: `(step :rule assumed :id <id> :term <t>)`
- *Rust*: `StepBody::Assumed(t)`
- *Dependencies*: none
- *Checker*: 전역 "preamble assumptions" 가설 태그와 함께
  $t$ 를 방출한다

== 가설추론 3종

=== `abductive_assume`
- *Syntax*: `(step :rule abductive_assume :id <id> :hypothesis (<t>+) :justification <j>)`
- *Rust*: `StepBody::AbductiveAssume { hypothesis, justification }`
- *Dependencies*: 직접적으로는 없음; `justification` 은 이전
  단계를 인용할 수 있다
- *Checker*: 각 $t$ 를 별개의 결론으로 방출하며, 모두 가설추론
  유래(provenance) 태그가 붙는다

=== `abductive_accept`
- *Syntax*: `(step :rule abductive_accept :id <id> :hypothesis <ref> :ground (<t>+))`
- *Rust*: `StepBody::AbductiveAccept { hypothesis, ground }`
- *Dependencies*: an `AbductiveAssume` step plus the ground terms it discharges
- *Checker*: 지반 항들이 명명된 가설을 모듈로 사슬을 닫는지
  확인한다

=== `classical_axiom`
- *Syntax*: `(step :rule classical_axiom :id <id> :axiom <kind> :instantiation (<t>+))`
- *Rust*: `StepBody::ClassicalAxiom { axiom, instantiation }`
- *Dependencies*: none
- *Checker*: `axiom` 이 `preamble.classical-axioms` 에 없으면
  거부한다. 그렇지 않으면 공리의 인스턴스화된 형태를 방출한다

== 증거 부속 문법(Witness sub-grammar)

이론 증거(theory witness)는 자체 부속 문법을 가진다.

```text
witness ::= (uf  :equalities ((= <t> <t>)+))
          | (lia :bounds (<bound>+))
          | (lra :bounds (<bound>+))
          | (bv  :bits ((<i> <0|1>)+))
          | (arr :rows ((<read-or-store>)+))
          | (dt  :discriminants ((<ctor>)+))
```

각 이론의 검사기가 자신의 증거 형태를 검증한다. 증거 형식은
*동결(frozen)* 되어 있다. 새로운 이론은 semver-가산적으로 새로운
증거 변형을 추가한다.

== 판정(Verdict)

```text
verdict ::= (verdict sat   :model ((<var> <val>)+))
          | (verdict unsat :final-step <ref>)
          | (verdict abductive :candidates ((<ref>)+) :final-step <ref>)
          | (verdict unknown :reason <text>)
```

`verdict` 는 인증서의 유일한 필수 꼬리 블록이다. 검사기는
이를 사용하여 다음을 확인한다. `final-step` 이 존재할 것, 그
결론이 판정 형태와 일치할 것, 가설 집합이 비어 있을 것(Unsat)
이거나 가설추론 선언과 일치할 것(Abductive)이거나 모델과
일관될 것(Sat).
