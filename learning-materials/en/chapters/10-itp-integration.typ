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

== `solve … by …` — proof terms inside the language

The tactics above live _outside_ adsmt: a Lean or Rocq
script calls in. But the lukb successor surface
(`adsmt-ir-lukb`; see the implement-from-scratch lukb
appendix) has its own _in-language_ bridge to
ITP-style proof. It is one construct:

```lukb
solve G by L
```

Read it as "_a proof of `G`, justified by the lemma
`L`._" Both `G` and `L` are *blocks* — a term, or a
`let`-chain ending in a term — so you can build up
intermediate facts on either side.

This is the *cut rule*, made syntax. Elaboration
(semantics B: it _constructs a proof term_, it does not
run the solver at parse time) emits exactly two
obligations, each closed over the ambient context so it
is well-formed at top level:

- the *leaf* `L` — discharge the lemma, and
- the *bridge* `L ⟹ G` — show the lemma implies the
  goal.

The kernel assembles the proof scaffold from these two;
the engine discharges the leaf. Because the only
inference used is the cut — no axiom, no
verdict-shortcut — `solve` is sound by construction.
The soundness core is pre-verified in Verus
(`~/solve-by-verification`, 5 verified, 0 errors).

```lukb
// goal: the head of a sorted, non-empty list is its minimum.
goal head_is_min : is_min(head(xs), xs) =
  solve is_min(head(xs), xs)
  by    sorted(xs) and nonempty(xs)
```

The leaf `sorted(xs) ∧ nonempty(xs)` is what _you_ owe;
the bridge `(sorted(xs) ∧ nonempty(xs)) ⟹
is_min(head(xs), xs)` is what the engine checks. The
analogy to `smt_abduce` is exact — `solve` is the
deductive, _already-justified_ sibling of an abductive
`sorry`: you name the lemma instead of leaving a hole,
and adsmt verifies the step rather than guessing it.

== Refinement types carry the intent

A `solve` is only as sharp as the propositions you can
_state_. The lukb successor surface states verification
intent with *refinement types*: a base sort carved by
a predicate,

```lukb
{ v: T | φ }
```

— the sort `T` restricted to those `v` satisfying `φ`.
Refinements are usable anywhere a type is: on a
`const`, on an `fn` parameter or return, on either side
of an arrow, and as a quantifier binder. `Nat` and
`WNat` are themselves refinements of `Int`
(`Nat = {x: Int | x ≥ 1}`, `WNat = {x: Int | x ≥ 0}`).

A `const` at a refined type postulates _both_ the typing
and the predicate as a trusted fact:

```lukb
const c : { v: Int | v ≥ 0 }   // gives  c : Int  AND  c ≥ 0
```

A refinement on a quantifier binder elaborates by the
pre-verified relativization lemma — the polarity is the
thing to remember:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*binder*], [*elaborates to*]),
  [`forall {v:T|φ}. ψ`], [`forall v:T. φ ⟹ ψ`],
  [`exists {v:T|φ}. ψ`], [`exists v:T. φ ∧ ψ`],
)

So `∀` weakens to an implication, `∃` strengthens to a
conjunction. Get the polarity backwards and you have
either a vacuous obligation or an unsatisfiable one;
adsmt's elaborator fixes it for you, but it is worth
holding in your head when you read the desugared goal.

*Function types and refined arrows.* `T -> U` is the
arrow (right-associative; `(A -> B) -> C` parenthesises
an _arrow domain_). Refine both ends and the arrow
carries a contract:

```lukb
{ u: A | 'p } -> { v: A | 'q }
```

— a precondition `'p` on the domain, a postcondition
`'q` on the codomain. The _value_ sort is still the
plain `A -> A`; the refinements are proof-irrelevant and
erased at lowering. The payoff is that an argument
supplied at this type _hands you its postcondition `'q`
as a usable fact_ — exactly the hypothesis a downstream
`solve` wants.

== Generic predicate parameters `'p`

The leading single quote in `'p` above is not
decoration: it marks a *generic predicate parameter*,
making a definition predicate-_polymorphic_. An `fn`
whose refinements mention `'p` binds it implicitly at
the head as `Π('p : T → Prop)`, and the body type-checks
*once*, with `'p` held abstract — the "checked-once"
guarantee. Parameter refinements become preconditions,
the return refinement a postcondition, and the whole
contract

