= Equality and Uninterpreted Functions

== The simplest theory worth a name

EUF — *equality + uninterpreted functions* — is the
foundation. Almost every other theory builds on top.
Its signature has no fixed function or predicate
symbols; you declare your own:

```text
(declare-sort Term 0)
(declare-fun f (Term) Term)
(declare-fun g (Term) Term)
(declare-const a Term)
(declare-const b Term)

(assert (= (f a) (g b)))
(assert (= a b))
(assert (not (= (f a) (g a))))
(check-sat)  ;; unsat
```

The reasoning: from $a = b$ we get $f a = f b$ and $g a =
g b$ (function congruence). Combined with $f a = g b$, we
get $f b = g b$ and $f a = g a$. So the negation
$not(f a = g a)$ contradicts.

== Equality is special

Equality (`=`) has the following axiom schema, built
into EUF:

- *Reflexivity*: $forall x. x = x$
- *Symmetry*: $forall x y. x = y => y = x$
- *Transitivity*: $forall x y z. x = y and y = z => x = z$
- *Function congruence*: $forall vec(x) vec(y). vec(x) = vec(y)
  => f(vec(x)) = f(vec(y))$ for every $f$.

These four together generate the *congruence closure*
of any set of equalities — the smallest equivalence
relation that respects function application.

== Union-find + congruence closure

The decision procedure is *congruence closure*. Its data
structure is *union-find* (disjoint-set forest):

- Each term has a representative.
- `find(t)` follows parent pointers to the representative.
- `union(t1, t2)` merges two equivalence classes.

The congruence step kicks in when two terms have
representatives that just got merged. Walk the parents
of both classes — if any pair $(f(s_1, …, s_n), f(t_1,
…, t_n))$ has the property that $"find"(s_i) = "find"(t_i)$
for all $i$, then by congruence those parents must also
be in the same class. Merge them and repeat. The cascade
eventually terminates because there are only finitely
many terms.

```rust
fn union(&mut self, a: TermId, b: TermId) {
    let ra = self.find(a);
    let rb = self.find(b);
    if ra == rb { return; }
    self.parent[rb] = ra;
    let parents_a = self.collect_parents(ra);
    let parents_b = self.collect_parents(rb);
    for pa in parents_a {
        for pb in &parents_b {
            if self.are_congruent(pa, *pb) {
                self.union(pa, *pb);  // cascade
            }
        }
    }
}
```

The asymptotic complexity is near-linear in the number
of terms (with the right small-tweaks).

== EUF in adsmt

adsmt's `adsmt-theory::uf` module implements congruence
closure. It exposes the standard `Theory` interface
(companion ch. 5):

```rust
impl Theory for UfSolver {
    fn assert_literal(&mut self, l: Literal) -> Result<(), Conflict> { ... }
    fn check(&mut self) -> SatVerdict { ... }
    fn push(&mut self) { ... }
    fn pop(&mut self)  { ... }
    fn explain(&self, t: Term) -> Vec<Literal> { ... }
}
```

`explain` is the key for the cert path: when UF deduces
a fact (an equality, say), the cert needs to record
*which prior equalities* were used. `explain` walks the
union-find tree and returns the path.

== Why uninterpreted?

"Uninterpreted" means the function symbols have no
fixed meaning — they're constrained only by the
congruence axioms. You can model anything that respects
substitutivity: program functions, mathematical operators
you've chosen not to specify in detail, abstract
relations.

This makes EUF the ideal *backbone* theory. Other
theories (arithmetic, arrays, bitvectors) layer on top:
the array theory uses EUF to handle the index/value
algebra, the arithmetic theory uses EUF to model
unconstrained variables in linear constraints.

== Common patterns

*Program verification.* Treat function calls as
uninterpreted: `(declare-fun f (Int Int) Int)`. Assertions
about specific calls (`(= (f 1 2) 5)`) become EUF
hypotheses. The verifier never has to evaluate `f` —
it just reasons about *which calls return what*.

*Model abstraction.* Replace a complex relation with an
uninterpreted predicate. Useful in static analysis when
the actual relation is too expensive to encode.

*Equality chaining.* "$a = b$, $b = c$, $f a = 5$. What's
$f c$?" EUF answers $5$ trivially. The same chain in a
purely propositional formulation is much more verbose.

== Limits

EUF doesn't handle:

- Quantifiers (chapter 7).
- Function definitions — `(define-fun ...)` substitutes
  syntactically, but doesn't deduce facts about
  partially-known functions.
- Higher-order equations — $f = g$ as a hypothesis is
  EUF-trivial, but solvers usually don't *deduce*
  function equalities except in special cases.

For most of these, the trick is to *abduce*: ask the
abductive layer (chapter 8) what hypothesis would
discharge the goal. If the answer is "assume $f =
g$", the user can decide whether the assumption is
reasonable.

== Worked example

A short Lean 4 proof obligation feeding into adsmt:

```lean
example (a b : Nat) (h : a = b) :
    (f a) + (g b) = (f b) + (g a) := by
  smt_decide [h]
```

The `smt_decide` tactic translates the goal to SMT-LIB
EUF + LIA mix, asserts the negation, and asks for unsat.

The translated SMT-LIB:

```text
(declare-sort Nat 0)
(declare-fun f (Nat) Nat)
(declare-fun g (Nat) Nat)
(declare-const a Nat)
(declare-const b Nat)
(assert (= a b))
(assert (not (= (+ (f a) (g b)) (+ (f b) (g a)))))
(check-sat)
;; unsat
```

The cert contains: refl on $f(a)$, congruence with $a =
b$ to get $f(a) = f(b)$, congruence on $g$, and an LIA
step proving the swapped sum equality.

This is EUF doing what it's best at: chasing equalities
through function applications. The downstream Lean
elaborator turns the cert back into a real Lean term
under the kernel.
