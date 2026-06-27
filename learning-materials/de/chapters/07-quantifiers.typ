= Quantoren

== Die zwei Bedeutungen von „Quantor"-Schwierigkeiten

Wenn ein SMT-Nutzer „Quantoren" beklagt, meint er in
der Regel eine von zwei verschiedenen Sachen:

1. *Performance* — „mein Benchmark enthält $forall$, der
   Solver ist langsam / liefert unknown."
2. *Vollständigkeit* — „es gibt eine Formel, von der ich
   weiß, dass sie unerfüllbar ist, doch der Solver kann
   es nicht beweisen."

Beide haben dieselbe Wurzel: die meisten quantifizierten
Fragmente sind unentscheidbar, und selbst die
entscheidbaren sind teuer. Solver behandeln Quantoren
mit *heuristischer Instanziierung*, die schnell ist,
wenn sie funktioniert, und unzuverlässig, wenn sie es
nicht tut.

== Die Idee der Instanziierung

Ein allquantifiziertes $forall x. phi(x)$ besagt, dass
$phi(x)$ für *jedes* $x$ im Bereich gilt. Wenn der Rest
der Formel einige spezifische Terme erwähnt — $a$,
$f(b)$, $g(c, d)$ —, kann der Solver $forall x. phi(x)$
an jedem solchen Term *instanziieren* und die
resultierenden Grund-Atome hinzufügen.

```text
(declare-sort Term 0)
(declare-fun f (Term) Term)
(declare-const a Term)
(declare-const b Term)
(assert (forall ((x Term)) (= (f x) x)))
(assert (= a b))
(assert (not (= (f a) b)))
(check-sat)
```

Der Allquantor besagt $f(x) = x$ für jedes $x$. An $a$
instanziieren: $f(a) = a$. Mit $a = b$ kombinieren:
$f(a) = b$, was der Behauptung widerspricht. Urteil
`unsat`.

Die Raffinesse liegt in der *Auswahl* der
Instanziierungsstelle. Jeden Grundterm probieren?
Kombinatorisch explosiv bei großen Problemen. Keinen
probieren? Information verlieren.

== E-Matching

Die Standardheuristik ist das *E-Matching*. Die
quantifizierte Formel trägt einen *Trigger* — ein
Unterausdrucksmuster, das die gebundene Variable
enthält. Wenn ein Grundterm *auf den Trigger passt*
(modulo Gleichheitsargumentation), wird instanziiert.

```text
(assert (! (forall ((x Term)) (= (f x) x)) :pattern ((f x))))
```

Der Trigger ist hier `(f x)`. Jedes Mal, wenn ein
Grundterm der Form `(f ?)` erscheint, wird $x$ auf den
passenden Teilterm instanziiert. Modulo Gleichheit
bedeutet: wenn der Grundterm `(f y)` lautet und wir
$y = a$ wissen, greift die Übereinstimmung trotzdem.

== Miller-Muster

Ein Trigger ist ein *Miller-Muster*, wenn jedes
Vorkommen der gebundenen Variable als Teilanwendung
verschiedener lokaler Variablen erscheint. Miller-Muster
erlauben Matching in linearer Zeit. adsmt akzeptiert
sowohl Miller- als auch Nicht-Miller-Muster;
Nicht-Miller-Muster erhalten eine Warnung und einen
langsameren Matching-Pfad.

```text
:pattern ((f x))            ; Miller
:pattern ((f x x))          ; non-Miller: x appears twice
:pattern ((f (g x)))        ; Miller via nested fixed pattern
```

== Trigger — den richtigen auswählen

Die Wahl des Triggers ist enorm wichtig. Wählt man ihn
zu restriktiv, findet der Solver keine
Instanziierungen, wenn eine das Ziel abschließen würde.
Wählt man ihn zu permissiv, instanziiert der Solver
wahllos und überschreitet sein Budget.

Die Standardheuristik, wenn kein Trigger angegeben ist:
den kleinsten Teilterm des Rumpfes wählen, der jede
gebundene Variable *abdeckt*. Das `learn_triggers` von
adsmt führt diesen gierigen, tiefensortierten Durchlauf
aus (Begleitband Kap. 7).

