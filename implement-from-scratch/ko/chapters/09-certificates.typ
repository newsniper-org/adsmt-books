= 인증서(Certificates)

== 인증서를 만드는 수고가 왜 필요한가?

현대적인 SMT 솔버는 수만 줄, 대략 $10^5$ 줄에 달하는 정교한
코드 덩어리이다. 사용자에게 그 판정(verdict)을 그저 믿어달라고
요구하는 것은 무리한 요구다 — 특히 SMT가 가장 가치 있는 안전
필수(safety-critical) 검증 환경에서는 더욱 그렇다.

해법은 *증명 인증서(proof certificate)*다. 판정이 어떻게
도출되었는지에 대한 구조화된 기록으로서, 훨씬 단순한 외부
검사기(external checker)가 이를 재검증할 수 있도록 설계되어
있다. 검사기는 CDCL, 이론 결합, 한정자 인스턴스화를 이해할
필요가 없으며, 고정된 추론 규칙 집합에 대해 각 단계를
검증하기만 하면 된다.

adsmt의 인증서 형식은 `adsmt-cert` 이다. 2장의 12개 커널 규칙에
대응하는 12종의 단계(step kind)와 세 개의 가설추론 마커, 그리고
약간의 이론 증거(theory witness)로 구성된 S-식(S-expression)
언어이다.

== 형식 개관

```text
(cert.v1
  (preamble
    (kernel-version "0.19")
    (cert-version "1")
    (classical-axioms (lem peirce))
    (theories (uf lia bv)))
  (steps
    (step :rule refl   :id 1 :term (= x x))
    (step :rule assume :id 2 :term (P x))
    (step :rule beta   :id 3 :input 2 :term ...)
    ...
    (step :rule deduct :id 17 :conclusion (=> (P x) (Q y))))
  (verdict unsat
           :final-step 17))
```

각 단계는 고유한 수치 `id` 로 식별된다. 단계들은 id로 이전
단계를 참조하므로, 의존 구조는 `verdict` 가 명시한 최종
단계에서 끝나는 DAG를 이룬다.

== StepBody — 12 + 3 + …

Rust 타입은 형식을 직접 반영한다.

```rust
pub struct Cert {
    pub preamble: Preamble,
    pub steps: Vec<Step>,
    pub verdict: Verdict,
}
pub struct Step { pub id: StepId, pub body: StepBody }

pub enum StepBody {
    Refl(Term),
    Trans { lhs: StepId, rhs: StepId },
    EqMp { lhs: StepId, rhs: StepId },
    Abs { var: Arc<Var>, body: StepId },
    Beta(Term),
    Deduct { hyp: StepId, conc: StepId },
    Inst { rule: StepId, var: Arc<Var>, term: Term },
    InstType { rule: StepId, var: Arc<TyVar>, ty: Type },
    Assume(Term),
    Theory { theory: TheoryName, witness: TheoryWitness },
    Instance { class: Term, dict: Term },
    Assumed(Term),
    AbductiveAssume { hypothesis: Vec<Term>, justification: AbductionJustification },
    AbductiveAccept { hypothesis: StepId, ground: Vec<Term> },
    ClassicalAxiom { axiom: ClassicalAxiomKind, instantiation: Vec<Term> },
}
```

필수 12종은 2장의 커널을 반영한다. 가설추론 삼총사는 8장의
탈출구들을 처리한다. 고전 공리 마커는 LEM, Peirce, 혹은 다른
배중률(excluded middle) 계열 공리에 의존하는 단계를 처리한다 —
이러한 공리는 preamble에 미리 선언되어야 검사기가 소비자가
지정된 공리를 수용하지 않을 경우 인증서를 거부할 수 있다.

== 기록기(Recorder)

커널의 열두 규칙 구현은 인증서 단계를 직접 방출하지 않는다 —
그렇게 하면 커널 TCB가 형식에 대한 관심사와 얽히게 되기
때문이다. 대신 기록기는 커널을 감싸는 얇은 관찰자(observer)다.

```rust
pub struct CertRecorder {
    steps: Vec<Step>,
    next_id: u64,
    preamble: PreambleBuilder,
}

impl CertRecorder {
    pub fn record_refl(&mut self, t: Term) -> StepId {
        let id = self.alloc_id();
        self.steps.push(Step { id, body: StepBody::Refl(t) });
        id
    }
    pub fn record_trans(&mut self, lhs: StepId, rhs: StepId) -> StepId {
        let id = self.alloc_id();
        self.steps.push(Step { id, body: StepBody::Trans { lhs, rhs } });
        id
    }
    // ... one method per StepBody variant ...

    pub fn finalize(self, verdict: Verdict) -> Cert {
        Cert { preamble: self.preamble.build(), steps: self.steps, verdict }
    }
}
```

엔진이 커널 규칙을 호출할 때마다, 대응하는 기록기 메서드도
호출하여 단계를 인증서에 엮어 넣는다. 이것이 커널-인증서
결합이 존재하는 유일한 자리이며, 나머지 모든 부분은 인증서를
순수한 데이터 구조로 다룬다.

== 검사기(Checker)

