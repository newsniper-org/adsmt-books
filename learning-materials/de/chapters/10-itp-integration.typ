= ITP-Integration

== Drei Integrationen, ein Entwurf

adsmt liefert ITP-Integrationen für drei Systeme:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*Status*]),
  [Lean 4],   [Referenz im Tree (`adsmt-cert::prover_emit::lean`)],
  [Rocq],     [Außerhalb des Trees (`~/adsmt-contrib/adsmt-emit-rocq`)],
  [Isabelle], [Außerhalb des Trees (`~/adsmt-contrib/adsmt-emit-isabelle`)],
)

Die drei Integrationen teilen sich einen *Anker*-Trait, der
eine gleichschrittige Entwicklung erzwingt: jede neue
Zertifikat-Schrittart erfordert Implementierungen in allen
drei, bevor sie kompiliert (Begleitband Kap. 10). Die
Ausgabeform spiegelt sich exakt: jedes Lean-`have` entspricht
einer Rocq-Ltac2-`Notation.notation` und einem
Isabelle-Isar-`have`.

Lean 4 ist die Referenz. Rocq und Isabelle spiegeln.

== Lean 4 — die Referenz

Der Lean-4-Pfad:

1. Der Benutzer schreibt `smt_decide` oder `smt_abduce` in
   sein Beweisskript.
2. Die Taktik-Halterung kompiliert das Ziel zu SMT-LIB plus
   Kontexthypothesen.
3. `adsmt` löst; gibt ein Zertifikat aus.
4. `prover_emit::lean` übersetzt das Zertifikat in ein
   Lean-Taktikskript.
5. Lean's Elaborator + Kern prüfen das Skript. Bestehen sie,
   ist das ursprüngliche Ziel erledigt.

```lean
import Adsmt

example (a b c : Nat) (h1 : a = b) (h2 : b = c) : a = c := by
  smt_decide [h1, h2]
```

Hinter den Kulissen:

```text
goal:         a = c
hypotheses:   h1 : a = b, h2 : b = c
to SMT-LIB:   (assert (= a b)) (assert (= b c)) (assert (not (= a c)))
solver run:   unsat with cert
              (step :rule assume :id 1 :term (= a b))
              (step :rule assume :id 2 :term (= b c))
              (step :rule trans  :id 3 :lhs 1 :rhs 2)
              (step :rule assume :id 4 :term (not (= a c)))
              (step :rule deduct :id 5 :hyp 4 :conc 3)
emit:         have h_3 : a = c := Trans.trans h1 h2
              exact absurd h_3 (by intro; assumption)
Lean kernel:  ✓ goal discharged
```

Die Taktik verschwindet in einen vollständig kerngeprüften
Beweis. Die Zertifikatsschicht ist für den Benutzer
unsichtbar.

== `smt_decide` versus `smt_abduce`

Zwei Taktiken, zwei Absichten:

- `smt_decide` — adsmt im *deduktiven* Modus aufrufen. Nur
  `sat`-/`unsat`-Verdikte schließen das Ziel. `unknown`
  schlägt fehl.
- `smt_abduce` — adsmt im *abduktiven* Modus aufrufen.
  `unsat` schließt das Ziel; `abductive` bringt Kandidaten-
  `sorry`-Platzhalter im Skript zum Vorschein.

```lean
example (n : Nat) : f n ≤ g n := by
  smt_abduce
-- emits:
-- have hyp_f : ∀ n, f n ≤ n := by sorry
-- have hyp_g : ∀ n, n ≤ g n := by sorry
-- exact Nat.le_trans (hyp_f n) (hyp_g n)
```

Der Benutzer füllt die `sorry`s mit seinen eigenen Beweisen
aus (oder akzeptiert sie als zusätzliche Axiome im
Geltungsbereich). Die *Struktur* des Beweises wird von adsmt
geliefert; der *Inhalt* der Annahmen liegt in der
Verantwortung des Benutzers.

== `solve … by …` — Beweisterme innerhalb der Sprache

