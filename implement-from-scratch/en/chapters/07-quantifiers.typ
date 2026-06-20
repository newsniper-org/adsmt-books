= Quantifiers

== Why quantifiers are hard

The theories of chapter 6 all assume *ground* atoms — no
universal or existential quantifiers in the formula. Add
quantifiers and the satisfiability problem becomes
undecidable in general: there is no algorithm that, given
an arbitrary first-order formula, always returns the right
answer.

What SMT solvers do instead is *heuristic instantiation*:
when a universal formula $forall x. phi(x)$ has been
asserted and the rest of the formula has produced concrete
ground terms, plug those ground terms into $phi(x)$ as
candidate instantiations and add them as ground atoms.
This makes the inner solver loop's job: it sees not the
original quantified formula but a growing pile of
instantiations. The question of *which* terms to
substitute, in what order, becomes the heart of the
problem.

== E-matching

The dominant technique is *E-matching*. The idea: the
formula $forall x. phi(x)$ comes annotated with a
*trigger* — a sub-pattern of $phi$ containing the bound
variable $x$. When the ground portion of the formula
produces a term that matches the trigger (modulo equality
reasoning), instantiate $x$ to the matching sub-term.

For instance, given $forall x. f(g(x)) > 0$ with trigger
$f(g(x))$, and a ground term $f(g(a))$ already in scope,
instantiate $x := a$. The instantiated atom $f(g(a)) > 0$
joins the SAT/theory layer.

```rust
pub struct Trigger {
    pub kind: TriggerKind,
    pub bound: Vec<Arc<Var>>,
}
pub enum TriggerKind {
    Single(Term),
    Multi(Vec<Term>),
}
```

The matcher walks the *term universe* — the set of ground
sub-terms appearing in the formula — looking for matches.
A single-pattern trigger matches a universe term when the
pattern's rigid parts (constants and bound vars not in the
trigger's flex set) agree and the flex parts pick up
substitutions.

```rust
fn match_one(pattern: &Term, target: &Term, bound: &[Arc<Var>])
    -> Option<Vec<(Arc<Var>, Term)>>
{
    let mut sigma = IndexMap::new();
    if extend_match(pattern, target, bound, &mut sigma) {
        Some(sigma.into_iter().collect())
    } else { None }
}
```

== Miller patterns

A *Miller pattern* is a trigger pattern where every flex
sub-application has the form $F(x_1, dots, x_n)$ with the
$x_i$ distinct bound variables. Miller patterns admit a
linear-time matching algorithm without higher-order
unification's pathologies. adsmt defaults to Miller
patterns and exposes a `:trigger!` escape for non-Miller
patterns that the user has reason to want anyway.

== Tier escalation

E-matching can fail to find any instantiation: the
universe might not contain any term shaped like the
trigger. adsmt escalates through a series of *tiers*,
each more aggressive than the previous:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Tier*], [*Strategy*]),
  [1], [Miller E-matching against the term universe.],
  [2], [Conflict-driven instantiation — pick instantiations that contradict an existing ground assertion.],
  [3], [Bounded enumeration — enumerate candidate sub-terms up to a depth budget.],
  [4], [Abductive escalation — emit the quantified formula as an abductive candidate hypothesis (chapter 8).],
)

```rust
pub fn instantiate_with_tier(var, body, universe) -> (Vec<Term>, Tier) {
    let res = instantiate_one(var, body, universe);
    if !res.is_empty() {
        return (res, Tier::One);
    }
    let res = enumerate(var, body, universe, DEFAULT_TIER3_BUDGET);
    if !res.is_empty() {
        return (res, Tier::Three);
    }
    (Vec::new(), Tier::Exhausted)
}
```

Tier 2 (conflict-based) and Tier 4 (abductive) require
information from neighbouring layers; we cover Tier 4 in
chapter 8.

== Trigger learning

Hand-picked triggers are the user's responsibility, but
when none are given, adsmt's `learn_triggers` helper picks
a covering set automatically. The algorithm walks the
body's application sub-terms in depth order and greedily
selects the smallest patterns that cover every flex
variable:

