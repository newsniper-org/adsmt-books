= Types and classes

== Why higher-kinded types

Classical SMT solvers work in many-sorted first-order logic.
"Sorts" in that setting are flat: there is an `Int` sort, a
`Real` sort, a `Bool` sort, an array sort `(Array I E)` for
each pair of index and element sorts, and so on. Type
abstraction — taking a sort and parameterising it over
another sort — is performed at the meta-level by the
signature builder, not visible in the formula language
itself.

This works fine for the bulk of SMT workloads. It runs into
friction at the boundary with interactive theorem provers,
which routinely manipulate proofs *about* functors,
type-level functions, or polymorphic structures. To reflect
a Lean 4 proof obligation into the SMT solver and back, the
solver needs to talk about the same things Lean does: types
parameterised over types, instances at higher kinds, and
genuine type-level polymorphism.

adsmt's solution is to admit *higher-kinded types* at the
solver's own surface. A type may itself be parameterised
over another type, the way `List` in Haskell can be
applied to any element type to yield `List Int`,
`List String`, `List (List Bool)`, and so on. Concretely
the kind system adds the standard kind formers:

$ kappa ::= "Type" | kappa_1 -> kappa_2 $

and types are now stratified:

$ tau ::= alpha^kappa | C^kappa | tau_1 tau_2 | tau_1 -> tau_2 $

where the kind annotation $kappa$ on each variable and
constant tracks how many type arguments the entity
expects. `Int` has kind `Type`; `List` has kind
`Type -> Type`; the `Functor` class operates on entities
of kind `Type -> Type`; and so on.

== Polymorphic constants

A polymorphic constant such as `id : forall alpha. alpha -> alpha`
has a type scheme — a universally quantified type — rather
than a single type. When `id` is used at a particular
instantiation (`id @Int`, say), the kernel rule `InstType`
performs the substitution. This is the same machinery as
ML-style polymorphism, lifted to admit higher kinds.

In code:

```rust
pub struct TyVar { pub name: String, pub kind: Kind }
pub enum Type {
    Var(Arc<TyVar>),
    Const(Arc<TyConst>),
    App(Arc<Type>, Arc<Type>),
    Fun(Arc<Type>, Arc<Type>),
}

pub fn inst_type(
    sigma: &[(Arc<TyVar>, Type)],
    thm: &Theorem,
) -> KernelResult<Theorem> {
    // Substitute every TyVar matching sigma's left-hand sides;
    // produce a new Theorem at the substituted types.
}
```

`inst_type` is one of the twelve kernel rules; it is
formally a partial function because the substitution must
respect kinds.

== Refinement types: the typed substrate

Before we get to classes, one ingredient earns its place
right next to the sort system: a sort can be *carved by a
predicate*. A *refinement type* `{v : T | φ}` is the base
sort `T` restricted to those values for which `φ` holds.
This is the typed substrate the rest of the chapter builds
on, and it lands in the lu-kb successor surface
(`adsmt-ir-lukb`).

Refinements are usable everywhere a type is: in `const`,
`fn` parameter, and `fn` return position, on both sides of
an arrow, and as quantifier binders. They mean different
things in each position, but all three readings come from
the same place — a refinement is elaboration *sugar* over
the existing CIC kernel, so it adds no trusted surface:

- A *constant* `const c : {v : T | φ}` postulates `c : T`
  *plus* the trusted fact `φ[v := c]`. (Dropping that fact
  would be unsound, exactly as dropping `Nat`'s positivity
  on a free constant would be.)
- A *quantifier binder* relativises by polarity. The
  pre-verified relativization lemma says
  `∀(x : {v:T|φ}). P` becomes `∀(x:T). φ(x) ⟹ P`, and
  dually `∃` becomes `∧`. (Universal quantification guards
  with an implication, existential with a conjunction.)