Die obigen Taktiken leben _außerhalb_ von adsmt: ein Lean-
oder Rocq-Skript ruft herein. Aber die
lukb-Nachfolgeroberfläche (`adsmt-ir-lukb`; siehe den
lukb-Anhang zur Implementierung von Grund auf) hat ihre
eigene _sprachinterne_ Brücke zum ITP-artigen Beweis. Es ist
ein einziges Konstrukt:

```lukb
solve G by L
```

Lies es als „_ein Beweis von `G`, gerechtfertigt durch das
Lemma `L`._" Sowohl `G` als auch `L` sind *Blöcke* — ein
Term oder eine `let`-Kette, die in einem Term endet —, sodass
du auf beiden Seiten Zwischenfakten aufbauen kannst.

Dies ist die *Schnittregel*, zur Syntax gemacht. Die
Elaboration (Semantik B: sie _konstruiert einen Beweisterm_,
sie führt den Solver nicht zur Parse-Zeit aus) gibt genau
zwei Verpflichtungen aus, jede über den umgebenden Kontext
abgeschlossen, sodass sie auf oberster Ebene wohlgeformt ist:

- das *Blatt* `L` — das Lemma erledigen, und
- die *Brücke* `L ⟹ G` — zeigen, dass das Lemma das Ziel
  impliziert.

Der Kern setzt das Beweisgerüst aus diesen beiden zusammen;
die Engine erledigt das Blatt. Da die einzige verwendete
Inferenz der Schnitt ist — kein Axiom, keine
Verdikt-Abkürzung —, ist `solve` per Konstruktion korrekt.
Der Korrektheitskern ist in Verus vorab verifiziert
(`~/solve-by-verification`, 5 verifiziert, 0 Fehler).

```lukb
// goal: the head of a sorted, non-empty list is its minimum.
goal head_is_min : is_min(head(xs), xs) =
  solve is_min(head(xs), xs)
  by    sorted(xs) and nonempty(xs)
```

Das Blatt `sorted(xs) ∧ nonempty(xs)` ist das, was _du_
schuldest; die Brücke `(sorted(xs) ∧ nonempty(xs)) ⟹
is_min(head(xs), xs)` ist das, was die Engine prüft. Die
Analogie zu `smt_abduce` ist exakt — `solve` ist das
deduktive, _bereits gerechtfertigte_ Geschwister eines
abduktiven `sorry`: du benennst das Lemma, anstatt eine Lücke
zu lassen, und adsmt verifiziert den Schritt, anstatt ihn zu
erraten.

== Verfeinerungstypen tragen die Absicht

Ein `solve` ist nur so scharf wie die Propositionen, die du
_formulieren_ kannst. Die lukb-Nachfolgeroberfläche formuliert
die Verifikationsabsicht mit *Verfeinerungstypen*: eine
Basis-Sorte, herausgeschnitten durch ein Prädikat,

```lukb
{ v: T | φ }
```

— die Sorte `T`, eingeschränkt auf jene `v`, die `φ`
erfüllen. Verfeinerungen sind überall dort verwendbar, wo ein
Typ steht: an einer `const`, an einem `fn`-Parameter oder
-Rückgabewert, auf jeder Seite eines Pfeils und als
Quantor-Binder. `Nat` und `WNat` sind selbst Verfeinerungen
von `Int` (`Nat = {x: Int | x ≥ 1}`,
`WNat = {x: Int | x ≥ 0}`).

Eine `const` an einem verfeinerten Typ postuliert _sowohl_ die
Typisierung _als auch_ das Prädikat als vertrauenswürdige
Tatsache:

```lukb
const c : { v: Int | v ≥ 0 }   // gives  c : Int  AND  c ≥ 0
```

Eine Verfeinerung an einem Quantor-Binder elaboriert über das
vorab verifizierte Relativierungslemma — die Polarität ist
das, was man sich merken muss:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Binder*], [*elaboriert zu*]),
  [`forall {v:T|φ}. ψ`], [`forall v:T. φ ⟹ ψ`],
  [`exists {v:T|φ}. ψ`], [`exists v:T. φ ∧ ψ`],
)

