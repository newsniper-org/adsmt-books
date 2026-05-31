= Preface

This book walks a reader through the construction of an SMT
solver of the shape adsmt itself takes: a higher-order logic
kernel with higher-kinded types, a Conflict-Driven
Clause-Learning SAT layer, polite combination of theory
solvers, a quantifier instantiation pipeline, an abductive
reasoning engine, a structured certificate format, and
reflection bindings into interactive theorem provers (ITPs).

The audience is the kind of undergraduate graduate who has
completed at least one of computer science, mathematics,
philosophy, or mathematical logic. We assume familiarity
with first-order logic notation, the basics of recursion
and data structures, and the standard mathematical style of
stating and proving claims. We do *not* assume prior
experience writing a solver, contributing to a kernel, or
working inside an interactive theorem prover.

The book follows the same architecture adsmt itself has,
but the goal is not to reproduce adsmt's code. Instead each
chapter introduces one concern, sketches the data structures
and algorithms that solve it cleanly, and discusses the
engineering decisions adsmt actually made — including the
ones it made wrong the first time around and later
corrected. Treat the chapters as a series of design lectures
backed by working examples; the goal is for a careful reader
to be able to build their own solver of comparable shape
without leaning on adsmt's source as a crutch.

== How to read this book

Chapter 1 motivates SMT solving and lays out the design
philosophy that distinguishes adsmt from its peers
(particularly Z3, CVC5, and Bitwuzla). Chapters 2 and 3
build the logical core: a small kernel of inference rules
plus the type system that runs on top of it. Chapter 4
develops the SAT layer in enough detail to write a usable
CDCL solver, including two-watched literals, VSIDS,
Luby-scheduled restarts, and learnt-clause retention via
LBD. Chapter 5 introduces theory combination — the
machinery that lets multiple theory solvers cooperate over
shared sorts. Chapter 6 walks through individual theory
implementations (UF, linear arithmetic, bit-vectors,
arrays, datatypes). Chapter 7 brings in quantifiers via
E-matching and Tier-based escalation. Chapter 8 introduces
the abductive engine — the layer that makes adsmt
distinctive. Chapter 9 explains the certificate format.
Chapter 10 covers ITP reflection, focusing on Lean 4.
Chapter 11 discusses engineering: testing, benchmarking,
surface freezes, semver, and the like. Three appendices
give reference material on the SMT-LIB surface, the lu-kb
surface, and the certificate AST.

== Notational conventions

We write meta-variables in mathematical italic ($x$, $y$,
$phi$) and concrete code in monospaced font (`Term::Var`,
`adsmt-core`). Type-theoretic judgements use the standard
turnstile notation: $Gamma tack t : tau$ means "$t$ has
type $tau$ in context $Gamma$". When a definition or
theorem ends with a square ($qed$) the surrounding prose
resumes.

We say *propositional formula* for variable-free Boolean
expressions, *first-order formula* for ones with
quantifiers over individuals, and *higher-order formula*
when quantifiers may range over functions or predicates.
SMT itself lives at the propositional level extended with
theory atoms; quantifier handling is layered on top.

The code excerpts use Rust syntax because that is what
adsmt is written in, but the algorithms transfer essentially
unchanged to OCaml, Standard ML, or Scala. When a Rust
idiom is genuinely load-bearing (lifetime annotations,
trait objects) the surrounding prose explains why; when it
is incidental syntax noise we suppress it.

== A note on out-of-scope material

This book covers the adsmt project proper: the in-tree
workspace + its absorbed `lu-*` foundation. The Rocq and
Isabelle backend documentation belongs to a separate
project (`adsmt-contrib`) and is being written elsewhere.
The OxiZ SAT backend, on which adsmt depends, is also a
separate project with its own documentation; we touch it
only in chapter 4 to explain the interface adsmt consumes,
not its internals.