- An *arrow domain* `{v:T|φ} -> U` is a *precondition*; an
  *arrow codomain* `A -> {v:T|ψ}` is a *postcondition*.
  We return to refined arrows below.

In the kernel a refined domain is just `Π(v:T). φ(v) -> Cod`
(a `T` together with a proof of `φ(v)`), and a refined
result is `Σ(v:T). φ(v)` (a `T` together with a proof). The
proof components are `Prop`-sorted, proof-irrelevant, and
*erased at lowering*: the SMT side only ever sees the base
sort `T` and the predicate `φ` routed through the
relativization. A malformed refinement can therefore only
fail to type-check — it can never reach the engine as
anything but an ordinary guarded formula.

`Nat` and `WNat` are not built-in sorts; they are two named
refinements of `Int`:

```
Nat  = {x : Int | x >= 1}
WNat = {x : Int | x >= 0}
```

Their positivity is exactly the refinement guard, which is
why the same machinery that handles a user-written
`{n : Int | n > 0}` also handles them.

=== `nop`: the trivial predicate

There is a uniformity trick that keeps all of this clean. A
built-in trivial predicate

$ "nop" : Pi(T : "Type"). T -> "Prop" := lambda T med x. "true" $

lets an *unrefined* `x : T` be read as `{x : T | nop(x)}`.
The refinement-aware logic then always sees a predicate —
`φ` or `nop` — and never needs a "refined versus unrefined"
special case. Because `nop(x) ≡ true`, a `nop` refinement
is *vacuous*: it is dropped, emitting no guard, no
hypothesis, and no contract, so the output stays clean while
the structure stays uniform. `const c : {v:T | nop(v)}` is
just `const c : T`; a plain arrow `A -> A` is
`{u:A|nop} -> {v:A|nop}` whose preservation obligations are
trivially `true`.

== Function types and refined arrows

A function type `T -> U` is the arrow former, right
associative: `A -> B -> C` parses as `A -> (B -> C)`. To put
an arrow in *domain* position you parenthesise it, so
`(A -> B) -> C` is a function taking a function.

A *refined arrow* puts refinements on the two ends:

```
{u : A | 'p} -> {v : A | 'q}
```

Its value sort is the plain `A -> A` — the refinements are
proof-irrelevant and erased at lowering. What the
refinements buy is a *contract*: the domain refinement `'p`
is a precondition the caller must establish, and the
codomain refinement `'q` is a postcondition. Crucially,
the contract flows *into* the body when such an arrow is
supplied as an *argument*: a parameter `f` of refined-arrow
type makes available the fact

$ "post"_f : forall (x : A). #raw("'p(x)") ==> #raw("'q(f(x))") $

as a usable hypothesis. That is not an unproven assumption —
supplying `f` at the refined-arrow type already obligated
whoever defined `f` to establish it.

== Generic predicate parameters

The `'p` and `'q` above were not concrete predicates; the
leading single quote marks them as *generic predicate
parameters*. This is *predicate polymorphism*: a function
can be parametric in the constraint it preserves, the way an
ordinary polymorphic function is parametric in a type.

The single quote is the disambiguator, decided at parse
time with no inference: `'p` is generic, a bare `q` is a
concrete in-scope predicate. So `{v:T | q(v)}` refines by a
specific `q`, while `{v:T | 'p(v)}` refines by a parameter.

A `fn` whose refinements mention `'p` binds it *implicitly*
at the head as `Π('p : T -> Prop)`. The payoff is the
*checked-once* guarantee: the body type-checks a single
time with `'p` held abstract, rather than being
re-elaborated per use site (which is what monomorphisation
would do). Each parameter refinement is a precondition, the
return refinement a postcondition, and the resulting
contract

