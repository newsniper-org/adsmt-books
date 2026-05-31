= What is SMT?

== The problem in one sentence

SMT — *Satisfiability Modulo Theories* — asks: given a
logical formula that may use functions and predicates
*interpreted* over standard mathematical structures (the
integers, the reals, bit-vectors, arrays, …), is it
satisfiable?

A *satisfiable* formula has an assignment of values to its
variables — and a consistent interpretation of its
function symbols — that makes the formula true. An
*unsatisfiable* formula has no such assignment.

== Some examples

```text
;; Satisfiable: a = 3 works.
(declare-const a Int)
(assert (> a 2))
(assert (< a 10))

;; Unsatisfiable: no real number is both > 5 and < 4.
(declare-const r Real)
(assert (> r 5.0))
(assert (< r 4.0))

;; Satisfiable: pick x = 0, y = 0, A any.
(declare-const x Int)
(declare-const y Int)
(declare-const A (Array Int Int))
(assert (= (select (store A x 1) x) 1))
(assert (= y 0))
```

The first example uses linear integer arithmetic (LIA).
The second uses linear real arithmetic (LRA) — and is
unsatisfiable because no real lies in $(5, 4)$, which is
empty. The third uses an array theory: storing 1 at
index `x` and then reading at `x` returns 1, which is
trivially true regardless of `A` and `y`.

== Why not just SAT?

Vanilla *propositional satisfiability* (SAT) handles
Boolean formulas — variables that are just true or false.
Modern SAT solvers are astonishingly fast: industrial
SAT instances with millions of variables routinely run
in seconds.

But many practical questions don't fit SAT directly.
"Is there an integer $x$ with $3 x + 2 = 14$?" isn't a
Boolean question; it's an arithmetic one. You could
*encode* it into SAT (bit-blast $x$ into 32 bits, encode
addition as binary adders, encode equality as bit-wise
xor + nor), and the resulting SAT formula does answer
the original question. But the encoding is enormous and
loses the *structure* — the SAT solver re-derives
arithmetic facts from scratch instead of using a fast
linear-arithmetic decision procedure.

SMT is the marriage. The propositional skeleton goes to
a SAT solver; the theory atoms (arithmetic, bitvector,
array, …) go to dedicated theory solvers; the layers
cooperate.

== Verdicts

An SMT solver answers a `(check-sat)` query with one of:

- *sat* — the formula has a model; ask `(get-model)` to
  see it.
- *unsat* — no model exists; ask `(get-unsat-core)` to
  see a minimal contradicting subset of assertions.
- *unknown* — the solver couldn't decide. Reasons range
  from quantifier-instantiation budget exhaustion to
  hitting an undecidable fragment.
- *abductive* (adsmt-specific) — the solver couldn't
  discharge the goal but produced a ranked list of
  hypotheses that *would* discharge it. Ask
  `(get-abductive-candidates)` for the list.

The first three are standard across SMT solvers; the
fourth is adsmt's distinguishing feature, and we'll
spend chapter 8 on it.

== The big picture

A typical adsmt workflow:

```text
User writes SMT-LIB script
       ↓ (parse)
Engine asserts formulas
       ↓ (check-sat)
Verdict: sat / unsat / abductive / unknown
       ↓ (extract)
Model, core, candidates, certificate
       ↓ (downstream)
ITP integration, code generation, decision support, ...
```

The most striking thing about this workflow is that it
applies across an enormous range of domains — program
verification, planning, scheduling, type inference,
synthesis. Same SMT-LIB script shape, same verdict
semantics, dramatically different uses.

== Why "modulo theories"?

The phrase echoes ring-theoretic "modulo" — work over a
quotient structure. An SMT formula's atoms are
interpreted *modulo* the theory's axioms: integers obey
arithmetic, arrays obey read-over-write, bit-vectors
obey their fixed-width algebra. The SAT layer doesn't
know what `+` means; it just treats `(+ x 3)` and `(+ x 3)`
as the *same Boolean variable* (if they appear in the
same formula), and the theory layer fills in the
semantic content.

This factoring — Boolean structure on one side, theory
semantics on the other — is what makes SMT scale. Each
layer is tuned to a problem it can solve well; the
combination handles formulas neither could on its own.

== A typical day in the life of an SMT solver

Many readers come to SMT through one of three doors:

1. *Verification.* "Prove this C function never
   dereferences null." Compile down to verification
   conditions; ask SMT.
2. *Program synthesis.* "Find a function such that…" —
   express the constraint, ask SMT for a witness.
3. *Interactive theorem proving.* "I'm halfway through a
   Lean proof and this sub-goal is gnarly. Can SMT just
   discharge it?"

adsmt is optimised for the third case. The kernel of
chapter 9 (certificate format), the Lean 4 reflection
of chapter 10, and the abductive surface of chapter 8
all serve the workflow "I'm in an ITP, SMT please
finish this for me — and if you can't, tell me why."

The next chapters dive into the layers that make this
possible.
