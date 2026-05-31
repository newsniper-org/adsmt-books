= Certificates

== Why bother with certificates?

A modern SMT solver is on the order of $10^5$ lines of
intricate code. Asking a user to trust its verdicts on
faith is asking a lot — especially in the safety-critical
verification settings where SMT is most valuable.

The solution is the *proof certificate*: a structured
record of how the verdict was reached, designed so that a
much simpler external checker can re-verify it. The
checker doesn't need to understand CDCL, theory
combination, or quantifier instantiation — it only needs
to verify each step against a fixed set of inference
rules.

adsmt's certificate format is `adsmt-cert`, an S-expression
language with 12 step kinds matching the 12 kernel rules
of chapter 2, plus three abductive markers and a handful
of theory witnesses.

== Format overview

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

Each step is identified by a unique numeric `id`. Steps
reference earlier steps by id, so the dependency structure
forms a DAG ending at the `verdict`-named final step.

== StepBody — 12 + 3 + …

The Rust types reflect the format directly:

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

The mandatory 12 mirror the kernel of chapter 2. The
abductive trio handles the chapter 8 escapes. The
classical axiom marker handles steps that depend on LEM,
Peirce, or another excluded-middle-style axiom — these
must be declared up front in the preamble so the checker
can refuse the cert if the consumer doesn't accept the
specified axiom.

== The recorder

The kernel's twelve rule implementations don't directly
emit certificate steps — that would entangle the kernel
TCB with format concerns. Instead, the recorder is a
thin observer wrapping the kernel:

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

Whenever the engine invokes a kernel rule, it also invokes
the matching recorder method, weaving the step into the
cert. This is the only place where kernel-and-cert
coupling lives; everything else operates on the cert as a
plain data structure.

== The checker

The cert checker is a separate library — not a kernel
component — that re-verifies a `Cert` against the kernel
rules. It maintains a map `step_id |-> conclusion` and
walks the cert in id order:

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

The clever part is `check_step`. For each rule, it reads
the cited dependencies out of `concl`/`deps`, applies the
rule's premises, and either produces a fresh
`(term, hypotheses)` pair or rejects the step.

For example, `Trans { lhs, rhs }` is checked thus:

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

That's the entire checker for `Trans` — a couple of
shape-and-equality assertions. The checker totals about
600 lines for all 15 step kinds, two orders of magnitude
smaller than the solver that produced the cert.

== Emit / parse round-trip

`adsmt-cert` exposes a parser and pretty-printer for the
S-expression syntax:

```rust
pub fn parse(input: &str) -> Result<Cert, ParseError>;
pub fn write(cert: &Cert, out: &mut impl Write) -> std::io::Result<()>;
```

A round-trip property test (`parse(write(c)) == c`) runs
on the test suite. The S-expression syntax is line-
oriented enough that humans can read it directly, which
turns out to be invaluable for debugging the recorder.

== Verdict matching

The final step's conclusion has to *match* the declared
verdict. For Unsat, that means the final step concludes
$"False"$ with the empty hypothesis set. For Sat, the
final step is a model witness (a list of constant
assignments) consistent with all asserted atoms.

The Abductive verdict is the new shape: its final step
references one or more `AbductiveAssume` steps and
declares the residual hypotheses. The checker walks the
chain to confirm that, modulo the named hypotheses, the
verdict goes through.

== Classical-axiom hygiene

The kernel of chapter 2 is *minimal* — it doesn't bake in
excluded middle, Peirce's law, or any of the classically-
valid-but-intuitionistically-invalid principles. When a
solver step depends on such an axiom, it must be recorded
as a `ClassicalAxiom` step naming the axiom and its
instantiation, and the preamble must declare the axiom in
its `classical-axioms` block.

Downstream consumers (ITPs in particular) often have
strong preferences: a constructive Lean 4 module might
refuse a cert that names `lem`, even if the cert is
internally valid. The preamble declaration lets the
consumer decide at parse time whether to accept the cert,
without having to walk every step.

== Reflection bridge

The recorded cert is the input to the ITP reflection
layer (chapter 10). `adsmt-cert::prover_emit::lean`,
`::rocq`, and `::isabelle` lower a `Cert` into the target
ITP's surface syntax, with each step kind mapping to a
specific tactic invocation or term constructor.

Reflection has its own correctness concerns — the
soundness of the *whole* chain "adsmt verdict $->$ cert
$->$ ITP-checked proof" requires the reflection layer to
faithfully translate every step. We'll examine that
machinery next.
