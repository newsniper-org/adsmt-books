= Logik erster Stufe und Theorien

== Jenseits der Aussagenlogik

Die Atome der Aussagenlogik haben keine innere Struktur.
„$p$ ist wahr" ist alles, was sich über $p$ sagen lässt.
Die *Logik erster Stufe* erweitert dies um:

- *Variablen*, die über einem Bereich laufen.
- *Funktionssymbole* — `+`, `f`, `succ` — die Terme
  nehmen und Terme zurückgeben.
- *Prädikatsymbole* — `<`, `=`, `prime?` — die Terme
  nehmen und boolesche Werte zurückgeben.
- *Quantoren* — $forall$, $exists$ — die Variablen
  binden.

Statt nur $p$ lässt sich nun $forall x. (P(x) =>
Q(f(x)))$ schreiben. Die Atome sind jetzt
*Anwendungen* — $P(x)$, $Q(f(x))$ — mit Struktur, die
der Solver ausnutzen kann.

== Syntax vs. Semantik

Eine *Signatur* benennt die Funktions- und
Prädikatsymbole einer Logik. Eine *Theorie* ist eine
Signatur plus eine Menge von Axiomen, die das Verhalten
dieser Symbole einschränken. Ein *Modell* der Theorie
ist eine Interpretation — ein Bereich plus konkrete
Funktionen und Relationen —, die die Axiome erfüllt.

Zum Beispiel hat die *Theorie der ganzzahligen
Arithmetik* die Signatur $\{+, -, *, <, =, 0, 1, …\}$
und Axiome, die besagen, dass „dies die übliche
ganzzahlige Arithmetik ist". Ihr Modell ist $ZZ$ mit
den üblichen Operationen.

Eine Formel $phi$ über einer Theorie $T$ ist
*T-erfüllbar*, wenn ein Modell von $T$ $phi$ wahr
macht. SMT-Solver entscheiden T-Erfüllbarkeit für
verschiedene $T$.

== Theorien in SMT-LIB

Der SMT-LIB-Standard definiert ein festes Spektrum von
Theorien. adsmt unterstützt eine Teilmenge
(Begleitband-Anhang A):

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Theorie*], [*Atome*]),
  [`Core` / EUF], [Gleichheit + uninterpretierte Funktionssymbole],
  [`Ints` / LIA], [Ganze Zahlen, lineare Arithmetik],
  [`Reals` / LRA], [Reelle Zahlen, lineare Arithmetik],
  [`FixedSizeBitVectors`], [Bitvektoren fester Breite],
  [`ArraysEx`], [Abbildungen mit Lesen/Schreiben],
  [`Datatypes`], [Algebraische Datentypen (Listen, Bäume, …)],
)

Jede Theorie besitzt ein *Entscheidungsverfahren*: einen
Algorithmus, der T-Erfüllbarkeit für Atome dieser
Theorie entscheidet. Die SMT-Engine leitet jedes Atom
an das passende Entscheidungsverfahren weiter.

== Quantorenfrei vs. quantifiziert

Eine *quantorenfreie* (QF) Formel enthält weder
$forall$ noch $exists$. Die meisten QF-Fragmente der
gängigen Theorien sind in NP entscheidbar. Die
Logiknamen in SMT-LIB beginnen mit `QF_`, um sie zu
kennzeichnen: `QF_LIA`, `QF_BV`, `QF_AUFLIA`.

Eine *quantifizierte* Formel enthält mindestens einen
Quantor. Die meisten quantifizierten Fragmente (mit der
bemerkenswerten Ausnahme der Presburger-Arithmetik —
quantifizierte LIA —, die entscheidbar, aber sehr teuer
ist) sind unentscheidbar.

Praktische SMT-Solver behandeln Quantoren *heuristisch*:
sie suchen nach Term-Instanziierungen, die die Formel
abschließen. Die Instanziierung mag genügen; falls
nicht, gibt der Solver `unknown` zurück (oder im Fall
von adsmt `abductive`). Kapitel 7 behandelt die
Quantorbehandlung im Detail.

== Theorie-Atome im booleschen Skelett

