= Typen und Klassen

== Warum höher-gekindete Typen

Klassische SMT-Solver arbeiten in mehrsortiger
Prädikatenlogik erster Stufe. „Sorten" sind in dieser
Umgebung flach: es gibt eine `Int`-Sorte, eine
`Real`-Sorte, eine `Bool`-Sorte, eine Array-Sorte
`(Array I E)` für jedes Paar aus Index- und Elementsorte
und so weiter. Typabstraktion — eine Sorte zu nehmen und
über eine andere Sorte zu parametrisieren — wird auf der
Meta-Ebene vom Signatur­bauer durchgeführt und ist in der
Formelsprache selbst nicht sichtbar.

Das funktioniert für den Großteil der SMT-Lasten gut. Es
gerät an der Grenze zu interaktiven Theorembeweisern in
Reibung, die routinemäßig Beweise *über* Funktoren,
Funktionen auf Typebene oder polymorphe Strukturen
manipulieren. Um eine Beweisverpflichtung aus Lean 4 in
den SMT-Solver hinein und wieder hinaus zu reflektieren,
muss der Solver über dieselben Dinge sprechen können wie
Lean: über Typen, die über Typen parametrisiert sind, über
Instanzen bei höheren Kinds und über echte Polymorphie auf
Typebene.

Die Lösung von adsmt besteht darin, *höher-gekindete
Typen* an der eigenen Oberfläche des Solvers zuzulassen.
Ein Typ darf seinerseits über einen anderen Typ
parametrisiert sein, so wie `List` in Haskell auf jeden
Elementtyp angewendet werden kann, um `List Int`,
`List String`, `List (List Bool)` und so weiter zu
liefern. Konkret fügt das Kind-System die üblichen
Kind-Bildner hinzu:

$ kappa ::= "Type" | kappa_1 -> kappa_2 $

und die Typen werden nun stratifiziert:

$ tau ::= alpha^kappa | C^kappa | tau_1 tau_2 | tau_1 -> tau_2 $

wobei die Kind-Annotation $kappa$ an jeder Variablen und
Konstanten festhält, wie viele Typargumente die Entität
erwartet. `Int` hat den Kind `Type`; `List` hat den Kind
`Type -> Type`; die Klasse `Functor` operiert auf
Entitäten des Kinds `Type -> Type`; und so weiter.

== Polymorphe Konstanten

Eine polymorphe Konstante wie `id : forall alpha. alpha -> alpha`
hat ein Typschema — einen universell quantifizierten Typ —
statt eines einzigen Typs. Wird `id` mit einer bestimmten
Instanziierung verwendet (etwa `id @Int`), führt die
Kernregel `InstType` die Substitution durch. Das ist
dieselbe Maschinerie wie der Polymorphismus im ML-Stil,
gehoben, um höhere Kinds zuzulassen.

Im Code:

```rust
pub struct TyVar { pub name: String, pub kind: Kind }
pub enum Type {
    Var(Arc<TyVar>),
    Const(Arc<TyConst>),
    App(Arc<Type>, Arc<Type>),
    Fun(Arc<Type>, Arc<Type>),
}

pub fn inst_type(
    sigma: &[(Arc<TyVar>, Type)],
    thm: &Theorem,
) -> KernelResult<Theorem> {
    // Substitute every TyVar matching sigma's left-hand sides;
    // produce a new Theorem at the substituted types.
}
```

`inst_type` ist eine der zwölf Kernregeln; sie ist formal
eine partielle Funktion, weil die Substitution die Kinds
respektieren muss.

== Refinement-Typen: das typisierte Substrat

Bevor wir zu den Klassen kommen, verdient sich eine Zutat
ihren Platz unmittelbar neben dem Sortensystem: eine Sorte
kann *durch ein Prädikat zugeschnitten* werden. Ein
*Refinement-Typ* `{v : T | φ}` ist die Basissorte `T`,
beschränkt auf jene Werte, für die `φ` gilt. Das ist das
typisierte Substrat, auf dem der Rest des Kapitels aufbaut,
und es landet in der Nachfolge-Oberfläche von lu-kb
(`adsmt-ir-lukb`).

