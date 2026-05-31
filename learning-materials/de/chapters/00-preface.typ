= Vorwort

Dieses Buch ist der Begleitband zu *Konzepten und Praxis*
des adsmt-Projekts. Der zugehörige Band, *Implement from
Scratch*, führt durch den *Aufbau* eines SMT-Solvers in
der Form von adsmt; der vorliegende Band führt durch
dessen *Nutzung* — und durch das konzeptuelle Gerüst,
das man braucht, um ihn gut zu nutzen.

== An wen richtet sich dieses Buch?

Vorausgesetzt wird ein abgeschlossenes Bachelorstudium
(oder eine vergleichbare Vertrautheit) in mindestens
einem der folgenden Fachgebiete:

- *Informatik / Softwaretechnik.* Man kann Code lesen,
  versteht Datenstrukturen und grundlegende Komplexität.
  SAT und SMT sind vermutlich bekannte Begriffe, auch
  wenn man noch nicht ernsthaft mit ihnen gearbeitet hat.
- *Mathematik.* Man ist mit formalen Beweisen,
  Mengenlehre, grundlegender Logik und (idealerweise)
  einer flüchtigen Bekanntschaft mit der Modelltheorie
  vertraut.
- *Philosophie* — speziell *Logik und Philosophie der
  Mathematik*. Man kennt den Unterschied zwischen Syntax
  und Semantik, zwischen Beweistheorie und Modelltheorie
  und idealerweise auch etwas über modale oder
  nicht-klassische Logiken.
- *Mathematische Logik.* Man hat die Henkin-Vollständigkeit,
  Löwenheim-Skolem und Kompaktheit gesehen; man kann
  Regeln des Sequenzenkalküls auf einen Blick lesen.

Jede *einzelne* dieser Voraussetzungen genügt. Das Buch
verwebt Konzepte durch alle vier Perspektiven, wo immer
sie erhellend sind. Eine Leserin aus der Informatik
erhält die Algorithmen und den Code; eine Leserin aus
der Mathematik erhält die Modelltheorie und Semantik;
eine Leserin aus der Philosophie erhält die
Unterscheidungen zwischen deduktiver, induktiver und
abduktiver Inferenz; eine Leserin aus der mathematischen
Logik erhält die beweistheoretische Darstellung, die
alles verbindet.

== Was dieses Buch behandelt

Elf Kapitel und vier Anhänge:

1. *Was ist SMT?* — das Problem, das Urteil, der
   Arbeitsablauf.
2. *Aussagenlogik und SAT* — das Fundament.
3. *Logik erster Stufe und Theorien* — die SMT-Seite der
   Grenze.
4. *Gleichheit und uninterpretierte Funktionen.*
5. *Arithmetik* — LIA, LRA, die Grenzfälle.
6. *Bitvektoren, Arrays und Datentypen.*
7. *Quantoren* — was sie schwierig macht.
8. *Abduktion* — das Alleinstellungsmerkmal von adsmt.
9. *Zertifikate und Vertrauen* — warum und wie ein Solver
   nachprüfbare Beweise erzeugt.
10. *ITP-Integration* — SMT-Nutzung innerhalb von Lean 4
    (und Rocq, Isabelle).
11. *Engineering* — eine kurze Rundtour durch Ausführung,
    Konfiguration und Erweiterung des Werkzeugs.

Anhänge: CLI-Cheatsheet, LSP-Cheatsheet, Übungen,
weiterführende Literatur.

== Was dieses Buch *nicht* behandelt

Dies ist keine Forschungsmonographie zu SMT. Der Stand
der Technik wird soweit skizziert, dass die
Entscheidungen von adsmt motiviert werden, ohne
Alternativen vertieft zu betrachten — dafür siehe die
Referenzen im Literaturverzeichnis.

Dies ist auch kein Buch zum Schreiben eines SMT-Solvers.
Der Begleitband, *Implement from Scratch*, leistet das
ausdrücklich. Wo dieses Buch beschreibt, *was* eine
Schicht tut, beschreibt jenes Buch, *wie* die Schicht
aufgebaut ist.

Schließlich dokumentiert dieses Buch nicht
`adsmt-contrib` — die out-of-tree Rocq- und
Isabelle-Emit-Backends. Diese haben ihren eigenen
Dokumentationsstrang.

== Wie man dieses Buch liest

Die Kapitel sind *grob* sequentiell aufgebaut. Eine
Leserin, die neu in SMT ist, sollte 1-3 der Reihe nach
lesen, dann 4-6 (die Theorie-Rundtour), dann 7-10 (die
fortgeschrittene Schicht + Abduktion + Vertrauen). Eine
Leserin mit Vorkenntnissen in SMT kann 1-3 überfliegen
und bei 4 oder 5 einsteigen.

Codebeispiele liegen in *Rust* (entsprechend der
Implementierungssprache von adsmt) und *SMT-LIB v2*
(das Standardeingabeformat) vor. Man braucht keine
flüssigen Rust-Kenntnisse, um den Code zu lesen — die
Beispiele sind kurz und werden erläutert. SMT-LIB v2 ist
im Oberflächen-Anhang des Begleitbandes dokumentiert.

== Notationskonventionen

- *Kursiv* bei der ersten Einführung von Begriffen.
- `monospace` für Code, Dateipfade und Oberflächensyntax.
- Die mathematische Notation verwendet die üblichen
  logischen Symbole.
- Nummerierte Kapitelverweise wie "(Kapitel 3)" verweisen
  innerhalb dieses Buches; "(Begleitband Kap. 3)" verweist
  auf den Begleitband *Implement from Scratch*.

== Danksagungen

adsmt baut auf jahrzehntelanger SMT-Forschung auf — siehe
das Literaturverzeichnis für die unmittelbar tragenden
Verweise. Das OxiZ-Projekt, auf dem die SAT- und
klassischen Theorieschichten von adsmt aufsetzen,
verdient ausdrückliche Erwähnung; ebenso logicutils,
dessen lu-kb-Dialekt adsmt in v0.x absorbiert hat.

Beginnen wir.
