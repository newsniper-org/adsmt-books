= Arithmetic

== Two arithmetic theories

SMT-LIB distinguishes:

- *LIA* (linear integer arithmetic) — integer variables,
  constraints built from $+$, $-$, $*$ by a constant,
  $<$, $<=$, $=$, $>$, $>=$.
- *LRA* (linear real arithmetic) — same shape, but
  variables range over the reals.

What's *not* in either: nonlinear multiplication
(`x * y`), division (`x / y`), modular arithmetic
(except as a bit-vector encoding). Those belong to
NLA / NRA, which are harder fragments.

== Linear constraints

A *linear constraint* has the form

$ a_1 x_1 + a_2 x_2 + dots + a_n x_n thick op thick c $

where the $a_i$ and $c$ are constants and $op in {< , <=
, =, >=, >, !=}$. Variables can be reals or integers
depending on the theory.

```text
; LIA
(declare-const x Int)
(declare-const y Int)
(assert (<= (+ x y) 10))
(assert (>= x 3))
(assert (>= y 4))

; LRA
(declare-const a Real)
(assert (<= a 2.5))
(assert (>= a 1.5))
```

Both fragments are decidable. LRA quantifier-free is in
P (polynomial time); LIA quantifier-free is NP-complete.

== The decision procedure: Simplex

For LRA, the workhorse is the *Simplex method* — borrowed
from linear programming. Constraints are written as
inequalities over a tableau; pivoting steps move toward
either a feasible point or a Farkas-witness of
infeasibility.

```text
     | x  y | constant
-----|------|---------
 s1  | 1  1 | s1 ≤ 10
 s2  | 1  0 | s2 ≥ 3
 s3  | 0  1 | s3 ≥ 4
```

The Simplex iteratively pivots the tableau, maintaining
basic-feasibility, until either every constraint is
satisfied (sat) or a row witnesses no feasible solution
(unsat).

For LIA, Simplex finds a *rational* solution; if the
solution happens to have integer coordinates, done.
Otherwise *branch-and-bound* introduces extra
constraints — "$x <= 3$ or $x >= 4$" — and recurses.

adsmt's `adsmt-theory::lia` and `::lra` use a layered
approach: cheap *bounds propagation* first (every
variable has interval bounds; tightening interval-of-
interest is fast and frequently sufficient), Simplex
afterwards if bounds alone don't decide.

== Bounds-only fast path

Many real LIA problems are decidable by bounds alone:

```text
(assert (<= x 10))
(assert (>= x 5))
(assert (= y (+ x 3)))
(assert (>= y 15))
```

Bounds say $5 <= x <= 10$, so $8 <= y <= 13$. The
constraint $y >= 15$ contradicts the upper bound 13.
Decided without ever invoking Simplex.

```rust
pub struct LiaSolver {
    bounds: HashMap<VarId, Interval>,
    asserted: Vec<LinConstraint>,
    simplex: Option<SimplexState>,
}

impl LiaSolver {
    fn check(&mut self) -> SatVerdict {
        if let Some(c) = self.bound_propagate() {
            return SatVerdict::Unsat(c);
        }
        // Bounds didn't decide. Build Simplex.
        let simplex = self.build_simplex();
        match simplex.solve() {
            SimplexResult::Feasible(m) => SatVerdict::Sat(m),
            SimplexResult::Infeasible(farkas) => SatVerdict::Unsat(farkas),
        }
    }
}
```

The Simplex falls back only when bounds aren't enough.
For interactive use this is a big win — most goals get
decided in microseconds.

== Quantified arithmetic — Presburger

*Quantified* LIA — Presburger arithmetic — is decidable
but very expensive. The standard decision procedure is
*Cooper's algorithm* (or refinements like Omega), with
triple-exponential worst case.

adsmt doesn't ship a complete Presburger decision
procedure. For quantified LIA goals, the engine
heuristically instantiates and falls through to the
abductive layer if instantiation exhausts. This means
some Presburger-true formulas get verdict `abductive`
rather than `unsat`; the user accepts the abductive
hypothesis or falls back to a dedicated Presburger
tactic.

== Common patterns

*Loop bounds.* "$0 <= i <= n$" in a verification context.
LIA handles this directly. Combining with array indexing
(`select A i`) requires Arrays + LIA combination
(chapter 6).

*Real-valued constraints in control theory.* "the
controller must keep $y$ within $[0, 1]$". LRA's Simplex
is the natural fit.

*Modular arithmetic.* SMT-LIB doesn't have a
"modular arithmetic" theory directly. Encode via
bit-vectors (chapter 6) or via auxiliary integer
variables with a divisibility constraint.

== Subtleties

*Strict vs. non-strict.* Simplex naturally handles
non-strict inequalities ($<=$, $>=$). Strict ones ($<$,
$>$) require *delta-perturbation* — introduce an
infinitesimal $delta > 0$ and treat $x < c$ as $x <=
c - delta$. Decisions don't depend on the specific
$delta$.

*Coefficient blow-up.* Repeated Simplex pivots can
produce coefficients that grow large. adsmt uses
arbitrary-precision rationals throughout the arithmetic
modules; the cost is modest and the correctness is
worth it.

*Integer infeasibility.* LIA via Simplex + branch-and-
bound can take exponential time on adversarial inputs
(see "Pigeonhole" benchmarks). For well-conditioned
real-world inputs the worst case is rarely hit.

== Worked example

Constraint: prove that there's no integer triple $(x, y,
z)$ with $x + 2y + 3z = 10$, $x >= 5$, $y >= 3$, $z >=
2$.

```text
(declare-const x Int)
(declare-const y Int)
(declare-const z Int)
(assert (= (+ x (* 2 y) (* 3 z)) 10))
(assert (>= x 5))
(assert (>= y 3))
(assert (>= z 2))
(check-sat) ;; unsat
```

The LIA solver: bounds give $x >= 5$, $y >= 3$, $z >=
2$, so $x + 2y + 3z >= 5 + 6 + 6 = 17 > 10$. The
equality is infeasible. Verdict `unsat`.

The cert records the Farkas combination explicitly:

```text
(step :rule theory :theory lia :witness
  (farkas
    :combination ((1.0 c_eq) (-1.0 c_x_lb) (-2.0 c_y_lb) (-3.0 c_z_lb))
    :concludes 10 ≥ 17))
```

This is the LIA-side cert that downstream ITPs (Lean's
`linarith`, Rocq's `lia`, Isabelle's `arith`) consume.
