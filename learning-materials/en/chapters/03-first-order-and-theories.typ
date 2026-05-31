= First-Order Logic and Theories

== Beyond propositional

Propositional logic's atoms have no internal structure.
"$p$ is true" is the only thing you can say about $p$.
*First-order logic* extends this with:

- *Variables* ranging over a domain.
- *Function symbols* — `+`, `f`, `succ` — that take terms
  and return terms.
- *Predicate symbols* — `<`, `=`, `prime?` — that take
  terms and return Booleans.
- *Quantifiers* — $forall$, $exists$ — that bind
  variables.

So instead of just $p$, we can write $forall x. (P(x) =>
Q(f(x)))$. The atoms are now *applications* — $P(x)$,
$Q(f(x))$ — with structure the solver can exploit.

== Syntax vs. semantics

A *signature* names the function and predicate symbols of
a logic. A *theory* is a signature plus a set of axioms
constraining how those symbols behave. A *model* of the
theory is an interpretation — a domain plus actual
functions and relations — that satisfies the axioms.

For example, the *theory of integer arithmetic* has the
signature $\{+, -, *, <, =, 0, 1, …\}$ and axioms that
say "this is the usual integer arithmetic". Its model is
$ZZ$ with the usual operations.

A formula $phi$ over a theory $T$ is *T-satisfiable* if
some model of $T$ makes $phi$ true. SMT solvers decide
T-satisfiability for various $T$.

== Theories in SMT-LIB

The SMT-LIB standard defines a fixed roster of theories.
adsmt supports a subset (companion appendix A):

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Theory*], [*Atoms*]),
  [`Core` / EUF], [Equality + uninterpreted function symbols],
  [`Ints` / LIA], [Integers, linear arithmetic],
  [`Reals` / LRA], [Reals, linear arithmetic],
  [`FixedSizeBitVectors`], [Fixed-width bit-vectors],
  [`ArraysEx`], [Maps with read/write],
  [`Datatypes`], [Algebraic data types (lists, trees, …)],
)

Each theory has a *decision procedure*: an algorithm that
decides T-satisfiability for atoms of that theory. The
SMT engine routes each atom to the appropriate decision
procedure.

== Quantifier-free vs. quantified

A *quantifier-free* (QF) formula has no $forall$ or
$exists$. Most QF fragments of the common theories are
decidable in NP. The SMT-LIB logic names start with `QF_`
to mark them: `QF_LIA`, `QF_BV`, `QF_AUFLIA`.

A *quantified* formula has at least one quantifier. Most
quantified fragments (with the notable exception of
Presburger arithmetic — quantified LIA — which is
decidable but very expensive) are undecidable.

Practical SMT solvers handle quantifiers *heuristically*:
they look for term-level instantiations that discharge
the formula. The instantiation might be enough; if not,
the solver returns `unknown` (or, in adsmt's case,
`abductive`). Chapter 7 covers quantifier handling in
detail.

== Theory atoms in the Boolean skeleton

Recall from chapter 2: the SAT layer treats each theory
atom as a fresh Boolean variable. The theory layer's job
is to determine which *combinations* of true/false
assignments to those atoms are consistent.

```text
SMT formula:    (< x 3) ∧ ((< x 0) ∨ (> x 5))

Theory atoms:   A := (< x 3)
                B := (< x 0)
                C := (> x 5)

Boolean skeleton: A ∧ (B ∨ C)

SAT proposes:   A=T, B=T, C=F
Theory check:   "x < 3 and x < 0 and ¬(x > 5)" — sat
                (e.g. x = -1)
Verdict:        sat with model x = -1
```

In a more interesting case, the theory check fails:

```text
SAT proposes:   A=T, B=F, C=T  (i.e. x < 3 and ¬(x < 0) and x > 5)
Theory check:   "x < 3 and 0 ≤ x and x > 5" — unsat
                (no integer in (-∞, 3) ∩ [0, ∞) ∩ (5, ∞))
SAT learns:     (¬A ∨ B ∨ ¬C) and tries another assignment
```

This back-and-forth between SAT and theory is the
*DPLL(T)* loop. Each turn refines the search.

== Combining theories

Real-world formulas mix theories. "Array of integers,
indexed by integers, satisfying a linear arithmetic
constraint on the indices" mixes Arrays + LIA. SMT
solvers need to *combine* decision procedures
gracefully.

The classical approach is *Nelson-Oppen combination*:
two theories cooperate by exchanging the equalities they
deduce on shared variables. So if Arrays deduces "$x = y$"
and LIA deduces nothing more, the LIA solver inherits
$x = y$ as a hypothesis on next check.

Nelson-Oppen has technical preconditions (stably
infinite, signature disjoint, …). When the preconditions
hold, the combined decision procedure is sound and
complete. When they don't, modern solvers fall back to
*polite combination* (Tinelli-Zarba) or other
generalisations.

adsmt uses polite combination by default. The user
doesn't normally see this — the SMT engine routes atoms
automatically, and the combination machinery is silent.
But the engineering challenge is real: most SMT engine
complexity lives in the combination layer.

== "Modulo theories" — finally explained

The full picture:

```text
A formula's Boolean structure  ←→  SAT solver
A formula's theory atoms       ←→  theory solvers
  (one per theory in use)
Cross-theory equalities         ←→  combination layer
Quantifier instantiations       ←→  quantifier layer
```

"Modulo theories" means: the SAT layer reasons *as if*
theory atoms were just Booleans, while the theory layer
fills in their actual semantic content. The factoring is
what makes SMT scale to industrial-size problems.

== Next steps

The next four chapters tour the individual theories in
the order they're typically encountered:

- Chapter 4: Equality + uninterpreted functions (EUF).
- Chapter 5: Arithmetic (LIA, LRA).
- Chapter 6: Bitvectors, arrays, datatypes.

Each chapter covers what the theory is good for, what
its decision procedure looks like at a sketch level, and
how to write SMT-LIB scripts that exercise it well.
