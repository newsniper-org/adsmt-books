= lu-kb-Oberfläche

`lu-kb` ist der zweite Eingabedialekt, den adsmt akzeptiert.
Der Name entstand im *logicutils*-Projekt (absorbiert bei
RC1.4.A, siehe `ABSORPTION_PLAN.md`), aber die hier
beschriebene Oberfläche ist der *lu-kb-Nachfolger* — der
moderne Dialekt, der in `adsmt-ir-lukb` implementiert ist.
Wo das ältere lukb ein loser Sack aus `fun` / `rule` /
`class` / `instance` / `query`-Blöcken war, der auf
logicutils-Wissensbasen abzielte, ist der Nachfolger eine
kleine, beweispflicht-geformte Modulsprache: eine Folge von
*Items*, die Sorten, Konstanten, Funktionen, Datentypen und
vertrauenswürdige Fakten postulieren und dann ein *Ziel*
formulieren, das abzutragen ist. Es ist die Oberfläche, die
adsmt für handgeschriebene Verifikationsbedingungen und für
die Typrelations-Arbeit in Kapitel 3 bevorzugt.

Die ältere `.kb`-Blockgrammatik wird zur
Rückwärtskompatibilität weiterhin geparst (die
Migrationskette `adsmt-parser/src/lukb/` bleibt unangetastet),
ist aber nicht mehr die empfohlene Verfassungsoberfläche und
wird hier nicht weiter dokumentiert.

== Oberflächenform

Ein lu-kb-Modul ist eine Folge von *Items*:

```text
sort Shape

const c: Int

fn area(s: Shape): Int

data Nat = zero | succ(Nat)
data List = nil | cons(head: Int, tail: List)

axiom area_pos: forall s. area(s) >= 0
assume c_small: c <= 10
goal:    forall s. area(s) >= 0
```

Jedes Item ist eines von: `sort`, `const`, `fn`, `data`,
`axiom`, `assume`, `goal`. Die Grammatik lebt in
`adsmt-ir-lukb` (`lexer.rs`, `parser.rs`, `ast.rs`), das
jedes Item in die Kern-IR aus Kapitel 3 elaboriert.

== Items

*`sort <name>`* — Deklariert eine opake (uninterpretierte)
Sorte. Äquivalent zu `declare-sort` in SMT-LIB.

*`const <name>: <type>`* — Eine freie Konstante, z. B. eine
VC-Variable. Der Typ darf ein beliebiger Typausdruck sein,
einschließlich einer Verfeinerung (siehe unten).

*`fn <name>(<params>): <ret> [= <body>]`* — Eine Funktion.
Jede Parametergruppe `names: ty` teilt sich einen Typ, sodass
`fn f(x: Int, y z: Bool): U` `f : Int -> Bool -> Bool -> U`
deklariert. *Ohne* `= body` ist die Funktion eine opake
*Signatur* (ein `open`-Symbol, das an seinem Pfeiltyp
postuliert wird, wobei `Bool` auf `Prop` abgebildet wird);
mit einem `= body` ist sie eine nichtrekursive *Definition*
(`f := λ(params). body`), die beim Solver-Lowering
δ-entfaltet wird. Ein Body, der `f` erwähnt (echte
Rekursion), benötigt das Kern-`fix` und ist ein späterer
Abschnitt.

*`data <name> = <ctor> | ...`* — Ein nicht-parametrischer
induktiver Datentyp, elaboriert zu `declare_inductive`. Jeder
Konstruktor trägt eine Feldliste; ein Feld kann seinen
Selektor benennen (`head: Int`) oder positional sein (`Int`).
Konstruktoren sind als Terme verwendbar.

*`axiom [<name>]: <formula>`* — Eine vertrauenswürdige
Hypothese ($in H$). Wird zu Engine-Start behauptet.

*`assume [<name>]: <formula>`* — Eine VC-Pfadbedingung
($in H$). Derselbe Vertrauensstatus wie `axiom`; der
Unterschied ist die Absicht (ein `assume` ist eine
Vorbedingung, die entlang eines Verifikationspfads
mitgeführt wird).

