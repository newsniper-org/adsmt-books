= Was ist SMT?

== Das Problem in einem Satz

SMT — *Satisfiability Modulo Theories — Erfüllbarkeit
modulo Theorien* — fragt: Ist eine logische Formel,
die Funktionen und Prädikate verwenden darf, welche
über üblichen mathematischen Strukturen (den ganzen
Zahlen, den reellen Zahlen, Bitvektoren, Arrays, …)
*interpretiert* sind, erfüllbar?

Eine *erfüllbare* Formel besitzt eine Zuweisung von
Werten an ihre Variablen — sowie eine konsistente
Interpretation ihrer Funktionssymbole —, die die Formel
wahr macht. Eine *unerfüllbare* Formel besitzt keine
solche Zuweisung.

== Einige Beispiele

```text
;; Satisfiable: a = 3 works.
(declare-const a Int)
(assert (> a 2))
(assert (< a 10))

;; Unsatisfiable: no real number is both > 5 and < 4.
(declare-const r Real)
(assert (> r 5.0))
(assert (< r 4.0))

;; Satisfiable: pick x = 0, y = 0, A any.
(declare-const x Int)
(declare-const y Int)
(declare-const A (Array Int Int))
(assert (= (select (store A x 1) x) 1))
(assert (= y 0))
```

Das erste Beispiel verwendet lineare ganzzahlige
Arithmetik (LIA). Das zweite verwendet lineare reelle
Arithmetik (LRA) — und ist unerfüllbar, weil keine
reelle Zahl in $(5, 4)$ liegt, was leer ist. Das dritte
verwendet eine Array-Theorie: das Speichern von 1 am
Index `x` und anschließende Lesen an `x` liefert 1, was
trivialerweise wahr ist, unabhängig von `A` und `y`.

== Warum nicht einfach SAT?

Klassische *aussagenlogische Erfüllbarkeit* (SAT)
behandelt boolesche Formeln — Variablen, die nur wahr
oder falsch sein können. Moderne SAT-Solver sind
erstaunlich schnell: industrielle SAT-Instanzen mit
Millionen von Variablen laufen routinemäßig in Sekunden.

Doch viele praktische Fragen passen nicht unmittelbar
zu SAT. „Gibt es eine ganze Zahl $x$ mit $3 x + 2 = 14$?"
ist keine boolesche Frage; sie ist eine arithmetische.
Man könnte sie nach SAT *kodieren* (das Bit-Blasting von
$x$ in 32 Bit, Addition als binäre Addierer kodieren,
Gleichheit als bitweises xor + nor), und die resultierende
SAT-Formel beantwortet tatsächlich die ursprüngliche
Frage. Doch die Kodierung ist enorm und verliert die
*Struktur* — der SAT-Solver leitet arithmetische Fakten
neu her, anstatt ein schnelles Entscheidungsverfahren
für lineare Arithmetik zu verwenden.

SMT ist die Ehe. Das aussagenlogische Skelett geht an
einen SAT-Solver; die Theorie-Atome (Arithmetik,
Bitvektor, Array, …) gehen an dedizierte Theorie-Solver;
die Schichten kooperieren.

== Urteile

Ein SMT-Solver beantwortet eine `(check-sat)`-Anfrage mit
einem der folgenden Urteile:

- *sat* — die Formel besitzt ein Modell; mit
  `(get-model)` lässt es sich abrufen.
- *unsat* — es existiert kein Modell; mit
  `(get-unsat-core)` erhält man eine minimale,
  widersprüchliche Teilmenge der Behauptungen.
- *unknown* — der Solver konnte nicht entscheiden. Die
  Gründe reichen vom Erschöpfen des Budgets für
  Quantorinstanziierung bis hin zum Erreichen eines
  unentscheidbaren Fragments.
- *abductive* (adsmt-spezifisch) — der Solver konnte das
  Ziel nicht abschließen, hat aber eine geordnete Liste
  von Hypothesen erzeugt, die es abschließen *würden*.
  Mit `(get-abductive-candidates)` erhält man die Liste.

Die ersten drei sind über SMT-Solver hinweg
standardisiert; das vierte ist das Alleinstellungsmerkmal
von adsmt, dem wir Kapitel 8 widmen.

== Das Gesamtbild

Ein typischer adsmt-Arbeitsablauf:

```text
User writes SMT-LIB script
       ↓ (parse)
Engine asserts formulas
       ↓ (check-sat)
Verdict: sat / unsat / abductive / unknown
       ↓ (extract)
Model, core, candidates, certificate
       ↓ (downstream)
ITP integration, code generation, decision support, ...
```

Das Bemerkenswerteste an diesem Arbeitsablauf ist, dass
er sich über ein enormes Spektrum von Anwendungsfeldern
erstreckt — Programmverifikation, Planung, Scheduling,
Typinferenz, Synthese. Dieselbe Form eines SMT-LIB-
Skripts, dieselbe Urteilssemantik, dramatisch
unterschiedliche Anwendungen.

== Warum „modulo Theorien"?

Die Wendung lehnt sich an das ringtheoretische „modulo"
an — Arbeiten über einer Quotientenstruktur. Die Atome
einer SMT-Formel werden *modulo* den Axiomen der Theorie
interpretiert: ganze Zahlen gehorchen der Arithmetik,
Arrays gehorchen dem Read-over-Write, Bitvektoren
gehorchen ihrer Algebra fester Breite. Die SAT-Schicht
weiß nicht, was `+` bedeutet; sie behandelt `(+ x 3)`
und `(+ x 3)` einfach als *dieselbe boolesche Variable*
(wenn sie in derselben Formel auftreten), und die
Theorieschicht füllt den semantischen Gehalt aus.

Diese Faktorisierung — boolesche Struktur auf der einen,
Theoriesemantik auf der anderen Seite — ist es, was SMT
skalieren lässt. Jede Schicht ist auf ein Problem
abgestimmt, das sie gut lösen kann; die Kombination
bewältigt Formeln, die keine der beiden für sich allein
schaffen würde.

== Ein typischer Alltag eines SMT-Solvers

Viele Leser kommen über eine von drei Türen zu SMT:

1. *Verifikation.* „Beweise, dass diese C-Funktion
   niemals einen Null-Pointer dereferenziert." Auf
   Verifikationsbedingungen kompilieren; SMT befragen.
2. *Programmsynthese.* „Finde eine Funktion, sodass …"
   — die Einschränkung formulieren, SMT um einen Zeugen
   bitten.
3. *Interaktives Theorembeweisen.* „Ich bin auf halbem
   Wege durch einen Lean-Beweis, und dieses Unterziel
   ist verzwickt. Kann SMT das nicht einfach abschließen?"

adsmt ist für den dritten Fall optimiert. Der Kern aus
Kapitel 9 (Zertifikatsformat), die Lean-4-Reflexion aus
Kapitel 10 und die abduktive Oberfläche aus Kapitel 8
bedienen alle den Arbeitsablauf „Ich bin in einem ITP,
SMT bitte erledige dies für mich — und wenn nicht, sag
mir warum."

Die folgenden Kapitel tauchen in die Schichten ein, die
dies ermöglichen.
