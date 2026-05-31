= ITP Reflection

== What "reflection" buys

Once we have a certificate, the verdict is independently
checkable by a small library. But for users embedded in
an interactive theorem prover — Lean 4, Rocq, Isabelle —
running a separate cert checker is awkward. They want the
solver's verdict turned into a *real proof term in the
ITP's own kernel*, so that the ITP itself becomes the
trusted authority.

That's the *reflection bridge*: given a cert, emit
ITP-surface code (tactic script or term) that, when
checked by the ITP, has the verdict as its statement.
adsmt ships three reflection backends:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*Module*], [*Status*]),
  [Lean 4], [`adsmt-cert::prover_emit::lean`], [In-tree reference],
  [Rocq],   [`adsmt-emit-rocq` (out-of-tree)],   [Mirrors Lean],
  [Isabelle], [`adsmt-emit-isabelle` (out-of-tree)], [Mirrors Lean],
)

The Lean 4 path is the *reference*: any change to the
output shape lands in `lean` first, then propagates to the
Rocq + Isabelle backends in lockstep (see
`prover_emit_policy.md`).

== Common anchors

The three backends share a set of *anchors* — abstract
operations each backend implements:

```rust
pub trait ProverEmit {
    fn open_proof(&mut self, goal: &Term);
    fn refl_step(&mut self, t: &Term);
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term);
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness);
    fn abductive_assume(&mut self, name: &str, hyp: &Term);
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind);
    // ... 12 mandatory + abductive + classical ...
    fn close_proof(&mut self);
}
```

`adsmt-cert::prover_emit::common` lowers a `Cert` by
walking its steps and invoking the appropriate trait
method. The backend implementations then format ITP-
specific syntax. This factoring keeps the three backends
exactly synchronised: any new step kind must add a method
to the trait, forcing all three backends to handle it
before the change can compile.

== Lean 4 — the reference backend

```rust
impl ProverEmit for LeanEmitter {
    fn open_proof(&mut self, goal: &Term) {
        write!(self.out, "theorem adsmt_goal : {} := by\n",
               lean_term(goal)).unwrap();
        self.indent = 2;
    }
    fn refl_step(&mut self, t: &Term) {
        self.line(&format!("have h{} : {} = {} := rfl",
                           self.next_id(), lean_term(t), lean_term(t)));
    }
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term) {
        let id = self.next_id();
        let prev = self.prev_two();
        self.line(&format!("have h{id} : {} = {} := Trans.trans h{} h{}",
                           lean_term(a), lean_term(c), prev.0, prev.1));
    }
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness) {
        let tactic = match theory {
            TheoryName::Uf  => "congrArg",
            TheoryName::Lia => "linarith",
            TheoryName::Lra => "linarith",
            TheoryName::Bv  => "bv_decide",
            TheoryName::Arr => "simp [Array.get_set]",
            TheoryName::Dt  => "decide",
        };
        self.line(&format!("have h{} : ... := by {}", self.next_id(), tactic));
    }
    fn abductive_assume(&mut self, name: &str, hyp: &Term) {
        // Renders as a Lean sorry-shaped placeholder.
        self.line(&format!("have {} : {} := by sorry  -- abductive",
                           name, lean_term(hyp)));
    }
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind) {
        let import = match kind {
            ClassicalAxiomKind::Lem => "Classical.em",
            ClassicalAxiomKind::Peirce => "Classical.peirce",
            // ...
        };
        self.preamble.push(format!("open {}", import));
    }
}
```

A cert with 17 steps yields a Lean tactic block with 17
`have`-lines, capped by a `close_proof` that names the
final identifier as the proof of the original goal. The
output goes through Lean's elaborator and kernel; Lean's
own trust delegates the soundness obligation.

== Rocq / Isabelle — mirroring

The Rocq and Isabelle backends live out-of-tree in
`~/adsmt-contrib/`. They implement the same `ProverEmit`
trait but emit Rocq Ltac2 syntax or Isabelle Isar syntax
respectively.

```text
~/adsmt-contrib/
├── adsmt-emit-rocq/
│   └── src/lib.rs        — impl ProverEmit for RocqEmitter
└── adsmt-emit-isabelle/
    └── src/lib.rs        — impl ProverEmit for IsabelleEmitter
```

A few constraints worth flagging:

- *Rocq Ltac1 is excluded.* Ltac2 only. Ltac1's untyped
  surface is too brittle for machine-generated tactics —
  the smallest cert variation produces an opaque parse
  error in Ltac1 that Ltac2 catches at typing time.
- *Output shape mirrors Lean exactly.* Each `have` in Lean
  corresponds to a `have :` in Isabelle and a
  `Notation.notation` in Rocq, in the same order, with the
  same identifier names. This is a hard invariant of the
  prover_emit policy.
- *Classical axioms are imported on-demand.* The preamble
  of each emitted file imports only the axioms named in
  the cert's preamble. An offline-first check refuses to
  emit if a named axiom is unsupported in the target ITP.

== Round-trip diff testing

The lockstep policy is enforced by a *round-trip diff
test*: given a cert, emit Lean output, normalise to a
canonical AST, then emit Rocq output, normalise, then
emit Isabelle output, normalise, and compare. Any
structural divergence between the three trees is a
policy violation that blocks merge.

```rust
#[test]
fn lockstep_lean_rocq_isabelle() {
    for cert in golden_certs() {
        let lean_tree   = normalize(emit_lean(&cert));
        let rocq_tree   = normalize(emit_rocq(&cert));
        let isabelle_tree = normalize(emit_isabelle(&cert));
        assert_eq!(lean_tree.shape(), rocq_tree.shape());
        assert_eq!(lean_tree.shape(), isabelle_tree.shape());
    }
}
```

This is what we mean by "Lean 4 reference" — Lean isn't
just *one of three* output formats, it's the format whose
shape the others must replicate.

== Abductive holes as `sorry`

Abductive steps emit ITP-native `sorry` placeholders. Lean:
`sorry`. Rocq: `Admitted` (when the abductive layer is at
a definition boundary) or `give_up` (in tactic mode).
Isabelle: `sorry`.

Each placeholder is named after the abductive hypothesis,
so the user sees in their editor a list of named
obligations like:

```text
adsmt_h_3 : ∀ x, x > 0 → P x
adsmt_h_7 : a ≠ b
```

These are exactly the hypotheses the abductive layer
surfaced — now wearing ITP clothing. The user discharges
them by proof or by accepting them as axioms; the rest of
the proof goes through under the ITP's own kernel.

== The full chain

Putting the layers from chapters 1-10 together, the
end-to-end pipeline is:

```text
SMT-LIB script
   ↓ parse
Internal AST
   ↓ engine.check_sat (CDCL + theory + quantifier + abduce)
SatResult
   ↓ recorder
Cert (S-expr)
   ↓ prover_emit::lean / ::rocq / ::isabelle
ITP-surface proof script
   ↓ ITP kernel
Verified theorem
```

Every link in this chain has an independent verifier on
the other side. The kernel (chapter 2) is verified by
itself — the 12 rules are the soundness contract. The
checker (chapter 9) verifies the cert against the kernel
rules. The ITP (chapter 10) verifies the emitted proof
against its own kernel. The abductive layer (chapter 8)
introduces *named obligations*, not unsoundness — the user
sees them explicitly and decides.

This is what we mean by saying SMT-as-tactic should serve
a proof assistant. The solver's verdict is never the
final word; the ITP's kernel is.