*`goal [<name>]: <formula>`* — Die abzutragende
Beweispflicht. Der Body darf als Sequent `H1, ..., Hk |- G`
geschrieben werden, das zur Parse-Zeit zu
`(H1 and ... and Hk) ==> G` entzuckert wird. Ein Ziel ist
das Analogon zu `assert (not phi)` gefolgt von `check-sat`;
das Urteil wird namentlich gemeldet.

== Das vereinheitlichte Verdikt

Ein lu-kb-Nachfolger-Modul wird vom `adsmtc`-Compiler (Batch)
oder von der `adsmtr`-Laufzeit / REPL gelöst und liefert ein
*UnifiedVerdict* — ein *separiertes Produkt* `{ smt, asp }`,
dessen SMT-Präzisions-Seite und typed-ASP-Partialitäts-Seite
unterschiedliche Fragen beantworten und daher bewusst *nicht*
zu einem einzigen Verband verschmolzen werden. Die asp-Seite
wird nur von der typed-ASP-Oberfläche (Anhang D) gefüllt; ein
reines lu-kb-Modul beansprucht die smt-Seite. Das
vereinheitlichte Verdikt kollabiert über die 3-wertige
*Kleene-Konjunktion* seiner beiden Seiten zu einem Tri-State
(ein `unsat` auf einer der beiden Seiten dominiert das Ganze).
Gemäß der Verus-/SMT-Konvention ist ein Ziel `G` genau dann
gültig, wenn `H ∧ ¬G` unerfüllbar ist — eine *abgetragene*
Verpflichtung liest sich daher als `unsat`. Unter
`--output-mode full` entkollabiert die smt-Seite zum
5-stufigen Präzisionsverband (`definite-sat` …
`definite-unsat`).

Die Oberfläche ist vollständig in
`docs/design/LUKB_SUCCESSOR_SURFACE.md` Abschnitt 10
dokumentiert.

== Verfeinerungstypen

Ein *Verfeinerungstyp* `{v: T | φ}` ist eine Basissorte `T`,
zugeschnitten durch ein Prädikat `φ` über den gebundenen
Namen `v`. Er ist überall verwendbar, wo ein Typ steht —
`const`-Typen, `fn`-Parameter- und Rückgabetypen, Definitions-
und Wertebereich eines Pfeils — und auch als
*Quantorenbinder*.

Die beiden Elaborationsstellen unterscheiden sich durch die
Polarität:

- *Postulieren* einer verfeinerten Konstante.
  `const c: {v: T | φ}` führt `c: T` *und* den
  vertrauenswürdigen Fakt `φ[v := c]` ein. Die Verfeinerung
  ist dir gegeben.

- *Quantifizieren* über eine Verfeinerung. Ein verfeinerter
  Binder relativiert den Quantor: `∀` erhält eine Schutzbe­dingung
  (`forall x: {T | φ}. ψ` wird zu `forall x: T. φ ==> ψ`),
  und `∃` erhält ein Konjunkt (`exists x: {T | φ}. ψ` wird zu
  `exists x: T. φ and ψ`). Diese Regel `∀ -> ⟹`, `∃ -> ∧`
  ist das vorab verifizierte Relativierungs-Lemma; sie ist
  erfüllbarkeitserhaltend.

`Nat` und `WNat` sind genau Verfeinerungen von `Int`:

```text
Nat  = { x: Int | x >= 1 }
WNat = { x: Int | x >= 0 }
```

sodass die Positivität eines `Nat`-typisierten Werts ein
*Fakt* ist, den der Solver erhält, und keine opake
Sortenmauer (siehe `NAT_WNAT_REFINEMENT_COLLAPSE.md`).

== Funktionstypen und verfeinerte Pfeile

`T -> U` ist ein Funktionstyp, *rechtsassoziativ*:
`A -> B -> C` wird als `A -> (B -> C)` geparst. Klammere, um
einen Pfeil in Definitionsbereichsposition zu setzen:
`(A -> B) -> C`.

