= Weiterführende Literatur

Dieser Anhang ist eine kuratierte Liste von Referenzen, die
über das hinausgehen, wofür dieses Buch Platz hatte. Jeder
Eintrag enthält eine einzeilige Annotation: was Sie dort
finden und warum es Ihre Zeit wert ist.

== SMT — Grundlagen

- *The SMT-LIB Initiative.* `https://smtlib.cs.uiowa.edu/`
  Die Startseite des Standards mit der aktuellen
  Sprachspezifikation, Theoriedefinitionen und der
  Benchmark-Bibliothek. Unverzichtbare Referenz für jeden,
  der SMT-LIB schreibt.

- *Barrett, Sebastiani, Seshia, Tinelli.* "Satisfiability
  Modulo Theories." Im *Handbook of Satisfiability* (2.
  Aufl., 2021). Kapitel 33. Die kanonische SMT-Übersicht.

- *Bradley, Manna.* *The Calculus of Computation*. Springer
  2007. Lehrbuchbehandlung der Entscheidungsverfahren mit
  durchgearbeiteten Beispielen; gute erste Einführung für
  jemanden mit CS-Hintergrund.

- *Kroening, Strichman.* *Decision Procedures: An
  Algorithmic Point of View*. Springer 2008. Begleitlehrbuch
  mit einer anderen Gliederung und zusätzlichen industriellen
  Fallstudien.

== SAT — Grundlagen

- *Biere, Heule, van Maaren, Walsh, eds.* *Handbook of
  Satisfiability*. 2. Aufl., IOS Press 2021. Die Referenz.

- *Marques-Silva, Lynce, Malik.* "Conflict-Driven Clause
  Learning SAT Solvers." Kapitel 4 des Handbook.

- *Eén, Sörensson.* "An Extensible SAT-Solver." SAT 2003.
  Das MiniSAT-Papier; der Entwurf, auf dem alle
  nachfolgenden CDCL-Solver aufbauen.

== Theorie-Solver

*EUF:*
- *Detlefs, Nelson, Saxe.* "Simplify: A theorem prover for
  program checking." *JACM* 52(3), 2005. Praktischer
  Kongruenzschluss.
- *Nieuwenhuis, Oliveras.* "Fast congruence closure and
  extensions." *Information and Computation* 2007.

*LIA/LRA:*
- *Dutertre, de Moura.* "A Fast Linear-Arithmetic Solver
  for DPLL(T)." CAV 2006.
- *Cooper.* "Theorem proving in arithmetic without
  multiplication." *Machine Intelligence* 7, 1972. Die
  Presburger-Referenz.

*BV:*
- *Brummayer, Biere.* "Effective Bit-Width and Under-
  Approximation." EUROCAST 2009.
- *Niemetz, Preiner, Biere.* "Boolector at the SMT
  Competition 2018." Moderner BV-Solver-Entwurf.

*Arrays:*
- *Stump, Barrett, Dill, Levitt.* "A decision procedure for
  an extensional theory of arrays." LICS 2001.

*Datentypen:*
- *Reynolds, Blanchette.* "A Decision Procedure for
  (Co)datatypes in SMT Solvers." *Journal of Automated
  Reasoning* 2017.

== EGraph und Gleichheitssättigung

- *Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha.* "egg:
  Fast and extensible equality saturation." POPL 2021.
  Moderne E-Graph-Technik.

- *Detlefs-Nelson-Saxe (a.a.O.).*
  Kongruenzschlussalgorithmus.

== Quantoreninstanzierung

- *Moskal, Schulte.* "E-matching with free variables." TBA.
- *de Moura, Bjørner.* "Efficient E-Matching for SMT
  Solvers." CADE 2007.
- *Reynolds et al.* "Quantifier instantiation techniques
  for finite model finding in SMT." CADE 2013. Tier-3-
  Hintergrund.

== Abduktives Schließen

- *Peirce, C. S.* *Collected Papers*, Bde. 1-8. Harvard
  University Press 1931-1958. Die philosophischen Grundlagen
  der Abduktion; insbesondere Bd. 5 §§5.171-5.181.

- *Inoue.* "Linear resolution for consequence finding."
  *Artificial Intelligence* 1992.

- *Dillig, Dillig, Aiken.* "Automated error diagnosis using
  abductive inference." PLDI 2012. Praktische Abduktion
  für die Verifikation.

- *Reynolds, Nötzli, Barrett, Tinelli.* "A decision
  procedure for separation logic in SMT." ATVA 2017.
  Verwandter Ansatz mit einer anderen Theorie.

== Logik höherer Stufe + HKT

- *Gordon, Melham.* *Introduction to HOL: A theorem proving
  environment for higher order logic*. Cambridge UP 1993.
  Die 12-Regel-Kernlinie.

- *Pierce.* *Types and Programming Languages*. MIT Press
  2002. Typentheoretischer Hintergrund; Kapitel 23 zu System
  $F_omega$ berührt HKT.

- *Wadler, Blott.* "How to make ad-hoc polymorphism less ad
  hoc." POPL 1989. Typklassen.

== Beweiszertifikate und Beweisprüfung