Refinements sind überall dort verwendbar, wo ein Typ steht:
in `const`, in der `fn`-Parameter- und der
`fn`-Rückgabeposition, auf beiden Seiten eines Pfeils und
als Quantor-Binder. Sie bedeuten an jeder Stelle etwas
anderes, doch alle drei Lesarten kommen aus derselben
Quelle — ein Refinement ist Elaborations-*Zucker* über dem
bestehenden CIC-Kern und fügt daher keine vertrauenswürdige
Oberfläche hinzu:

- Eine *Konstante* `const c : {v : T | φ}` postuliert
  `c : T` *plus* die vertrauenswürdige Tatsache `φ[v := c]`.
  (Diese Tatsache fallenzulassen wäre unsound — genauso wie
  es das Fallenlassen der Positivität von `Nat` an einer
  freien Konstante wäre.)
- Ein *Quantor-Binder* relativiert nach Polarität. Das
  vorverifizierte Relativierungslemma besagt, dass
  `∀(x : {v:T|φ}). P` zu `∀(x:T). φ(x) ⟹ P` wird, und dual
  wird `∃` zu `∧`. (Die Allquantifizierung sichert mit
  einer Implikation, die Existenzquantifizierung mit einer
  Konjunktion.)
- Eine *Pfeil-Domäne* `{v:T|φ} -> U` ist eine
  *Vorbedingung*; eine *Pfeil-Kodomäne* `A -> {v:T|ψ}` ist
  eine *Nachbedingung*. Auf verfeinerte Pfeile kommen wir
  weiter unten zurück.

Im Kern ist eine verfeinerte Domäne nichts anderes als
`Π(v:T). φ(v) -> Cod` (ein `T` zusammen mit einem Beweis
von `φ(v)`), und ein verfeinertes Ergebnis ist
`Σ(v:T). φ(v)` (ein `T` zusammen mit einem Beweis). Die
Beweiskomponenten sind `Prop`-sortiert, beweis-irrelevant
und werden *beim Lowering gelöscht*: die SMT-Seite sieht
stets nur die Basissorte `T` und das durch die
Relativierung geleitete Prädikat `φ`. Ein fehlgeformtes
Refinement kann daher nur die Typprüfung nicht bestehen —
es kann die Engine niemals als etwas anderes als eine
gewöhnliche bewachte Formel erreichen.

`Nat` und `WNat` sind keine eingebauten Sorten; sie sind
zwei benannte Refinements von `Int`:

```
Nat  = {x : Int | x >= 1}
WNat = {x : Int | x >= 0}
```

Ihre Positivität ist genau die Refinement-Wache, weshalb
dieselbe Maschinerie, die ein vom Anwender geschriebenes
`{n : Int | n > 0}` behandelt, auch sie behandelt.

=== `nop`: das triviale Prädikat

Es gibt einen Uniformitätstrick, der all dies sauber hält.
Ein eingebautes triviales Prädikat

$ "nop" : Pi(T : "Type"). T -> "Prop" := lambda T med x. "true" $

lässt ein *unverfeinertes* `x : T` als `{x : T | nop(x)}`
lesen. Die refinement-bewusste Logik sieht dann stets ein
Prädikat — `φ` oder `nop` — und braucht nie einen
Sonderfall „verfeinert versus unverfeinert". Da
`nop(x) ≡ true` gilt, ist ein `nop`-Refinement *vakuös*: es
wird fallengelassen und emittiert keine Wache, keine
Hypothese und keinen Vertrag, sodass die Ausgabe sauber
bleibt, während die Struktur uniform bleibt.
`const c : {v:T | nop(v)}` ist einfach `const c : T`; ein
schlichter Pfeil `A -> A` ist `{u:A|nop} -> {v:A|nop}`,
dessen Erhaltungsverpflichtungen trivial `true` sind.

== Funktionstypen und verfeinerte Pfeile

Ein Funktionstyp `T -> U` ist der Pfeil-Bildner,
rechtsassoziativ: `A -> B -> C` wird als `A -> (B -> C)`
geparst. Um einen Pfeil in die *Domänen*-Position zu
setzen, klammert man ihn ein, sodass `(A -> B) -> C` eine
Funktion ist, die eine Funktion entgegennimmt.

Ein *verfeinerter Pfeil* setzt Refinements an die beiden
Enden:

```
{u : A | 'p} -> {v : A | 'q}
```