$ forall arrow(#raw("'p")). forall arrow(x). (and.big_i "pre"_i) ==> "post" $

is treated two ways:

- For a *definition*, the contract is a *goal* — the
  construct-site obligation the body must discharge.
- For a *signature*, the contract is a *trusted axiom* — the
  user asserts it, and use sites are obligated instead.

At a use site `'p := q` is instantiated, the contract
becomes monomorphic, and the now-concrete precondition is
discharged. This is *dictionary passing*: the dictionary is
the concrete predicate `q` plus the value-level proof that
the argument satisfies it. Concrete refinement functions
(those with no `'p` at all) get the identical contract
treatment; they are simply the special case where the
dictionary is fixed in advance.

In the kernel, none of this is new: `g : {v:A|'p} -> {v:A|'p}`
is `Π(p:A→Prop). Π(v:A). p(v) → Σ(w:A). p(w)`, an ordinary
dependent type the kernel already checks. Predicate
polymorphism lives entirely at the dictionary layer, sharing
its source of truth with the type-class machinery we turn to
next — only monomorphic instances ever reach the engine.

== Type classes are type relations

adsmt's term for a type class is a *type relation*. These
are not two layers that resemble each other; they are *one
concept under one name*. The crate that implements them is
called `adsmt-class` and is, literally, the type-class
layer; everything it manipulates it calls a relation. When
this book says "type relation" it means exactly what Haskell
or Lean 4 would call a type class.

A type relation is a predicate-shaped relation over types,
together with an explicit dictionary of operations. In the
surface a user writes a class with methods and declares
instances; what the kernel and `adsmt-class` see is:

- A *`Relation`* of fixed arity — one or more type
  parameters, possibly with kind constraints, carrying the
  method signatures (and, as we will see, laws and predicate
  parameters).
- *`Instance`* witnesses asserting that specific types
  inhabit the relation, each carrying the dictionary of
  operation bodies, possibly via *premises* on other
  relations.
- A *`Resolver`* that performs instance lookup at every use
  site, walking premises to assemble the full `Dict`.

The `Instance` boundary rule (chapter 2) is exactly the
boundary into this layer: it delegates instance discharge to
the type-class elaborator and trusts the returned witness.

=== Dictionary passing

Relations are compiled away by *dictionary passing*: every
relation-constrained function gains an explicit dictionary
parameter at every use site. A function

```
sort : (Ord a) => List a -> List a
```

becomes

```
sort_with_dict : OrdDict a -> List a -> List a
```

with the dictionary explicitly threaded. The solver never
needs first-class instances internally; once dictionary
passing has been performed, the rest of the system sees
ordinary function applications. This is the same technique
GHC uses for Haskell classes and Lean 4 for its type-class
layer, and — as the previous section showed — it is also
exactly how a generic predicate parameter `'p` flows: a
refinement predicate travels as a dictionary entry the same
way a method does.

== Lawful-by-proof instances

A type relation carries more than method *signatures*. It
can carry *laws* — proof obligations every instance must
discharge to be admitted. The design intent is blunt: let
goals sit as members of a relation just like its functions,
and admit *only* the instances that prove every one of those
goals. A declaration that fails a law is not flagged at run
time; it is *build-rejected*.

A `Law` is a named obligation *builder*: given a `Dict` view
of an instance — its carrier type(s) plus a method resolver
that reaches through the instance's premises into superclass
dictionaries — it constructs the concrete closed,
`Bool`-typed HOL proposition that must hold. Because the
builder is a plain function pointer it adds no closure
state and leaves `Relation` cheaply `Clone`. At admission,
`declare_instance_lawful` builds each law and hands it to a
`LawProver`; the instance is admitted only if *every*
obligation is proven valid.

The soundness direction is one-sided and that is the whole
point. `LawProver::prove_valid` returns `true` only when it
genuinely has a proof (the goal's negation is
unsatisfiable). It may return `false` for a
valid-but-unprovable goal — that merely *rejects* an
instance (a completeness loss); it can never *admit* an
unlawful one. The gate is conservative, never unsound, and
it is adsmt's *own* engine that backs the `LawProver`: a
relation's laws are discharged by the same solver everything
else runs through.

```rust
pub fn install_numberlike_checked(
    db: &mut InstanceDb,
    prover: &dyn LawProver,
) -> Result<(), ClassError> {
    // Each instance's laws are built and proven before it is
    // admitted; an unproven law rejects the declaration with
    // ClassError::LawUnproven { relation, law }.
}
```

== The `*Like` family

The flagship lawful relations are the `*Like` number-system
family, declared as real `adsmt-class` relations. They form
a hierarchy along two axes that share a common `Reduces`
spine (the encode/decode bridge that lets a carrier-valued
operation reduce into the integers):

- *Order axis.* `PartialOrd(I)` provides a partial order
  `le : I -> I -> Bool` with the laws *reflexivity*,
  *antisymmetry*, and *transitivity*. `Ord(I)` is the
  total-order subtrait: it premises `PartialOrd(I)`, adds
  the *totality* law `∀a b. le a b ∨ le b a`, and introduces
  *no new method* — `le` is inherited through the premise,
  the same shape as Rust's `Ord : PartialOrd`.

- *Integer axis.* `PartialIntegerLike(I)` is the
  integer-like commutative core `{add, mul, domain}`, where
  `domain` is the per-carrier validity/positivity predicate.
  It deliberately omits `zero` (since `0 ∉ Nat`) and
  `neg`/`sub` (since `Nat`/`WNat` are not subtraction
  closed). `IntegerLike(I)` premises both
  `PartialIntegerLike(I)` and `Ord(I)`: an integer-like
  carrier that is *also* totally ordered. It is a pure
  conjunction marker — no own methods, no own laws,
  everything inherited through the two premises.

The premise-aware `Dict` is what makes inheritance work. The
totality law of `Ord` references `le`, which lives in the
`PartialOrd` dictionary; `Dict::method` resolves it through
the `Ord` instance's premise. Superclasses are admitted
before subclasses precisely so a subtrait law can resolve an
inherited method against an already-admitted premise.

The ground instances are the lu-kb arithmetic carriers
`Int`, `Nat`, and `WNat`. Their dictionary content connects
straight back to refinements:

- `le` is `Int.le` for `Int`; for `Nat`/`WNat` it is the
  restriction of `ℤ`'s order through the integer injection,
  `λa b. Int.le (ι a) (ι b)` (a `Bool` result needs no
  back-injection, so the restriction is total and sound).
- `domain` is `⊤` for `Int`, `ι x ≥ 0` for `WNat`, and
  `ι x ≥ 1` for `Nat` — the very positivity predicates that
  define the `WNat`/`Nat` refinements.

The lawful gate is not decoration here. An `Ord` instance is
admitted only if the engine discharges *totality* for its
`le`; a carrier with no compatible total order — a future
`FloatingPoint(M, E)` with `NaN`, say — is rejected by that
gate and stays `PartialOrd` only.

== Predicate parameters on a relation

Beyond methods and laws, a relation may carry a *predicate
parameter* `'p : T -> Prop` — the relation-level form of the
generic constraint parameters from earlier. An instance
supplies the concrete predicate as a dictionary entry, and a
`'p` constraint then resolves exactly like a method
constraint, flowing through the same `Relation` / `Instance` /
`Resolver` / `Dict` spine. The data model is in place:
`Relation::pred_params`, `Instance::preds`, and `Dict::pred` /
`require_pred`, with arity validated at declaration. This
is the registry half of predicate polymorphism — the
function-level `Π('p)` from earlier gives the checked-once
contract; the relation-level `'p` lets that predicate flow
across the whole interlock as a dictionary, one source of
truth shared with the methods.

== Preservation is a predicate, not a relation

It is tempting to make "preserves `'p`" into a relation —
something like `Preserving('p)` with an instance per type.
That is the *wrong abstraction*, and the reason is
coherence. A type relation is *coherent*: there is one
canonical instance per type. But a datatype `A` can have
*many* functions that preserve a given `'p`, and they need
not agree. Preservation is therefore a property of a
*function*, not of a type, and the right shape for it is a
*higher-order predicate* `preserving(f)`, checked
independently per function. (An earlier `Preserving('p)`
relation was built and then retired once this was clear.)

How do you *express* such a per-function property in the
surface? As exactly what it is — a *defined higher-order
predicate*. `preserving` takes the function and states the
preservation proposition directly:

```
fn preserving(f : {u:A | 'p(u)} -> {v:A | 'q(v)}) -> Bool
    = forall x : A. 'p(x) ==> 'p(f(x))
```

The refined-arrow argument erases to the value arrow
`A -> A`; its domain/codomain predicates `'p`/`'q` are
collected from inside the arrow and bound implicitly at the
head (predicate polymorphism), so the body may name `'p`. A
`Bool`-valued definition like this is just a δ-definition of
a proposition — it carries *no obligation of its own*. The
obligation appears only at a *use site*:
`preserving(even, ge0, double)` unfolds to the concrete
`∀x. even(x) ⟹ even(double(x))`, which the engine discharges.
(The plainest reusable form needs no generics at all — the
preserved predicate can be an ordinary higher-order argument
`fn preserving(p : A -> Bool, f : A -> A) -> Bool = forall x. p(x) ==> p(f(x))`.)

This is the resolution of a subtle trap. Were `preserving` a
proof-*producing* fn — a body that runs `solve … by …` and
returns the proof — its leaf obligation, closed over the
*generic* `'p`/`'q`, would be `∀'p 'q f. ('q(f x) ==> 'p(f x))`,
which is simply *false* (take `'p := λn. n >= 0`,
`'q := λn. n >= −5`, `f := λn. n − 3`: `f` inhabits the
refined arrow yet `f(0) = −3` is not `>= 0`). A definition
site cannot discharge it. As a *predicate*, there is no
def-site leaf at all — the leaf only materialises at a
concrete use, where it is honest and provable-or-not.

So when you want to *prove* a concrete `preserving(f)` goal
by hand — citing the image lemma `'q ==> 'p` together with
`f`'s postcondition `post_f : ∀x. 'p(x) ==> 'q(f(x))`
(asserted as an `axiom` for now) — that is exactly the
`solve … by …` construct of the next section. The definition
*states* the property; the cut *discharges* it.

== `solve … by …`: proof terms in the surface

`solve G by L` is an in-language *proof term*: a proof of
the proposition `G`, justified by the lemma `L`. It is the
structured-proof *cut* — "to prove `G` it suffices to
establish `L`; here is `L`." Its semantics is *proof-term
construction* (call it semantics B), not a runtime call to
the solver: in the value world there is no solving, only the
construction of a kernel-checked proof.

It elaborates to two obligations and a proof:

```
solve G by L   ⤳   let pf_L : L = <leaf obligation>
                   let pf_G : G = <bridge obligation, with L in scope>
                   pf_G
```

- The *leaf* `L` is the genuine content. The engine
  discharges it; a certificate is kernel-checked.
- The *bridge* is `G` under the hypothesis `L` (plus the
  ambient facts such as `post_f`) — usually a trivial
  modus-ponens step.

Both obligations are closed over the ambient context so they
are well-formed at top level, and both `G` and `L` may be a
*block* — a `let`-chain ending in the proposition it
denotes — so the user can name intermediate results inside
each clause.

The soundness is exactly the cut rule: if `⊢ L` and
`L ⊢ G` then `⊢ G`. The construct adds *no axiom* and *no
verdict write-path*. Both obligations are real goals checked
by engine and kernel; `by L` only *structures* the proof
(and names the key lemma so the system need not guess the
intermediate step). If either obligation is unprovable,
`solve G by L` fails to verify — so in the `preserving`
example above, an `f` whose `'q` does not imply `'p` is
simply rejected at check time. The kernel builds the
scaffold; the engine fills exactly one hole. The soundness
core of this is pre-verified in Verus (five verified, zero
errors).

=== Image binders

The `by` clause used a binder that is *not* a refinement
type:

```
forall {y = f(x) | 'p(x)}. q(y)
```

This is an *image binder*, a heavily type-inference-driven
abbreviation. It ranges over the inferred *preimage* `x`
(its sort recovered as `f`'s domain), guards it by the
constraint `c`, and binds the *image* `y = f(x)`, unfolding
`y` to `f(x)` in the body. So

```
forall {y = f(x) | p(x)}. q(y)
  ≡  forall x : {A | p(x)}. q(f(x))
```

via the pre-verified `image_quantifier_desugar` lemma. The
`=` (rather than `:`) is what distinguishes it at parse time
from the `{v:T | φ}` refinement binder; the elaborator runs
inference to recover `x`'s sort and the definitional
`y = f(x)` binding.

== The four-way interlock

These pieces are not a grab-bag of features; they are meant
to *organically interlock*. adsmt's core design intent is a
four-way interlock of type inference, abductive-deductive
logic, ASP, and SMT (with HKT underneath), and the typed
substrate of this chapter is the connective tissue:

- Type *inference* recovers the preimage and image of an
  image binder, and the kinds in a higher-kinded position.
- Refinement contracts are the *abductive-deductive* duality
  made typed — a construct site generates an obligation
  (abduction), a use site consumes the same fact as a
  hypothesis (deduction).
- A predicate parameter `'p` flows through the type-relation
  *dictionary* spine the same way a method does, so the
  *class* machinery carries constraint information into the
  engines.
- The lawful gate, the `solve … by …` leaf, and a refinement
  guard all bottom out in the *SMT* engine.

`IntegerLike(I, L, N)` is the first higher-kinded type-class
instance and the prototypical piece of connective tissue: a
relation that simultaneously carries methods, laws, premises,
and the positivity predicate that ties its carriers back to
their refinements.

== Implementation notes

A few engineering decisions to flag.

*Kind inference is bidirectional.* The user writes type
expressions where the kinds are usually obvious from
position; the elaborator infers them and refuses ambiguity.
This matches Haskell's `KindSignatures` machinery and is
approximately what Lean 4 does. The implementation fits in a
few hundred lines.

*Type relations resolve eagerly.* When a relation-constrained
expression is elaborated, instance lookup happens immediately
and the dictionary is inlined. There is no runtime lookup.
This pays off later — the SAT and theory layers never need to
reason about pending instances.

*Refinements add no trusted surface.* A `{v:T|φ}` is sugar
for a `Π`/`Σ` the kernel already checks, and its proof
components are erased at lowering. The worst a malformed
refinement can do is fail to type-check.

*Higher-kinded polymorphism is optional at the surface.* A
user who never writes `(f : Type -> Type)` constraints gets a
first-order-feeling experience. The HKT machinery is below
the surface, ready when needed but not paid for when not.

== The cost of HOL+HKT

This design choice is not free. It is harder to write a
correct kernel for HOL+HKT than for first-order logic; it is
harder to write theory solvers that handle the full
generality; it requires more care in proof reflection; and a
lawful-by-proof relation pays the cost of running the engine
at *build* time to admit an instance. The benefits — an
ITP-friendly surface, smooth reflection, refinement contracts
as a typed abductive-deductive substrate, and lawful classes
that cannot silently admit a broken instance — are what
justify the cost. Whether it is worth it for *your* solver is
a question only you can answer. adsmt's answer is yes.

The next chapter takes us to the SAT layer, which is
deliberately independent of the kernel: SAT solving knows
nothing about types or higher kinds, only about Boolean
satisfiability of CNF formulas. The kernel and SAT layer talk
to each other through a flat interface in which every theory
atom becomes a Boolean literal.