Ein *verfeinerter Pfeil* hängt einen Vertrag an einen Pfeil:

```text
{u: A | 'p} -> {v: A | 'q}
```

Die Definitionsbereichs-Verfeinerung `'p` ist eine
*Vorbedingung* und die Wertebereichs-Verfeinerung `'q` eine
*Nachbedingung*. Die *Wertesorte* eines verfeinerten Pfeils
ist nur das schlichte `A -> A` — die Verfeinerungen sind
beweisirrelevant und werden beim Lowering gelöscht —, aber
sie sind nicht kosmetisch: ein Argument, das an diesem Typ
geliefert wird, trägt `'q` als verwendbaren Fakt an die
Aufrufstelle. Verfeinerte Pfeile sind, wie eine „Funktion,
die eine Eigenschaft bewahrt“ *typisiert* wird; die
Beweispflicht, dass sie sie tatsächlich bewahrt, wird
separat abgetragen (siehe *Generische Prädikatparameter* und
*Bildbinder und Bewahrung* unten).

== Generische Prädikatparameter `'p`

Ein führendes einfaches Anführungszeichen markiert einen
*generischen Prädikatparameter* — ein Prädikat, über das das
Item polymorph ist. Ein bloßer Bezeichner `q` (ohne
Anführungszeichen) ist ein *konkretes* Prädikat; das
Anführungszeichen ist es, was die beiden zur Parse-Zeit
unterscheidet.

Wenn die Verfeinerungen einer `fn` `'p` erwähnen, bindet die
`fn` es *implizit* am Kopf als `Π('p: T -> Prop)`. Der Body
wird *einmal* typgeprüft, mit `'p` abstrakt gehalten — die
„einmal-geprüft“-Garantie: eine generische
Verfeinerungsfunktion wird ein einziges Mal verifiziert und
bei jeder Instanziierung wiederverwendet, statt pro
Verwendung erneut geprüft zu werden.

Die Parameter-Verfeinerungen sind Vorbedingungen und die
Rückgabe-Verfeinerung eine Nachbedingung, sodass eine
generische Funktion den Vertrag

```text
forall 'p... . forall x... . (pre_1 and ... and pre_k) ==> post
```

trägt. Dieser Vertrag wird für die beiden `fn`-Formen in
entgegengesetzte Richtungen gelesen:

- Für eine *Definition* (`= body`) ist der Vertrag ein
  *Ziel* — die Konstruktionsstellen-Beweispflicht, dass der
  Body seine Nachbedingung tatsächlich erfüllt.

- Für eine *Signatur* (kein Body) ist der Vertrag ein
  *vertrauenswürdiges Axiom*.

An einer Verwendungsstelle wird der Parameter instanziiert,
`'p := q`, und die nun monomorphe Vorbedingung wird
abgetragen — klassisches Dictionary-Passing. Konkrete
Verfeinerungsfunktionen (jene, deren Verfeinerungen ein
schlichtes `q` statt eines `'p` erwähnen) erhalten dieselbe
Vertragsbehandlung, nur ohne das führende `Π`.

== Das triviale Prädikat `nop`

`nop` ist das stets-wahre Prädikat,

```text
nop : Π(T: Type). T -> Prop := λ T x. true
```

Es existiert, damit die verfeinerungsbewusste Logik *immer*
ein Prädikat sieht, selbst für unverfeinerte Werte. Ein
unverfeinertes `x: T` wird einheitlich als `{x: T | nop(x)}`
behandelt. Weil `nop(x) ≡ true`, ist eine `nop`-Verfeinerung
vakuös: sie gibt weder eine Hypothese noch eine
Schutzbedingung aus, sodass `const c: {v: T | nop(v)}` genau
`const c: T` ist und die Ausgabe sauber bleibt. `nop` ist der
Boden des Verfeinerungsverbands — die Stelle, an der ein
„keine Einschränkung“-Slot landet, wenn einer der obigen
Prädikatparameter unbeschränkt gelassen wird.

== `solve ... by ...`-Beweisterme

