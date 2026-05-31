= Introduction

== What an SMT solver does

An SMT solver answers the question: *given a set of logical
constraints in some restricted vocabulary, is there an
assignment of values to free variables that satisfies all of
them simultaneously?* The "Satisfiability Modulo Theories"
in the name is the same satisfiability problem you have met
in propositional logic, but the atomic units of the formula
are not just Boolean variables — they are claims about
specific mathematical structures: linear inequalities over
the integers, equations over uninterpreted function symbols,
read-write patterns on arrays, bit-level operations on fixed-
width vectors, and so on.

A trivial example. The propositional formula
$ phi = (p or q) and not (p and q) $
is satisfiable: take $p = top, q = bot$. An SMT formula
augments this style of reasoning with theory atoms:
$ psi = (x + y > 5) and (x < 3) and (y < 3) $
is *unsatisfiable* — $x < 3$ and $y < 3$ together give
$x + y < 6$, but the strict inequality $x + y > 5$ requires
$x + y >= 6$ over the integers and the conjunction collapses.
A solver that reports unsatisfiability for $psi$ must reason
not only about the Boolean structure of the conjunction but
also about the *arithmetic content* of each inequality.

This division of labour — the Boolean structure handled by a
SAT-like core, the theory content handled by specialised
theory solvers — is the architectural idea that defines the
SMT family of tools.

== Why build another one

There are excellent SMT solvers already: Z3 from Microsoft
Research, CVC5 from a consortium led by Stanford and Iowa,
Bitwuzla for bit-vectors, MathSAT for verification
workloads, Yices for real-time settings. The adsmt project
makes no claim to dethrone any of these on traditional SMT
benchmarks. It exists for three reasons.

*First*, adsmt is built around an *abductive* reasoning
layer that the others lack. When a traditional SMT solver
reaches a state where it cannot determine satisfiability
within its budget, it returns `unknown`. adsmt, when it
reaches such a state, attempts to find a *minimal set of
additional hypotheses* that would, if added to the input,
make the problem decidable. This abductive output is then
returned alongside the verdict so callers (especially
interactive theorem prover users) can decide what to do
with it. The classical use case is interactive proof: a
human proof author asks adsmt to discharge a step, adsmt
fails, but adsmt also says *here is what would have made
it work*. The human can accept the hint, sharpen it, or
reject it.

*Second*, adsmt is built around a *higher-order logic with
higher-kinded types* (HOL+HKT) kernel rather than the
many-sorted first-order logic that classical SMT solvers
work in. This brings adsmt closer to the logical surface
that interactive theorem provers (Lean 4, Rocq, Isabelle)
already operate over, which makes reflection — sending
proof certificates from adsmt to an ITP for re-verification
— substantially smoother. Whether the higher-order surface
is worth the implementation cost is a design judgement
adsmt has made; we discuss the tradeoffs in chapter 3.

*Third*, adsmt is built as a *Lean 4-first* solver. Its
certificate format includes a Lean reflection emit module
that lets a Lean user invoke adsmt as a tactic and have
the resulting proof re-elaborated in their kernel. Other
ITPs (Rocq, Isabelle) are supported through out-of-tree
backends; the in-tree project commits to Lean 4 as the
reference target.

The combination of these three commitments is what makes
adsmt distinctive. None of them is *novel* in isolation —
abductive reasoning has a long literature, HOL+HKT systems
exist in HOL Light and Lean itself, ITP-friendly SMT has
been pursued by veriT and CVC5's Alethe output. The
combination, however, is unusual enough that "build adsmt"
is a different exercise from "build Z3".

== The plan of attack

We are going to build the solver bottom up. The kernel
(chapter 2) is the smallest possible trusted base. The
type system (chapter 3) layers on top. The SAT layer
(chapter 4) is independent of everything above; it could
be ripped out and replaced with an external SAT solver
(adsmt itself does this with OxiZ as the default backend).
The theory layer (chapters 5 and 6) cooperates with the
SAT layer through a well-defined protocol. The quantifier
layer (chapter 7) sits above the theory layer and uses it
as a service. The abductive layer (chapter 8) operates on
top of everything, escalating when the lower layers run out
of steam. The certificate format (chapter 9) is woven
through every layer — every inference, every theory call,
every abductive escalation produces a structured proof
fragment. Chapter 10 covers reflection. Chapter 11 is the
engineering chapter: testing strategies, surface
stabilisation, semver discipline, and the practical
realities of shipping the solver.

A reader who finishes this book should be able to
implement a comparable system from a blank workspace, in
whichever language they prefer. The reader should also be
able to read adsmt's own source code without surprises: we
have stayed close to the actual design decisions adsmt
made, including the corners where adsmt's first attempt
was wrong and a later revision fixed it.