- *Stump, Oe, Reynolds, Hadarean, Tinelli.* "SMT proof
  checking using a logical framework." *Formal Methods in
  System Design* 2013. LFSC; verwandt mit adsmt-cert.

- *Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds,
  Barrett.* "SMTCoq: A plug-in for integrating SMT solvers
  into Coq." CAV 2017.

- *de Moura, Bjørner.* "Proofs and refutations, and Z3."
  IWIL 2008. Das Beweisformat von Z3.

== ITP-Integration

- *Avigad, de Moura, Kong.* *Theorem Proving in Lean 4*.
  Online-Buch unter `https://lean-lang.org/theorem_proving_in_lean4/`.
  Die Lean-4-Referenz.

- *Coq Development Team.* *The Coq Reference Manual*.
  Online; mit jeder Coq-/Rocq-Veröffentlichung aktualisiert.

- *Nipkow, Klein.* *Concrete Semantics with Isabelle/HOL*.
  Springer 2014. Isabelle-Lehrbuch mit durchgearbeiteten
  operationalsemantischen Beispielen.

== Verifikation — angewandtes SMT

- *Cook, Khlaaf, Piterman.* "Reasoning About Infinite
  Procedures." STACS 2015.

- *Hawblitzel et al.* "IronFleet: Proving practical
  distributed systems correct." SOSP 2015. Industrielle
  SMT-via-Dafny-Fallstudie.

- *Leroy, Blazy.* "CompCert: Formal verification of a
  realistic compiler." *CACM* 2009. Anderer Stil
  (Coq-basiert, weniger SMT), aber die
  Verifikations-Strenge ist vergleichbar.

== Synthese

- *Solar-Lezama.* *Program Synthesis by Sketching*.
  PhD-Arbeit, UC Berkeley 2008. Sketch + SMT für Synthese.

- *Polikarpova, Kuraj, Solar-Lezama.* "Program synthesis
  from polymorphic refinement types." PLDI 2016.

== adsmt-spezifisch

- `~/AD1/README.md` — Workspace-Überblick.
- `~/AD1/memory/*.md` — projektinterner Kontext,
  Zyklushistorie, Entwurfsentscheidungen.
- `~/AD1/CONTRIBUTIONS_AUDIT.md` — RC2.7-Audit-Aufzeichnung.
- `~/AD1/DOC_AUDIT.md` — RC2.4- + RC2.8-cargo-doc-Audits.
- `~/AD1/PUBLISH_AUDIT.md` — RC2.2-Publish-Probelauf.
- `~/AD1/ABSORPTION_PLAN.md` — logicutils-Absorption.
- `~/adsmt-contrib/README.md` — Out-of-Tree-Backends.

== Verwandte Software

- *OxiZ* — `https://github.com/cool-japan/oxiz`. Pure-Rust-
  Z3-Reimplementierung; das SAT-/Theorie-Delegationsziel
  von adsmt. Die Begleitprojekte demonstrieren zusammen die
  Architektur "an OxiZ für den deduktiven Kern delegieren,
  adsmt-spezifische Schichten hinzufügen"
  (`memory/oxiz_relationship.md`).

- *Z3* — `https://github.com/Z3Prover/z3`. Der
  Referenz-SMT-Solver. Es lohnt sich, ihn als
  Vergleichsbasis zu installieren.

- *CVC5* — `https://cvc5.github.io/`. Der andere große
  Forschungs-SMT-Solver. Stark bei Quantoren und
  Datentypen.

- *Yices2* — `https://yices.csl.sri.com/`. Der Solver von
  SRI; schnell bei QF_NRA und gutes Simplex.

- *Lean 4* — `https://lean-lang.org/`. Der Beweisassistent,
  auf den die Referenzreflexion von adsmt zielt.

- *Rocq* — `https://rocq-prover.org/`. Der Beweisassistent,
  vormals bekannt als Coq.

- *Isabelle* — `https://isabelle.in.tum.de/`. Der andere
  große Beweisassistent.

- *logicutils* — ursprüngliches Repository für den
  lu-kb-Dialekt, den adsmt bei v0.x absorbiert hat. Wird
  für Nicht-SMT-Anwendungsfälle fortgeführt.

- *leo4* — Dual-ITP-Bindungs-Bibliothek (OxiLean + Lean 4)
  des Benutzers; regelt die Freeze-Richtlinie von
  `contributions/oxiz/bindings/`.

== Schlussbemerkung

Diese Liste ist absichtlich selektiv. Die SMT-Literatur ist
enorm und wächst rapide; wir haben Referenzen ausgewählt,
die sich über ein Jahrzehnt oder mehr bewährt haben, plus
eine Handvoll neuerer Papiere, die bereits kanonisch
geworden sind.

Für den neuesten Stand verfolgen Sie CAV (Computer-Aided
Verification), TACAS (Tools and Algorithms for the
Construction and Analysis of Systems) und SAT (die
SAT-Konferenz). SMTCOMP — der jährliche SMT-Wettbewerb —
läuft jeden Sommer und veröffentlicht Ergebnisse, die ein
nützlicher Puls des Standes der Technik sind.
