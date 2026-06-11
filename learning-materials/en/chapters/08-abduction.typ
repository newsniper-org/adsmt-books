= Abduction

== Deduction, induction, abduction

Philosophy of science classifies inference into three
modes, often credited to Charles Sanders Peirce:

- *Deduction.* Given a rule and a premise, derive the
  conclusion. "All ravens are black. This is a raven.
  Therefore it's black." Sound and certain.
- *Induction.* Given many cases of a pattern, generalise.
  "Every raven I've seen is black. So all ravens are
  black." Defeasible; the next case might break it.
- *Abduction.* Given an observation, posit a hypothesis
  that would explain it. "This raven is white. Maybe it's
  an albino." Speculative; multiple hypotheses might
  fit.

Standard SMT is purely *deductive*: given a formula,
deduce sat or unsat. *Abductive SMT* — adsmt's
distinguishing feature — adds the third mode.

== The abductive question

Standard SMT asks: *"is $phi$ true?"*

Abductive SMT asks: *"what hypothesis $H$ would make
$phi$ true (or, equivalently, $not phi$ false)?"*

Practically, $H$ is the minimal set of additional
assumptions the user would need to accept for the
solver to discharge the original goal. The user
inspects $H$ and decides whether the assumptions are
reasonable for their domain.

== Why this matters for proof assistants

In an ITP context, the typical interaction is:

1. User writes a proof. Hits a sub-goal.
2. User invokes the SMT tactic. SMT either discharges
   the sub-goal or returns "unknown".
3. On "unknown", the user is stuck — they have to guess
   what extra hypothesis would help.

Abductive SMT changes step 3:

3'. On *abductive*, SMT returns a *ranked list of
    candidate hypotheses*. The user picks one and adds
    it as an assumption (or proves it separately).

The difference is qualitative: instead of "the solver
gave up", the user sees "here are five specific things
the solver thinks would help, ranked by your-cost
proxy."

== A worked example

A Lean 4 user has the goal:

```lean
example (n : Nat) : f n ≤ g n := by
  smt_abduce
```

`smt_abduce` invokes adsmt in abductive mode. The
ground reasoning (we have no facts about $f$ or $g$)
exhausts immediately, so adsmt escalates:

```text
abductive-candidates:
  (candidate :rank 1 :hypothesis ((∀ n, f n ≤ n) (∀ n, n ≤ g n))
             :justification (sld_chain via Trans.trans))
  (candidate :rank 2 :hypothesis ((∀ n, f n ≤ g n))
             :justification (quantifier_exhausted))
  (candidate :rank 3 :hypothesis ((∀ n, f n = n) (∀ n, n = g n))
             :justification (sld_chain via Eq.subst))
```

The Lean 4 tactic surfaces these as named placeholders:

```lean
example (n : Nat) : f n ≤ g n := by
  have h1 : ∀ n, f n ≤ n := by sorry  -- candidate 1
  have h2 : ∀ n, n ≤ g n := by sorry  -- candidate 1
  exact Nat.le_trans (h1 n) (h2 n)
```

The user discharges the `sorry`s if the hypotheses are
true in their context, or refines the goal if the
candidates aren't acceptable.

== How adsmt finds candidates

Three sources, each surfaced at the engine boundary
(companion ch. 8):

1. *SLD chains over Horn rules.* The user's knowledge
   base (asserted facts + rules in `.kb` form) is
   walked backwards from the goal. Each rule whose
   head unifies with the goal generates a sub-chain;
   sub-chains whose residuals aren't ground become
   candidate hypotheses.

2. *Theory gaps.* When a theory solver returns
   "unknown" with a specific shape ("I'd need to know
   $i eq.not j$ to decide this select/store"), the gap
   becomes a candidate.

3. *Quantifier exhaustion.* When the tier-1-2-3
   instantiation pipeline runs out, the quantifier
   itself becomes a candidate — promote it as a
   hypothesis the user might accept.

The three sources are merged into one ranked list
before returning to the caller.

== Ranking

Multiple candidates often discharge the same goal. adsmt
ranks them by a user-cost proxy:

- Fewer atoms preferred.
- Smaller (lower-depth) atoms preferred.
- Already-in-scope atoms preferred over fresh ones.

The user sees the top candidate at the front of the list
and can scan further if the top isn't right.

== Minimality

A first cut at "hypotheses that would discharge the
goal" usually accumulates redundancy. If $H_1 = \{P,
Q\}$ discharges and $H_2 = \{P\}$ also discharges (with
$P$ alone), the latter is preferred. adsmt's
`minimize` pass walks each candidate, dropping atoms
implied by the rest of the candidate (modulo theory
context).

The result is a *theory-minimal* candidate set: no
proper subset of any returned candidate discharges.

== Trust

Abductive candidates are *hypotheses*, not proofs.
The user takes responsibility for whether the
hypothesis is true. The certificate records the
abductive step explicitly (chapter 9), so the
downstream ITP sees:

```text
(step :rule abductive_assume
      :id 17
      :hypothesis ((P a) (Q b))
      :justification (sld_chain ...))
```

The ITP renders this as `sorry`-shaped placeholders.
There's no risk that the abductive layer silently
introduces unsoundness — every accepted hypothesis is
*visible* as an obligation.

== When abduction misbehaves

Abduction has its own failure modes:

- *No candidates.* The user's knowledge base is too
  sparse — the SLD chain finds no rule whose head
  unifies with the goal. Verdict
  `unknown(AbductiveExhausted)`. The user enriches
  the knowledge base or simplifies the goal.
- *Too many candidates.* Hundreds of candidates after
  ranking. The user's domain probably has structure
  the solver doesn't know about. Suggest manually
  tightening the assertions.
- *Bad ranking.* The "correct" candidate is third in
  the list, not first. adsmt's rank heuristic is
  user-cost-style; if your domain disagrees, file
  custom rank weights via the LSP / CLI options.

== Where abduction shines

The flagship use cases:

- *Interactive proof.* The user iterates between adsmt
  and their proof script, accepting candidates as
  obligations they then discharge by tactics.
- *Specification refinement.* "Why is my spec
  inconsistent?" Abductive candidates show what
  hypothesis you'd need to add to *recover*
  satisfiability, hinting at what assumption you're
  missing.
- *Theory exploration.* Given a few axioms, what
  consequences can you state and have the solver
  abduce missing facts for? A sort of automated
  conjecture-generation.

== The bigger claim

adsmt's claim isn't that abductive SMT replaces
deductive SMT — it doesn't. The claim is that
*deductive SMT's "unknown" verdict is impoverished*,
and a solver designed to serve a proof assistant
should give the user something more actionable. The
abductive layer is that something.

Chapter 9 covers the certificate machinery that makes
abductive steps recoverable on the ITP side. Chapter 10
walks through the integration end-to-end.
