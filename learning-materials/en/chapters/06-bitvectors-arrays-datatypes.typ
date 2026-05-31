= Bitvectors, Arrays, Datatypes

This chapter sketches the three remaining theories in
adsmt's roster.

== Bitvectors (BV)

Fixed-width unsigned binary integers — 32-bit, 64-bit,
or any other width specified at declaration. Operations:
add, sub, mul, div, shifts, bitwise and / or / xor,
comparisons.

```text
(declare-const x (_ BitVec 32))
(declare-const y (_ BitVec 32))
(assert (bvult x y))
(assert (= (bvadd x #x00000001) y))
(check-sat) ;; sat
```

BV is the *workhorse* of hardware verification and
low-level program analysis. Bit-shift, mask, and overflow
behaviour all match real hardware exactly.

== BV decision procedure: three layers

adsmt's BV solver has three layers:

1. *Literal evaluation.* Constants on both sides? Just
   evaluate at solver level — `#x00000001 + #x00000002 =
   #x00000003`. Cheap and frequently sufficient.

2. *Bit-fact propagation.* For literals with concrete
   bits, propagate facts: if `(bvand x #xff) = #x42`,
   the low 8 bits of $x$ are fixed at `0x42` regardless
   of the upper bits. This is faster than full
   bit-blasting.

3. *Bit-blasting fallback.* When the first two layers
   don't decide, encode the BV constraint into pure SAT
   by introducing one Boolean variable per bit and
   adding clauses for each gate. Drop the result into
   the SAT layer.

```rust
impl Theory for BvSolver {
    fn check(&mut self) -> SatVerdict {
        if let Some(c) = self.literal_eval() { return c; }
        if let Some(c) = self.bit_fact_propagate() { return c; }
        let clauses = self.bit_blast();
        self.sat.check_with(clauses)
    }
}
```

Bit-blasting is complete for QF_BV — any quantifier-free
BV formula is decidable this way. The cost is the
encoding size: a 64-bit multiplication produces $O(n^2) =
4096$ clauses. Layers 1 and 2 skip the encoding
whenever possible.

== Arrays

The array theory handles maps from indices to values.
The signature has two operations:

- `(select A i)` — read the value at index $i$.
- `(store A i v)` — produce a new array with index $i$
  set to $v$, all others unchanged.

Two axioms:

- *Read-over-write same.* $select(store(A, i, v), i) = v$.
- *Read-over-write different.* $i ne j => select(store(A,
  i, v), j) = select(A, j)$.

```text
(declare-const A (Array Int Int))
(assert (= (select (store A 0 42) 0) 42))   ;; same: 42 = 42, sat trivial
(assert (= (select (store A 0 42) 1) (select A 1)))  ;; different: tautology
```

The decision procedure walks `store` chains. A `select`
into a `store` chain reduces to either the most recent
matching store (read-over-write same) or recurses to
the predecessor (read-over-write different).

== Arrays + LIA

The combination of Arrays + LIA is where things get
interesting. Indexing with arithmetic expressions:

```text
(declare-const A (Array Int Int))
(declare-const i Int)
(declare-const j Int)
(assert (= i (+ j 1)))
(assert (= (select (store A i 5) j) 7))
```

The store/select disagreement requires LIA to determine
$i ne j$ (from $i = j + 1$, by LIA reasoning $i ne j$).
The Arrays solver invokes the combination layer to
ask LIA whether $i = j$; LIA responds no; Arrays
concludes the select reduces to $select(A, j) = 7$.

Polite combination (chapter 3) handles this automatically.

== Datatypes

The Datatypes theory handles algebraic data types: lists,
trees, option, records, sum types. Each datatype has:

- *Constructors* — `nil`, `cons`, `Some`, `None`, …
- *Selectors* — `head`, `tail`, `value`, …
- *Testers* — `is-nil`, `is-cons`, …

```text
(declare-datatype IntList ((nil) (cons (head Int) (tail IntList))))
(declare-const l IntList)
(assert (is-cons l))
(assert (= (head l) 3))
(check-sat) ;; sat: l = (cons 3 ?)
```

Axioms include:

- *Disjointness.* `nil` $ne$ `cons a t`.
- *Injectivity.* `cons a1 t1 = cons a2 t2 => a1 = a2
  and t1 = t2`.
- *Acyclicity.* No data value contains itself as a sub-
  term.

The decision procedure tracks constructor membership and
chases injectivity / disjointness facts. Acyclicity is
checked via occurs-check.

== Combining the trio with EUF

Bit-vectors over uninterpreted arrays of bit-vector
elements... combine BV + Arrays + EUF, plus possibly LIA
if integer indices appear. adsmt's polite combination
handles arbitrary subsets:

```text
(declare-sort Process 0)
(declare-fun pc (Process) (_ BitVec 8))   ;; EUF + BV
(declare-fun state (Process) (Array (_ BitVec 8) Int))  ;; + Arrays + LIA
(declare-const p Process)
(assert (= (pc p) #x10))
(assert (> (select (state p) #x10) 0))
```

Each atom routes to its theory:
- `(pc p) = #x10` → EUF + BV
- `(select ... #x10) > 0` → Arrays + LIA
- The shared term `(pc p)` mediates between layers.

== Worked example: aliased array writes

A classic verification puzzle: prove that storing $x$
at index $i$ then $y$ at index $j$, with $i ne j$,
commutes with the swap.

```text
(declare-const A (Array Int Int))
(declare-const i Int)
(declare-const j Int)
(declare-const x Int)
(declare-const y Int)
(assert (not (= i j)))
(assert (not (= (store (store A i x) j y)
                (store (store A j y) i x))))
(check-sat) ;; unsat
```

The Arrays solver: extensionality says two arrays are
equal iff they agree on every index. So consider three
classes of index $k$:

- $k = i$: lhs gives $x$ (store at $i$, then select past
  the $j$-store since $i ne j$). rhs gives $x$ (store at
  $i$ at the top). Equal.
- $k = j$: lhs gives $y$. rhs gives $y$. Equal.
- $k notin {i, j}$: lhs gives $A[k]$. rhs gives $A[k]$.
  Equal.

So lhs $=$ rhs everywhere, contradicting the assertion.
The cert records the three cases as three sub-proofs,
each closing with read-over-write reasoning.

== Limits

Each of the three theories has gaps:

- *BV:* multiplication blow-up. Encoding a 64-bit mul
  produces lots of clauses; in pathological cases, the
  SAT layer chokes.
- *Arrays:* extensionality. The above example used it.
  Solvers handle it heuristically, not always
  completely.
- *Datatypes:* mutually recursive types and structural
  induction. SMT solvers do *not* handle induction
  directly. Induction belongs to the ITP, which the
  cert + reflection chain (chapter 10) bridges.

The abductive layer (chapter 8) helps when these gaps
bite: the solver surfaces "I'd need an induction
hypothesis" rather than just `unknown`.
