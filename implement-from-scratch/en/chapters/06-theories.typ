= Individual theories

This chapter walks through each theory adsmt ships, in
roughly increasing implementation complexity.

== Uninterpreted functions (UF)

The simplest theory. UF asserts equalities and disequalities
over uninterpreted function symbols and constants:
$ f(a) = b, quad a = c, quad b != f(c) $

The natural data structure is a *union-find* over terms,
augmented with *congruence closure*: when $a = c$ enters the
union-find, the structure must merge $f(a)$ and $f(c)$ as
well (and recursively any larger terms built on them).

```rust
pub struct Uf {
    parent: HashMap<Term, Term>,        // union-find pointer
    rank: HashMap<Term, usize>,         // for rank-based union
    diseqs: Vec<(Term, Term)>,          // asserted disequalities
    scope_stack: Vec<UfSnapshot>,
}
```

`assert(t1 = t2)` calls `union(t1, t2)`. `assert(t1 != t2)`
checks first whether `find(t1) == find(t2)` (immediate
conflict) and otherwise records the pair. `check()` re-runs
the disequality scan against the current find roots.

Congruence: maintain a per-class list of *parent terms* —
applications that have one of the class's representatives
as an argument. After each union, walk the parent lists of
both classes and check whether any two of them are now
congruent (same head, same per-argument class). If yes,
union them too. The cascade is the same shape we already
saw in the e-graph.

== Linear arithmetic — bounds and Simplex

LIA (integer) and LRA (real) handle linear inequalities.
adsmt uses a two-layer strategy:

*Layer 1 — bound tracking.* For each variable, maintain a
running lower bound $ell_x$ and upper bound $u_x$. New
constraints tighten the bounds. If $ell_x > u_x$ for any
variable: contradiction.

```rust
pub struct LinArith {
    name_: &'static str,
    bounds: HashMap<String, Bounds>,
    scope_stack: Vec<LinArithSnapshot>,
    conflict: Option<TheoryWitness>,
}
struct Bounds {
    lower: Option<(i128, bool)>, // (value, strict?)
    upper: Option<(i128, bool)>,
}
```

This handles variable-vs-constant constraints
(`x ≤ 5`, `x ≥ 3`) in constant time. For LIA, strict
inequalities tighten to their integer counterparts:
`x > 5` becomes `x ≥ 6`.