Wenn man sich mit der Triggerauswahl herumschlagen
muss, ist der Ausweg, *den Trigger explizit zu
schreiben*. Die Taktik `smt_decide` in Lean 4
akzeptiert eine `:trigger`-Klausel; die SMT-LIB-
Oberfläche akzeptiert `(! phi :pattern (...))`.

== Wenn E-Matching scheitert

E-Matching kann aus mehreren Gründen scheitern:

- *Verfehltes Muster.* Kein Grundterm in der Form des
  Triggers erscheint in der Formel.
- *Kombinatorische Explosion.* Trigger feuern Millionen
  Mal, jede Instanziierung billig, doch die Summe nicht
  handhabbar.
- *In der Theorie verborgene Zeugen.* Die nötige
  Instanziierung betrifft einen Term, der erst nach
  einer Kette von Theorieargumentation existiert.

Die Antwort von adsmt ist das *Tier*-System:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Tier*], [*Strategie*]),
  [1], [E-Matching gegen das Universum der Grundterme],
  [2], [Konfliktgetriebene Instanziierung],
  [3], [Begrenzte Aufzählung von Kandidatentermen],
  [4], [Abduktiv — den Quantor als Kandidatenhypothese emittieren],
)

Die Stufen 1-3 sind graduelle Lockerungen. Stufe 4 ist
qualitativ: „ich finde keine Instanziierung, also
lege ich den Quantor als etwas offen, das der Nutzer
möglicherweise als Annahme akzeptieren muss, damit der
Beweis durchgeht."

== Die abduktive Eskalation

Wenn alle Anstrengungen der Stufen 1-2-3 erschöpft sind,
gibt die Engine `SatResult::Abductive` mit dem aus dem
Quantor abgeleiteten Kandidaten zurück. Das macht die
Quantorbehandlung von adsmt *nicht binär*: statt „ich
habe aufgegeben" erhält man „ich habe aufgegeben, *aber
hier ist, was funktioniert hätte*."

Das Kandidatenformat:

```text
(abductive-candidate
  :hypothesis ((or (= x a) (= x b)))
  :justification (quantifier_exhausted
    :var x
    :original-body (= (f x) x))
  :rank 1)
```

Ein Nutzer akzeptiert den Kandidaten, indem er die
Hypothese als Behauptung hinzufügt. Der Solver läuft
dann erneut und schließt entweder das ursprüngliche
Ziel ab (die Hypothese genügte) oder legt weitere
Kandidaten offen.

== Wann Quantoren *nicht* verwenden

Ein pragmatischer Hinweis: wenn man seine Bedingung
ohne Quantoren ausdrücken kann (indem man *selbst
instanziiert* — die endlich vielen Fälle ausschreibt),
sollte man es tun. Quantorenfreie Fragmente sind in NP
entscheidbar und robust; quantifizierte Fragmente sind
heuristisch und spröde.

Häufige Muster, in denen das funktioniert:

- „$forall x in {a, b, c}. P(x)$" → drei Konjunktionen
  ausschreiben.
- „$forall x. (x = a or x = b) => P(x)$" → die beiden
  Konjunktionen ausschreiben.
- „$forall x. P(x) => Q(x)$ über einer *endlichen* Menge,
  die durch ein rekursives Prädikat charakterisiert ist"
  → die Fälle induktiv ausschreiben (im ITP, nicht im
  SMT).

Diese Umformungen verlagern die Arbeit der
Quantorbehandlung *aus* SMT heraus und in den Editor
des Nutzers oder die Induktionstaktiken des ITPs.

== Verfeinerungsbeschränkte Quantoren

Die SMT-LIB-Oberfläche gibt einem das blanke
$forall x. phi(x)$. Die *Nachfolgeoberfläche der lu-kb*
von adsmt — die typisierte Wissensbasis-Fassade mit den
Elementen `sort` / `const` / `fn` / `data` / `axiom` /
`assume` / `goal` — erlaubt es, die *Einschränkung* des
Bereichs direkt in den Binder zu schreiben. Statt

```text
forall (n: Int). n >= 0 => p(n)
```

schreibt man einen *Verfeinerungstyp* als Sorte des
Binders:

