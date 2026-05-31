= The kernel

== Why have a kernel at all

A *kernel* in the sense used here is the smallest possible
set of inference rules that the rest of the solver is
allowed to invoke. Every step in every theory must
ultimately resolve into kernel rule applications; nothing
that produces a `Theorem` may sit outside this trusted base.
The contract is exact: the kernel is small enough to read
in an afternoon and audit in a weekend, and any code that
*claims* to produce a `Theorem` without going through the
kernel is a bug. This is the same architecture used by HOL
Light, Isabelle/HOL, and (with adaptations) Lean 4 and Rocq.

The payoff is enormous. Bugs in theory code do not break
soundness; the worst they can do is fail to derive a result
that the theory should have derived. Bugs in the SAT layer
do not break soundness; the worst they can do is loop or
miss a propagation. The trusted computing base — the code
that, if buggy, would let a false proposition be derived —
shrinks to a tiny self-contained core.

== The 12-rule kernel

adsmt's kernel exposes exactly twelve primitive inference
rules. They come in three groups: equality reasoning,
abstraction and reduction, and modus-ponens-style
combination. Listed by name:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header(
    [*Group*], [*Rule*], [*Meaning*]
  ),
  [equality], [`Refl(t)`], [$t = t$ for any term $t$],
  [equality], [`Trans(h_1, h_2)`], [from $a = b$ and $b = c$ derive $a = c$],
  [equality], [`EqMp(h_iff, h_p)`], [from $p arrow.l.r.double q$ and $p$ derive $q$],
  [abstraction], [`Abs(x, h_eq)`], [from $f x = g x$ derive $lambda x. f x = lambda x. g x$],
  [abstraction], [`Beta(redex)`], [$ (lambda x. b) a = b[x := a] $],
  [combination], [`Deduct(h_a, h_b)`], [from $A$ derive $B$ derive $A arrow.r B$],
  [combination], [`Inst(sigma, h_thm)`], [substitute term-level variables in a theorem],
  [combination], [`InstType(sigma, h_thm)`], [substitute type-level variables in a theorem],
  [boundary], [`Assume(t)`], [introduce $t$ as a hypothesis],
  [boundary], [`Theory{name, witness, parents}`], [delegate to a theory solver and trust its witness],
  [boundary], [`Instance{relation, types, witness}`], [discharge a type-class instance obligation],
  [boundary], [`Assumed{formula, explain}`], [abductive marker — `sorry`-shaped placeholder],
)

These twelve rules are exhaustive in the sense that every
proof step adsmt produces uses one and only one of them.
They are also disjoint: no rule overlaps any other.

== Terms and types

To state the rules precisely we need to fix the term
language. adsmt's terms are the standard simply-typed
lambda calculus extended with type-class application:

$ t ::= x | c | t_1 t_2 | lambda x : tau. t $

where $x$ ranges over term variables, $c$ over constants
(introduced by the type system at signature time), and the
binders allow nesting. Types are:

$ tau ::= alpha | C | tau_1 -> tau_2 $

where $alpha$ is a type variable, $C$ a type constant, and
the arrow forms function types. We discuss how higher
kinds enter the picture in chapter 3.

A *theorem*, formally, is a pair $(Gamma, t)$ where $Gamma$
is a multiset of formulas (the hypotheses) and $t$ is a
Boolean-sorted term (the conclusion). The standard
turnstile notation $Gamma tack t$ reads as usual. Each
kernel rule is a partial function from theorems and term-
level arguments to a new theorem; failure of the partial
function (e.g. trying to apply `Trans` to a pair of
theorems whose middle terms do not match) raises a kernel
error, which the surrounding code must handle.

== Representation in code

adsmt represents the kernel in Rust roughly like this:

