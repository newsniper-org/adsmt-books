= Exercises

These exercises are sorted roughly by chapter and
graded from *warm-up* (W) through *core* (C) to
*stretch* (S). The warm-ups should take a few minutes;
the core problems an hour or two; the stretch problems a
weekend.

== Chapter 1 — What is SMT?

*W1.1.* Write an SMT-LIB script that asserts $3x + 5 =
17$ and asks for $x$. Verify with `lu-smt` that the
model gives $x = 4$.

*W1.2.* Write a script that asserts the negation of a
trivial tautology (e.g. $forall x. x = x$ in its
quantifier-free instance form $a = a$). Verify the
verdict is `unsat`.

*C1.3.* Take a small problem from a domain you know
(scheduling, a logic puzzle, a Sudoku grid) and encode
it as SMT-LIB. Solve. Compare your encoding's runtime
to a hand-coded specialised solver.

== Chapter 2 — Propositional logic and SAT

*W2.1.* Convert the formula $(p => q) and (q => r) and
not (p => r)$ to CNF by hand. Verify that the SAT
solver returns `unsat`.

*W2.2.* The *pigeonhole principle* PHP$_n$ says $n + 1$
pigeons can't fit in $n$ holes. Write PHP$_3$ (4 pigeons,
3 holes) as a SAT instance and time the solver. How
does it scale to PHP$_8$?

*C2.3.* The *Tseitin transformation* turns an arbitrary
propositional formula into an equisatisfiable CNF
in polynomial time. Implement Tseitin in a language of
your choice and test it on the formula
$(a or b or c) and (not(a and b) or d) and dots$ of
your own devising.

*S2.4.* Read the original DPLL paper (Davis-Putnam-
Logemann-Loveland 1962). Write a toy DPLL solver in
≤300 lines that handles unit propagation and pure
literal elimination. Compare its speed to a modern
CDCL on benchmarks of growing size.

== Chapter 3 — First-order logic and theories

*W3.1.* Identify whether each formula belongs to QF_UF,
QF_LIA, QF_LRA, QF_BV, or a combination:

```text
(a) (= (f a) (f b))
(b) (and (> x 3) (< x 7))
(c) (= (select A i) (select A j))
(d) (= (bvadd #x01 #x02) #x03)
(e) (and (> x 3) (= (f x) y))
```

*C3.2.* Compose a formula with at least three theories
where the *combination* delivers a verdict no single
theory's decision procedure could on its own. Use
adsmt's `--audit-json` output to confirm all three
theories were exercised.

*S3.3.* Read the Nelson-Oppen 1979 paper. Identify two
conditions that the theories must satisfy for
straightforward Nelson-Oppen to apply. Find an example
in the SMT-LIB benchmark suite where these conditions
fail and polite combination is needed.

== Chapter 4 — Equality and UF

*W4.1.* The classical EUF puzzle: given $f(f(f(a))) =
a$ and $f(f(f(f(f(a))))) = a$, prove $f(a) = a$. Encode
and verify in SMT-LIB.

*C4.2.* Implement a tiny union-find in a language of
your choice. Add congruence closure for a fixed set of
binary function symbols. Run it on the puzzle above
and on a chain $(f(a) = b, f(b) = c, …, f(y) = z)$ to
see how the find-tree shape evolves.

*S4.3.* Read the Detlefs-Nelson-Saxe Simplify paper.
Identify the "fast" variant of congruence closure that
amortises better than the naive cascade. Implement it.
Benchmark against the naive version.

== Chapter 5 — Arithmetic

*W5.1.* For each, predict the verdict before running:

```text
(a) (assert (> x 3)) (assert (< x 4)) (check-sat)
    over Int and over Real
(b) (assert (> x 3)) (assert (<= x 4)) (check-sat)
    over Int
(c) (assert (= (* 2 x) 5)) (check-sat)
    over Int and over Real
```

*C5.2.* The *Frobenius coin problem*: given coin
denominations $a$ and $b$ with $gcd(a, b) = 1$, the
largest value *not* expressible as $a x + b y$ with
$x, y >= 0$ is $a b - a - b$. Verify this for
$(a, b) = (3, 5)$ using LIA.

