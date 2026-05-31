= Literaturverzeichnis

Die Kapitel dieses Buches stützen sich auf einen langen Korpus
von Arbeiten zu automatisiertem Schließen, SMT, Typtheorie und
interaktivem Theorembeweisen. Die folgenden Hinweise sind die
unmittelbar tragenden Referenzen für die vorgestellten
Algorithmen und Designentscheidungen.

== SAT- und SMT-Grundlagen

- Marques-Silva, Lynce, Malik. *Conflict-driven clause
  learning SAT solvers* (Handbook of Satisfiability,
  2009). Die kanonische CDCL-Referenz; Kapitel 4 folgt den
  Behandlungen zu zwei überwachten Literalen und VSIDS
  von hier.

- Eén, Sörensson. *An extensible SAT-solver* (SAT
  2003). Das MiniSAT-Papier. Das CDCL von adsmt ist diesem
  Design treu.

- Biere, Heule, van Maaren, Walsh, eds. *Handbook of
  Satisfiability* (2nd ed., 2021). Umfassende Referenz;
  Kapitel 24 (Sebastiani) deckt SMT in der Tiefe ab.

- Nieuwenhuis, Oliveras, Tinelli. *Solving SAT and SAT
  modulo theories: from an abstract Davis-Putnam-Logemann-
  Loveland procedure to DPLL(T)* (JACM 2006). Das abstrakte
  DPLL(T)-Rahmenwerk, auf das sich Kapitel 5 stützt.

== Theorie-Solver

- Nelson, Oppen. *Simplification by cooperating decision
  procedures* (TOPLAS 1979). Die ursprüngliche
  Nelson-Oppen-Kombinationsmethode.

- Tinelli, Zarba. *Combining decision procedures for
  sorted theories* (JELIA 2004). polite-Kombination; die
  Verallgemeinerung, die Kapitel 5 für die Kombinations-Policy
  von adsmt verwendet.

- Bradley, Manna. *The Calculus of Computation* (Springer
  2007). Lehrbuchbehandlung der Entscheidungsverfahren für
  UF, LIA und LRA.

- Dutertre, de Moura. *A Fast Linear-Arithmetic Solver
  for DPLL(T)* (CAV 2006). Der Simplex-basierte LIA-/LRA-Solver,
  den Kapitel 6 skizziert.

- Niemetz, Preiner, Wolf, Biere. *CoSMT: Bit-Vector
  Solving with QF-BV* (CAV 2019). Moderne Bit-Blasting-Referenzen
  für Kapitel 6.

== E-Graph und Gleichheits-Reasoning

- Detlefs, Nelson, Saxe. *Simplify: a theorem prover for
  program checking* (JACM 2005). Praktischer Kongruenzhüllen-Algorithmus.

- Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha. *egg:
  Fast and extensible equality saturation* (POPL 2021).
  Moderne E-Graph-Technik; die Hash-Consing- und
  Kongruenzkaskade in Kapitel 7 folgen dieser Linie.

== Quantor-Instantiierung

- Detlefs, Nelson, Saxe (op. cit.). E-Matching-Grundlagen.

- de Moura, Bjørner. *Efficient E-Matching for SMT
  Solvers* (CADE 2007). Die E-Matching-Variante, die
  Kapitel 7 implementiert.

- Reynolds, Tinelli, Goel, Krstić, Deters, Barrett.
  *Quantifier instantiation techniques for finite model
  finding in SMT* (CADE 2013). Inspiration für die
  Tier-3-beschränkte Aufzählung.

== Abduktives Schließen

- Inoue. *Linear resolution for consequence finding*
  (Artificial Intelligence 1992). Das SLD-Ketten-Skelett
  von Kapitel 8.

- Eiter, Gottlob. *The complexity of logic-based
  abduction* (JACM 1995). Theoretische Schranken; informiert
  die Minimierungsstrategie.

- Dillig, Dillig, Aiken. *Automated error diagnosis using
  abductive inference* (PLDI 2012). Praktische
  Anwendung von Abduktion für Verifikation; das
  Nutzerkosten-Ranking aus Kapitel 8 stützt sich auf
  ähnliche Intuitionen.

== Logik höherer Ordnung und Typtheorie

- Gordon, Melham. *Introduction to HOL: A theorem proving
  environment for higher order logic* (Cambridge UP
  1993). Der 12-Regel-Kern aus Kapitel 2 folgt dieser
  Linie.

- Pierce. *Types and Programming Languages* (MIT Press
  2002). System F, abhängige Typen, Typklassen — der
  typtheoretische Hintergrund von Kapitel 3.

- Wadler, Blott. *How to make ad-hoc polymorphism less
  ad hoc* (POPL 1989). Einführung der Typklassen und
  Übersetzung mittels Dictionary-Passing.

== Zertifikatformate und Reflexion

- Stump, Oe, Reynolds, Hadarean, Tinelli. *SMT proof
  checking using a logical framework* (Formal Methods in
  System Design 2013). Das LFSC-Beweisformat; adsmt-cert
  ist ein kleinerer Verwandter.

- Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds, Barrett.
  *SMTCoq: A plug-in for integrating SMT solvers into Coq*
  (CAV 2017). Coq-seitige Reflexion; gespiegelt in
  `adsmt-emit-rocq`.

- Lochbihler. *Mechanising a type-safe model of multithreaded
  Java with a verified compiler* (Journal of Automated
  Reasoning 2018). Isabelle-seitige Reflexionsmuster;
  `adsmt-emit-isabelle` schöpft aus ähnlicher Maschinerie.

- Avigad, de Moura, Kong. *Theorem Proving in Lean 4*
  (online book, ongoing). Die Lean-4-Oberfläche, in die
  Kapitel 10 emittiert.

== Software-Engineering

- Klabnik, Nichols. *The Rust Programming Language*
  (Mozilla, ongoing). Referenz zur Rust-Sprache.

- Cargo Book. Workspace-, Semver- und
  Publikationskonventionen, auf die sich Kapitel 11
  stützt.

- Debian Policy Manual §5.6 (versioning) and §2.1
  (channels). Das Debian-artige Kanalmodell, das
  Kapitel 11 übernimmt.

== adsmt-interne Dokumente

- `~/AD1/CONTRIBUTIONS_AUDIT.md` — Audit-Datensatz RC2.7.
- `~/AD1/DOC_AUDIT.md` — cargo-doc-Audits RC2.4 + RC2.8.
- `~/AD1/PUBLISH_AUDIT.md` — Publish-Dry-Run RC2.2.
- `~/AD1/ABSORPTION_PLAN.md` — Historie der logicutils-Absorption.
- `~/AD1/memory/prover_emit_policy.md` — Lean/Rocq/Isabelle-Gleichschritt-Policy.
- `~/AD1/memory/oxiz_relationship.md` — Integrationsplan OxiZ Path A+B.
- `~/AD1/memory/lsp_roadmap.md` — LSP-Phasen-Freigaben.
