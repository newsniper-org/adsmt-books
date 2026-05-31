= Quantifiers

== The two senses of "quantifier" trouble

When an SMT user complains "quantifiers", they usually
mean one of two distinct things:

1. *Performance* — "my benchmark has $forall$, the
   solver's slow / returns unknown."
2. *Completeness* — "there's a formula I know is unsat
   but the solver can't prove it."

Both stem from the same root: most quantified fragments
are undecidable, and even the decidable ones are
expensive. Solvers handle quantifiers with *heuristic
instantiation*, which is fast when it works and
unreliable when it doesn't.

== The instantiation idea

A universal $forall x. phi(x)$ says $phi(x)$ holds for
*every* $x$ in the domain. If the rest of the formula
mentions some specific terms — $a$, $f(b)$, $g(c, d)$ —
the solver can *instantiate* $forall x. phi(x)$ at each
such term and add the resulting ground atoms.

```text
(declare-sort Term 0)
(declare-fun f (Term) Term)
(declare-const a Term)
(declare-const b Term)
(assert (forall ((x Term)) (= (f x) x)))
(assert (= a b))
(assert (not (= (f a) b)))
(check-sat)
```

The universal says $f(x) = x$ for every $x$. Instantiate
at $a$: $f(a) = a$. Combine with $a = b$: $f(a) = b$,
contradicting the assertion. Verdict `unsat`.

The cleverness is in *picking* the instantiation point.
Try every ground term? Combinatorially explosive in big
problems. Try none? Lose information.

== E-matching

The standard heuristic is *E-matching*. The quantified
formula carries a *trigger* — a sub-pattern containing
the bound variable. When a ground term *matches the
trigger* (modulo equality reasoning), instantiate.

```text
(assert (! (forall ((x Term)) (= (f x) x)) :pattern ((f x))))
```

The trigger here is `(f x)`. Any time a ground term of
shape `(f ?)` appears, instantiate $x$ to the matching
sub-term. Modulo equality means: if the ground term is
`(f y)` and we know $y = a$, the match still fires.

== Miller patterns

A trigger is a *Miller pattern* if every occurrence of
the bound variable appears as a sub-application of
distinct local variables. Miller patterns admit linear-
time matching. adsmt accepts both Miller and non-Miller
patterns; non-Miller patterns get a warning and a
slower matching path.

```text
:pattern ((f x))            ; Miller
:pattern ((f x x))          ; non-Miller: x appears twice
:pattern ((f (g x)))        ; Miller via nested fixed pattern
```

== Triggers — picking the right one

Trigger choice matters enormously. Pick too restrictive
a trigger, and the solver finds no instantiations
when one would discharge. Pick too permissive, and
the solver instantiates indiscriminately and runs out of
budget.

The standard heuristic when no trigger is given: pick
the smallest sub-term of the body that *covers* every
bound variable. adsmt's `learn_triggers` does this
greedy depth-ordered pass (companion ch. 7).

If you find yourself fighting trigger choice, the
escape is to *write the trigger explicitly*. Lean 4's
`smt_decide` tactic accepts a `:trigger` clause; the
SMT-LIB surface accepts `(! phi :pattern (...))`.

== When E-matching fails

E-matching can fail for several reasons:

- *Pattern miss.* No ground term shaped like the
  trigger appears in the formula.
- *Combinatorial explosion.* Triggers fire millions of
  times, each instantiation cheap but the aggregate
  intractable.
- *Theory-buried witnesses.* The needed instantiation
  involves a term that exists only after a chain of
  theory reasoning.

adsmt's response is the *Tier* system:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Tier*], [*Strategy*]),
  [1], [E-matching against the universe of ground terms],
  [2], [Conflict-driven instantiation],
  [3], [Bounded enumeration of candidate terms],
  [4], [Abductive — emit the quantifier as a candidate hypothesis],
)

Tiers 1-3 are gradient relaxations. Tier 4 is qualitative:
"I can't find an instantiation, so I'll surface the
quantifier as a thing the user might need to accept as
an assumption to make the proof go through."

== The abductive escalation

When all tier-1-2-3 efforts exhaust, the engine returns
`SatResult::Abductive` with the quantifier-derived
candidate. This is what makes adsmt's quantifier
handling *non-binary*: instead of "I gave up", you get
"I gave up *but here's what would have worked*."

The candidate format:

```text
(abductive-candidate
  :hypothesis ((or (= x a) (= x b)))
  :justification (quantifier_exhausted
    :var x
    :original-body (= (f x) x))
  :rank 1)
```

A user accepts the candidate by adding the hypothesis
as an assertion. The solver then re-runs and either
discharges the original goal (the hypothesis was
enough) or surfaces additional candidates.

== When to *not* use quantifiers

A pragmatic suggestion: if you can express your
constraint without quantifiers (by *instantiating
yourself* — write out the finitely many cases), do.
Quantifier-free fragments are decidable in NP and
robust; quantified fragments are heuristic and brittle.

Common patterns where this works:

- "$forall x in {a, b, c}. P(x)$" → write out three
  conjuncts.
- "$forall x. (x = a or x = b) => P(x)$" → write out
  the two conjuncts.
- "$forall x. P(x) => Q(x)$ over a *finite* set
  characterised by a recursive predicate" → write the
  cases inductively (in the ITP, not in SMT).

These transformations push the quantifier-handling
work *out* of SMT and into either the user's editor or
the ITP's induction tactics.

== Quantifiers in real proof scripts

A Lean 4 tactic invocation:

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) : xs.head? ≠ some 0 := by
  smt_decide [h]
```

The `smt_decide` tactic translates the goal to SMT-LIB
with $forall$ explicit, applies trigger learning (one
trigger: `(mem x xs)`), and tries instantiation. For
this concrete shape the verdict is `unsat` (List.head?
returns either none or Some of a positive number).

If the instantiation fails — say the hypothesis was
over a more complex predicate — the abductive surface
kicks in. The user sees a `sorry` placeholder named
after the needed instantiation:

```lean
-- adsmt_h_quant_1 : ∀ x ∈ xs, x > 0  -- accepted as hypothesis
```

The user either re-checks their hypothesis or replaces
the `sorry` with a tactic that discharges the named
obligation.

== Take-aways

1. Quantifier handling is *heuristic*. Trust verdicts
   in the QF fragments; treat quantified verdicts as
   "yes-most-of-the-time".
2. *Triggers* are the most important user-controllable
   variable. Pick them deliberately when E-matching
   exhausts.
3. The *abductive escape* (chapter 8) is adsmt's
   answer to "but what if I really need a verdict?":
   instead of giving up, the solver hands you a
   hypothesis menu.
