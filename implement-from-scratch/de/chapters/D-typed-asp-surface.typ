= typed-ASP-Oberfläche

Die *typed-ASP-Face* ist das Closed-World-, Least-Model-
Geschwister der SMT-LIB-Oberfläche und der **Nachfolger
von `lu-kb`** (Anhang B). Während `.smt2` und `.kb` fragen
„Ist diese Formelmenge erfüllbar?“, fragt ein
typed-ASP-Programm „Was ist das eindeutige Modell dieser
Regeln unter der *Closed-World*-Annahme, dass nichts gilt,
außer es wird hergeleitet?“ Es elaboriert zu *demselben*
typisierten CIC-Kernel (`adsmt-ir`) wie jede andere
Oberfläche und ist daher ein Frontend, keine eigene
Engine: jede Regel wird von den Kernel-Admittern
nachgeprüft und jede Antwort durch Neuberechnung des
Modells nachverifiziert — ein Face-Fehler ergibt nur einen
`FaceError`, nie eine vertraute falsche Antwort.

== Gestalt der Oberfläche

Ein Programm ist eine Folge von *Items*:

```text
sort Node.
pred edge(Node, Node).
pred reach(Node, Node).

edge(a, b).  edge(b, c).  edge(c, d).
reach(X, Y) :- edge(X, Y).
reach(X, Z) :- reach(X, Y), edge(Y, Z).

?- reach(a, X).        % alle von a erreichbaren Knoten
```

Die Konvention ist Prolog-/clingo-förmig: ein Bezeichner,
dessen erstes Byte `[A-Z]` oder `_` ist, ist in
Term-Position eine *Variable*; ein kleingeschriebener
Bezeichner ist eine Konstante oder ein Konstruktor.
Deklarationspositionen (sort-/Prädikat-/Konstruktornamen)
sind unabhängig von Groß-/Kleinschreibung.

== Items

*`sort <Name>.`* — Eine opake endliche Domäne (im Kernel
`open Name : Type(0)`).

*`enum <Name> = { c0, c1, … }.`* — Eine endliche,
geschlossene Domäne nullstelliger Konstruktoren (ein
Kernel-`Inductive`).

*`data <Name> = c0(S, …) | c1 | … .`* — Ein induktiver
Datentyp mit argumenttragenden Konstruktoren; das strenge
Positivitätsgatter des Kernels prüft die Rekursion nach.
Konstruktorterme dienen auch als erststufige *Muster*
(siehe unten).

*`pred <name>(S0, S1, …).`* — Eine typisierte Relation
(Ergebnis `Prop`). Argument-Sorten sind deklarierte
sorts / enums / data-Typen oder das eingebaute `Int`.

*`abducible <name>(S, …).`* — Deklariert ein Prädikat als
*abducible*: seine Grundatome bilden den Hypothesenraum.
Ein Abducible ist ein `def`-Vervollständigungs-*loses*
`Open`-Atom — das Dual eines gewöhnlichen Prädikats
(Kapitel 8).

*`<atom>.`* — Ein *Fakt* (ein Grundatom) oder, mit
Kopfvariablen, eine Regel mit leerem Rumpf.

*`<head> :- <body>.`* — Eine definite Regel. Der Rumpf ist
eine Konjunktion positiver Atome, `not`-negierter Atome
und `{ … }`-Theorieatome.

*`:- <body>.`* — Eine *Integritätsbedingung*: der Rumpf
darf im Modell nicht gelten; gilt eine Grundinstanz, hat
das Programm keine Antwortmenge
(`Solution.consistent = false`).

*`?- <atom>.`* — Eine Anfrage; Variablen sind die
„Alle-finden“-Ausgaben. *`?- abduce <atom>.`* — eine
abduktive Anfrage (die ⊆-minimalen Hypothesenmengen, die
das Ziel wahr machen).

== Die Negationsleiter

Der Elaborator *erschließt* die Stufe eines Programms und
weigert sich, die Sprosse zu überschreiten, deren
Korrektheitsgatter existiert (oberhalb wird geparst, aber
abstiniert — nie approximiert).

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Stufe*], [*Ergänzt*], [*Status*]),
  [L0], [typisierte sorts/Prädikate, Fakten, definite Regeln, erststufiges data-Matching], [umgesetzt],
  [L1], [Theorie-Inneres (`open` Int-Atome) + CanEq typisierte (Un-)Gleichheit], [umgesetzt],
  [L2], [stratifiziertes `not` + Integritätsbedingungen `:- B`], [umgesetzt],
  [L3], [volle stabile Modelle + Loop-Formel-Zertifikat], [geplant (hart-gegattert)],
  [L4], [Auswahl `{…}` / disjunktive Köpfe], [geplant],
  [L5], [Aggregate + weiche Bedingungen / Optimierung], [geplant],
  [L6], [erstklassige Abduktion], [in die Regel-IR verschmolzen],
)

