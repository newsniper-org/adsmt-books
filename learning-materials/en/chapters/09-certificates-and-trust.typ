= Certificates and Trust

== Why "trust the solver" isn't enough

Modern SMT solvers are large: tens of thousands of
lines of intricate code spanning SAT, theory solvers,
heuristics, combination, and quantifier instantiation.
Bugs are rare but not unheard of: subtle Simplex
pivoting issues, congruence-closure cascade misses,
quantifier-instantiation soundness gaps. These have
all been found in production solvers over the years.

For most uses (program verification at a "best-effort"
level, scheduling, planning) the residual bug risk is
acceptable. For high-assurance work (formally verified
compilers, safety-critical specifications, proof
assistants) it isn't.

The remedy is *certificates*: a structured trace of how
the solver reached its verdict, designed so a much
smaller external checker — or the proof assistant
itself — can re-verify.

== The certificate idea

When the solver derives a verdict, it doesn't just
return "unsat"; it returns the step-by-step reasoning:

```text
(cert.v1
  (preamble (kernel-version "0.19") (cert-version "1"))
  (steps
    (step :rule assume :id 1 :term (P a))
    (step :rule assume :id 2 :term (=> (P a) (Q b)))
    (step :rule eq_mp  :id 3 :lhs 2 :rhs 1)
    (step :rule assume :id 4 :term (not (Q b)))
    (step :rule deduct :id 5 :hyp 4 :conc 3))
  (verdict unsat :final-step 5))
```

Each `step` cites earlier steps and applies one of a
fixed set of inference rules. The final verdict
references a final-step whose conclusion matches the
declared verdict shape.

The *checker* — separate, small (about 600 lines) —
walks the steps in order, validates each one against
the rule definitions, and confirms the verdict.

== Why the checker can be small

The solver does enormous work to *find* the cert. The
checker only has to *verify* each step. Verification
of a single step is simple shape-matching:

```rust
StepBody::Trans { lhs, rhs } => {
    let (Term::Eq(a, b), _) = concl[lhs] else { return Err(...); };
    let (Term::Eq(c, d), _) = concl[rhs] else { return Err(...); };
    if b != c { return Err(TransPivotMismatch); }
    Ok(Term::eq(a, d))
}
```

Twelve rules, each a few lines. The checker totals
about 600 lines. A bug in the solver doesn't
propagate to a bug in the checker (different code,
different authors, different testing).

== adsmt's cert format

The `adsmt-cert` format has 12 mandatory kernel rule
kinds (matching the 12 inference rules of the kernel,
companion ch. 2) plus three abductive markers (ch. 8)
plus theory witnesses (chs. 4-6):

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Kind*], [*Purpose*]),
  [`refl`, `trans`, `eq_mp`], [Equality reasoning],
  [`abs`, `beta`],            [Lambda calculus],
  [`deduct`, `inst`, `inst_type`], [Hypothetical reasoning, instantiation],
  [`assume`, `assumed`],      [Hypotheses, axioms],
  [`theory`],                 [Theory-level witnesses (UF, LIA, BV, …)],
  [`instance`],               [Type-class instances],
  [`abductive_assume`, `abductive_accept`], [Abductive hypothesis trail],
  [`classical_axiom`],        [Steps depending on LEM, Peirce, etc.],
)

The format is documented in the companion volume's
appendix C in full detail.

== Theory witnesses

Theory steps don't re-derive the theory's reasoning;
they cite a *witness* that the theory's decision
procedure validates separately. UF cites the chain of
union/find merges; LIA cites a Farkas combination
proving infeasibility; BV cites the bit-level proof.

```text
(step :rule theory :theory lia :witness
  (farkas
    :combination ((1.0 c_eq) (-1.0 c_x_lb))
    :concludes (≥ 10 17)))
```

The cert checker calls back into the theory module to
validate the witness. So the cert layer trusts the
theory checker; the theory checker trusts its
mathematical foundation. Each step's TCB (trusted
computing base) is small and inspectable.

== Classical axioms

Some steps depend on *classical* logic axioms — LEM
(law of excluded middle), Peirce, double-negation
elimination. These are valid in classical
mathematics, *not* in intuitionistic logic.

The cert tracks classical-axiom use explicitly:

```text
(preamble
  (classical-axioms (lem peirce)))
(steps
  (step :rule classical_axiom :id 7 :axiom lem :instantiation ((P a))))
```

A Lean 4 (or Rocq, Isabelle) consumer that prefers
constructive proofs can refuse to accept a cert
naming LEM. The classical-axiom registration in the
preamble makes the policy enforceable at parse time.

== Trust boundaries

The full chain of "I trust this verdict":

1. *Trust the kernel.* 12 inference rules; about 1000
   lines of Rust. The kernel is the TCB.
2. *Trust the recorder.* The recorder only invokes
   kernel rules; if a step appears in a cert, it
   actually happened in the kernel. (This is testable
   by property: every certified step roundtrips
   through the kernel.)
3. *Trust the checker.* About 600 lines, mostly shape
   matching. Independently testable.
4. *Trust the ITP.* Lean 4 / Rocq / Isabelle each have
   their own kernel and trust story. The reflection
   layer (chapter 10) translates certs into proofs
   *under each ITP's kernel*, transferring trust to
   the ITP.

Each link in this chain has its own verification path
that doesn't depend on the others. The full system's
trust isn't "trust adsmt" — it's "trust a small kernel
plus a separately-implemented checker, with each
verifying the other's outputs."

== When the cert disagrees with the verdict

If the checker rejects a cert, *something is wrong*.
Either the solver has a bug (it claimed unsat but the
chain doesn't actually establish unsat) or the cert
recorder dropped a step. Both are serious; both are
findable.

For adsmt the rule is *check before commit*: every
test run checks the certs it generates. CI rejects
any commit where checked certs don't validate. The
discipline costs a little CPU and buys peace of mind.

== Practical advice

- *Use certs for high-assurance work.* Compile your
  SMT-LIB script with `--emit-cert`, get a `.cert`
  output, run it through `adsmt-cert-check`. If both
  agree, you have independent confirmation.
- *Don't use certs for casual prototyping.* The
  overhead of writing certs is small (a few percent)
  but non-zero. If you're iterating on a spec, the
  cert is wasted bytes.
- *Read your certs occasionally.* The S-expression
  format is human-readable. When a goal you thought
  was discharged by linarith actually used Peirce, the
  cert tells you.

== The chain continues

Chapter 10 picks up from the cert and shows how a
downstream ITP — Lean 4 in detail, Rocq and Isabelle
in summary — turns the cert into a *real proof under
the ITP's kernel*. That's where the trust boundary
fully closes.