Seine Wertsorte ist der schlichte `A -> A` — die
Refinements sind beweis-irrelevant und werden beim Lowering
gelöscht. Was die Refinements erkaufen, ist ein *Vertrag*:
das Domänen-Refinement `'p` ist eine Vorbedingung, die der
Aufrufer herstellen muss, und das Kodomänen-Refinement `'q`
ist eine Nachbedingung. Entscheidend ist, dass der Vertrag
*in den Rumpf hinein* fließt, wenn ein solcher Pfeil als
*Argument* übergeben wird: ein Parameter `f` vom Typ eines
verfeinerten Pfeils macht die Tatsache

$ "post"_f : forall (x : A). #raw("'p(x)") ==> #raw("'q(f(x))") $

als verwendbare Hypothese verfügbar. Das ist keine
unbewiesene Annahme — `f` beim verfeinerten Pfeiltyp zu
liefern hat denjenigen, der `f` definiert hat, bereits
verpflichtet, sie herzustellen.

== Generische Prädikatparameter

Die `'p` und `'q` oben waren keine konkreten Prädikate; das
führende einfache Anführungszeichen kennzeichnet sie als
*generische Prädikatparameter*. Das ist
*Prädikatpolymorphie*: eine Funktion kann in dem Constraint,
den sie erhält, parametrisch sein — so wie eine gewöhnliche
polymorphe Funktion in einem Typ parametrisch ist.

Das einfache Anführungszeichen ist der Unterscheider, zur
Parse-Zeit ohne Inferenz entschieden: `'p` ist generisch,
ein nacktes `q` ist ein konkretes Prädikat im Sichtbereich.
So verfeinert `{v:T | q(v)}` durch ein bestimmtes `q`,
während `{v:T | 'p(v)}` durch einen Parameter verfeinert.

Eine `fn`, deren Refinements `'p` erwähnen, bindet es am
Kopf *implizit* als `Π('p : T -> Prop)`. Der Gewinn ist die
Garantie der *Einmal-Prüfung*: der Rumpf wird ein einziges
Mal mit abstrakt gehaltenem `'p` typgeprüft, statt pro
Verwendungsstelle neu elaboriert zu werden (was die
Monomorphisierung täte). Jedes Parameter-Refinement ist
eine Vorbedingung, das Rückgabe-Refinement eine
Nachbedingung, und der resultierende Vertrag

