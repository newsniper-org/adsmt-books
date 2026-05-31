= Bibliography

The chapters of this book draw on a long body of work in
automated reasoning, SMT, type theory, and interactive
theorem proving. The pointers below are the most directly
load-bearing references for the algorithms and design
decisions presented.

== SAT and SMT foundations

- Marques-Silva, Lynce, Malik. *Conflict-driven clause
  learning SAT solvers* (Handbook of Satisfiability,
  2009). The canonical CDCL reference; chapter 4 follows
  the two-watched-literals and VSIDS treatments here.

- Eén, Sörensson. *An extensible SAT-solver* (SAT
  2003). The MiniSAT paper. adsmt's CDCL is faithful to
  this design.

- Biere, Heule, van Maaren, Walsh, eds. *Handbook of
  Satisfiability* (2nd ed., 2021). Comprehensive
  reference; chapter 24 (Sebastiani) covers SMT in
  depth.

- Nieuwenhuis, Oliveras, Tinelli. *Solving SAT and SAT
  modulo theories: from an abstract Davis-Putnam-Logemann-
  Loveland procedure to DPLL(T)* (JACM 2006). The DPLL(T)
  abstract framework chapter 5 relies on.

== Theory solvers

- Nelson, Oppen. *Simplification by cooperating decision
  procedures* (TOPLAS 1979). The original Nelson-Oppen
  combination method.

- Tinelli, Zarba. *Combining decision procedures for
  sorted theories* (JELIA 2004). Polite combination; the
  generalisation chapter 5 uses for adsmt's combination
  policy.

- Bradley, Manna. *The Calculus of Computation* (Springer
  2007). Textbook treatment of UF, LIA, LRA decision
  procedures.

- Dutertre, de Moura. *A Fast Linear-Arithmetic Solver
  for DPLL(T)* (CAV 2006). The Simplex-based LIA / LRA
  solver chapter 6 sketches.

- Niemetz, Preiner, Wolf, Biere. *CoSMT: Bit-Vector
  Solving with QF-BV* (CAV 2019). Modern bit-blasting
  references for chapter 6.

== EGraph and equality reasoning

- Detlefs, Nelson, Saxe. *Simplify: a theorem prover for
  program checking* (JACM 2005). Practical congruence
  closure algorithm.

- Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha. *egg:
  Fast and extensible equality saturation* (POPL 2021).
  Modern E-graph technique; chapter 7's hash-cons +
  congruence cascade follows this lineage.

== Quantifier instantiation

- Detlefs, Nelson, Saxe (op. cit.). E-matching foundations.

- de Moura, Bjørner. *Efficient E-Matching for SMT
  Solvers* (CADE 2007). The E-matching variant chapter 7
  implements.

- Reynolds, Tinelli, Goel, Krstić, Deters, Barrett.
  *Quantifier instantiation techniques for finite model
  finding in SMT* (CADE 2013). Tier-3 bounded enumeration
  inspiration.

== Abductive reasoning

- Inoue. *Linear resolution for consequence finding*
  (Artificial Intelligence 1992). The SLD chain skeleton
  of chapter 8.

- Eiter, Gottlob. *The complexity of logic-based
  abduction* (JACM 1995). Theoretical bounds; informs the
  minimisation strategy.

- Dillig, Dillig, Aiken. *Automated error diagnosis using
  abductive inference* (PLDI 2012). Practical
  abduction-for-verification application; the user-cost
  ranking of chapter 8 draws on similar intuitions.

== Higher-order logic and type theory

- Gordon, Melham. *Introduction to HOL: A theorem proving
  environment for higher order logic* (Cambridge UP
  1993). The 12-rule kernel of chapter 2 follows this
  lineage.

- Pierce. *Types and Programming Languages* (MIT Press
  2002). System F, dependent types, type classes — the
  type-theoretic backdrop of chapter 3.

- Wadler, Blott. *How to make ad-hoc polymorphism less
  ad hoc* (POPL 1989). Type-class introduction and
  dictionary-passing translation.

== Certificate formats and reflection

- Stump, Oe, Reynolds, Hadarean, Tinelli. *SMT proof
  checking using a logical framework* (Formal Methods in
  System Design 2013). The LFSC proof format; adsmt-cert
  is a smaller cousin.

- Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds, Barrett.
  *SMTCoq: A plug-in for integrating SMT solvers into Coq*
  (CAV 2017). Coq-side reflection; mirrored in
  `adsmt-emit-rocq`.

- Lochbihler. *Mechanising a type-safe model of multithreaded
  Java with a verified compiler* (Journal of Automated
  Reasoning 2018). Isabelle-side reflection patterns;
  `adsmt-emit-isabelle` draws on similar machinery.

- Avigad, de Moura, Kong. *Theorem Proving in Lean 4*
  (online book, ongoing). The Lean 4 surface chapter 10
  emits into.

== Software engineering

- Klabnik, Nichols. *The Rust Programming Language*
  (Mozilla, ongoing). Rust language reference.

- Cargo Book. Workspace, semver, and publication
  conventions chapter 11 relies on.

- Debian Policy Manual §5.6 (versioning) and §2.1
  (channels). The Debian-style channel model chapter 11
  adopts.

== adsmt-internal documents

- `~/AD1/CONTRIBUTIONS_AUDIT.md` — RC2.7 audit record.
- `~/AD1/DOC_AUDIT.md` — RC2.4 + RC2.8 cargo-doc audits.
- `~/AD1/PUBLISH_AUDIT.md` — RC2.2 publish dry-run.
- `~/AD1/ABSORPTION_PLAN.md` — logicutils absorption history.
- `~/AD1/memory/prover_emit_policy.md` — Lean/Rocq/Isabelle lockstep policy.
- `~/AD1/memory/oxiz_relationship.md` — OxiZ Path A+B integration plan.
- `~/AD1/memory/lsp_roadmap.md` — LSP phase sign-offs.
