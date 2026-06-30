= lu-kb Surface

`lu-kb` is the second input dialect adsmt accepts. The
name originated in the *logicutils* project (absorbed at
RC1.4.A, see `ABSORPTION_PLAN.md`), but the surface
described here is the *lu-kb successor* — the modern
dialect implemented in `adsmt-ir-lukb`. Where the legacy
lukb was a loose bag of `fun` / `rule` / `class` /
`instance` / `query` blocks aimed at logicutils
knowledge bases, the successor is a small, obligation-shaped
module language: a sequence of *items* that postulate
sorts, constants, functions, datatypes, and trusted
facts, then state a *goal* to discharge. It is the
surface adsmt prefers for hand-authored verification
conditions and for the type-relation work in chapter 3.

The legacy `.kb` block grammar is still parsed for
backward compatibility (the `adsmt-parser/src/lukb/`
migration chain is untouched), but it is no longer the
recommended authoring surface and is not documented
further here.

== Surface shape

A lu-kb module is a sequence of *items*:

```text
sort Shape

const c: Int

fn area(s: Shape): Int

data Nat = zero | succ(Nat)
data List = nil | cons(head: Int, tail: List)

axiom area_pos: forall s. area(s) >= 0
assume c_small: c <= 10
goal:    forall s. area(s) >= 0
```

Each item is one of: `sort`, `const`, `fn`, `data`,
`axiom`, `assume`, `goal`. The grammar lives in
`adsmt-ir-lukb` (`lexer.rs`, `parser.rs`, `ast.rs`),
which elaborates each item into the kernel IR of
chapter 3.

== Items

*`sort <name>`* — Declares an opaque (uninterpreted)
sort. Equivalent to `declare-sort` in SMT-LIB.

*`const <name>: <type>`* — A free constant, e.g. a VC
variable. The type may be any type expression, including
a refinement (below).

*`fn <name>(<params>): <ret> [= <body>]`* — A function.
Each parameter group `names: ty` shares a type, so
`fn f(x: Int, y z: Bool): U` declares `f : Int -> Bool
-> Bool -> U`. With *no* `= body` the function is an
opaque *signature* (an `open` symbol postulated at its
arrow type, `Bool` mapping to `Prop`); with a `= body`
it is a non-recursive *definition* (`f := λ(params).
body`), δ-unfolded at solver lowering. A body that
mentions `f` (genuine recursion) needs the kernel `fix`
and is a later slice.

*`data <name> = <ctor> | ...`* — A non-parametric
inductive datatype, elaborated to `declare_inductive`.
Each constructor carries a field list; a field may name
its selector (`head: Int`) or be positional (`Int`).
Constructors are usable as terms.

*`axiom [<name>]: <formula>`* — A trusted hypothesis
($in H$). Asserted at engine start.

*`assume [<name>]: <formula>`* — A VC path condition
($in H$). Same trust status as `axiom`; the distinction
is intent (an `assume` is a precondition carried along
a verification path).

*`goal [<name>]: <formula>`* — The obligation to
discharge. The body may be written as a sequent `H1,
..., Hk |- G`, desugared at parse time to `(H1 and ...
and Hk) ==> G`. A goal is the analogue of `assert (not
phi)` followed by `check-sat`; the verdict is reported
by name.

== The unified verdict

A lu-kb-successor module is solved by the `adsmtc` compiler
(batch) or the `adsmtr` runtime/REPL, producing a
*UnifiedVerdict* — a *separated product* `{ smt, asp }` whose
SMT-precision side and typed-ASP-partiality side answer
different questions and so are deliberately *not* fused into
one lattice. The `asp` side is populated only by the
typed-ASP face (appendix D); a pure lu-kb module exercises the
`smt` side.

The unified verdict collapses to a tri-state via the 3-valued
*Kleene conjunction* of its two sides — an `unsat` on either
side dominates the whole. Per the Verus/SMT convention a goal
`G` is valid iff `H ∧ ¬G` is unsat, so a *discharged*
obligation reads `unsat`. Under `--output-mode full` the `smt`
side un-collapses to the 5-level precision lattice
(`definite-sat` … `definite-unsat`).

The surface is documented in full in
`docs/design/LUKB_SUCCESSOR_SURFACE.md` section 10.

== Refinement types

A *refinement type* `{v: T | φ}` is a base sort `T`
carved down by a predicate `φ` over the bound name `v`.
It is usable anywhere a type is — `const` types, `fn`
parameter and return types, the domain and codomain of
an arrow — and also as a *quantifier binder*.

