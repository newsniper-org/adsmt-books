= Aussagenlogik und SAT

== Atome, Junktoren, Formeln

In der Aussagenlogik geht es um *Atome* — boolesche
Variablen, die wahr oder falsch sein können —,
kombiniert mit den üblichen Junktoren: und ($and$),
oder ($or$), nicht ($not$), impliziert ($=>$), genau
dann wenn ($<=>$).

Eine *Formel* wird aus Atomen und Junktoren aufgebaut.
Eine *Wahrheitszuweisung* (oder Modell) ordnet jedem
Atom wahr oder falsch zu. Eine Formel ist *erfüllbar*,
wenn eine Zuweisung sie wahr macht.

Das klassische Beispiel:

```text
(p ∨ q) ∧ (¬p ∨ r) ∧ (¬q ∨ ¬r)
```

Diese Formel hat acht mögliche Zuweisungen für
$(p, q, r)$. Eine erfüllende ist $(T, F, T)$: $p$ ist
wahr (also gilt die erste Klausel), $r$ ist wahr (also
gilt die zweite Klausel über $not p or r$), $q$ ist
falsch (also gilt die dritte Klausel über
$not q or not r$).

== CNF — konjunktive Normalform

Eine Formel ist in *CNF* (konjunktiver Normalform), wenn
sie ein `and` von `or`s von Literalen (Atomen oder
negierten Atomen) ist. Jede aussagenlogische Formel
besitzt eine äquivalente CNF, und das Standard-SAT-
Eingabeformat (DIMACS) verlangt sie.

```text
( p ∨  q     ) ∧
(¬p ∨  r     ) ∧
(¬q ∨ ¬r     )
```

Jede `or`-Klausel ist einfach eine *Klausel*. Die CNF-
Form ist eine Konjunktion von Klauseln, abgekürzt als
`{c_1, c_2, ..., c_n}`.

== Warum CNF?

Mit CNF lässt sich aufgrund einer Beobachtung leicht
arbeiten: *damit eine CNF-Formel wahr ist, muss jede
Klausel wahr sein*. Die Aufgabe eines SAT-Solvers
zerfällt also in „finde eine Zuweisung, die jede
Klausel erfüllt". Wird eine Klausel auf falsch
gezwungen, ist der Kandidat erledigt.

Daraus ergeben sich konkrete Prune-Regeln für den
SAT-Solver:

- *Unit Propagation.* Wenn eine Klausel ein
  unzugewiesenes Literal hat und alle anderen falsch
  sind, muss dieses Literal wahr sein.
- *Konfliktgetriebenes Backtracking.* Wenn alle Literale
  einer Klausel falsch sind, lässt sich die Zuweisung
  nicht erweitern; zurücksetzen.

Diese beiden Regeln allein bilden den Antrieb von *DPLL*
(Davis-Putnam-Logemann-Loveland), dem geistigen
Vorfahren jedes modernen SAT-Solvers.

== CDCL — die moderne SAT-Engine

Moderne SAT-Solver backtracken nicht nur bei einem
Konflikt; sie *lernen* aus jedem Konflikt. Das Muster
lautet:

1. *Auswählen.* Eine unzugewiesene Variable auswählen
   (mittels einer Heuristik) und probeweise zuweisen.
2. *Propagieren.* Unit Propagation anwenden, um
   erzwungene Zuweisungen abzuleiten.
3. *Konflikt.* Wenn die Propagation auf eine Klausel
   stößt, in der alle Literale falsch sind, wird die
   Kette der Ursachen des Konflikts bis zu einem
   *Schnittpunkt* zurückverfolgt; eine *gelernte Klausel*
   wird emittiert, die die Kette zusammenfasst.
4. *Backtracken.* Zuweisungen werden bis zu einer Ebene
   rückgängig gemacht, auf der die gelernte Klausel
   nützliche Propagationen auslösen kann.
5. *Wiederholen.*

