= Vorwort

Dieses Buch führt den Leser durch die Konstruktion eines
SMT-Solvers in genau der Form, die adsmt selbst annimmt:
ein Kern höherstufiger Logik mit höher-gekindeten Typen,
eine SAT-Schicht nach dem Prinzip Conflict-Driven
Clause-Learning, eine polite-Kombination von
Theorie-Solvern, eine Pipeline zur Quantor-Instanziierung,
eine Maschinerie für abduktives Schließen, ein
strukturiertes Zertifikatsformat sowie
Reflektionsbindungen in interaktive Theorembeweiser (ITPs).

Die Zielgruppe ist der Universitätsabsolvent, der
mindestens eines der Fächer Informatik, Mathematik,
Philosophie oder mathematische Logik abgeschlossen hat.
Vorausgesetzt wird Vertrautheit mit der Notation der
Prädikatenlogik erster Stufe, den Grundlagen von Rekursion
und Datenstrukturen sowie dem üblichen mathematischen Stil
des Aufstellens und Beweisens von Behauptungen. Es wird
*keine* Vorerfahrung im Schreiben eines Solvers, im
Beitragen zu einem Kern oder im Arbeiten innerhalb eines
interaktiven Theorembeweisers vorausgesetzt.

Das Buch folgt derselben Architektur, die adsmt selbst
besitzt, doch das Ziel besteht nicht darin, den Code von
adsmt zu reproduzieren. Stattdessen führt jedes Kapitel
ein Anliegen ein, skizziert die Datenstrukturen und
Algorithmen, die es sauber lösen, und diskutiert die
ingenieurtechnischen Entscheidungen, die adsmt tatsächlich
getroffen hat — einschließlich derjenigen, die beim ersten
Mal falsch getroffen und später korrigiert wurden. Man
betrachte die Kapitel als eine Reihe von Entwurfsvorträgen,
gestützt durch funktionierende Beispiele; das Ziel ist, dass
ein aufmerksamer Leser in der Lage ist, seinen eigenen
Solver vergleichbarer Gestalt zu bauen, ohne sich dabei auf
den Quelltext von adsmt als Krücke zu stützen.

== Wie man dieses Buch liest

Kapitel 1 motiviert das SMT-Lösen und legt die
Entwurfsphilosophie dar, die adsmt von seinen Geschwistern
(insbesondere Z3, CVC5 und Bitwuzla) unterscheidet. Die
Kapitel 2 und 3 bauen den logischen Kern auf: einen kleinen
Kern von Inferenzregeln sowie das darauf aufsetzende
Typsystem. Kapitel 4 entwickelt die SAT-Schicht in
ausreichender Tiefe, um einen brauchbaren CDCL-Solver zu
schreiben, einschließlich Two-Watched-Literals, VSIDS,
Luby-getakteter Restarts und Retention gelernter Klauseln
über LBD. Kapitel 5 führt die Theorie-Kombination ein —
jene Maschinerie, die es mehreren Theorie-Solvern erlaubt,
über gemeinsame Sorten zu kooperieren. Kapitel 6 geht
einzelne Theorieimplementierungen durch (UF, lineare
Arithmetik, Bitvektoren, Arrays, Datentypen). Kapitel 7
bringt Quantoren über E-Matching und tier-basierte
Eskalation ins Spiel. Kapitel 8 führt die abduktive
Maschinerie ein — die Schicht, die adsmt unverwechselbar
macht. Kapitel 9 erläutert das Zertifikatsformat.
Kapitel 10 behandelt die ITP-Reflektion mit Schwerpunkt auf
Lean 4. Kapitel 11 erörtert das Engineering: Tests,
Benchmarking, Surface-Freezes, Semver und dergleichen. Drei
Anhänge geben Referenzmaterial zur SMT-LIB-Oberfläche, zur
lu-kb-Oberfläche und zum Zertifikats-AST.

== Notationskonventionen

Metavariablen werden in mathematischem Kursiv ($x$, $y$,
$phi$) geschrieben, konkreter Code in nichtproportionaler
Schrift (`Term::Var`, `adsmt-core`). Typentheoretische
Urteile verwenden die übliche Sequenznotation: $Gamma tack
t : tau$ bedeutet „$t$ hat Typ $tau$ im Kontext $Gamma$".
Wenn eine Definition oder ein Theorem mit einem Quadrat
($qed$) endet, wird der umgebende Fließtext fortgesetzt.

Es wird von einer *propositionalen Formel* gesprochen,
wenn variablenfreie Boolesche Ausdrücke gemeint sind, von
einer *Formel erster Stufe*, wenn Quantoren über
Individuen vorkommen, und von einer *höherstufigen
Formel*, wenn Quantoren auch über Funktionen oder
Prädikate reichen dürfen. SMT selbst lebt auf der
propositionalen Ebene, erweitert um Theorieatome; die
Behandlung von Quantoren wird darauf aufgesetzt.

Die Codeauszüge verwenden Rust-Syntax, da adsmt darin
geschrieben ist, aber die Algorithmen lassen sich im
Wesentlichen unverändert nach OCaml, Standard ML oder
Scala übertragen. Wo ein Rust-Idiom tatsächlich tragend
ist (Lifetime-Annotationen, Trait-Objekte), erklärt der
umgebende Text das Warum; wo es bloß beiläufige
Syntax­geräusche sind, werden sie unterdrückt.

== Eine Bemerkung zu nicht behandeltem Material

Dieses Buch behandelt das adsmt-Projekt im eigentlichen
Sinne: den im Baum befindlichen Workspace samt absorbiertem
`lu-*`-Fundament. Die Dokumentation zu den Rocq- und
Isabelle-Backends gehört zu einem separaten Projekt
(`adsmt-contrib`) und wird andernorts verfasst. Auch das
OxiZ-SAT-Backend, von dem adsmt abhängt, ist ein eigenes
Projekt mit eigener Dokumentation; es wird nur in Kapitel 4
berührt, um die Schnittstelle zu erläutern, die adsmt
konsumiert, nicht seine Interna.
