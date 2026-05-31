= Further Reading

This appendix is a curated list of references that go
beyond what this book has space for. Each entry includes
a one-line annotation: what you'll find there and why
it's worth your time.

== SMT — foundations

- *The SMT-LIB Initiative.* `https://smtlib.cs.uiowa.edu/`
  The standard's home page, with the current language
  spec, theory definitions, and the benchmark library.
  Indispensable reference for anyone writing SMT-LIB.

- *Barrett, Sebastiani, Seshia, Tinelli.* "Satisfiability
  Modulo Theories." In the *Handbook of Satisfiability*
  (2nd ed., 2021). Chapter 33. The canonical SMT survey.

- *Bradley, Manna.* *The Calculus of Computation*.
  Springer 2007. Textbook treatment of decision
  procedures with worked examples; good first introduction
  for someone with a CS background.

- *Kroening, Strichman.* *Decision Procedures: An
  Algorithmic Point of View*. Springer 2008. Companion
  textbook with a different organisation and additional
  industrial case studies.

== SAT — foundations

- *Biere, Heule, van Maaren, Walsh, eds.* *Handbook of
  Satisfiability*. 2nd ed., IOS Press 2021. The reference.

- *Marques-Silva, Lynce, Malik.* "Conflict-Driven Clause
  Learning SAT Solvers." Chapter 4 of the Handbook.

- *Eén, Sörensson.* "An Extensible SAT-Solver." SAT
  2003. The MiniSAT paper; the design that subsequent
  CDCL solvers all build on.

== Theory solvers

*EUF:*
- *Detlefs, Nelson, Saxe.* "Simplify: A theorem prover
  for program checking." *JACM* 52(3), 2005. Practical
  congruence closure.
- *Nieuwenhuis, Oliveras.* "Fast congruence closure and
  extensions." *Information and Computation* 2007.

*LIA/LRA:*
- *Dutertre, de Moura.* "A Fast Linear-Arithmetic Solver
  for DPLL(T)." CAV 2006.
- *Cooper.* "Theorem proving in arithmetic without
  multiplication." *Machine Intelligence* 7, 1972. The
  Presburger reference.

*BV:*
- *Brummayer, Biere.* "Effective Bit-Width and Under-
  Approximation." EUROCAST 2009.
- *Niemetz, Preiner, Biere.* "Boolector at the SMT
  Competition 2018." Modern BV solver design.

*Arrays:*
- *Stump, Barrett, Dill, Levitt.* "A decision procedure
  for an extensional theory of arrays." LICS 2001.

*Datatypes:*
- *Reynolds, Blanchette.* "A Decision Procedure for
  (Co)datatypes in SMT Solvers." *Journal of Automated
  Reasoning* 2017.

== EGraph and equality saturation

- *Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha.* "egg:
  Fast and extensible equality saturation." POPL 2021.
  Modern E-graph technique.

- *Detlefs-Nelson-Saxe (op. cit.).* Congruence closure
  algorithm.

== Quantifier instantiation

- *Moskal, Schulte.* "E-matching with free variables." TBA.
- *de Moura, Bjørner.* "Efficient E-Matching for SMT
  Solvers." CADE 2007.
- *Reynolds et al.* "Quantifier instantiation techniques
  for finite model finding in SMT." CADE 2013. Tier-3
  background.

== Abductive reasoning

- *Peirce, C. S.* *Collected Papers*, vols. 1-8. Harvard
  University Press 1931-1958. The philosophical
  foundations of abduction; specifically vol. 5 §§5.171-
  5.181.

- *Inoue.* "Linear resolution for consequence finding."
  *Artificial Intelligence* 1992.

- *Dillig, Dillig, Aiken.* "Automated error diagnosis
  using abductive inference." PLDI 2012. Practical
  abduction for verification.

- *Reynolds, Nötzli, Barrett, Tinelli.* "A decision
  procedure for separation logic in SMT." ATVA 2017.
  Related approach using a different theory.

== Higher-order logic + HKT

- *Gordon, Melham.* *Introduction to HOL: A theorem
  proving environment for higher order logic*. Cambridge
  UP 1993. The 12-rule kernel lineage.

- *Pierce.* *Types and Programming Languages*. MIT Press
  2002. Type-theoretic background; chapter 23 on system
  $F_omega$ touches HKT.