Dies ist *CDCL*: Conflict-Driven Clause Learning. Fast
jeder State-of-the-Art-SAT-Solver ist eine CDCL-Variante.

Der Trick ist, *was zu lernen ist*. Der Standardschnitt
ist der *1-UIP* (first unique implication point): man
läuft den Implikationsgraphen des Konflikts vom
Widerspruch rückwärts, bis man ein einzelnes Literal
trifft, dessen Umkehrung den Konflikt verhindert hätte.
Die gelernte Klausel ist die Negation dieses Pfades.

== Heuristiken

Der Auswahlschritt von CDCL nutzt *VSIDS* (Variable State
Independent Decaying Sum): jede Variable hat einen Score,
der ansteigt, wenn sie in einer gelernten Klausel
vorkommt, und mit der Zeit abklingt. Variablen mit hohem
Score werden zuerst ausgewählt; die Heuristik fokussiert
die Suche auf „heiße" Variablen.

Der Restart-Schritt von CDCL nutzt *Luby-Folgen* (oder
geometrische Varianten): periodisch wird der aktuelle
Entscheidungs-Stack verworfen und neu begonnen, wobei
die gelernten Klauseln erhalten bleiben. Restarts helfen,
pathologische Suchregionen zu verlassen.

Diese beiden Heuristiken, kombiniert mit der
Zwei-Watched-Literal-Propagation und der LBD-basierten
Bereinigung gelernter Klauseln, bilden den Standard-
Werkzeugkasten von CDCL. Die SAT-Schicht von adsmt
implementiert sie alle.

== Von SAT zu SMT — die Brücke

Das *boolesche Skelett* einer SMT-Formel ist eine CNF:
man ersetzt jedes Theorie-Atom (etwa `(< x 3)` oder
`(= (f a) b)`) durch eine frische boolesche Variable
und behandelt die Formel als aussagenlogisch. Der
SAT-Solver versucht, das Skelett zu erfüllen; für jeden
Kandidaten prüft der *Theorie-Solver*, ob das
Literalmuster mit der Theorie konsistent ist.

```text
Theory atoms:    A := (< x 3)
                 B := (> x 5)
                 C := (= y 0)

Boolean skeleton: (A ∨ C) ∧ (B ∨ C) ∧ (¬A ∨ ¬B)

SAT tries:       A=T, B=T, C=T
                 → theory check: (< x 3) ∧ (> x 5) is unsat!
                 → SAT learns the clause (¬A ∨ ¬B)
                 (already there, so this trial dies fast)
SAT tries:       A=T, B=F, C=T
                 → theory check: (< x 3) ∧ ¬(> x 5) ∧ (= y 0)
                 → satisfiable with x = 0, y = 0
```

Die Schleife heißt *DPLL(T)*: SAT schlägt boolesche
Zuweisungen vor, die Theorie prüft sie. Die Architektur
wird in Kapitel 3 vorgestellt.

== Entscheidbarkeit und Komplexität

SAT ist *NP-vollständig* — es ist kein
polynomialzeitiger Algorithmus bekannt, der jede
SAT-Instanz entscheidet. In der Praxis bewältigen
moderne Solver industrielle Instanzen mit Millionen von
Variablen in Sekunden; im schlechtesten Fall benötigen
sie exponentielle Zeit. Die Diskrepanz zwischen
Worst-Case- und praktischer Leistung ist eines der
großen empirischen Phänomene der Informatik.

SMT erbt die NP-Härte von SAT (mindestens) und fügt
darüber hinaus die Komplexität der Theorieschicht hinzu.
Für manche Theorien (LIA, BV bei fester Breite) bleibt
die Kombination in NP; für andere (reell abgeschlossene
Körper, vollständig quantifiziertes LIA) eskaliert sie
weiter. Die unentscheidbaren Fragmente (allgemeine
Logik erster Stufe mit Arithmetik) sind der Grund,
weshalb `unknown` ein echtes Urteil ist.

Im Folgenden wendet man sich der Theorieseite zu.