```rust
pub enum Term {
    Var(Arc<Var>),
    Const(Arc<Const>),
    App(Arc<Term>, Arc<Term>),
    Lam(Arc<Var>, Arc<Term>),
}

pub struct Theorem {
    hypotheses: Vec<Term>,
    conclusion: Term,
}

pub fn refl(t: Term) -> KernelResult<Theorem> {
    let eq = mk_eq(t.clone(), t)?;
    Ok(Theorem {
        hypotheses: Vec::new(),
        conclusion: eq,
    })
}
```

Every rule is one function. The functions live in a module
that exposes the `Theorem` constructor *only* through these
twelve rules — the struct's fields are private and there is
no public `Theorem::new`. Anywhere outside the kernel
module, the only way to produce a value of type `Theorem`
is to call a kernel rule. This is the same trick HOL Light
uses with OCaml's module system; adsmt uses Rust's privacy
to achieve the same end.

The `Arc` wrappers are an efficiency hack: terms are
immutable and frequently shared, so reference-counted
pointers let subtree sharing reduce allocation pressure.
The kernel does not depend on `Arc` for correctness; a
purely-owned `Box` version would compute the same theorems
at higher memory cost.

== Boundary rules in detail

The four boundary rules — `Assume`, `Theory`, `Instance`,
`Assumed` — are where the kernel admits content from
outside itself. Each one is a trust point.

`Assume(t)` is straightforward: it produces $t tack t$.
The hypothesis appears on both sides, and the surrounding
proof must eventually discharge $t$ via `Deduct`. This
rule introduces no trust risk: anything proved by `Assume`
remains hypothetical until discharged.

`Theory{name, witness, parents}` is where adsmt's theory
solvers re-enter the kernel. The `witness` is a structured
record explaining why the theory believes a conclusion
follows from the parents. The kernel does not check the
witness — it trusts the theory solver to have produced
something correct. This is the same trust model SMT
solvers in general use: theory solvers are trusted code.
What adsmt adds is a *structured witness* that downstream
consumers (proof checkers, ITPs) can use to reconstruct an
independent verification.

`Instance{relation, types, witness}` is the type-class
counterpart: instance discharge for a relation at given
types is delegated to the type-class layer, which produces
a witness. Again the kernel trusts; the witness lets
downstream consumers re-check.

`Assumed{formula, explain}` is the *abductive* marker — a
deliberate, named, structured `sorry`. When the abductive
engine proposes a hypothesis the user has not yet
accepted, the proof tree contains an `Assumed` step
recording exactly which formula is being assumed and a
human-readable explanation of why. This is the kernel's
formal handle for "this proof isn't done yet". Downstream
consumers (ITPs, cert checkers) treat `Assumed` steps as
proof-gap markers, not as completed proofs.

== Soundness of the kernel

The twelve rules are jointly sound: the small-step kernel
calculus they define has the property that if every
boundary rule is invoked with a *correct* witness, every
producible theorem $(Gamma, t)$ has the standard semantics
$Gamma models t$. We do not prove this here — the proof
follows the usual pattern for simply-typed lambda calculi
extended with theory atoms, and is standard textbook
material (see Pierce's _Types and Programming Languages_
or Harrison's _Handbook of Practical Logic and Automated
Reasoning_). What matters for our purposes is that the
proof exists, and that it has been carried out for the
specific kernel adsmt uses.

The soundness of the boundary rules is *conditional* on the
correctness of the theory solvers and the type-class
elaborator. That is the trust we accept by including those
rules; we mitigate it by emitting structured witnesses
that allow independent re-checking.

== Implementation order

When building this yourself, implement the kernel first
and resist the temptation to make any other code depend
on details that the kernel does not yet support. The
discipline is the same one HOL Light teaches: get the
kernel right and small, then everything else can be
written on top with confidence. Tests at the kernel level
should cover every rule individually, plus a small set of
multi-rule proofs (e.g. proving that $x = y arrow.r y = x$
via `Trans` and `Refl`). adsmt's `adsmt-core` crate has
this exact structure.
