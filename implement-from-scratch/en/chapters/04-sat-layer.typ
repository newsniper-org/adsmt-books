= The SAT layer

== Architecture

The SAT layer's job is to find a satisfying assignment for
a propositional CNF formula, or to prove no such assignment
exists. The contract with the rest of the solver is narrow:
in goes a `Vec<Clause>` where each clause is a
`Vec<(atom, polarity)>`, out comes one of three verdicts —
`Sat`, `Unsat`, or `Unknown` — and on the `Sat` path the
satisfying assignment is available for theory-side
verification.

adsmt ships three SAT backends: OxiZ (a Pure-Rust CDCL
solver, the default), CaDiCaL (a C++ CDCL solver behind an
FFI), and a built-in fallback in `adsmt-engine::cdcl`. The
fallback exists so the no-feature-flag build is
self-contained; production builds use OxiZ. This chapter
walks through what the built-in CDCL implementation does;
the same architecture applies to either external backend.

== The CDCL algorithm at a glance

Conflict-Driven Clause Learning sits on top of
backtracking-based propositional search. The basic loop:

#enum(numbering: "(1)",
  [Propagate the current partial assignment until no further
   unit-clause-driven assignments are possible.],
  [If propagation produced a conflict (some clause is now
   falsified), perform conflict analysis: walk back through
   the implication graph to find a *learnt clause*
   that captures the reason for the conflict. Add the learnt
   clause to the formula; backjump to a level where it
   propagates.],
  [Otherwise, if every variable is assigned, return `Sat`.],
  [Otherwise pick a decision variable (a heuristic chooses
   which one), assign it, and loop.],
)

The two essential components are *propagation* (step 1) and
*conflict analysis* (step 2). The decision heuristic (step
4) and restart policy are second-order optimisations that
have outsized impact on solver performance in practice.

== Two-watched literals

A naive propagator iterates over every clause on every
assignment, checking whether it is now unit. With $n$
clauses and an average of $k$ literals each, this costs
$O(n k)$ per assignment. The two-watched-literals scheme
reduces the amortised cost dramatically.

The observation: a clause is unit only when all but one of
its literals are assigned false. So we need to inspect a
clause only when one of its currently-watched literals
becomes false. Pick two arbitrary literals per clause as
"watched"; maintain an inverted index from each literal to
the clauses watching it; on each new assignment, examine
only the clauses watching its negation.