`solve G by L` ist ein *innersprachlicher Beweisterm*: ein
Beweis der Proposition `G`, gerechtfertigt durch das Lemma
`L`. Es ist der *Schnitt* (cut) des strukturierten Beweises,
in Oberflächensyntax gegossen. `G` und `L` sind jeweils ein
*Block* — ein Term, möglicherweise eine `let`-Kette.

Seine Semantik ist *Beweisterm-Konstruktion*, nicht
Laufzeit-Lösen. `solve G by L` elaboriert zu zwei
Beweispflichten, beide über den umgebenden Kontext
geschlossen, sodass jede auf oberster Ebene wohlgeformt ist:

- die *Blatt*-Beweispflicht `L` und
- die *Brücken*-Beweispflicht `L ==> G`.

Der Kern baut das Beweisgerüst (den Schnitt), und die Engine
trägt das Blatt ab. Die Korrektheit ist genau die
Schnittregel — kein neues Axiom, keine Urteilsabkürzung —,
und der Korrektheitskern ist in Verus vorab verifiziert
(`~/solve-by-verification`, 5 verifiziert, 0 Fehler). Siehe
`SOLVE_BY_PROOF_TERMS.md`.

Eine typische Verwendung beweist, dass eine Funktion einen
Bewahrungsvertrag erfüllt, indem sie den Beweis über ein
Zwischenlemma faktorisiert:

```text
fn double(x: Int): Int = x + x

// `double` bewahrt Nichtnegativität. Das Ziel ist der
// verfeinerte-Pfeil-Vertrag; `by` schneidet durch ein Lemma
// über den Body.
goal double_preserves:
  solve (forall x: {v: Int | v >= 0}. double(x) >= 0)
  by    (forall x: Int. x >= 0 ==> x + x >= 0)
```

Die Engine trägt das arithmetische Blatt
`forall x. x >= 0 ==> x + x >= 0` ab, der Kern liefert die
Brücke von diesem Blatt zum verfeinerten-Pfeil-Ziel, und das
Ziel ist durch den Schnitt bewiesen.

== Bildbinder und Bewahrung

Ein *Bildbinder* `{y = f(x) | c}` ist eine
typinferenz-getriebene Quantorabkürzung. Er läuft über das
inferierte *Urbild* `x` (dessen Sorte der Definitionsbereich
von `f` ist), geschützt durch die Bedingung `c`, und
entfaltet `y` im Body zu `f(x)`:

```text
forall {y = f(x) | p(x)}. q(y)
  ≡  forall x: {A | p(x)}. q(f(x))
```

Dies ist das vorab verifizierte `image_quantifier_desugar`.
Es lässt dich über „die Werte im Bild von `f`“
quantifizieren, ohne das Urbild explizit zu benennen.

Bildbinder sind das natürliche Vehikel für
*Bewahrungs*-Aussagen. Ein zentraler Designpunkt: *Bewahrung
ist ein Prädikat höherer Ordnung, keine Typrelation.* Eine
Typrelation ist kohärent — eine Instanz pro Typ —, aber ein
einzelner Datentyp `A` kann *viele* Funktionen haben, die
eine Eigenschaft `'p` bewahren. Also ist „bewahrt `'p`“ eine
Eigenschaft einer *Funktion*, geschrieben als Prädikat
höherer Ordnung `preserving(f)` und pro Funktion geprüft,
typischerweise über ein `solve ... by ...` über ein
verfeinertes-Pfeil-Argument. (Ein früherer
`Preserving('p)`-*Typrelations*-Versuch wurde als die
falsche Abstraktion verworfen.)

== Typrelationen sind Typklassen

In adsmt *ist* „Typrelation“ der Begriff für eine Typklasse —
ein Konzept, implementiert in `adsmt-class` (wörtlich „die
Typklassen-Schicht“). Das Vokabular ist `Relation` /
`Instance` / `Resolver` / `Dict` / `Law`. Eine Relation darf
auch einen *Prädikatparameter* `'p : T -> Prop` tragen, den
jede Instanz als Dictionary-Eintrag liefert — derselbe
generische-Prädikat-Mechanismus wie der `fn`-Kopf oben.

