= The Abductive Layer

== Abduction vs. deduction

Classical SMT is purely *deductive*: given a formula $phi$,
answer "is $phi$ satisfiable?" The answer is a verdict —
Sat, Unsat, or Unknown — possibly with a witness model or
unsat core attached.

*Abduction* is the dual question. Given a formula $phi$
that the solver *cannot* discharge, what additional
hypothesis $H$ would make $phi$ provable? Concretely, find
a minimal $H$ such that $H union phi$ is unsat (when $phi$
states a goal's negation) or $H union phi'$ is sat (when
$phi'$ states the goal directly).

```rust
pub struct AbductiveCandidate {
    pub hypothesis: Vec<Term>,
    pub justification: Justification,
    pub rank: Rank,
}
pub enum Justification {
    SldChain(Vec<HornStep>),
    TheoryGap { theory: TheoryName, missing: Term },
    QuantifierExhausted { var: Arc<Var>, body: Term },
}
```

For SMT-as-proof-assistant — the use case adsmt is built
around — abductive candidates are the most actionable
output a solver can produce. The user (or an ITP tactic)
isn't asking "is this true?" — they're asking "what do I
need to assume to make my proof go through?" The Tier 4
escalation we saw in chapter 7 surfaces those candidates
directly.

== Horn rules and SLD chains

The cleanest setting for abduction is *Horn clauses* —
clauses with at most one positive literal. A Horn rule
$p_1 and p_2 and dots and p_n -> q$ says "if the $p_i$
hold, then $q$ holds." A *fact* is a Horn rule with $n = 0$:
just $q$.

Given a Horn rule base $R$ and a goal $G$, an *SLD chain*
is a finite sequence of backward-chaining steps that
reduces $G$ to atomic sub-goals not unifiable with any
rule's head. Those leftover sub-goals are the *abductive
hypothesis*: assume them, and the goal goes through.

```rust
pub fn build_chain(goal: &Term, rules: &[HornRule], depth: usize)
    -> Option<SldChain>
{
    if depth == 0 { return None; }
    for rule in rules {
        if let Some(sigma) = unify(&rule.head, goal) {
            let mut sub_chains = Vec::new();
            let mut residual = Vec::new();
            for body_atom in &rule.body {
                let atom = apply(&sigma, body_atom);
                match build_chain(&atom, rules, depth - 1) {
                    Some(sub) => sub_chains.push(sub),
                    None => residual.push(atom),
                }
            }
            return Some(SldChain {
                steps: vec![HornStep { rule: rule.clone(), sigma }],
                sub_chains,
                residual,
            });
        }
    }
    None
}
```

The residual atoms are what we couldn't unify away. Those
become the abductive hypothesis.

== Minimisation

A first SLD chain is rarely minimal. The naive backward
chainer accumulates every unmatched sub-goal even when some
are redundant — entailed by others, or by background
theory axioms. adsmt's `minimize` pass walks the residual:

```rust
pub fn minimize(residual: &[Term], ctx: &TheoryContext) -> Vec<Term> {
    let mut keep: Vec<Term> = Vec::new();
    for atom in residual {
        if entailed_by(atom, &keep, ctx) { continue; }
        keep.retain(|kept| !entailed_by(kept, &[atom.clone()], ctx));
        keep.push(atom.clone());
    }
    keep
}
```

`entailed_by` consults the active theory context — UF
congruences, arithmetic bounds, BV literal evaluation —
to discharge redundant atoms. The remaining list is a
minimal cover under the active theories.

== Ranking

Multiple distinct minimal hypotheses can discharge the
same goal. `rank` orders the candidates by *user-cost*
proxies — fewer atoms preferred, simpler atoms preferred,
atoms appearing already in scope preferred over fresh
ones:

```rust
pub fn rank(candidates: &mut Vec<AbductiveCandidate>, in_scope: &HashSet<Term>) {
    candidates.sort_by_key(|c| (
        c.hypothesis.len(),
        c.hypothesis.iter().map(term_depth).sum::<usize>(),
        c.hypothesis.iter().filter(|t| !in_scope.contains(*t)).count(),
    ));
}
```

The user sees a ranked list, not a raw set. The Lean4
`smt_abduce` tactic and the LSP code-action menu both
respect this order: the top candidate is the suggested
hypothesis, the rest are alternatives the user can choose
from.

== Workflow integration

Inside the engine's `check_sat` loop, abduction is driven
by *gaps* — points where ground reasoning, theory
combination, or quantifier instantiation produce something
short of a definitive verdict.

```rust
pub enum SatResult {
    Sat(Model),
    Unsat(UnsatCore),
    Abductive { candidates: Vec<AbductiveCandidate> },
    Unknown(UnknownReason),
}

fn abductive_escalation(state: &SolverState) -> Vec<AbductiveCandidate> {
    let mut out = Vec::new();
    if let Some(quant_gap) = state.exhausted_quantifier() {
        out.push(quantifier_to_candidate(quant_gap));
    }
    if let Some(theory_gap) = state.theory_unknown() {
        out.push(theory_gap_to_candidate(theory_gap));
    }
    if !out.is_empty() { return out; }
    let goal = state.current_goal();
    let chains = build_chains_with_horn_base(&goal, state.horn_rules(), MAX_DEPTH);
    chains.into_iter()
        .map(|chain| chain_to_candidate(chain, state.theory_context()))
        .collect()
}
```

The four gap categories — exhausted quantifier, theory
unknown, Horn-chain residual, classical-axiom requirement —
each feed candidates into the same return path. The caller
gets a single homogeneous `AbductiveCandidate` list to
present.

== Tier 4 — promoting candidates to certificates

A user (or ITP tactic) accepts an abductive candidate by
adding its hypothesis atoms to the assertion set. On
re-`check_sat`, those atoms are now ground assumptions,
the chain that produced the candidate completes, and the
solver emits a definite verdict.

The certificate format (chapter 9) records the abductive
acceptance explicitly:

```text
(cert.v1
  (steps
    (step :rule abductive_assume
          :id 17
          :hypothesis ((P a) (Q b))
          :justification (sld_chain ...))
    ...))
```

The downstream ITP — Lean 4, Rocq, or Isabelle — sees this
step as an explicit `sorry`-shaped placeholder: a proof
that's *conditional* on the hypotheses, with the
hypotheses surfaced as obligations the user must
discharge by other means. The reflection layer (chapter
10) renders the certificate as ITP-friendly tactic script
where each `abductive_assume` becomes a named hypothesis
the user can introduce.

== When abduction degrades gracefully

If neither E-matching, theory closure, nor abductive
chaining produces a usable candidate, the solver returns
`Unknown(UnknownReason::AbductiveExhausted)`. This is
strictly more informative than vanilla SMT `unknown`: the
caller knows the abductive layer was tried and ran out
of ideas, not that some up-stream layer hit its budget.

For an interactive theorem prover, "unknown but here are
fifteen candidate hypotheses I tried and discarded" is
itself useful debugging output. The
`UnknownReason::AbductiveExhausted` variant carries the
trial log; the LSP surfaces it as a diagnostic with a
"show abductive trace" code-action.

== Why this matters for SMT-as-tactic

Conventional SMT-as-tactic delivers a binary verdict to
the proof assistant. When it works, great; when it
doesn't, the user has no actionable feedback. Abductive
candidates change the game: even a *failed* discharge
yields concrete hypotheses the user can either accept or
use to refine the goal.

This is what motivates building adsmt at all. The
"deductive verdict only" mode is fine — adsmt does it as
well as any SMT solver — but the *abductive escape* is
why we're building a new solver rather than wrapping an
existing one. Chapter 9 describes the certificate
machinery that makes abductive steps recoverable in
downstream ITPs.
