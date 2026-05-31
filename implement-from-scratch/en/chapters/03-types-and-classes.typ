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

== Type classes

A *type class* is a predicate-shaped relation over types,
together with an explicit dictionary of operations. In
adsmt's surface the user writes:

```
class Ord (a : Type) where
  le : a -> a -> Bool
```

and at use sites:

```
instance Ord Int where
  le = int_le
```

The classes are sugar; what the kernel sees is:

- A *relation* (`Ord`) of a fixed arity — one or more types,
  possibly with kind constraints.
- *Instance witnesses* asserting that specific types are
  members of the relation, accompanied by the dictionary
  of operations.
- *Class application* that resolves an instance lookup at
  every use site.

The `Instance` boundary rule (chapter 2) is exactly the
boundary into this layer: it delegates instance discharge
to the type-class elaborator and trusts the returned
witness.

== Dictionary passing

Classes are compiled away by *dictionary passing*: every
class-constrained function gains an explicit dictionary
parameter at every use site. A function

```
sort : (Ord a) => List a -> List a
```

becomes

```
sort_with_dict : OrdDict a -> List a -> List a
```

with the dictionary explicitly threaded. The solver never
needs first-class class instances internally; once dictionary
passing has been performed, the rest of the system sees
ordinary function applications.

This is the same technique GHC uses to compile Haskell
classes and that Lean 4 uses for its type-class layer. It
makes proof reflection simple because the dictionary is a
plain term-level structure that can be carried through
verbatim.

== Higher-kinded relations

A `Functor` class operates on entities of kind
`Type -> Type`:

```
class Functor (f : Type -> Type) where
  map : (a -> b) -> f a -> f b
```

Instances at this kind look like:

```
instance Functor List where
  map = list_map
```

The instance lookup happens at kind `Type -> Type` —
exactly the higher-kinded position. The kernel handles
this through the same `Instance` rule; the difference is
just that the `types: Vec<Type>` field carries entities
of higher kind, and the kind-checker is consulted at
instance lookup time.

== Implementation notes

A few engineering decisions to flag.

*Kind inference is bidirectional.* The user writes type
expressions where the kinds are usually obvious from
position; the elaborator infers them and refuses ambiguity.
This matches what Haskell's `KindSignatures` machinery does
and is approximately what Lean 4 does. The implementation
fits in a few hundred lines.

*Type classes resolve eagerly.* When a class-constrained
expression is elaborated, instance lookup happens
immediately and the dictionary is inlined. There is no
runtime lookup. This pays off later — the SAT/theory
layers never need to reason about pending instances.

*Higher-kinded polymorphism is optional at the surface.*
A user who never writes `(f : Type -> Type)` constraints
gets a first-order-feeling experience. The HKT machinery
is below the surface, ready when needed but not paid for
when not.

== The cost of HOL+HKT

This design choice is not free. It is harder to write a
correct kernel for HOL+HKT than for first-order logic; it
is harder to write theory solvers that handle the full
generality; it requires more care in proof reflection. The
benefits — ITP-friendly surface, smooth reflection,
expressiveness for proof obligations adjacent to typed
programming — are what justify the cost. Whether it is
worth it for *your* solver is a question only you can
answer. adsmt's answer is yes.

The next chapter takes us to the SAT layer, which is
deliberately independent of the kernel: SAT solving knows
nothing about types or higher kinds, only about Boolean
satisfiability of CNF formulas. The kernel and SAT layer
talk to each other through a flat interface in which every
theory atom becomes a Boolean literal.