Die *\*Like-Familie* (`PartialOrd` -> `Ord` ->
`IntegerLike`, `RealLike`, ...) teilt sich ein
`Reduces`-Rückgrat, und `IntegerLike(I, L, N)` ist die erste
höher-gekindete Typklassen-Instanz. Sie ist das Bindegewebe
der *vierfachen Verschränkung* — der zentralen Designabsicht,
dass Typinferenz, abduktiv-deduktive Logik, ASP und SMT (plus
HKT) sich organisch verschränken, statt in getrennten Silos
zu leben.

Relationen sind *gesetzeskonform durch Beweis*. Eine Relation
trägt *Gesetzes*-Ziel-Member neben ihren Methoden-Membern,
und eine Instanz wird nur zugelassen, wenn adsmts eigene
Engine *jedes* Gesetz beweist — andernfalls wird der Build
*abgelehnt*. Dies ist `declare_instance_lawful` plus ein
engine-gestützter `LawProver`: Gesetzeskonformität ist keine
Konvention, sondern eine abgetragene Beweispflicht, im selben
Geist wie das Konstruktionsstellen-Ziel, das eine
Verfeinerungs-`fn`-Definition trägt.

Die `=`/`!=` und Vergleiche der Oberfläche werden von der
`Eq`/`Ord`/`UpCast`-Relationsfamilie *gegated*
(`Eq`-Gating im Rust-Stil): Jede deklarierte Sorte erhält
automatisch ein Builtin-`Eq`, das `Eq` einer
`data`-Deklaration wird *gesetzeskonform* zugelassen (die
Engine trägt seine Äquivalenz- + Entscheidbarkeitsgesetze
ab), und sortenübergreifende numerische Gleichheit und
Vergleiche lösen `PartialEq`/`PartialOrd`-Instanzen auf,
deren Prämissen den die Injektion ausführenden `UpCast`
benennen. Die von verus emittierten `is-{ctor}`-Testeraufrufe
reiten auf der `Eq`-Instanz des Datentyps — nulläre
Konstruktoren entzuckern zu `x = C`, feldtragende zum
definitorischen `match x { C(..) => true, _ => false }`.

== Vergleich mit SMT-LIB

lu-kb ist auf die Verfassung von Beweispflichten mit reichen
Typen zugeschnitten, während SMT-LIB auf das Abtragen eines
flachen Ziels zugeschnitten ist:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Belang*], [*SMT-LIB*], [*lu-kb-Nachfolger*]),
  [Granularität], [Pro Ziel], [Pro Modul],
  [Konstanten], [`declare-const`], [`const x: T`],
  [Funktionen], [`declare-fun` / `define-fun`], [`fn`-Signatur / -Definition],
  [Verfeinerungstypen], [Nicht nativ], [`{v: T | φ}` in jeder Typposition],
  [Verträge], [Manuelle Nebenbedingungen], [Verfeinerte Pfeile + generisches `'p`],
  [Beweisstruktur], [Flaches assert/check], [`solve ... by ...`-Schnitt],
  [Typklassen], [Nicht nativ], [Typrelationen (gesetzeskonform durch Beweis)],
)

Beide Oberflächen kompilieren zur selben Kern-IR, sodass das
Engine-Verhalten identisch ist, sobald die Elaboration
erledigt ist — der Unterschied liegt vollständig darin, was
der *Autor* im Voraus ausdrücken kann.

== Editor-Integration

Die VS-Code-Erweiterung (unter `tooling/vscode-extension/`)
erkennt `.smt2` und die lu-kb-Erweiterungen. Der LSP-Server
(`adsmt-lsp`) routet Dateien nach Erweiterung an den
passenden Parser; die Vervollständigungsliste passt sich an
die aktive Oberfläche an und bietet die Nachfolger-Schlüsselwörter
(`sort`, `const`, `fn`, `data`, `axiom`, `assume`, `goal`,
`solve`) neben den älteren Block-Schlüsselwörtern, die der
Kompatibilitätsparser weiterhin akzeptiert.