Zur Erinnerung aus Kapitel 2: die SAT-Schicht behandelt
jedes Theorie-Atom als frische boolesche Variable. Die
Aufgabe der Theorieschicht ist es zu bestimmen, welche
*Kombinationen* von wahr/falsch-Zuweisungen an diese
Atome konsistent sind.

```text
SMT formula:    (< x 3) ∧ ((< x 0) ∨ (> x 5))

Theory atoms:   A := (< x 3)
                B := (< x 0)
                C := (> x 5)

Boolean skeleton: A ∧ (B ∨ C)

SAT proposes:   A=T, B=T, C=F
Theory check:   "x < 3 and x < 0 and ¬(x > 5)" — sat
                (e.g. x = -1)
Verdict:        sat with model x = -1
```

In einem interessanteren Fall schlägt die Theorieprüfung
fehl:

```text
SAT proposes:   A=T, B=F, C=T  (i.e. x < 3 and ¬(x < 0) and x > 5)
Theory check:   "x < 3 and 0 ≤ x and x > 5" — unsat
                (no integer in (-∞, 3) ∩ [0, ∞) ∩ (5, ∞))
SAT learns:     (¬A ∨ B ∨ ¬C) and tries another assignment
```

Dieses Hin und Her zwischen SAT und Theorie ist die
*DPLL(T)*-Schleife. Jeder Durchlauf verfeinert die
Suche.

== Kombination von Theorien

Reale Formeln vermischen Theorien. „Array von ganzen
Zahlen, indiziert durch ganze Zahlen, das eine
linear-arithmetische Bedingung an die Indizes erfüllt"
mischt Arrays + LIA. SMT-Solver müssen
Entscheidungsverfahren elegant *kombinieren*.

Der klassische Ansatz ist die *Nelson-Oppen-Kombination*:
zwei Theorien kooperieren durch den Austausch der
Gleichheiten, die sie auf gemeinsamen Variablen
ableiten. Wenn Arrays „$x = y$" ableitet und LIA nichts
weiter, erbt der LIA-Solver $x = y$ als Hypothese für
die nächste Prüfung.

Nelson-Oppen hat technische Voraussetzungen (stabil
unendlich, signaturdisjunkt, …). Wenn die
Voraussetzungen erfüllt sind, ist das kombinierte
Entscheidungsverfahren korrekt und vollständig. Wenn
nicht, fallen moderne Solver auf die
*polite-Kombination* (Tinelli-Zarba) oder andere
Verallgemeinerungen zurück.

adsmt verwendet standardmäßig die polite-Kombination.
Üblicherweise sieht der Nutzer dies nicht — die
SMT-Engine leitet Atome automatisch weiter, und die
Kombinationsmaschinerie bleibt im Verborgenen. Doch die
ingenieurtechnische Herausforderung ist real: der
Großteil der Komplexität der SMT-Engine liegt in der
Kombinationsschicht.

== „Modulo Theorien" — endlich erklärt

Das Gesamtbild:

```text
A formula's Boolean structure  ←→  SAT solver
A formula's theory atoms       ←→  theory solvers
  (one per theory in use)
Cross-theory equalities         ←→  combination layer
Quantifier instantiations       ←→  quantifier layer
```

„Modulo Theorien" bedeutet: die SAT-Schicht argumentiert
*so, als ob* die Theorie-Atome bloße boolesche
Variablen wären, während die Theorieschicht deren
tatsächlichen semantischen Gehalt ergänzt. Diese
Faktorisierung lässt SMT auf industrielle
Problemgrößen skalieren.

== Nächste Schritte

Die nächsten vier Kapitel führen durch die einzelnen
Theorien in der Reihenfolge, in der man ihnen
üblicherweise begegnet:

- Kapitel 4: Gleichheit + uninterpretierte Funktionen
  (EUF).
- Kapitel 5: Arithmetik (LIA, LRA).
- Kapitel 6: Bitvektoren, Arrays, Datentypen.

Jedes Kapitel behandelt, wofür die Theorie gut ist, wie
ihr Entscheidungsverfahren auf Skizzenniveau aussieht
und wie man SMT-LIB-Skripte schreibt, die sie sinnvoll
ausreizen.