인증서 검사기는 — 커널 컴포넌트가 아닌 — 별개의 라이브러리이며,
`Cert` 를 커널 규칙에 대해 재검증한다. 그것은
`step_id |-> conclusion` 형태의 맵을 유지하면서, 인증서를 id
순으로 순회한다.

```rust
pub fn check(cert: &Cert) -> Result<(), CertError> {
    let mut concl: HashMap<StepId, Term> = HashMap::new();
    let mut deps:  HashMap<StepId, HashSet<Term>> = HashMap::new();
    for step in &cert.steps {
        let (term, hyps) = check_step(step, &concl, &deps, &cert.preamble)?;
        concl.insert(step.id, term);
        deps.insert(step.id, hyps);
    }
    let final_term = concl.get(&cert.verdict.final_step)
        .ok_or(CertError::DanglingFinal)?;
    cert.verdict.matches(final_term)
}
```

영리한 부분은 `check_step` 이다. 각 규칙마다 인용된
의존성들을 `concl`/`deps` 에서 읽어, 규칙의 전제(premise)에
적용하고, 새로운 `(term, hypotheses)` 쌍을 산출하거나 그 단계를
거부한다.

예를 들어, `Trans { lhs, rhs }` 는 다음과 같이 검사된다.

```rust
StepBody::Trans { lhs, rhs } => {
    let (Term::Eq(a, b), hyps_a) = (concl[lhs].clone(), deps[lhs].clone()) else {
        return Err(CertError::TransNeedsEq);
    };
    let (Term::Eq(c, d), hyps_b) = (concl[rhs].clone(), deps[rhs].clone()) else {
        return Err(CertError::TransNeedsEq);
    };
    if b != c { return Err(CertError::TransPivotMismatch); }
    Ok((Term::eq(a, d), &hyps_a | &hyps_b))
}
```

이것이 `Trans` 에 대한 검사기 전부다 — 형태와 동등성에 대한
몇 줄의 단언이다. 검사기는 15가지 단계 종류 전체에 대해 약
600줄에 불과하며, 이는 인증서를 산출한 솔버보다 두 자릿수
작다.

== 방출/파싱 왕복(Emit / parse round-trip)

`adsmt-cert` 는 S-식 문법에 대한 파서와 예쁜 출력기(pretty
printer)를 제공한다.

```rust
pub fn parse(input: &str) -> Result<Cert, ParseError>;
pub fn write(cert: &Cert, out: &mut impl Write) -> std::io::Result<()>;
```

테스트 스위트에서는 왕복 속성 테스트(`parse(write(c)) == c`)가
실행된다. S-식 문법은 사람이 직접 읽을 수 있을 만큼 줄 단위로
정돈되어 있으며, 이는 기록기를 디버깅할 때 매우 값지다는 것이
드러난다.

== 판정 일치(Verdict matching)

최종 단계의 결론은 선언된 판정과 *일치(match)*해야 한다.
Unsat의 경우, 최종 단계는 빈 가설 집합으로 $"False"$ 를
결론지어야 한다. Sat의 경우, 최종 단계는 단언된 모든 원자와
일관된 모델 증거(model witness, 상수 할당 목록)이다.

Abductive 판정은 새로운 형태다. 그 최종 단계는 하나 이상의
`AbductiveAssume` 단계를 참조하고, 잔여 가설을 선언한다.
검사기는 그 사슬을 따라가며, 명명된 가설을 모듈로(modulo)
하여 판정이 통과한다는 것을 확인한다.

== 고전 공리 위생(Classical-axiom hygiene)

2장의 커널은 *최소(minimal)*이다 — 배중률, Peirce의 법칙,
혹은 고전적으로는 타당하지만 직관주의적으로는 타당하지 않은
원리를 내장하고 있지 않다. 솔버 단계가 그러한 공리에 의존하는
경우, 그것은 공리와 인스턴스화를 명명한 `ClassicalAxiom`
단계로 기록되어야 하며, preamble은 그 공리를 자신의
`classical-axioms` 블록에서 선언해야 한다.

하류의 소비자(특히 ITP)는 종종 강한 선호를 가진다. 구성적
(constructive) Lean 4 모듈은 인증서가 내부적으로 타당하더라도
`lem` 을 명명하는 인증서를 거부할 수 있다. preamble 선언 덕분에
소비자는 모든 단계를 다 따라가지 않고도, 파싱 시점에 인증서
수용 여부를 결정할 수 있다.

== 반사(reflection) 다리

기록된 인증서는 ITP 반사 계층(10장)의 입력이 된다.
`adsmt-cert::prover_emit::lean`, `::rocq`, `::isabelle` 가
`Cert` 를 대상 ITP의 표면 문법으로 내려보내며(lower), 각 단계
종류가 특정 전술 호출이나 항 생성자(term constructor)에
매핑된다.

반사는 그 자체의 정합성 관심사를 가진다 — "adsmt 판정 $->$
인증서 $->$ ITP-검증된 증명"이라는 *전체* 사슬의 건전성
(soundness)을 위해서는 반사 계층이 모든 단계를 충실히 번역해야
한다. 다음 장에서 그 기제를 살펴본다.
