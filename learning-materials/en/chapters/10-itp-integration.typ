= ITP Integration

== Three integrations, one design

adsmt ships ITP integrations for three systems:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*Status*]),
  [Lean 4],   [In-tree reference (`adsmt-cert::prover_emit::lean`)],
  [Rocq],     [Out-of-tree (`~/adsmt-contrib/adsmt-emit-rocq`)],
  [Isabelle], [Out-of-tree (`~/adsmt-contrib/adsmt-emit-isabelle`)],
)

The three integrations share an *anchor* trait that
forces lockstep evolution: any new certificate step
kind requires implementations in all three before it
compiles (companion ch. 10). The output shape mirrors
exactly: each Lean `have` corresponds to a Rocq Ltac2
`Notation.notation` and an Isabelle Isar `have`.

Lean 4 is the reference. Rocq and Isabelle mirror.

== Lean 4 — the reference

The Lean 4 path:

1. User writes `smt_decide` or `smt_abduce` in their
   proof script.
2. The tactic harness compiles the goal to SMT-LIB
   plus context hypotheses.
3. `adsmt` solves; emits a cert.
4. `prover_emit::lean` translates the cert into Lean
   tactic script.
5. Lean's elaborator + kernel check the script. If it
   passes, the original goal is discharged.

```lean
import Adsmt

example (a b c : Nat) (h1 : a = b) (h2 : b = c) : a = c := by
  smt_decide [h1, h2]
```

Behind the scenes:

```text
goal:         a = c
hypotheses:   h1 : a = b, h2 : b = c
to SMT-LIB:   (assert (= a b)) (assert (= b c)) (assert (not (= a c)))
solver run:   unsat with cert
              (step :rule assume :id 1 :term (= a b))
              (step :rule assume :id 2 :term (= b c))
              (step :rule trans  :id 3 :lhs 1 :rhs 2)
              (step :rule assume :id 4 :term (not (= a c)))
              (step :rule deduct :id 5 :hyp 4 :conc 3)
emit:         have h_3 : a = c := Trans.trans h1 h2
              exact absurd h_3 (by intro; assumption)
Lean kernel:  ✓ goal discharged
```

The tactic disappears into a fully kernel-checked
proof. The cert layer is invisible to the user.

== `smt_decide` vs. `smt_abduce`

Two tactics, two intents:

- `smt_decide` — call adsmt in *deductive* mode. Only
  `sat` / `unsat` verdicts close the goal. `unknown`
  fails.
- `smt_abduce` — call adsmt in *abductive* mode.
  `unsat` closes the goal; `abductive` surfaces
  candidate `sorry`-placeholders in the script.

```lean
example (n : Nat) : f n ≤ g n := by
  smt_abduce
-- emits:
-- have hyp_f : ∀ n, f n ≤ n := by sorry
-- have hyp_g : ∀ n, n ≤ g n := by sorry
-- exact Nat.le_trans (hyp_f n) (hyp_g n)
```

The user fills in the `sorry`s with their own proofs
(or accepts them as additional axioms in scope). The
*structure* of the proof is provided by adsmt; the
*content* of the assumptions is the user's
responsibility.

== Rocq integration

The Rocq backend (`~/adsmt-contrib/adsmt-emit-rocq`)
emits Ltac2 tactics (not Ltac1 — Ltac1 is excluded
per the prover_emit policy). The output shape mirrors
the Lean reference:

```coq
From Adsmt Require Import AdsmtTactic.

Example example_eq : forall (a b c : nat), a = b -> b = c -> a = c.
Proof.
  intros a b c h1 h2.
  adsmt_decide [h1; h2].
Qed.
```

The tactic invokes adsmt, gets the cert, generates a
Ltac2 script that walks the cert's steps. Each cert
step becomes a Ltac2 `assert` with a small witness
tactic.

== Isabelle integration

The Isabelle backend
(`~/adsmt-contrib/adsmt-emit-isabelle`) emits Isar
syntax, again mirroring Lean:

```isabelle
lemma example_eq:
  fixes a b c :: nat
  assumes h1: "a = b" and h2: "b = c"
  shows "a = c"
proof -
  have h_3: "a = c" by (rule trans, fact h1, fact h2)
  show ?thesis by fact
qed
```

The proof structure mirrors Lean / Rocq exactly; only
the surface syntax differs. The lockstep property is
enforced by a round-trip diff test (companion ch. 10).

== Classical-axiom hygiene

Each backend imports the classical axioms named in
the cert's preamble *on demand*. A Lean cert citing
LEM imports `Classical.em`; a Rocq cert imports
`Classical_Prop.classic`; an Isabelle cert imports
`HOL.Classical`.

If a backend's target doesn't support a named
axiom — e.g. a strict constructive Lean module that
refuses `Classical.em` — the emit refuses with a
diagnostic. The user either accepts the classical
import or asks the solver to retry with classical
axioms disabled.

== Performance considerations

Three knobs worth knowing about:

*1. Cert size.* A large goal can produce a multi-kB
cert. Emit times scale linearly; ITP elaboration
scales linearly. For interactive use, sub-second is
the goal; the LSP path (cheap recheck) keeps it
there.

*2. Tactic granularity.* `smt_decide` per-subgoal is
fine; `smt_decide` over a massive disjunction is
slow. Split before invoking.

*3. Abductive cost.* The abductive search budget is
bounded (`:abductive-tier 0..4` in SMT-LIB or the
equivalent in the tactic surface). Tier 4 is the
most aggressive and most expensive.

== When SMT-as-tactic shines

- *Equality chains.* "$a = b$, $b = c$, $c = d$, …, prove
  $a = z$." adsmt's EUF handles this in microseconds;
  Lean's `congr` tactic chain is similar but more
  verbose to write.
- *Linear arithmetic.* "Prove $3x + 2y >= 5$ given
  $x >= 1$, $y >= 1$." LIA via Simplex. Lean's
  `linarith` does this too — adsmt extends with the
  Farkas-witness cert path for transparency.
- *Bit-vector identities.* "Prove
  `(x ^ y) ^ x = y`." Bit-blasting decides. Lean's
  `bv_decide` is the closest in-Lean equivalent.

== When SMT-as-tactic struggles

- *Induction.* SMT doesn't do induction. The ITP does.
- *Higher-order reasoning that needs unification.* SMT
  uses Miller patterns; Lean's higher-order unifier
  is far more powerful.
- *Domain-specific automation* — category theory,
  cubical, set-theoretic constructions. SMT is
  general-purpose; specialised tactics beat it.

The combination is the strength: use SMT where it
shines (concrete first-order, equality, arithmetic),
use the ITP's native tactics where SMT can't help.
adsmt's design — abductive escape, transparent certs,
ITP-friendly emission — is built around this division.

== A complete worked example

A small Lean 4 proof using `smt_abduce`:

```lean
import Adsmt

example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  smt_abduce
```

The abductive output:

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := by
    sorry  -- abductive candidate 1
  exact h xs.head! h_head_in
```

The user reads the candidate hypothesis
(`xs.head! ∈ xs`, which is true for non-empty lists)
and discharges it with `exact List.head!_mem_of_ne_nil
hne`. The full proof:

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := List.head!_mem_of_ne_nil hne
  exact h xs.head! h_head_in
```

adsmt found the structure; the user supplied the
domain knowledge.

This — *partnership between solver and prover* — is
what adsmt is for.