*S5.3.* Implement a basic Simplex tableau in ≤500
lines. Test on a small linear program (3-5 variables,
5-10 constraints). Compare to running the same problem
through adsmt's LRA solver.

== Chapter 6 — BV, Arrays, Datatypes

*W6.1.* The *XOR-swap* trick: $x := x xor y$, $y := x
xor y$, $x := x xor y$ swaps $x$ and $y$ without a
temporary. Encode the three-statement sequence in BV
and verify the swap.

*C6.2.* Prove (via Arrays + LIA) that *bubble sort*'s
inner loop preserves the multiset of elements. Encode
"before" and "after" arrays for one step and check
equality of element counts.

*S6.3.* Encode the Datatype theory's *acyclicity*
constraint in QF_DT and find a formula that the solver
discharges only because of acyclicity. (Hint: try
representing $L = "cons" 1 L$.)

== Chapter 7 — Quantifiers

*W7.1.* Write a quantified formula where E-matching
with the obvious trigger succeeds. Run with
`:trigger-mode miller` and confirm.

*C7.2.* Write a quantified formula where E-matching
fails but bounded enumeration (Tier 3) succeeds.
Confirm with `--audit-json` that Tier 3 was reached.

*S7.3.* Write a quantified formula where Tier 3 also
fails and Tier 4 (abductive) kicks in. Inspect the
abductive candidates; verify that adding one of them
as an assertion makes Tier 1 succeed.

== Chapter 8 — Abduction

*W8.1.* Given the goal $p(a)$ and the empty rule base,
predict the verdict. Run; observe `abductive` with the
expected candidate.

*C8.2.* Set up a small Horn rule base of 5-6 rules.
Submit a goal whose SLD chain has a non-empty residual.
Inspect the candidates by rank and discuss whether the
ranking matches your domain intuition.

*S8.3.* Implement a tiny SLD-resolution engine in your
preferred language. Run it on the same Horn base as
above. Compare its residuals to adsmt's `minimize`d
candidates.

== Chapter 9 — Certificates and trust

*W9.1.* Generate a cert for a simple `unsat` instance.
Read the cert manually. Identify which step established
the contradiction.

*C9.2.* Take a generated cert and *break* it (drop a
step, swap two step ids, change a witness term). Confirm
`adsmt-cert-check` rejects the broken cert. Identify
which validation rule caught it.

*S9.3.* Read the `adsmt-cert` checker source (~600
lines). Audit it: is there any rule where the checker
trusts a structural property that *should* be re-derived?
Submit a finding (or a clean bill of health) as an
issue.

== Chapter 10 — ITP integration

*W10.1.* In Lean 4 with `Adsmt` imported, use
`smt_decide` to close a simple arithmetic goal (e.g.
$n + 1 > n$ for `Nat`).

*C10.2.* Use `smt_abduce` on a goal you don't expect
adsmt to discharge. Read the surfaced `sorry`-
placeholders; discharge each one manually. Confirm the
full proof type-checks.

*S10.3.* Take a goal from a Rocq or Isabelle theory
file, port it to Lean + adsmt, and use `smt_decide`.
Compare the discharge time across the three ITPs (via
the out-of-tree backends).

== Open-ended capstones

*K1.* Pick a small *verification* project — a parser, a
sorting routine, a state machine. Specify its
correctness in SMT-LIB. Use adsmt to discharge as many
sub-goals as possible. Document where SMT helps and
where you fall back to manual proof.

*K2.* Pick a *logic puzzle* (Einstein's puzzle, a Zebra
puzzle, a Sudoku variant). Encode in SMT-LIB. Time
adsmt against a vanilla SAT encoding and against a
pure-Prolog solution. Discuss the trade-offs.

*K3.* Build a *small DSL* whose semantics you encode in
SMT-LIB. Implement a `verify` command that emits the
SMT-LIB and calls adsmt. Use the abductive surface to
help the user when a verify fails.

== Solutions

This book does not ship solution sketches. The
exercises are calibrated so that working through them
under your own judgement is more valuable than seeing
an authorised answer. The bibliography in chapter 99
points to references for the theory; the source code
of adsmt is the ground truth for the practice.