So schwächt `∀` zu einer Implikation ab, `∃` verstärkt zu
einer Konjunktion. Bekommst du die Polarität verkehrt herum,
hast du entweder eine vakuöse Verpflichtung oder eine
unerfüllbare; adsmts Elaborator korrigiert das für dich, aber
es lohnt sich, dies im Kopf zu behalten, wenn du das
entzuckerte Ziel liest.

*Funktionstypen und verfeinerte Pfeile.* `T -> U` ist der
Pfeil (rechtsassoziativ; `(A -> B) -> C` klammert eine
_Pfeil-Domäne_ ein). Verfeinere beide Enden, und der Pfeil
trägt einen Vertrag:

```lukb
{ u: A | 'p } -> { v: A | 'q }
```

— eine Vorbedingung `'p` an der Domäne, eine Nachbedingung
`'q` an der Kodomäne. Die _Wert_-Sorte ist nach wie vor das
schlichte `A -> A`; die Verfeinerungen sind beweisirrelevant
und werden beim Lowering gelöscht. Der Gewinn ist, dass ein
zu diesem Typ geliefertes Argument _dir seine Nachbedingung
`'q` als verwendbare Tatsache überreicht_ — genau die
Hypothese, die ein nachgelagertes `solve` will.

== Generische Prädikatparameter `'p`

Das führende einfache Anführungszeichen in `'p` oben ist
keine Dekoration: es markiert einen *generischen
Prädikatparameter* und macht eine Definition
prädikat-_polymorph_. Ein `fn`, dessen Verfeinerungen `'p`
erwähnen, bindet es implizit am Kopf als `Π('p : T → Prop)`,
und der Rumpf wird *einmal* typgeprüft, mit `'p` abstrakt
gehalten — die „Einmal-geprüft"-Garantie. Parameter-
Verfeinerungen werden zu Vorbedingungen, die
Rückgabe-Verfeinerung zu einer Nachbedingung, und der gesamte
Vertrag