```rust
pub fn learn_triggers(body: &Term, flex: &[Arc<Var>]) -> Option<Trigger> {
    let mut candidates = Vec::new();
    collect_apps(body, &mut candidates);
    candidates.sort_by_key(term_depth);
    let mut covered = HashSet::new();
    let mut selected = Vec::new();
    for cand in candidates {
        let cand_flex = flex_vars_in(&cand, flex);
        if cand_flex.iter().all(|v| covered.contains(v)) { continue; }
        for v in &cand_flex { covered.insert(v.clone()); }
        selected.push(cand);
        if covered.len() == flex.len() { break; }
    }
    if covered.len() != flex.len() { return None; }
    if selected.len() == 1 {
        Some(Trigger::single(selected.pop().unwrap(), flex.to_vec()))
    } else {
        Some(Trigger::multi(selected, flex.to_vec()))
    }
}
```

The cover ensures that any successful E-match
instantiates every flex variable. The greedy depth order
is a heuristic that tends to pick small, frequently-
matching patterns first.

== The E-graph

The pure E-matcher walks a flat `TermUniverse`. A more
sophisticated alternative — the *E-graph* — maintains a
hash-consed term store augmented with congruence closure,
exposing not just the explicit universe terms but every
*derived congruent* term as well.

```rust
pub struct EGraph {
    nodes: Vec<ENode>,
    parent: Vec<ENodeId>,
    class_parents: HashMap<ENodeId, Vec<ENodeId>>,
    hash_cons: HashMap<ENodeKey, ENodeId>,
    scope_stack: Vec<EGraphSnapshot>,
}
```

`add` lowers a term into the graph and returns its class
id. `merge` unifies two classes and cascades the congruence
closure — when two parent E-nodes' children become
equivalent, the parents are also merged. `as_universe`
projects the graph back into a flat `TermUniverse` for
consumption by the E-matcher.

The e-graph integration buys completeness: if congruence-
closing the e-graph would produce a trigger match that
the flat universe missed, the e-graph catches it.

In adsmt, the vendored OxiZ backend makes this
congruence-aware matching its _default_, realized as one
unified core called _CCFV_ — congruence closure with free
variables, after Barbosa–Fontaine–Reynolds' E-ground
(dis)unification. A trigger is matched _modulo_ the ground
congruence: a pattern $f(g(x))$ fires against a ground term
$f(c)$ whenever $c$ and $g(a)$ are congruent, precisely the
match a syntactic walk over the flat universe drops. For a
model-completion engine — one that may answer `sat` by
building a model — this is not only a completeness gain but
a _soundness_ requirement: missing such a congruence match
lets the engine certify a congruence-blind model as `sat`
on a problem that is in fact `unsat`. The same CCFV core
also expresses conflict-driven instantiation and the
model-completion search, differing only in the constraint
it solves and whether it reads the real congruence or a
default-extended total view.

== Quantifier instantiation in the engine loop

The engine's `check_sat` loop runs quantifier instantiation
between successive ground-fragment checks:

```rust
const QUANTIFIER_ROUNDS: usize = 3;
let mut instantiations: Vec<Term> = Vec::new();
for round in 0..QUANTIFIER_ROUNDS {
    let mut combined = self.all_literals();
    for inst in &instantiations { combined.push((inst.clone(), true)); }
    match self.check_ground(&combined) {
        SatResult::Sat => {
            let (quants, rest) = partition_quantifiers(&combined);
            if quants.is_empty() { return SatResult::Sat; }
            let universe = collect_universe(&rest);
            for (var, body) in &quants {
                for inst in instantiate_one(var, body, &universe) {
                    if !instantiations.iter().any(|t| t.alpha_eq(&inst)) {
                        instantiations.push(inst);
                    }
                }
                // Tier 2 and Tier 3 fallback...
            }
            if instantiations.len() == prev_len { return SatResult::Sat; }
        }
        other => return other,
    }
}
// Tier 4 — abductive escalation
return SatResult::Abductive { candidates: build_tier4_candidates(...) };
```

Each round may add new instantiations; the loop continues
until either a definite verdict emerges, no new
instantiations appear (Sat), or the round budget is
exhausted (Tier 4 abductive escalation).

== Why this is "best-effort"

E-matching with tier escalation is a *heuristic*. It can
fail to find an instantiation that would discharge a
formula even when one exists. SMT solvers in general
accept this trade: the alternative — complete handling of
quantifiers — is either incompatible with theory
combination or so expensive as to be unusable.

What adsmt adds is the Tier 4 escape: when every term-level
heuristic exhausts, the quantifier becomes an *abductive
candidate*. The user sees not "unknown" but "I could solve
this if you accepted this hypothesis." That hypothesis is
the bare existence of some specific witness; accepting it
makes the proof go through, and the user (or downstream
ITP) gets to decide whether the assumption is appropriate.

We turn to that abductive layer next.
