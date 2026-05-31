= Theory combination

== The combination problem

Consider an SMT formula that mixes arithmetic and array
operations:

$ a[i] + a[j] > 0 and a[i] = -a[j] and i != j $

Neither a pure arithmetic solver nor a pure array solver
can decide this on its own. The arithmetic solver does not
know how to interpret `a[i]` — it sees opaque variables.
The array solver does not know how to interpret `+` — it
can deduce things like *if `i = j` then `a[i] = a[j]`*, but
not what either side sums to. To decide formulas of this
shape we need the two solvers to *cooperate*: each shares
the information it learns about *shared variables* with
the other, until either a contradiction emerges or a
combined model exists.

This is the *theory combination* problem. The classical
solution is *Nelson-Oppen* combination, applicable when the
theories involved are *stably infinite* and have disjoint
signatures. adsmt uses a generalisation called *polite
combination* which removes the disjoint-signature
requirement in exchange for slightly more machinery.

== Nelson-Oppen at a glance

The Nelson-Oppen protocol runs the participating theory
solvers in lock-step. The shared variables are the
variables appearing in atoms processed by more than one
theory. Each theory:

#enum(numbering: "(1)",
  [Receives every asserted atom it can interpret,],
  [Reports any equalities between shared variables that it
   has derived,],
  [Receives the union of all equalities derived by the
   other theories,],
  [Repeats until either (a) it derives `false`
   (unsatisfiable) or (b) no new equalities surface
   (satisfiable in combination).],
)

The protocol's correctness rests on the stably-infinite
condition: every model of each theory, in isolation, can
be extended to have infinitely many elements at each sort.
If both theories produce only finite models, additional
cardinality reasoning is required.

== Polite combination

Polite combination drops the disjoint-signature requirement
and handles cardinality reasoning explicitly. Each theory
exposes a *politeness witness* describing, per sort, what
upper bound (if any) it places on the cardinality of
models. A `BV<8>` sort, for instance, has cardinality at
most $2^8 = 256$; an `Int` sort is $omega$; the
combination machinery picks the *infimum* across all
participating theories and asserts that the combined model
has at most that many elements at that sort.

Concretely each theory implements:

```rust
pub trait Theory: Send {
    fn name(&self) -> &'static str;
    fn handles_sort(&self, ty: &Type) -> bool;
    fn assert(&mut self, lit: Literal) -> AssertResult;
    fn check(&mut self) -> CheckResult;
    fn explain(&self) -> Option<TheoryWitness>;
    fn derive_equalities(&self) -> Vec<(Term, Term)>;
    fn derive_disequalities(&self) -> Vec<(Term, Term)>;
    fn cardinality_witness(&self, sort: &Type) -> PoliteWitness;
    fn push(&mut self);
    fn pop(&mut self, levels: u32);
    fn reset(&mut self);
}
```

The combination orchestrator (`adsmt-theory::polite::Combination`)
owns a `Vec<Box<dyn Theory>>` and drives the protocol:

```rust
pub fn check(&mut self) -> CombinedCheck {
    loop {
        // 1. Per-theory check.
        for t in &mut self.theories {
            match t.check() {
                CheckResult::Unsat { witness } => return Unsat { ... },
                CheckResult::Unknown { reason } => return Unknown { ... },
                CheckResult::Sat => continue,
            }
        }
        // 2. Gather derived equalities.
        let new_eqs = self.gather_derived_equalities();
        if new_eqs.is_empty() {
            // 3. Cardinality enforcement.
            if let Some(unsat) = self.enforce_cardinality() {
                return unsat;
            }
            return Sat;
        }
        // 4. Re-broadcast new equalities.
        for (a, b) in new_eqs { self.assert(Literal::positive(mk_eq(a, b))?); }
    }
}
```

The loop converges because each round either reduces the
number of distinct equivalence classes or produces no new
information.

== Cardinality enforcement

For each sort $sigma$ where the combined witness puts a
finite cardinality bound $n$, the orchestrator gathers the
disequalities asserted at $sigma$ and computes the maximum
clique in the disequality graph. If the clique size
exceeds $n$, the combined model has too many elements at
$sigma$ — contradiction.

