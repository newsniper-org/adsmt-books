= Preface

This book is the *concepts and practice* companion to the
adsmt project. The companion volume, *Implement from
Scratch*, walks through *building* an SMT solver of
adsmt's shape; this volume walks through *using* one — and
through the conceptual scaffolding you need to use it
well.

== Who is this for?

You hold an undergraduate degree (or equivalent
familiarity) in at least one of:

- *Computer science / software engineering.* You know how
  to read code, you understand data structures and basic
  complexity. SAT and SMT are probably familiar names,
  even if you haven't worked with them in earnest.
- *Mathematics.* You're comfortable with formal proof,
  set theory, basic logic, and (ideally) a passing
  acquaintance with model theory.
- *Philosophy* — specifically, *logic and philosophy of
  mathematics*. You know the difference between syntax
  and semantics, between proof theory and model theory,
  and ideally something about modal or non-classical
  logics.
- *Mathematical logic.* You've seen Henkin completeness,
  Lowenheim-Skolem, compactness; you can read sequent-
  calculus rules at a glance.

Any *one* of these suffices. The book threads concepts
through all four perspectives wherever they're
illuminating. A computer-science reader gets the
algorithms and code; a mathematics reader gets the model
theory and semantics; a philosophy reader gets the
distinctions between deductive, inductive, and abductive
inference; a mathematical-logic reader gets the proof-
calculus presentation that ties them together.

== What this book covers

Eleven chapters and four appendices:

1. *What is SMT?* — the problem, the verdict, the workflow.
2. *Propositional logic and SAT* — the foundation.
3. *First-order logic and theories* — the SMT side of
   the boundary.
4. *Equality and uninterpreted functions.*
5. *Arithmetic* — LIA, LRA, the boundary cases.
6. *Bitvectors, arrays, and datatypes.*
7. *Quantifiers* — what makes them hard.
8. *Abduction* — adsmt's distinguishing feature.
9. *Certificates and trust* — why and how a solver
   produces re-verifiable proofs.
10. *ITP integration* — using SMT inside Lean 4 (and Rocq,
    Isabelle).
11. *Engineering* — a brief tour of running, configuring,
    extending the tool.

Appendices: CLI cheatsheet, LSP cheatsheet, exercises,
further reading.

== What this book does *not* cover

This is not a research monograph on SMT. We sketch the
state of the art enough to motivate adsmt's choices but
don't survey alternatives at depth — for that, see the
references in the bibliography.

This is also not a book on writing an SMT solver. The
companion volume, *Implement from Scratch*, does that
explicitly. Where this book describes *what* a layer
does, that book describes *how* the layer is built.

Finally, this book does not document `adsmt-contrib` —
the out-of-tree Rocq and Isabelle emit backends. Those
have their own documentation effort.

== How to read this book

The chapters are *roughly* sequential. A reader new to
SMT should read 1-3 in order, then 4-6 (the theory tour),
then 7-10 (the advanced layer + abduction + trust).
A reader with prior SMT exposure can skim 1-3 and start at
4 or 5.

Code samples are in *Rust* (matching adsmt's
implementation language) and *SMT-LIB v2* (the standard
input syntax). You don't need Rust fluency to read the
code — the examples are short and explained. SMT-LIB v2
is documented in the surface appendix of the companion
volume.

== Notational conventions

- *Italic* for first introductions of terms.
- `monospace` for code, file paths, and surface syntax.
- Mathematical notation uses standard logical symbols.
- Numbered chapter references like "(chapter 3)" point
  within this book; "(companion ch. 3)" points at the
  *Implement from Scratch* companion.

== Acknowledgements

adsmt builds on decades of SMT research — see the
bibliography for the most directly load-bearing pointers.
The OxiZ project, on which adsmt's SAT and classical
theory layers rest, deserves explicit mention; so does
logicutils, whose lu-kb dialect adsmt absorbed at v0.x.

Let's begin.
