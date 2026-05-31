= Propositional Logic and SAT

== Atoms, connectives, formulas

Propositional logic is about *atoms* — Boolean variables
that can be true or false — combined with the standard
connectives: and ($and$), or ($or$), not ($not$),
implies ($=>$), iff ($<=>$).

A *formula* is built from atoms and connectives.
A *truth assignment* (or model) maps each atom to true or
false. A formula is *satisfiable* if some assignment
makes it true.

The classical example:

```text
(p ∨ q) ∧ (¬p ∨ r) ∧ (¬q ∨ ¬r)
```

This formula has eight possible assignments to $(p, q, r)$.
A satisfying one is $(T, F, T)$: $p$ is true (so the first
clause holds), $r$ is true (so the second clause holds via
$not p or r$), $q$ is false (so the third clause holds via
$not q or not r$).

== CNF — conjunctive normal form

A formula is in *CNF* (conjunctive normal form) if it's
an `and` of `or`s of literals (atoms or negated atoms).
Every propositional formula has an equivalent CNF, and
the standard SAT input format (DIMACS) requires it.

```text
( p ∨  q     ) ∧
(¬p ∨  r     ) ∧
(¬q ∨ ¬r     )
```

Each `or`-clause is just a *clause*. The CNF form is a
conjunction of clauses, abbreviated `{c_1, c_2, ..., c_n}`.

== Why CNF?

CNF is easy to work with because of one observation:
*for a CNF formula to be true, every clause must be
true*. So a SAT solver's job decomposes into "find an
assignment that satisfies every clause." If any clause
is forced false, the candidate assignment is dead.

This gives the SAT solver concrete pruning rules:

- *Unit propagation.* If a clause has one un-assigned
  literal and all others are false, that literal must be
  true.
- *Conflict driving.* If a clause has all literals false,
  the assignment can't be extended; back-track.

These two rules alone power *DPLL* (Davis-Putnam-Logemann-
Loveland), the spiritual ancestor of every modern SAT
solver.

== CDCL — the modern SAT engine

Modern SAT solvers don't just back-track on conflict;
they *learn* from each conflict. The pattern is:

1. *Pick.* Choose an un-assigned variable (using a
   heuristic) and tentatively assign it.
2. *Propagate.* Apply unit propagation to derive forced
   assignments.
3. *Conflict.* If propagation hits a clause where all
   literals are false, analyse the conflict's chain of
   causes back to a *cut point*; emit a *learnt clause*
   summarising the chain.
4. *Back-track.* Undo assignments back to a level where
   the learnt clause can fire useful propagations.
5. *Repeat.*

This is *CDCL*: Conflict-Driven Clause Learning. Almost
every state-of-the-art SAT solver is a CDCL variant.

The trick is *what to learn*. The standard cut is the
*1-UIP* (first unique implication point): walk the
conflict's implication graph backwards from the
contradiction until you hit a single literal that, if
flipped, would have prevented the conflict. The learnt
clause is the negation of that path.

== Heuristics

CDCL's pick-step uses *VSIDS* (Variable State Independent
Decaying Sum): each variable has a score that bumps when
it appears in a learnt clause, decaying over time.
High-score variables get picked first; the heuristic
focuses the search on "hot" variables.

CDCL's restart-step uses *Luby sequences* (or geometric
variants): periodically discard the current decision
stack and start fresh, with learnt clauses preserved.
Restarts escape pathological search regions.

These two heuristics, combined with two-watched-literal
propagation and LBD-based learnt-clause cleanup, are the
standard CDCL toolkit. adsmt's SAT layer implements all
of them.

== From SAT to SMT — the bridge

An SMT formula's *Boolean skeleton* is a CNF: replace
each theory atom (like `(< x 3)` or `(= (f a) b)`) with
a fresh Boolean variable, and treat the formula as
propositional. The SAT solver tries to satisfy the
skeleton; for each candidate, the *theory solver* checks
whether the literal pattern is consistent with the
theory.

```text
Theory atoms:    A := (< x 3)
                 B := (> x 5)
                 C := (= y 0)

Boolean skeleton: (A ∨ C) ∧ (B ∨ C) ∧ (¬A ∨ ¬B)

SAT tries:       A=T, B=T, C=T
                 → theory check: (< x 3) ∧ (> x 5) is unsat!
                 → SAT learns the clause (¬A ∨ ¬B)
                 (already there, so this trial dies fast)
SAT tries:       A=T, B=F, C=T
                 → theory check: (< x 3) ∧ ¬(> x 5) ∧ (= y 0)
                 → satisfiable with x = 0, y = 0
```

The loop is *DPLL(T)*: SAT proposes Boolean assignments,
the theory checks them. We'll see the architecture in
chapter 3.

== Decidability and complexity

SAT is *NP-complete* — there's no known polynomial-time
algorithm that decides every SAT instance. In practice
modern solvers handle industrial instances with millions
of variables in seconds; in the worst case they take
exponential time. The gap between worst-case and
practical performance is one of the great empirical
phenomena in computer science.

SMT inherits SAT's NP-hardness (at minimum) and adds the
theory layer's complexity on top. For some theories
(LIA, BV at fixed widths) the combination remains in NP;
for others (real closed fields, full quantified LIA), it
escalates further. The undecidable fragments (general
first-order with arithmetic) are why `unknown` is a
real verdict.

We turn to the theory side next.