$ forall arrow('p). thin forall arrow(x). thin
  (and.big_i "pre"_i) arrow.r.double "post" $

is a *goal* when you are _defining_ the function (the
construct-site obligation, discharged by the engine) and
a *trusted axiom* when it is only a _signature_. At a
use site you instantiate `'p := q`; the now-monomorphic
precondition is discharged on the spot. This is
*dictionary-passing*: the caller supplies the predicate
the callee abstracted over.

The single quote is what disambiguates, at parse time, a
generic `'q` from a *concrete* predicate `q` (no quote).
Concrete refinement `fn`s get the same contract
treatment — the genericity is the only difference.

*The trivial predicate `nop`.* For uniformity the
refinement-aware logic always wants to see a predicate,
so an _unrefined_ `x: T` is read as `{x: T | nop(x)}`,
where

```lukb
nop : Π(T: Type). T → Prop := λ T x. true
```

Since `nop(x) ≡ true`, a `nop` refinement is vacuous: it
is dropped — no hypothesis, no guard emitted — so the
desugared output stays clean, and `const c: {v:T|nop(v)}`
is just `const c: T`. You will never write `nop`
yourself; it is the identity element that lets "refined"
and "unrefined" share one code path.

== Putting it together: preservation

These pieces compose into a small but real verification
idiom. Suppose a datatype `A` has many functions, and
you want to say "_`f` preserves the property `'p`._"

The tempting move is to make `Preserving('p)` a *type
relation* (adsmt's own term for a type class; see the
next section). That was tried and *retired* — it is the
wrong abstraction. A type relation is _coherent_: one
instance per type. But `A` may have _many_ `'p`-
preserving functions, and many that don't. Preservation
is therefore not a property of the type — it is a
property of the *function*, a higher-order predicate
`preserving(f)`, checked independently for each `f`.

As a *reusable* predicate, preservation is best *defined* —
a `Bool`-valued higher-order predicate that states the
proposition, with `'p`/`'q` collected from a refined-arrow
argument (a `Bool` return carries no obligation of its own):

```lukb
fn preserving( f: { u: A | 'p(u) } -> { v: A | 'q(v) } ) : Bool =
  forall x: A. 'p(x) ==> 'p(f(x))
```

The work appears only at a concrete *use* — and that is
where `solve … by …` earns its place. With `f`'s
postcondition available (here an explicit `axiom`, from
`f`'s refined-arrow type), the cut discharges a concrete
"`f` preserves `p`" goal:

```lukb
const p: A -> Bool    const q: A -> Bool    const f: A -> A
axiom post_f: forall {x: A | p(x)}. q(f(x))
goal:
  solve forall {x: A | p(x)}. p(f(x))
  by    forall {y = f(x) | p(x)}. q(y) ==> p(y)
```

The leaf — "`q ==> p` on the image" — is the genuine
content; the bridge composes it with `post_f` to close the
goal. Why a *definition* and not a proof-producing `fn`? A
`preserving` that ran `solve … by …` in its body and was
checked once over a _generic_ `'p`/`'q` would be *unsound*:
its leaf `∀'p 'q f. 'q(f x) ==> 'p(f x)` is false in general.
So the predicate is *stated* once and *discharged* per
concrete use.

== Image binders — inference does the work

One more binder form, driven almost entirely by type
inference. An *image binder*

```lukb
forall { y = f(x) | c }. q(y)
```

ranges over the inferred _preimage_ `x` (its sort is
`f`'s domain), guards it by `c`, and unfolds `y` to
`f(x)` in the body. By the pre-verified
`image_quantifier_desugar` it is exactly

```lukb
forall x: { A | c }. q(f(x))
```

You write the quantifier in terms of the _value you care
about_ (`y`, in the image of `f`); adsmt recovers the
variable it must actually range over (`x`, in the
domain). It is a small convenience that reads the way the
mathematics reads.

== Type relations are type classes

"_Type relation_" is adsmt's name for a type class —
*one* concept, and `adsmt-class` is literally the
type-class layer (`Relation` / `Instance` / `Resolver` /
`Dict` / `Law`). The *\*Like family* — `PartialOrd` →
`Ord` → `IntegerLike`, `RealLike`, … — shares a
`Reduces` spine, and `IntegerLike(I, L, N)` is the first
_higher-kinded_ instance.

Two properties matter for verification:

- *Lawful-by-proof.* A relation carries *law*
  goal-members beside its method members. An instance is
  admitted only if adsmt's _own engine_ proves every law
  — otherwise the build is *rejected*
  (`declare_instance_lawful` + an engine-backed
  `LawProver`). The same solver that discharges a `solve`
  leaf is what certifies that `Ord` for your type is
  actually a total order.
- *Predicate parameters.* A relation may carry a
  predicate parameter `'p : T → Prop` that an instance
  supplies as a *dictionary* entry — the same
  dictionary-passing you saw with generic `fn`s, now at
  the instance level.

This is one face of the *four-way interlock* that is
adsmt's core design intent: type inference, abductive-
deductive logic, ASP, and SMT (plus HKT) are meant to
_organically_ interlock rather than sit in separate
silos. `IntegerLike(I, L, N)` is the connective tissue —
type information flowing, through a higher-kinded
instance, into the engines that `solve` calls on.

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
what adsmt is for. The external tactics (`smt_decide`,
`smt_abduce`) and the in-language proof term
(`solve … by …`) are two routes to the same place: in
both, the human names the intent — a hypothesis to fill,
a refinement to carry, a lemma to cut on — and the
engine discharges the obligation under a kernel-checked
scaffold. Whether the proof lives in Lean or in a lukb
`goal`, the division of labour is the same.