The two elaboration sites differ by polarity:

- *Postulating* a refined constant. `const c: {v: T | φ}`
  introduces `c: T` *and* the trusted fact `φ[v := c]`.
  The refinement is given to you.

- *Quantifying* over a refinement. A refined binder
  relativizes the quantifier: `∀` gains a guard
  (`forall x: {T | φ}. ψ` becomes `forall x: T. φ ==>
  ψ`), and `∃` gains a conjunct (`exists x: {T | φ}. ψ`
  becomes `exists x: T. φ and ψ`). This `∀ -> ⟹`,
  `∃ -> ∧` rule is the pre-verified relativization
  lemma; it is sat-preserving.

`Nat` and `WNat` are exactly refinements of `Int`:

```text
Nat  = { x: Int | x >= 1 }
WNat = { x: Int | x >= 0 }
```

so the positivity of a `Nat`-typed value is a *fact* the
solver receives, not an opaque sort wall (see
`NAT_WNAT_REFINEMENT_COLLAPSE.md`).

== Function types and refined arrows

`T -> U` is a function type, *right-associative*: `A ->
B -> C` parses as `A -> (B -> C)`. Parenthesise to put
an arrow in domain position: `(A -> B) -> C`.

A *refined arrow* attaches a contract to an arrow:

```text
{u: A | 'p} -> {v: A | 'q}
```

The domain refinement `'p` is a *precondition* and the
codomain refinement `'q` is a *postcondition*. The
*value* sort of a refined arrow is just the plain `A ->
A` — the refinements are proof-irrelevant and erased at
lowering — but they are not cosmetic: an argument
supplied at this type carries `'q` as a usable fact at
the call site. Refined arrows are how a "function that
preserves a property" is *typed*; the obligation that it
actually preserves it is discharged separately (see
*Generic predicate parameters* and *Image binders and
preservation* below).

== Generic predicate parameters `'p`

A leading single quote marks a *generic predicate
parameter* — a predicate the item is polymorphic over. A
bare identifier `q` (no quote) is a *concrete* predicate;
the quote is what disambiguates the two at parse time.