$ forall arrow(#raw("'p")). forall arrow(x). (and.big_i "pre"_i) ==> "post" $

wird auf zweierlei Weise behandelt:

- Für eine *Definition* ist der Vertrag ein *Ziel* — die
  Verpflichtung an der Konstruktionsstelle, die der Rumpf
  abtragen muss.
- Für eine *Signatur* ist der Vertrag ein
  *vertrauenswürdiges Axiom* — der Anwender behauptet ihn,
  und stattdessen werden die Verwendungsstellen verpflichtet.

An einer Verwendungsstelle wird `'p := q` instanziiert, der
Vertrag wird monomorph, und die nun konkrete Vorbedingung
wird abgetragen. Das ist *Wörterbuch-Übergabe*: das
Wörterbuch ist das konkrete Prädikat `q` plus der Beweis auf
Wertebene, dass das Argument es erfüllt. Konkrete
Refinement-Funktionen (jene ganz ohne `'p`) erhalten die
identische Vertragsbehandlung; sie sind einfach der
Sonderfall, in dem das Wörterbuch im Voraus festgelegt ist.

Im Kern ist nichts davon neu: `g : {v:A|'p} -> {v:A|'p}`
ist `Π(p:A→Prop). Π(v:A). p(v) → Σ(w:A). p(w)`, ein
gewöhnlicher abhängiger Typ, den der Kern bereits prüft. Die
Prädikatpolymorphie lebt vollständig auf der
Wörterbuch-Schicht und teilt ihre Wahrheitsquelle mit der
Typklassen-Maschinerie, der wir uns als Nächstes zuwenden —
nur monomorphe Instanzen erreichen je die Engine.

== Typklassen sind Typrelationen

Der Begriff von adsmt für eine Typklasse ist eine
*Typrelation*. Das sind nicht zwei Schichten, die einander
ähneln; es ist *ein Konzept unter einem Namen*. Die Crate,
die sie implementiert, heißt `adsmt-class` und ist
buchstäblich die Typklassen-Schicht; alles, was sie
manipuliert, nennt sie eine Relation. Wenn dieses Buch
„Typrelation" sagt, meint es genau das, was Haskell oder
Lean 4 eine Typklasse nennen würden.

Eine Typrelation ist eine prädikatsförmige Relation über
Typen, zusammen mit einem expliziten Wörterbuch von
Operationen. In der Oberfläche schreibt ein Anwender eine
Klasse mit Methoden und deklariert Instanzen; was der Kern
und `adsmt-class` sehen, ist:

- Eine *`Relation`* fester Stelligkeit — ein oder mehrere
  Typparameter, gegebenenfalls mit Kind-Einschränkungen, die
  die Methodensignaturen tragen (und, wie wir sehen werden,
  Gesetze und Prädikatparameter).
- *`Instance`*-Zeugen, die behaupten, dass bestimmte Typen
  die Relation bewohnen, jeder begleitet vom Wörterbuch der
  Operationsrümpfe, gegebenenfalls über *Prämissen* auf
  anderen Relationen.
- Ein *`Resolver`*, der an jeder Verwendungsstelle die
  Instanzsuche durchführt und die Prämissen abschreitet, um
  das vollständige `Dict` zusammenzusetzen.

Die Randregel `Instance` (Kapitel 2) ist genau die Grenze
zu dieser Schicht: sie delegiert die Instanz-Erfüllung an
den Typklassen-Elaborator und vertraut dem zurückgegebenen
Zeugen.

=== Wörterbuch-Übergabe

Relationen werden durch *Wörterbuch-Übergabe* wegcompiliert:
jede relations-eingeschränkte Funktion erhält an jeder
Verwendungsstelle einen expliziten Wörterbuch-Parameter.
Eine Funktion

```
sort : (Ord a) => List a -> List a
```

wird zu

```
sort_with_dict : OrdDict a -> List a -> List a
```

mit explizit hindurchgereichtem Wörterbuch. Der Solver
benötigt intern niemals erstklassige Instanzen; sobald die
Wörterbuch-Übergabe vorgenommen worden ist, sieht der Rest
des Systems gewöhnliche Funktionsanwendungen. Es ist
dieselbe Technik, die GHC für Haskell-Klassen und Lean 4
für seine Typklassen-Schicht verwendet — und, wie der
vorige Abschnitt zeigte, ist es auch genau, wie ein
generischer Prädikatparameter `'p` fließt: ein
Refinement-Prädikat reist als Wörterbuch-Eintrag auf
dieselbe Weise wie eine Methode.

== Gesetzeskonforme Instanzen durch Beweis

Eine Typrelation trägt mehr als Methoden-*Signaturen*. Sie
kann *Gesetze* tragen — Beweisverpflichtungen, die jede
Instanz abtragen muss, um zugelassen zu werden. Die
Entwurfsabsicht ist unverblümt: lass Ziele als Mitglieder
einer Relation stehen, ganz wie ihre Funktionen, und lass
*nur* die Instanzen zu, die jedes einzelne dieser Ziele
beweisen. Eine Deklaration, die ein Gesetz nicht besteht,
wird nicht zur Laufzeit markiert; sie wird *beim Bauen
abgewiesen*.

Ein `Law` ist ein benannter Verpflichtungs-*Bauer*: gegeben
eine `Dict`-Sicht auf eine Instanz — ihre Trägertyp(en) plus
ein Methoden-Resolver, der durch die Prämissen der Instanz
hindurch in die Superklassen-Wörterbücher reicht —
konstruiert er die konkrete geschlossene, `Bool`-typisierte
HOL-Proposition, die gelten muss. Da der Bauer ein
schlichter Funktionszeiger ist, fügt er keinen
Closure-Zustand hinzu und lässt `Relation` günstig `Clone`
bleiben. Bei der Zulassung baut `declare_instance_lawful`
jedes Gesetz und übergibt es einem `LawProver`; die Instanz
wird nur zugelassen, wenn *jede* Verpflichtung als gültig
bewiesen ist.

Die Soundness-Richtung ist einseitig, und das ist der ganze
Punkt. `LawProver::prove_valid` liefert nur dann `true`,
wenn es echt einen Beweis hat (die Negation des Ziels ist
unerfüllbar). Es darf für ein gültiges-aber-unbeweisbares
Ziel `false` liefern — das *weist* eine Instanz lediglich
*ab* (ein Vollständigkeitsverlust); es kann niemals eine
ungesetzliche *zulassen*. Das Tor ist konservativ, nie
unsound, und es ist adsmts *eigene* Engine, die den
`LawProver` trägt: die Gesetze einer Relation werden von
demselben Solver abgetragen, durch den alles andere läuft.

```rust
pub fn install_numberlike_checked(
    db: &mut InstanceDb,
    prover: &dyn LawProver,
) -> Result<(), ClassError> {
    // Each instance's laws are built and proven before it is
    // admitted; an unproven law rejects the declaration with
    // ClassError::LawUnproven { relation, law }.
}
```

== Die `*Like`-Familie

Die Aushänge-Schilder unter den gesetzeskonformen
Relationen sind die `*Like`-Zahlensystem-Familie, deklariert
als echte `adsmt-class`-Relationen. Sie bilden eine
Hierarchie entlang zweier Achsen, die ein gemeinsames
`Reduces`-Rückgrat teilen (die Codieren/Decodieren-Brücke,
die eine trägerwertige Operation in die ganzen Zahlen
reduzieren lässt):

- *Ordnungs-Achse.* `PartialOrd(I)` stellt eine
  Halbordnung `le : I -> I -> Bool` mit den Gesetzen der
  *Reflexivität*, *Antisymmetrie* und *Transitivität*
  bereit. `Ord(I)` ist der Subtrait der Totalordnung: er
  setzt `PartialOrd(I)` voraus, fügt das *Totalitäts*-Gesetz
  `∀a b. le a b ∨ le b a` hinzu und führt *keine neue
  Methode* ein — `le` wird über die Prämisse geerbt, dieselbe
  Gestalt wie Rusts `Ord : PartialOrd`.

- *Ganzzahl-Achse.* `PartialIntegerLike(I)` ist der
  ganzzahlartige kommutative Kern `{add, mul, domain}`,
  wobei `domain` das pro-Träger-Gültigkeits-/
  Positivitätsprädikat ist. Er lässt absichtlich `zero` aus
  (da `0 ∉ Nat`) sowie `neg`/`sub` (da `Nat`/`WNat` nicht
  subtraktionsabgeschlossen sind). `IntegerLike(I)` setzt
  sowohl `PartialIntegerLike(I)` als auch `Ord(I)` voraus:
  ein ganzzahlartiger Träger, der *auch* total geordnet ist.
  Er ist ein reiner Konjunktions-Marker — keine eigenen
  Methoden, keine eigenen Gesetze, alles über die zwei
  Prämissen geerbt.

Das prämissen-bewusste `Dict` ist es, das die Vererbung
funktionieren lässt. Das Totalitäts-Gesetz von `Ord`
verweist auf `le`, das im `PartialOrd`-Wörterbuch lebt;
`Dict::method` löst es über die Prämisse der `Ord`-Instanz
auf. Superklassen werden vor Subklassen zugelassen, gerade
damit ein Subtrait-Gesetz eine geerbte Methode gegen eine
bereits zugelassene Prämisse auflösen kann.

Die Grundinstanzen sind die lu-kb-Arithmetik-Träger `Int`,
`Nat` und `WNat`. Ihr Wörterbuch-Inhalt knüpft direkt an die
Refinements an:

- `le` ist `Int.le` für `Int`; für `Nat`/`WNat` ist es die
  Einschränkung der Ordnung von `ℤ` durch die
  Ganzzahl-Injektion, `λa b. Int.le (ι a) (ι b)` (ein
  `Bool`-Ergebnis braucht keine Rück-Injektion, also ist die
  Einschränkung total und sound).
- `domain` ist `⊤` für `Int`, `ι x ≥ 0` für `WNat` und
  `ι x ≥ 1` für `Nat` — eben die Positivitätsprädikate, die
  die `WNat`/`Nat`-Refinements definieren.

Das gesetzeskonforme Tor ist hier keine Dekoration. Eine
`Ord`-Instanz wird nur zugelassen, wenn die Engine die
*Totalität* für ihr `le` abträgt; ein Träger ohne
kompatible Totalordnung — ein künftiges
`FloatingPoint(M, E)` mit `NaN`, etwa — wird durch dieses
Tor abgewiesen und bleibt nur `PartialOrd`.

== Prädikatparameter an einer Relation

Über Methoden und Gesetze hinaus kann eine Relation einen
*Prädikatparameter* `'p : T -> Prop` tragen — die
Relations-Ebenen-Form der generischen Constraint-Parameter
von vorhin. Eine Instanz liefert das konkrete Prädikat als
Wörterbuch-Eintrag, und ein `'p`-Constraint löst dann genau
wie ein Methoden-Constraint auf, indem es durch dasselbe
`Relation`-/`Instance`-/`Resolver`-/`Dict`-Rückgrat fließt.
Das Datenmodell steht: `Relation::pred_params`,
`Instance::preds` und `Dict::pred` / `require_pred`, mit zur
Deklarationszeit validierter Stelligkeit. Das ist die
Registry-Hälfte der Prädikatpolymorphie — das
Funktions-Ebenen-`Π('p)` von vorhin gibt den
einmal-geprüften Vertrag; das Relations-Ebenen-`'p` lässt
dieses Prädikat als Wörterbuch über den gesamten Verbund
fließen, eine Wahrheitsquelle, die mit den Methoden geteilt
wird.

== Erhaltung ist ein Prädikat, keine Relation

Es ist verlockend, „erhält `'p`" zu einer Relation zu machen
— etwas wie `Preserving('p)` mit einer Instanz pro Typ. Das
ist die *falsche Abstraktion*, und der Grund ist Kohärenz.
Eine Typrelation ist *kohärent*: es gibt eine kanonische
Instanz pro Typ. Aber ein Datentyp `A` kann *viele*
Funktionen haben, die ein gegebenes `'p` erhalten, und sie
müssen nicht übereinstimmen. Erhaltung ist daher eine
Eigenschaft einer *Funktion*, nicht eines Typs, und die
richtige Gestalt dafür ist ein *Prädikat höherer Ordnung*
`preserving(f)`, das unabhängig pro Funktion geprüft wird.
(Eine frühere `Preserving('p)`-Relation wurde gebaut und
dann ausgemustert, sobald dies klar war.)

Wie *drückt man so eine pro-Funktion-Eigenschaft aus* in der
Oberfläche? Als genau das, was sie ist — ein *definiertes
Prädikat höherer Ordnung*. `preserving` nimmt die Funktion
und formuliert die Erhaltungs-Proposition unmittelbar:

```
fn preserving(f : {u:A | 'p(u)} -> {v:A | 'q(v)}) -> Bool
    = forall x : A. 'p(x) ==> 'p(f(x))
```

Das verfeinerter-Pfeil-Argument wird zum Wertpfeil `A -> A`
gelöscht; seine Domänen-/Kodomänen-Prädikate `'p` und `'q`
werden aus dem Inneren des Pfeils eingesammelt und am Kopf
*implizit* gebunden (Prädikatpolymorphie), sodass der Rumpf
`'p` benennen darf. Eine solche `Bool`-typisierte Definition
ist nur eine δ-Definition einer Proposition — sie trägt
*keine eigene Verpflichtung*. Die Verpflichtung erscheint
erst an einer *Verwendungsstelle*: `preserving(even, ge0, double)`
entfaltet sich zum konkreten `∀x. even(x) ⟹ even(double(x))`,
das die Engine abträgt. (Die schlichteste wiederverwendbare
Form braucht überhaupt keine Generizität — das erhaltene
Prädikat kann ein gewöhnliches Argument höherer Ordnung sein,
`fn preserving(p : A -> Bool, f : A -> A) -> Bool = forall x. p(x) ==> p(f(x))`.)

Das ist die Auflösung einer feinen Falle. Wäre `preserving`
eine beweis-*erzeugende* `fn` — ein Rumpf, der
`solve … by …` ausführt und den Beweis zurückgibt —, so
wäre ihre über das *generische* `'p` und `'q` geschlossene
Blatt-Verpflichtung `∀'p 'q f. ('q(f x) ==> 'p(f x))`, und
die ist schlicht *falsch* (nimm `'p := λn. n >= 0`,
`'q := λn. n >= −5`, `f := λn. n − 3`: `f` bewohnt den
verfeinerten Pfeil, doch `f(0) = −3` ist nicht `>= 0`). Eine
Definitionsstelle kann sie nicht abtragen. Als *Prädikat*
gibt es überhaupt kein Definitions-Blatt — das Blatt
materialisiert sich erst an einer konkreten Verwendung, wo
es ehrlich und beweisbar-oder-nicht ist.

Wenn man also ein konkretes `preserving(f)`-Ziel von Hand
*beweisen* will — unter Berufung auf das Bildlemma
`'q ==> 'p` zusammen mit `f`s Nachbedingung
`post_f : ∀x. 'p(x) ==> 'q(f(x))` (vorerst als `axiom`
behauptet) —, dann ist das genau das `solve … by …`-Konstrukt
des nächsten Abschnitts. Die Definition *formuliert* die
Eigenschaft; der Schnitt *trägt sie ab*.

== `solve … by …`: Beweisterme in der Oberfläche

`solve G by L` ist ein sprachinterner *Beweisterm*: ein
Beweis der Proposition `G`, gerechtfertigt durch das Lemma
`L`. Es ist der *Schnitt* des strukturierten Beweises — „um
`G` zu beweisen, genügt es, `L` herzustellen; hier ist `L`."
Seine Semantik ist *Beweisterm-Konstruktion* (nenne es
Semantik B), kein Laufzeit-Aufruf des Solvers: in der
Wertewelt gibt es kein Lösen, nur die Konstruktion eines
kern-geprüften Beweises.

Es elaboriert zu zwei Verpflichtungen und einem Beweis:

```
solve G by L   ⤳   let pf_L : L = <leaf obligation>
                   let pf_G : G = <bridge obligation, with L in scope>
                   pf_G
```

- Das *Blatt* `L` ist der eigentliche Inhalt. Die Engine
  trägt es ab; ein Zertifikat wird kern-geprüft.
- Die *Brücke* ist `G` unter der Hypothese `L` (plus den
  Umgebungstatsachen wie `post_f`) — meist ein trivialer
  Modus-Ponens-Schritt.

Beide Verpflichtungen sind über den Umgebungskontext
geschlossen, sodass sie auf oberster Ebene wohlgeformt sind,
und sowohl `G` als auch `L` dürfen ein *Block* sein — eine
`let`-Kette, die in der Proposition endet, die sie
bezeichnet —, sodass der Anwender Zwischenergebnisse
innerhalb jeder Klausel benennen kann.

Die Soundness ist genau die Schnittregel: wenn `⊢ L` und
`L ⊢ G`, dann `⊢ G`. Das Konstrukt fügt *kein Axiom* und
*keinen Verdikt-Schreibpfad* hinzu. Beide Verpflichtungen
sind echte Ziele, von Engine und Kern geprüft; `by L`
*strukturiert* nur den Beweis (und benennt das
Schlüssel-Lemma, damit das System den Zwischenschritt nicht
erraten muss). Wenn eine der Verpflichtungen unbeweisbar
ist, schlägt `solve G by L` bei der Verifikation fehl — also
wird im obigen `preserving`-Beispiel ein `f`, dessen `'q`
nicht `'p` impliziert, zur Prüfzeit einfach abgewiesen. Der
Kern baut das Gerüst; die Engine füllt genau ein Loch. Der
Soundness-Kern davon ist in Verus vorverifiziert (fünf
verifiziert, null Fehler).

=== Bild-Binder

Die `by`-Klausel benutzte einen Binder, der *kein*
Refinement-Typ ist:

```
forall {y = f(x) | 'p(x)}. q(y)
```

Das ist ein *Bild-Binder*, eine stark
typinferenz-getriebene Abkürzung. Er läuft über das
inferierte *Urbild* `x` (dessen Sorte als `f`s Domäne
wiedergewonnen wird), bewacht es durch den Constraint `c`
und bindet das *Bild* `y = f(x)`, wobei `y` im Rumpf zu
`f(x)` entfaltet wird. So gilt

```
forall {y = f(x) | p(x)}. q(y)
  ≡  forall x : {A | p(x)}. q(f(x))
```

über das vorverifizierte
`image_quantifier_desugar`-Lemma. Das `=` (statt `:`) ist
es, das ihn zur Parse-Zeit vom `{v:T | φ}`-Refinement-Binder
unterscheidet; der Elaborator führt Inferenz aus, um `x`s
Sorte und die definitionelle `y = f(x)`-Bindung
wiederzugewinnen.

== Der vierfache Verbund

Diese Teile sind kein Sammelsurium von Funktionen; sie sind
dafür gedacht, *organisch ineinanderzugreifen*. adsmts
zentrale Entwurfsabsicht ist ein vierfacher Verbund aus
Typinferenz, abduktiv-deduktiver Logik, ASP und SMT (mit HKT
darunter), und das typisierte Substrat dieses Kapitels ist
das Bindegewebe:

- Die Typ-*Inferenz* gewinnt das Urbild und das Bild eines
  Bild-Binders wieder sowie die Kinds an einer
  höher-gekindeten Position.
- Refinement-Verträge sind die *abduktiv-deduktive* Dualität
  typisiert gemacht — eine Konstruktionsstelle erzeugt eine
  Verpflichtung (Abduktion), eine Verwendungsstelle
  verbraucht dieselbe Tatsache als Hypothese (Deduktion).
- Ein Prädikatparameter `'p` fließt durch das
  Typrelations-*Wörterbuch*-Rückgrat auf dieselbe Weise wie
  eine Methode, sodass die *Klassen*-Maschinerie
  Constraint-Information in die Engines trägt.
- Das gesetzeskonforme Tor, das `solve … by …`-Blatt und
  eine Refinement-Wache münden alle im *SMT*-Solver.

`IntegerLike(I, L, N)` ist die erste höher-gekindete
Typklassen-Instanz und das prototypische Stück Bindegewebe:
eine Relation, die gleichzeitig Methoden, Gesetze, Prämissen
und das Positivitätsprädikat trägt, das ihre Träger an ihre
Refinements zurückbindet.

== Implementierungshinweise

Einige ingenieurtechnische Entscheidungen, die hervorzuheben
sind.

*Kind-Inferenz ist bidirektional.* Der Anwender schreibt
Typausdrücke, bei denen die Kinds in der Regel aus der
Position offensichtlich sind; der Elaborator inferiert sie
und weist Mehrdeutigkeit zurück. Das passt zu dem, was die
`KindSignatures`-Maschinerie in Haskell macht, und ist
ungefähr das, was Lean 4 tut. Die Implementierung passt in
ein paar hundert Zeilen.

*Typrelationen werden eifrig aufgelöst.* Wird ein
relations-eingeschränkter Ausdruck elaboriert, geschieht die
Instanzsuche sofort, und das Wörterbuch wird inline
eingesetzt. Es gibt keine Laufzeit-Suche. Das zahlt sich
später aus — die SAT- und Theorieschichten müssen nie über
ausstehende Instanzen schließen.

*Refinements fügen keine vertrauenswürdige Oberfläche
hinzu.* Ein `{v:T|φ}` ist Zucker für ein `Π`/`Σ`, das der
Kern bereits prüft, und seine Beweiskomponenten werden beim
Lowering gelöscht. Das Schlimmste, was ein fehlgeformtes
Refinement anrichten kann, ist, die Typprüfung nicht zu
bestehen.

*Höher-gekindete Polymorphie ist an der Oberfläche
optional.* Ein Anwender, der niemals
`(f : Type -> Type)`-Constraints schreibt, erhält ein
Erleben wie in der ersten Stufe. Die HKT-Maschinerie liegt
unter der Oberfläche, einsatzbereit, wenn sie gebraucht
wird, ohne ihren Preis zu fordern, wenn nicht.

== Die Kosten von HOL+HKT

Diese Entwurfsentscheidung ist nicht umsonst. Es ist
schwieriger, einen korrekten Kern für HOL+HKT zu schreiben
als für die Logik erster Stufe; es ist schwieriger,
Theorie-Solver zu schreiben, die die volle Allgemeinheit
abdecken; es erfordert mehr Sorgfalt bei der
Beweis-Reflektion; und eine gesetzeskonform-durch-Beweis
Relation zahlt den Preis, die Engine zur *Bau*-Zeit laufen
zu lassen, um eine Instanz zuzulassen. Die Gewinne — eine
ITP-freundliche Oberfläche, glatte Reflektion,
Refinement-Verträge als typisiertes abduktiv-deduktives
Substrat und gesetzeskonforme Klassen, die keine kaputte
Instanz stillschweigend zulassen können — sind das, was die
Kosten rechtfertigt. Ob es sich für *Ihren* Solver lohnt,
ist eine Frage, die nur Sie beantworten können. Die Antwort
von adsmt lautet ja.

Das nächste Kapitel führt zur SAT-Schicht, die bewusst
unabhängig vom Kern ist: SAT-Lösen weiß nichts von Typen
oder höheren Kinds, nur von Boolescher Erfüllbarkeit von
CNF-Formeln. Kern und SAT-Schicht sprechen miteinander
über eine flache Schnittstelle, in der jedes Theorieatom
ein Boolesches Literal wird.