== Theorie-Inneres und CanEq (L1)

Ein Regelrumpf kann ein `{ … }`-*Theorieatom* tragen. Für
`Int`-Operanden ist es Arithmetik — `big(T) :- dur(T, D),
{ D >= 4 }.` behält die langen Aufgaben. Der Vergleich
`=`/`!=` wird durch **CanEq** nach der Operanden-Sorte
geleitet: arithmetische Gleichheit auf `Int`, *strukturelle*
(Un-)Gleichheit auf jedem enum / data-Typ. Ein
sortenübergreifender Vergleich (`Int = Node`) ist ein
Elaborationsfehler, kein stilles Atom — die
wiederkehrende sortenübergreifende Fehlerklasse wird an
der Face-Grenze gefangen. Intern wird jeder Operator zu
einem `open`-Kernelsymbol (`#int.lt`, `#eq.S`, …), das der
Kernel typprüft und der Grounder als das `θ` des Gatters
auswertet.

== Stratifizierte Negation (L2)

`not p(X)` gilt im *perfekten Modell* genau dann, wenn
`p(X)` nicht herleitbar ist. Es ist nur unter
**Stratifikation** korrekt: kein Prädikat darf von seiner
eigenen Negation abhängen. Der Elaborator baut den
Abhängigkeitsgraphen und weist einen negativen Zyklus
zurück (`FaceError::NonStratified`); der Solver wertet die
Schichten von unten nach oben aus, sodass jedes `not` eine
bereits entschiedene untere Schicht liest. Jede Variable
unter `not` muss auch durch ein positives Rumpfatom
gebunden sein (eine freie wäre eine Allquantifizierung,
keine Closed-World-Negation).

```text
single(X) :- person(X), not married(X).
```

== Abduktion — das Dual der Regel

Deduktion und Abduktion teilen sich *eine* Regel-IR. Der
Vorwärts-Kleinste-Fixpunkt berechnet die
Antwortmengen-Mitgliedschaft; dieselben Regeln, rückwärts
gelesen, treiben die Abduktion. `?- abduce G` liefert die
⊆-minimalen Mengen von Abducible-Atomen, die, angenommen,
`G` wahr machen; eine *leere* Erklärung bedeutet, dass `G`
bereits folgt (Deduktion = Abduktion mit leerer
Abducible-Menge). Die Abduktionsschicht aus Kapitel 8 wird
direkt wiederverwendet — die Closed-World-Face ist der Ort
ihrer Vorwärtsrichtung.

== Oberflächenzucker

Reine Entzuckerungen (jede expandiert in den Kern, sodass
Kernel + Fixpunkt sie nachprüfen — Korrektheit ist
automatisch):

- *anonymes `_`* — eine eigene frische Variable bei jedem
  Auftreten (`p(_, _)` ist nicht `p(X, X)`).
- *Pooling `;`* — `color(red; green; blue).` expandiert zu
  drei Fakten; kartesisch über die Positionen.
- *Ganzzahl-Intervall `..`* — `value(1..3).` expandiert zu
  `value(1)`, `value(2)`, `value(3)` (inklusiv, literale
  Grenzen); poolbar und gegen Explosion beschränkt.

== Korrektheits-Firewall

Der Kernel beglaubigt *Typisierung* und *positive
Herleitungen*; ein nicht vertrauter Grounder + das
nachrechenbare Kleinste-Fixpunkt-Gatter beglaubigen das
Closed-World-Modell. Beide teilen nie ein Urteil. Ein
fehlerhafter Grounder oder eine Heuristik kann die
Antwortmenge nur *verkleinern* oder `Unknown` liefern —
nie eine falsche Folgerung erzeugen. Die Abstinenzgrenze
ist breit und bewusst: ein nicht stratifiziertes Programm,
eine unsichere Regel (eine ungebundene Variable), eine
unendliche Domäne oder jede „keine Antwortmenge“-Behauptung
ohne Zertifikat ist ein `FaceError` oder `Unknown`, nie
eine Approximation.

== Vergleich zu lu-kb und SMT-LIB

#table(
  columns: 4,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Aspekt*], [*SMT-LIB*], [*lu-kb*], [*typed-ASP*]),
  [Welt],      [offen], [offen], [geschlossen (Least Model)],
  [Frage],     [SAT eines Ziels], [SAT einer WB], [das eindeutige Modell],
  [Negation],  [klassisch], [klassisch], [stratifiziertes NAF],
  [Abduktion], [`(abduce)`], [über `rule`], [nativ (Regel-Dual)],
  [Theorie],   [nativ], [nativ], [`{…}`-Inneres, dieselbe Engine],
)

Alle drei Oberflächen elaborieren zum selben Kernel, daher
bedeutet ein sort / data-Typ / Theorieatom über sie hinweg
dasselbe; nur die *Weltannahme* und die *Frage*
unterscheiden sich.