When examining such a clause we either:
- find another non-false literal to watch (cost: $O(k)$
  scan of the clause's literals);
- find that the other watched literal is satisfied (the
  clause is fine; skip);
- find that the other watched literal is unassigned (the
  clause is unit; propagate);
- find that the other watched literal is false (conflict).

The data structure is simple:

```rust
pub struct CdclState {
    pub trail: Vec<TrailEntry>,
    pub assign: HashMap<String, bool>,
    pub clause_watches: Vec<[usize; 2]>,
    pub watches: HashMap<(String, bool), Vec<usize>>,
    pub prop_head: usize,
    // … learnt-clause storage, activity tables, etc.
}
```

The `prop_head` cursor advances through the trail one
literal at a time; for each new trail entry we look up its
*negation* in `watches` and examine those clauses only.

== Conflict analysis — 1-UIP

When a clause is falsified the propagator returns its
index. Conflict analysis walks back through the implication
graph (the trail, with each entry's `reason` pointing at
the clause that propagated it) to find a *learnt clause*
that, if it had been present from the start, would have
prevented this conflict.

The standard algorithm — "1-UIP" — produces the learnt
clause by resolving the conflict clause against the
antecedents of its current-decision-level literals until
exactly one literal at the current decision level remains.
That single literal is the *first unique implication point*;
the resulting clause is the learnt clause, and the maximum
decision level among the *other* literals is the *backjump
level* — the level we should roll back to.

In code (sketch):

```rust
fn analyze_1uip(clauses, state, conflict_idx) -> (Vec<Lit>, u32) {
    let current = state.decision_level;
    let mut seen = HashSet::new();
    let mut learnt = Vec::new();
    let mut count_current = 0;
    // Seed from the conflict clause.
    for lit in &clauses[conflict_idx] {
        process(lit, ...);
    }
    // Walk the trail backwards, resolving each current-level
    // seen literal against its antecedent.
    let mut idx = state.trail.len();
    while count_current > 1 {
        idx -= 1;
        // ...
    }
    // Recover the UIP and the backjump level.
    // ...
}
```

The full implementation is about 100 lines in adsmt's
`cdcl.rs`; it is mechanical once you have the trail
infrastructure in place.

== VSIDS — variable activity

The decision heuristic that has dominated CDCL since the
Chaff solver of 2001 is *VSIDS* — variable state
independent decaying sum. Each atom carries an activity
score; every conflict bumps the activities of the atoms in
the learnt clause; periodically every score is multiplied
by a decay factor (typically 0.95) so recent bumps
dominate stale ones.

```rust
pub fn bump_activity(&mut self, clause: &Clause, bump: f64) {
    for lit in clause {
        *self.activity.entry(atom_key(lit)).or_insert(0.0) += bump;
    }
}
pub fn decay_activity(&mut self, factor: f64) {
    for v in self.activity.values_mut() { *v *= factor; }
}
```

The decision picker walks the open clauses and picks the
unassigned atom with the highest activity. With the bump
+ decay cycle this becomes a strong proxy for "which atom
is involved in the conflicts I am hitting now?".

== Restarts and Luby

CDCL benefits from periodic restarts — forgetting the
current decision history and starting search from the
top-level facts. The schedule matters: pure geometric
restarts (every $2^k$ conflicts) underperform a sequence
that revisits short-budget epochs. The *Luby sequence* —
$1, 1, 2, 1, 1, 2, 4, 1, 1, 2, 1, 1, 2, 4, 8, dots$ —
empirically wins on randomised SAT instances.

The Luby iteration is Knuth's reluctant-doubling formula
and fits in ten lines:

```rust
fn luby_index(i: usize) -> usize {
    let mut u = 1usize;
    let mut v = 1usize;
    for _ in 0..i {
        if (u & u.wrapping_neg()) == v { u += 1; v = 1; }
        else { v *= 2; }
    }
    v
}
```

The outer CDCL loop then calls
`cdcl_solve(clauses, base_conflicts * luby_index(epoch))`
for `epoch = 0, 1, 2, ...` until a definite verdict
emerges or the restart budget exhausts.

== Learnt clause management

Storing every learnt clause forever blows up memory and
slows propagation. The standard remedy: periodically delete
the *least useful* learnt clauses. "Useful" is measured by
a per-clause activity score (bumped every time the
propagator uses the clause as a unit antecedent) and by
*LBD* (Literal Block Distance): the number of distinct
decision levels among the clause's literals at the moment
it was learnt. Low-LBD clauses ("glue clauses", LBD ≤ 6)
are protected from deletion; the rest are subject to
periodic culling.

```rust
fn reduce_learnt(state, owned, input_len, threshold) {
    // Keep glue clauses unconditionally.
    let mut candidates: Vec<_> = state.learnt_activity.iter()
        .enumerate()
        .filter(|(i, _)| state.learnt_lbd[*i] > 6)
        .collect();
    candidates.sort_by(|a, b| a.1.partial_cmp(b.1).unwrap());
    // Drop the lowest-activity half.
    // ...
}
```

== Putting it together

A CDCL solver fits in about 800 lines including all of the
machinery above. adsmt's `cdcl.rs` is roughly this size,
and a careful reader can step through its main loop in
under an hour. The discipline that matters most is
*trail-based propagation with explicit reason tagging*:
once the trail and reason structure is right, every other
piece slots in.

The next chapter pivots to theory combination — the layer
above SAT that lets multiple specialised theory solvers
cooperate over shared sorts.