When a `fn`'s refinements mention `'p`, the `fn` binds it
*implicitly* at the head as `Π('p: T -> Prop)`. The body
type-checks *once*, with `'p` held abstract — the
"checked-once" guarantee: a generic refinement function
is verified a single time and reused at every
instantiation, rather than re-checked per use.

The parameter refinements are preconditions and the
return refinement a postcondition, so a generic function
carries the contract

```text
forall 'p... . forall x... . (pre_1 and ... and pre_k) ==> post
```

This contract is read in opposite directions for the two
`fn` forms:

- For a *definition* (`= body`), the contract is a
  *goal* — the construct-site obligation that the body
  actually meets its postcondition.

- For a *signature* (no body), the contract is a
  *trusted axiom*.

At a use site the parameter is instantiated, `'p := q`,
and the now-monomorphic precondition is discharged —
classic dictionary passing. Concrete refinement
functions (those whose refinements mention a plain `q`
rather than a `'p`) get the same contract treatment,
just without the leading `Π`.

== The trivial predicate `nop`

`nop` is the always-true predicate,

```text
nop : Π(T: Type). T -> Prop := λ T x. true
```

It exists so that the refinement-aware logic *always*
sees a predicate, even for unrefined values. An
unrefined `x: T` is treated uniformly as `{x: T |
nop(x)}`. Because `nop(x) ≡ true`, a `nop` refinement is
vacuous: it emits no hypothesis and no guard, so `const
c: {v: T | nop(v)}` is exactly `const c: T` and the
output stays clean. `nop` is the bottom of the
refinement lattice — the place a "no constraint" slot
lands when one of the predicate parameters above is left
unconstrained.

== `solve ... by ...` proof terms

`solve G by L` is an *in-language proof term*: a proof of
the proposition `G`, justified by the lemma `L`. It is
the structured-proof *cut* made into surface syntax. `G`
and `L` are each a *block* — a term, possibly a
`let`-chain.

Its semantics is *proof-term construction*, not runtime
solving. `solve G by L` elaborates to two obligations,
both closed over the ambient context so each is
well-formed at top level:

- the *leaf* obligation `L`, and
- the *bridge* obligation `L ==> G`.

The kernel builds the proof scaffold (the cut), and the
engine discharges the leaf. Soundness is exactly the cut
rule — no new axiom, no verdict shortcut — and the
soundness core is pre-verified in Verus
(`~/solve-by-verification`, 5 verified, 0 errors). See
`SOLVE_BY_PROOF_TERMS.md`.

A typical use proves that a function meets a
preservation contract, factoring the proof through an
intermediate lemma:

```text
fn double(x: Int): Int = x + x

// `double` preserves nonnegativity. The goal is the
// refined-arrow contract; `by` cuts through a lemma
// about the body.
goal double_preserves:
  solve (forall x: {v: Int | v >= 0}. double(x) >= 0)
  by    (forall x: Int. x >= 0 ==> x + x >= 0)
```

The engine discharges the arithmetic leaf `forall x. x
>= 0 ==> x + x >= 0`, the kernel supplies the bridge from
that leaf to the refined-arrow goal, and the goal is
proved by the cut.

== Image binders and preservation

An *image binder* `{y = f(x) | c}` is a
type-inference-driven quantifier abbreviation. It ranges
over the inferred *preimage* `x` (whose sort is `f`'s
domain), guarded by the constraint `c`, and unfolds `y`
to `f(x)` in the body:

```text
forall {y = f(x) | p(x)}. q(y)
  ≡  forall x: {A | p(x)}. q(f(x))
```

This is the pre-verified `image_quantifier_desugar`. It
lets you quantify over "the values in the image of `f`"
without naming the preimage explicitly.

Image binders are the natural vehicle for *preservation*
statements. A key design point: *preservation is a
higher-order predicate, not a type relation.* A type
relation is coherent — one instance per type — but a
single datatype `A` can have *many* functions that
preserve a property `'p`. So "preserves `'p`" is a
property of a *function*, written as a higher-order
predicate `preserving(f)` and checked per function,
typically via a `solve ... by ...` over a refined-arrow
argument. (An earlier `Preserving('p)` *type-relation*
attempt was retired as the wrong abstraction.)

== Type relations are type classes

In adsmt, "type relation" *is* the term for a type class
— one concept, implemented in `adsmt-class` (literally
"the type-class layer"). The vocabulary is `Relation` /
`Instance` / `Resolver` / `Dict` / `Law`. A relation may
also carry a *predicate parameter* `'p : T -> Prop` that
each instance supplies as a dictionary entry — the same
generic-predicate mechanism as the `fn` head above.

The *\*Like family* (`PartialOrd` -> `Ord` ->
`IntegerLike`, `RealLike`, ...) shares a `Reduces` spine,
and `IntegerLike(I, L, N)` is the first higher-kinded
type-class instance. It is the connective tissue of the
*four-way interlock* — the core design intent that type
inference, abductive-deductive logic, ASP, and SMT (plus
HKT) interlock organically rather than living in
separate silos.

Relations are *lawful by proof*. A relation carries
*law* goal-members alongside its method members, and an
instance is admitted only if adsmt's own engine proves
*every* law — otherwise the build is *rejected*. This is
`declare_instance_lawful` plus an engine-backed
`LawProver`: lawfulness is not a convention but a
discharged obligation, in the same spirit as the
construct-site goal a refinement `fn` definition carries.

== Comparison to SMT-LIB

lu-kb is shaped for authoring obligations with rich
types, where SMT-LIB is shaped for discharging a flat
goal:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Concern*], [*SMT-LIB*], [*lu-kb successor*]),
  [Granularity], [Per goal], [Per module],
  [Constants], [`declare-const`], [`const x: T`],
  [Functions], [`declare-fun` / `define-fun`], [`fn` signature / definition],
  [Refinement types], [Not native], [`{v: T | φ}` in any type position],
  [Contracts], [Manual side conditions], [Refined arrows + generic `'p`],
  [Proof structure], [Flat assert/check], [`solve ... by ...` cut],
  [Type classes], [Not native], [Type relations (lawful by proof)],
)

Both surfaces compile to the same kernel IR, so engine
behaviour is identical once elaboration is done — the
difference is entirely in what the *author* can say
up front.

== Editor integration

The VS Code extension (under
`tooling/vscode-extension/`) recognises `.smt2` and the
lu-kb extensions. The LSP server (`adsmt-lsp`) routes
files by extension into the appropriate parser; the
completion list adapts to the active surface, offering
the successor keywords (`sort`, `const`, `fn`, `data`,
`axiom`, `assume`, `goal`, `solve`) alongside the
legacy block keywords still accepted by the
compatibility parser.