*Layer 2 — Simplex tableau* (via OxiZ's `oxiz-math`). For
constraints involving multiple variables (`x + y ≤ z + 3`),
the bound tracker is not enough. The literal is forwarded
to a Simplex backend that maintains the standard tableau
representation and pivots until either a feasible solution
or a contradiction emerges.

```rust
fn assert(&mut self, lit: Literal) -> AssertResult {
    if let Some((var, op, k)) = self.dest_var_constant(&lit.term) {
        if let Some(witness) = self.record_bound(var, op, k) {
            return AssertResult::Conflict { witness };
        }
        AssertResult::Accepted
    } else if self.is_two_var_constraint(&lit.term) {
        self.simplex.assert(lit)
    } else {
        AssertResult::Ignored
    }
}
```

The two-layer design pays off when the bulk of constraints
are variable-vs-constant — the Simplex pivots, expensive,
fire only when truly needed.

== Bit-vectors

BV constraints are fixed-width binary arithmetic:
`(= (bvadd x 1) (bvor y 0xff))`. adsmt handles them in
three layers:

*Layer 1 — literal evaluation.* When both operands of a
bit-vector operator are concrete literals, evaluate at
assertion time:
$ "bvand"("0b1100", "0b1010") -> "0b1000" $

*Layer 2 — bit-level fact propagation.* When one operand is
a variable and the other a literal, derive partial bit
knowledge on the variable. For
`(bvand x 0x0F) = 0x05`: the high four bits of `x` are
unconstrained (the AND zeroed them in the result), and the
low four bits of `x` must be `0x5`. Encode the partial
knowledge as `(mask, value)` pairs per variable; merge
pairs cumulatively; promote to a full binding once `mask`
covers every bit of the width.

*Layer 3 — bit-blasting* (via `bv_blast`). For mixed-
variable constraints (`(bvadd x y) = (bvmul z 3)`), lower
each BV bit to a fresh boolean atom and emit CNF that
encodes the bit-level semantics. The CNF goes to the SAT
backend, which decides it as a propositional problem. The
adder is implemented as a ripple-carry chain; the
multiplier as shift-and-add; AND/OR/XOR are bit-wise.

```rust
pub fn blast_term(t: &Term, w: u32, env: &mut BlastEnv) -> Option<Vec<Bit>> {
    if let Some((value, lw)) = t.dest_bv_lit() {
        return Some(lit_bits(value, w));
    }
    if let Term::Var(v) = t {
        return Some((0..w).map(|i| Bit::Atom(bit_var(&v.name, i))).collect());
    }
    if let Some((op, ow, lhs, rhs)) = t.dest_bv_binop() {
        // lower lhs and rhs, then combine bit-by-bit
        // according to op (bvand, bvor, bvxor, bvadd, bvsub, bvmul).
    }
    None
}
```

== Arrays — read over write

The array theory handles `(select arr idx)` and
`(store arr idx val)` operations. The key inference rule is
*read over write*:

$ "select"("store"(a, i, v), j) = cases(
  v "if" i = j,
  "select"(a, j) "if" i != j,
) $

Operationally: when asserting an equation
`(select (store a i v) j) = expr`, attempt the rewrite. The
same-index case fires unconditionally; the different-index
case requires evidence that `i != j` is already known
(either asserted directly or derived).

```rust
fn read_over_write(t: &Term, diseqs: &[(Term, Term)]) -> Option<(Term, String)> {
    let (arr, j) = t.dest_select()?;
    let (inner_a, i, v) = arr.dest_store()?;
    if i.alpha_eq(&j) {
        Some((v, "same-index".into()))
    } else if pair_known_disequal(&i, &j, diseqs) {
        Some((mk_select(inner_a, j), "diseq-index".into()))
    } else {
        None
    }
}
```

A second rule normalises store-over-store:
$ "store"("store"(a, i, v_1), j, v_2) = cases(
  "store"(a, i, v_2) "if" i = j,
  "store"("store"(a, j, v_2), i, v_1) "if" i != j,
) $

The same-index dominance is the more useful rule (it
collapses redundant writes); the disequal-index
commutativity helps put nested stores into a canonical
order so downstream EUF can detect aliasing.

Negative array equalities — `a != b` between array-sorted
operands — queue an *extensionality witness*: some index $d$
must exist where `select(a, d) != select(b, d)`. The
quantifier layer (chapter 7) is responsible for
instantiating $d$.

== Datatypes

Algebraic datatypes — `Color = Red | Green | Blue` and
inductive datatypes like `Nat = Zero | Succ Nat` or
`List a = Nil | Cons a (List a)` — get a dedicated theory.
Two core reasoning rules:

*Constructor disjointness.* If `a` was constructed by
`Red` and `b` by `Green`, they cannot be equal. Asserting
`a = b` produces a conflict immediately.

*Injectivity.* If `Cons head1 tail1 = Cons head2 tail2`
holds, then `head1 = head2` and `tail1 = tail2`. The
theory's `derive_equalities` walks asserted equalities
between constructor applications and emits the pointwise
arg-equalities.

```rust
fn derive_equalities(&self) -> Vec<(Term, Term)> {
    let mut out = Vec::new();
    for (a, b) in &self.asserted_eqs {
        if let (Some((ca, args_a)), Some((cb, args_b))) =
            (Self::dest_constructor_app(a), Self::dest_constructor_app(b))
        {
            if ca == cb && args_a.len() == args_b.len() {
                for (arg_a, arg_b) in args_a.into_iter().zip(args_b) {
                    out.push((arg_a, arg_b));
                }
            }
        }
    }
    out
}
```

Cardinality: a finite enum has a finite cardinality
witness; an inductive datatype is $omega$. The polite
combination uses these for the cardinality clique check.

== Polite combination interface

Every theory above plugs into the `Theory` trait. The
combination orchestrator (chapter 5) drives them
collectively. The choreography is uniform regardless of
theory: same trait, same protocol, same `push`/`pop` shape.
This is why adding a new theory is a contained exercise —
implement the trait, register an instance, and the
combination machinery picks it up.

A useful exercise for the reader: implement a string
theory along these lines. The basic operations (`length`,
`concat`, `substr`) plus a constraint vocabulary
(`prefix-of`, `contains`) is enough to handle a surprising
fraction of real-world SMT workloads. The trick is the
length abstraction — most string formulas decompose into
arithmetic on lengths plus equality reasoning on
characters.