$ forall arrow('p). thin forall arrow(x). thin
  (and.big_i "pre"_i) arrow.r.double "post" $

ist ein *Ziel*, wenn du die Funktion _definierst_ (die
Konstruktionsstellen-Verpflichtung, von der Engine erledigt),
und ein *vertrauenswürdiges Axiom*, wenn es nur eine
_Signatur_ ist. An einer Verwendungsstelle instanziierst du
`'p := q`; die nun monomorphe Vorbedingung wird auf der Stelle
erledigt. Dies ist *Dictionary-Passing*: der Aufrufer liefert
das Prädikat, über das der Aufgerufene abstrahiert hat.

Das einfache Anführungszeichen ist das, was zur Parse-Zeit ein
generisches `'q` von einem *konkreten* Prädikat `q` (ohne
Anführungszeichen) unterscheidet. Konkrete verfeinerte `fn`s
erhalten dieselbe Vertragsbehandlung — die Generizität ist der
einzige Unterschied.

*Das triviale Prädikat `nop`.* Aus Gründen der
Einheitlichkeit will die verfeinerungsbewusste Logik stets ein
Prädikat sehen, sodass ein _unverfeinertes_ `x: T` als
`{x: T | nop(x)}` gelesen wird, wobei

```lukb
nop : Π(T: Type). T → Prop := λ T x. true
```

Da `nop(x) ≡ true`, ist eine `nop`-Verfeinerung vakuös: sie
wird verworfen — keine Hypothese, kein Guard ausgegeben —,
sodass die entzuckerte Ausgabe sauber bleibt, und
`const c: {v:T|nop(v)}` ist einfach `const c: T`. Du wirst
`nop` niemals selbst schreiben; es ist das Identitätselement,
das es „verfeinert" und „unverfeinert" erlaubt, sich einen
Codepfad zu teilen.

== Alles zusammensetzen: Erhaltung

Diese Bausteine setzen sich zu einem kleinen, aber echten
Verifikations-Idiom zusammen. Angenommen, ein Datentyp `A` hat
viele Funktionen, und du willst sagen „_`f` erhält die
Eigenschaft `'p`._"

Der verlockende Zug ist, `Preserving('p)` zu einer
*Typrelation* zu machen (adsmts eigener Begriff für eine
Typklasse; siehe den nächsten Abschnitt). Das wurde versucht
und *zurückgezogen* — es ist die falsche Abstraktion. Eine
Typrelation ist _kohärent_: eine Instanz pro Typ. Aber `A`
kann _viele_ `'p`-erhaltende Funktionen haben und viele, die
es nicht tun. Die Erhaltung ist daher keine Eigenschaft des
Typs — sie ist eine Eigenschaft der *Funktion*, ein Prädikat
höherer Stufe `preserving(f)`, unabhängig für jedes `f`
geprüft.

Als _wiederverwendbares_ Prädikat wird die Erhaltung am
besten *definiert* — ein `Bool`-wertiges Prädikat höherer
Stufe, das die Aussage festhält, wobei `'p`/`'q` aus einem
verfeinerten Pfeilargument eingesammelt werden (ein
`Bool`-Rückgabewert trägt keine eigene Verpflichtung):

```lukb
fn preserving( f: { u: A | 'p(u) } -> { v: A | 'q(v) } ) : Bool =
  forall x: A. 'p(x) ==> 'p(f(x))
```

Die Arbeit fällt erst bei einer konkreten *Verwendung* an —
und genau dort verdient sich `solve … by …` seinen Platz. Mit
der Nachbedingung von `f` zur Hand (hier ein explizites
`axiom`, aus dem verfeinerten Pfeiltyp von `f`) entlädt der
Schnitt ein konkretes Ziel „`f` erhält `p`":

```lukb
const p: A -> Bool    const q: A -> Bool    const f: A -> A
axiom post_f: forall {x: A | p(x)}. q(f(x))
goal:
  solve forall {x: A | p(x)}. p(f(x))
  by    forall {y = f(x) | p(x)}. q(y) ==> p(y)
```

Das Blatt — „`q ==> p` auf dem Bild" — ist der eigentliche
Inhalt; die Brücke verbindet es mit `post_f`, um das Ziel zu
schließen. Warum eine *Definition* und kein
beweiserzeugendes `fn`? Ein `preserving`, das `solve … by …` in seinem Rumpf
ausführte und _einmal_ über ein _generisches_ `'p`/`'q`
geprüft würde, wäre *unsolide*: sein Blatt
`∀'p 'q f. 'q(f x) ==> 'p(f x)` ist im Allgemeinen falsch.
Das Prädikat wird also _einmal_ *formuliert* und pro konkreter
Verwendung *entladen*.

== Bild-Binder — die Inferenz erledigt die Arbeit

Eine weitere Binder-Form, fast vollständig von der
Typinferenz getrieben. Ein *Bild-Binder*

```lukb
forall { y = f(x) | c }. q(y)
```

läuft über das inferierte _Urbild_ `x` (seine Sorte ist die
Domäne von `f`), schützt es durch `c` und entfaltet `y` zu
`f(x)` im Rumpf. Nach dem vorab verifizierten
`image_quantifier_desugar` ist er genau

```lukb
forall x: { A | c }. q(f(x))
```

Du schreibst den Quantor in Begriffen des _Werts, der dich
interessiert_ (`y`, im Bild von `f`); adsmt stellt die
Variable wieder her, über die er tatsächlich laufen muss (`x`,
in der Domäne). Es ist eine kleine Annehmlichkeit, die sich so
liest, wie die Mathematik sich liest.

== Typrelationen sind Typklassen

„_Typrelation_" ist adsmts Name für eine Typklasse — *ein*
Konzept, und `adsmt-class` ist buchstäblich die
Typklassenschicht (`Relation` / `Instance` / `Resolver` /
`Dict` / `Law`). Die *\*Like-Familie* — `PartialOrd` → `Ord`
→ `IntegerLike`, `RealLike`, … — teilt sich ein
`Reduces`-Rückgrat, und `IntegerLike(I, L, N)` ist die erste
_höherwertige_ (higher-kinded) Instanz.

Zwei Eigenschaften zählen für die Verifikation:

- *Lawful-durch-Beweis.* Eine Relation trägt neben ihren
  Methoden-Mitgliedern auch *Gesetzes*-Zielmitglieder. Eine
  Instanz wird nur dann zugelassen, wenn adsmts _eigene
  Engine_ jedes Gesetz beweist — andernfalls wird der Build
  *abgelehnt* (`declare_instance_lawful` + ein
  Engine-gestützter `LawProver`). Derselbe Solver, der ein
  `solve`-Blatt erledigt, ist es, der zertifiziert, dass `Ord`
  für deinen Typ tatsächlich eine totale Ordnung ist.
- *Prädikatparameter.* Eine Relation kann einen
  Prädikatparameter `'p : T → Prop` tragen, den eine Instanz
  als *Dictionary*-Eintrag liefert — dasselbe
  Dictionary-Passing, das du bei generischen `fn`s gesehen
  hast, nun auf Instanzebene.

Dies ist eine Facette des *Vier-Wege-Verbunds*, der adsmts
zentrale Entwurfsabsicht ist: Typinferenz, abduktiv-deduktive
Logik, ASP und SMT (plus HKT) sollen _organisch_
ineinandergreifen, statt in getrennten Silos zu sitzen.
`IntegerLike(I, L, N)` ist das Bindegewebe — Typinformation,
die durch eine höherwertige Instanz in die Engines fließt, die
`solve` heranzieht.

== Rocq-Integration

Das Rocq-Backend (`~/adsmt-contrib/adsmt-emit-rocq`) gibt
Ltac2-Taktiken aus (kein Ltac1 — Ltac1 ist gemäß der
prover_emit-Richtlinie ausgeschlossen). Die Ausgabeform
spiegelt die Lean-Referenz:

```coq
From Adsmt Require Import AdsmtTactic.

Example example_eq : forall (a b c : nat), a = b -> b = c -> a = c.
Proof.
  intros a b c h1 h2.
  adsmt_decide [h1; h2].
Qed.
```

Die Taktik ruft adsmt auf, holt sich das Zertifikat, erzeugt
ein Ltac2-Skript, das die Schritte des Zertifikats durchläuft.
Jeder Zertifikatschritt wird zu einem Ltac2-`assert` mit
einer kleinen Zeugen-Taktik.

== Isabelle-Integration

Das Isabelle-Backend
(`~/adsmt-contrib/adsmt-emit-isabelle`) gibt Isar-Syntax aus
und spiegelt erneut Lean:

```isabelle
lemma example_eq:
  fixes a b c :: nat
  assumes h1: "a = b" and h2: "b = c"
  shows "a = c"
proof -
  have h_3: "a = c" by (rule trans, fact h1, fact h2)
  show ?thesis by fact
qed
```

Die Beweisstruktur spiegelt Lean/Rocq exakt; nur die
Oberflächensyntax unterscheidet sich. Die
Gleichschritt-Eigenschaft wird durch einen
Round-Trip-Diff-Test durchgesetzt (Begleitband Kap. 10).

== Hygiene klassischer Axiome

Jedes Backend importiert die in der Präambel des Zertifikats
genannten klassischen Axiome *auf Anforderung*. Ein
Lean-Zertifikat, das LEM zitiert, importiert `Classical.em`;
ein Rocq-Zertifikat importiert `Classical_Prop.classic`; ein
Isabelle-Zertifikat importiert `HOL.Classical`.

Wenn das Ziel eines Backends ein benanntes Axiom nicht
unterstützt — z. B. ein streng konstruktives Lean-Modul, das
`Classical.em` ablehnt — verweigert das Emit mit einer
Diagnose. Der Benutzer akzeptiert entweder den klassischen
Import oder bittet den Solver, mit deaktivierten klassischen
Axiomen erneut zu versuchen.

== Performance-Überlegungen

Drei wissenswerte Stellschrauben:

*1. Zertifikatsgröße.* Ein großes Ziel kann ein
mehrere-kB-großes Zertifikat erzeugen. Die Emit-Zeiten
skalieren linear; die ITP-Elaboration skaliert linear. Für
interaktive Nutzung ist Subsekunden-Antwort das Ziel; der
LSP-Pfad (günstige Neuprüfung) hält dies aufrecht.

*2. Taktik-Granularität.* `smt_decide` pro Teilziel ist in
Ordnung; `smt_decide` über eine riesige Disjunktion ist
langsam. Aufteilen, bevor aufgerufen wird.

*3. Abduktive Kosten.* Das abduktive Suchbudget ist begrenzt
(`:abductive-tier 0..4` in SMT-LIB oder das Äquivalent in
der Taktikoberfläche). Tier 4 ist am aggressivsten und am
teuersten.

== Wann SMT-als-Taktik glänzt

- *Gleichheitsketten.* "$a = b$, $b = c$, $c = d$, …, beweise
  $a = z$." Das EUF von adsmt erledigt dies in Mikrosekunden;
  Lean's `congr`-Taktik-Kette ist ähnlich, aber mühsamer zu
  schreiben.
- *Lineare Arithmetik.* "Beweise $3x + 2y >= 5$ unter
  $x >= 1$, $y >= 1$." LIA via Simplex. Lean's `linarith`
  schafft das auch — adsmt erweitert es um den
  Farkas-Zeugen-Zertifikatspfad für Transparenz.
- *Bitvektor-Identitäten.* "Beweise
  `(x ^ y) ^ x = y`." Bit-Blasting entscheidet. Lean's
  `bv_decide` ist das nächstgelegene Lean-interne Äquivalent.

== Wann SMT-als-Taktik kämpft

- *Induktion.* SMT führt keine Induktion durch. Der ITP tut
  es.
- *Schließen höherer Stufe, das Unifikation benötigt.* SMT
  verwendet Miller-Muster; Lean's Unifikator höherer Stufe
  ist weit mächtiger.
- *Domänenspezifische Automatisierung* — Kategorientheorie,
  kubische Konstruktionen, mengentheoretische
  Konstruktionen. SMT ist allgemein; spezialisierte Taktiken
  übertreffen es.

Die Kombination ist die Stärke: nutzen Sie SMT dort, wo es
glänzt (konkretes erstes Ordnung, Gleichheit, Arithmetik),
nutzen Sie die einheimischen Taktiken des ITPs dort, wo SMT
nicht helfen kann. Der Entwurf von adsmt — abduktiver
Ausweg, transparente Zertifikate, ITP-freundliche Emission —
ist um diese Aufteilung herum aufgebaut.

== Ein vollständig durchgearbeitetes Beispiel

Ein kleiner Lean-4-Beweis mit `smt_abduce`:

```lean
import Adsmt

example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  smt_abduce
```

Die abduktive Ausgabe:

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := by
    sorry  -- abductive candidate 1
  exact h xs.head! h_head_in
```

Der Benutzer liest die Kandidatenhypothese
(`xs.head! ∈ xs`, die für nicht-leere Listen wahr ist) und
erledigt sie mit `exact List.head!_mem_of_ne_nil hne`. Der
vollständige Beweis:

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := List.head!_mem_of_ne_nil hne
  exact h xs.head! h_head_in
```

adsmt fand die Struktur; der Benutzer lieferte das
Bereichswissen.

Dies — *Partnerschaft zwischen Solver und Beweiser* — ist,
wofür adsmt da ist. Die externen Taktiken (`smt_decide`,
`smt_abduce`) und der sprachinterne Beweisterm
(`solve … by …`) sind zwei Wege zum selben Ort: in beiden
benennt der Mensch die Absicht — eine zu füllende Hypothese,
eine zu tragende Verfeinerung, ein Lemma, auf das geschnitten
wird — und die Engine erledigt die Verpflichtung unter einem
kerngeprüften Gerüst. Ob der Beweis in Lean oder in einem
lukb-`goal` lebt, die Arbeitsteilung ist dieselbe.