- *Wadler, Blott.* "How to make ad-hoc polymorphism less
  ad hoc." POPL 1989. Type classes.

== Proof certificates and proof checking

- *Stump, Oe, Reynolds, Hadarean, Tinelli.* "SMT proof
  checking using a logical framework." *Formal Methods in
  System Design* 2013. LFSC; related to adsmt-cert.

- *Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds,
  Barrett.* "SMTCoq: A plug-in for integrating SMT
  solvers into Coq." CAV 2017.

- *de Moura, Bjørner.* "Proofs and refutations, and Z3."
  IWIL 2008. Z3's proof format.

== ITP integration

- *Avigad, de Moura, Kong.* *Theorem Proving in Lean 4*.
  Online book at `https://lean-lang.org/theorem_proving_in_lean4/`.
  The Lean 4 reference.

- *Coq Development Team.* *The Coq Reference Manual*.
  Online; updated with each Coq/Rocq release.

- *Nipkow, Klein.* *Concrete Semantics with Isabelle/HOL*.
  Springer 2014. Isabelle textbook with operational-
  semantics worked examples.

== Verification — applied SMT

- *Cook, Khlaaf, Piterman.* "Reasoning About Infinite
  Procedures." STACS 2015.

- *Hawblitzel et al.* "IronFleet: Proving practical
  distributed systems correct." SOSP 2015. Industrial
  SMT-via-Dafny case study.

- *Leroy, Blazy.* "CompCert: Formal verification of a
  realistic compiler." *CACM* 2009. Different style
  (Coq-based, less SMT), but the verification-grade
  rigor is comparable.

== Synthesis

- *Solar-Lezama.* *Program Synthesis by Sketching*. PhD
  thesis, UC Berkeley 2008. Sketch + SMT for synthesis.

- *Polikarpova, Kuraj, Solar-Lezama.* "Program synthesis
  from polymorphic refinement types." PLDI 2016.

== adsmt-specific

- `~/AD1/README.md` — workspace overview.
- `~/AD1/memory/*.md` — project-internal context, cycle
  history, design decisions.
- `~/AD1/CONTRIBUTIONS_AUDIT.md` — RC2.7 audit record.
- `~/AD1/DOC_AUDIT.md` — RC2.4 + RC2.8 cargo-doc audits.
- `~/AD1/PUBLISH_AUDIT.md` — RC2.2 publish dry-run.
- `~/AD1/ABSORPTION_PLAN.md` — logicutils absorption.
- `~/adsmt-contrib/README.md` — out-of-tree backends.

== Related software

- *OxiZ* — `https://github.com/cool-japan/oxiz`. Pure-Rust
  Z3 reimplementation; adsmt's SAT/theory delegation
  target. The companion projects together demonstrate
  the "delegate to OxiZ for the deductive core, add
  adsmt-specific layers" architecture (`memory/oxiz_relationship.md`).

- *Z3* — `https://github.com/Z3Prover/z3`. The reference
  SMT solver. Worth installing as a comparison baseline.

- *CVC5* — `https://cvc5.github.io/`. The other major
  research SMT solver. Strong on quantifiers and
  datatypes.

- *Yices2* — `https://yices.csl.sri.com/`. SRI's solver;
  fast on QF_NRA and good Simplex.

- *Lean 4* — `https://lean-lang.org/`. The proof
  assistant adsmt's reference reflection targets.

- *Rocq* — `https://rocq-prover.org/`. The proof assistant
  formerly known as Coq.

- *Isabelle* — `https://isabelle.in.tum.de/`. The other
  major proof assistant.

- *logicutils* — original repo for the lu-kb dialect
  adsmt absorbed at v0.x. Continues for non-SMT use
  cases.

- *leo4* — user's dual-ITP (OxiLean + Lean 4) binding
  library; governs the `contributions/oxiz/bindings/`
  freeze policy.

== Closing note

This list is intentionally selective. The SMT literature
is enormous and growing fast; we've picked references
that have stood the test of a decade or more, plus a
handful of recent papers that have already become
canonical.

For the latest, follow CAV (Computer-Aided Verification),
TACAS (Tools and Algorithms for the Construction and
Analysis of Systems), and SAT (the SAT conference).
SMTCOMP — the annual SMT competition — runs every
summer and posts results that are a useful pulse on
the state of the art.