```text
forall {n: Int | n >= 0}. p(n)
```

Ein Verfeinerungstyp `{v: T | φ}` ist eine Basissorte
`T`, ausgeschnitten durch ein Prädikat `φ`. Der
Klammerbinder durchläuft genau jene `T`, die `φ`
erfüllen. Das ist syntaktischer Zucker, keine neue
Logik: der Elaborator faltet die Einschränkung zurück in
die gewöhnliche erststufige Form, und die *Polarität
dieser Entfaltung hängt vom Quantor ab*:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Binder*], [*Elaboriert zu*]),
  [`forall {v: T | φ}. ψ`], [`forall (v: T). φ => ψ`],
  [`exists {v: T | φ}. ψ`], [`exists (v: T). φ and ψ`],
)

Ein Allquantor *impliziert* (jedes `v`, das `φ`
besteht, muss `ψ` erfüllen); ein Existenzquantor
*konjugiert* (irgendein `v` besteht sowohl `φ` als auch
erfüllt `ψ`). Die beiden Pfeile
$forall arrow.r.double.long (=>)$ und
$exists arrow.r.long (and)$ sind keine Konvention, die
man sich merken muss — sie sind die Schlussfolgerungen
eines einzigen vorab verifizierten
Relativierungslemmas, sodass die Entzuckerung als
erfüllbarkeitserhaltend vertrauenswürdig ist.

`Nat` und `WNat` werden als Verfeinerungen von `Int`
ausgeliefert:

```text
; Nat  = {x: Int | x >= 1}
; WNat = {x: Int | x >= 0}
forall {n: Nat}. p(n)       ; durchläuft 1, 2, 3, ...
forall {n: WNat}. p(n)      ; durchläuft 0, 1, 2, ...
```

`forall {n: Nat}. p(n)` zu schreiben ist exakt
`forall (n: Int). n >= 1 => p(n)` — aber man drückt die
Absicht einmal aus, im Binder, statt einen Wächter durch
den Rumpf zu fädeln.

=== Der Vergleichszucker

Der häufige Fall — ein Binder, eingeschränkt durch einen
einzigen Vergleich gegen eine feste Schranke — hat eine
noch leichtere Form, die die Klammern und die
Prädikatvariable weglässt:

```text
forall (n: Int) >= 0. p(n)        ; {n: Int | n >= 0}
forall (k: Int) < limit. q(k)     ; {k: Int | k < limit}
exists (i: Int) > 0. r(i)         ; {i: Int | i > 0}
```

`forall (n: T) op rhs. ψ` liest sich als „für alle `n`
der Sorte `T` mit `n op rhs`" und bedeutet exakt die
Klammerform `forall {n: T | n op rhs}. ψ`. Sie erbt
dieselbe $forall arrow.r.double.long (=>)$ /
$exists arrow.r.long (and)$-Polarität, weil sie nach
einem Einschritt-Umschreiben *die* Klammerform ist.
Greife danach, wann immer die Einschränkung eine
einzelne Schrankenprüfung ist; greife zur vollen
`{v: T | φ}`-Klammerform, wenn das Prädikat
zusammengesetzt ist.

=== Warum das mehr als Syntax ist

Zwei Gewinne. Erstens *Lesbarkeit*: der Bereich eines
Quantors wird dort angegeben, wo die Variable eingeführt
wird, nicht als Vorbedingung einer Implikation
versteckt, nach der der Leser suchen muss. Zweitens
*Einheitlichkeit*: ein unverfeinerter Binder `x: T` wird
intern als `{x: T | nop(x)}` behandelt, wobei `nop` das
triviale Prädikat ist, das immer `true` ist. Die
verfeinerungsbewusste Logik sieht daher *stets* ein
Prädikat auf jedem Binder; eine `nop`-Verfeinerung ist
gehaltlos und gibt keinen Wächter aus, sodass
`forall (x: T). ψ` exakt $forall x. psi$ ohne Ballast
bleibt. Man erhält die ausdrucksstarke Klammerform, ohne
dafür zu bezahlen, wenn man sie nicht nutzt.

== Bild-Binder — über den Wertebereich einer Funktion quantifizieren