```rust
fn enforce_cardinality(&self) -> Option<CombinedCheck> {
    let diseqs_by_sort = self.gather_disequalities_by_sort();
    for (sort, pairs) in &diseqs_by_sort {
        let bound = self.cardinality_bound(sort);
        let Some(bound) = bound else { continue; };
        let clique = max_disequality_clique(pairs, bound + 1);
        if clique > bound {
            return Some(CombinedCheck::Unsat { /* polite witness */ });
        }
    }
    None
}
```

`max_disequality_clique` is bounded clique enumeration with
early exit when the running maximum exceeds the bound — a
small enough search space in practice that brute force
suffices.

== Routing literals to theories

Not every literal is relevant to every theory. The
combination decides which theory should see which literal
by inspecting the operand sort: an equality literal `(= a
b)` is routed to every theory that handles `a.type_of()`.
A non-equality literal (a theory-specific predicate, say
`(> x y)`) goes to the theory that owns that predicate.

```rust
pub fn assert(&mut self, lit: Literal) -> Vec<(String, AssertResult)> {
    let routing_sort = if let Some((a, _)) = lit.term.dest_eq() {
        a.type_of()
    } else {
        lit.term.type_of()
    };
    let mut out = Vec::new();
    for t in &mut self.theories {
        if t.handles_sort(&routing_sort) {
            out.push((t.name().to_string(), t.assert(lit.clone())));
        }
    }
    out
}
```

A conflict at any theory short-circuits the broadcast and
returns immediately — adsmt landed this optimisation
explicitly because the original draft happily continued
asserting to every theory even after one had reported
infeasibility.

== Push and pop

The SAT layer drives decisions and backtracks; each
assertion may need to be undone when the SAT layer
backtracks past the decision that introduced it. The
combination supports `push` / `pop` operations that
broadcast the same to every theory:

```rust
pub fn push(&mut self) {
    for t in &mut self.theories { t.push(); }
}
pub fn pop(&mut self, levels: u32) {
    for t in &mut self.theories { t.pop(levels); }
}
```

Each theory implements its own snapshot scheme. UF, for
instance, snapshots the union-find structure; LIA snapshots
the bound table; arrays snapshots the local disequalities
table and the pending-extensionality queue. The pattern is
uniform: each theory owns a `scope_stack` of snapshots and
restores on `pop`.

== Engine-side routing

In `adsmt-engine` the function `dpllt::run_once` drives a
single iteration: literals → assert into combination →
combination check. The eager-conflict short-circuit is
visible in the loop:

```rust
pub fn run_once(combo: &mut Combination, literals: &[(Term, bool)]) -> LoopOutcome {
    for (atom, polarity) in literals {
        let lit = build_lit(atom, *polarity);
        for (name, r) in combo.assert(lit) {
            if let AssertResult::Conflict { witness } = r {
                return LoopOutcome::Unsat { theory: name, witness };
            }
        }
    }
    match combo.check() {
        CombinedCheck::Sat => LoopOutcome::Sat,
        CombinedCheck::Unsat { theory, witness } => LoopOutcome::Unsat { theory, witness },
        CombinedCheck::Unknown { theory, reason } => LoopOutcome::Unknown { theory, reason },
    }
}
```

This is the level at which the SAT and theory layers
communicate. The SAT layer gives `run_once` a list of
literals consistent with its current trail; `run_once`
reports back whether the theories agree, and if not, which
witness they produced.

== An optional addition — EGraph

adsmt's `adsmt-theory::egraph_theory` wraps an EUF e-graph
inside the `Theory` trait. The e-graph maintains a
hash-consed term universe and a union-find structure
augmented with *congruence closure*: whenever two function
applications $f(a)$ and $f(b)$ are observed with $a$ and
$b$ in the same equivalence class, the wrapper merges
$f(a)$ and $f(b)$ as well. The cascade fires until a
fixpoint, producing congruence-closed equalities that are
exposed via `derive_equalities`.

This is *additive* — both UF and EGraph can be registered
side by side. EGraph contributes congruent function
applications that UF only notices on direct
literal-pair input.

== Summary

Theory combination is the layer that distinguishes SMT
solvers from SAT solvers. The protocol — polite or
Nelson-Oppen — is a well-defined cooperative algorithm
across solver components, and each component is small and
auditable. The next chapter walks through the individual
theory solvers.