Manchmal ist die Variable, über die man sprechen will,
kein frisches Bereichselement, sondern das *Bild* eines
solchen unter einer Funktion: „für jedes `y`, das `f`
von irgendeinem `x` ist, das `c` erfüllt...". Das von
Hand auszuschreiben bedeutet, das Urbild `x`
einzuführen, es einzuschränken und überall, wo `y`
erscheint, `f(x)` einzusetzen. Die Nachfolgeoberfläche
von adsmt gibt einem einen *Bild-Binder*, der die
Einsetzung für einen erledigt, vollständig durch
Typinferenz gesteuert:

```text
forall {y = f(x) | p(x)}. q(y)
```

Dies durchläuft das *Urbild* `x` — dessen Sorte der
Elaborator als `f`s Definitionsbereich erschließt —,
bewacht durch `p(x)`, wobei `y` im Rumpf zu `f(x)`
entfaltet wird. Es ist genau

```text
forall (x: {A | p(x)}). q(f(x))
```

wobei `A` die Definitionsbereichssorte von `f` ist. Das
`y` ist nie ein echter Binder; es ist ein *Name für
`f(x)`*, der den Rumpf lesbar hält. Wie die
Verfeinerungs-Binder ist auch dieses Umschreiben
(`image_quantifier_desugar`) vorab verifiziert, sodass
die Abkürzung eine vertrauenswürdige Äquivalenz ist,
kein zerbrechliches Makro.

Verwende ihn, wenn die natürliche Aussage über Ausgaben
ist — „jeder Wert, den der Parser erzeugt, ist
wohlgeformt", „jedes durch `step` erreichbare Element
bleibt in der Invariante" — und man andernfalls die
Urbildvariable von Hand stricken und `f(x)` durch den
Rumpf tragen müsste.

== Quantoren in realen Beweisskripten

Ein Lean-4-Taktikaufruf:

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) : xs.head? ≠ some 0 := by
  smt_decide [h]
```

Die Taktik `smt_decide` übersetzt das Ziel in SMT-LIB
mit explizitem $forall$, wendet das Triggerlernen an
(ein Trigger: `(mem x xs)`) und versucht die
Instanziierung. Für diese konkrete Form lautet das
Urteil `unsat` (List.head? liefert entweder none oder
Some einer positiven Zahl).

Wenn die Instanziierung scheitert — etwa weil die
Hypothese über einem komplexeren Prädikat lag —, greift
die abduktive Oberfläche. Der Nutzer sieht einen
`sorry`-Platzhalter, der nach der benötigten
Instanziierung benannt ist:

```lean
-- adsmt_h_quant_1 : ∀ x ∈ xs, x > 0  -- accepted as hypothesis
```

Der Nutzer prüft entweder seine Hypothese erneut oder
ersetzt das `sorry` durch eine Taktik, die die benannte
Verpflichtung abschließt.

== Take-aways

1. Die Quantorbehandlung ist *heuristisch*. Den
   Urteilen in den QF-Fragmenten ist zu vertrauen;
   quantifizierte Urteile sollten als
   „meistens-ja" behandelt werden.
2. *Trigger* sind die wichtigste vom Nutzer steuerbare
   Stellschraube. Sie sollten gezielt gewählt werden,
   wenn E-Matching erschöpft.
3. In der *Nachfolgeoberfläche der lu-kb* schiebe den
   Bereich in den Binder. `forall {n: T | φ}. ψ` und sein
   Vergleichszucker `forall (n: T) op rhs. ψ` sagen
   einmal, was man meint — und die
   $forall arrow.r.double.long (=>)$ /
   $exists arrow.r.long (and)$-Relativierung ist
   vertrauenswürdig, sodass die Einschränkung nicht in
   der Übersetzung verloren geht. *Bild-Binder*
   `forall {y = f(x) | c}` erlauben es, über den
   Wertebereich einer Funktion zu quantifizieren, ohne
   das Urbild auszuschreiben.
4. Die *abduktive Ausweichmöglichkeit* (Kapitel 8) ist
   die Antwort von adsmt auf „aber was, wenn ich
   wirklich ein Urteil brauche?": statt aufzugeben,
   reicht der Solver dem Nutzer ein Hypothesenmenü.
