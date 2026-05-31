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

== Typklassen

Eine *Typklasse* ist eine prädikatsförmige Relation über
Typen, zusammen mit einem expliziten Wörterbuch von
Operationen. In der Oberfläche von adsmt schreibt der
Anwender:

```
class Ord (a : Type) where
  le : a -> a -> Bool
```

und an Gebrauchsstellen:

```
instance Ord Int where
  le = int_le
```

Die Klassen sind syntaktischer Zucker; was der Kern sieht,
ist:

- Eine *Relation* (`Ord`) fester Stelligkeit — ein oder
  mehrere Typen, gegebenenfalls mit Kind-Einschränkungen.
- *Instanz-Zeugen*, die behaupten, dass bestimmte Typen
  Mitglieder der Relation sind, begleitet vom Wörterbuch
  der Operationen.
- *Klassen-Anwendung*, die an jeder Gebrauchsstelle eine
  Instanzsuche auflöst.

Die Randregel `Instance` (Kapitel 2) ist genau die Grenze
zu dieser Schicht: sie delegiert die Instanz-Erfüllung an
den Typklassen-Elaborator und vertraut dem
zurückgegebenen Zeugen.

== Wörterbuch-Übergabe

Klassen werden durch *Wörterbuch-Übergabe* wegcompiliert:
jede klassen-eingeschränkte Funktion erhält an jeder
Gebrauchsstelle einen expliziten Wörterbuch-Parameter. Eine
Funktion

```
sort : (Ord a) => List a -> List a
```

wird zu

```
sort_with_dict : OrdDict a -> List a -> List a
```

mit explizit hindurchgereichtem Wörterbuch. Der Solver
benötigt intern niemals erstklassige Klassen­instanzen;
sobald die Wörterbuch-Übergabe vorgenommen worden ist,
sieht der Rest des Systems gewöhnliche
Funktionsanwendungen.

Es ist dieselbe Technik, die GHC zum Übersetzen der
Haskell-Klassen verwendet und die Lean 4 für seine
Typklassen­schicht nutzt. Sie macht die Beweis-Reflektion
einfach, weil das Wörterbuch eine gewöhnliche Struktur auf
Termebene ist, die unverändert mitgeführt werden kann.

== Höher-gekindete Relationen

Eine Klasse `Functor` operiert auf Entitäten des Kinds
`Type -> Type`:

```
class Functor (f : Type -> Type) where
  map : (a -> b) -> f a -> f b
```

Instanzen bei diesem Kind sehen so aus:

```
instance Functor List where
  map = list_map
```

Die Instanzsuche geschieht beim Kind `Type -> Type` —
genau an der höher-gekindeten Stelle. Der Kern behandelt
dies über dieselbe Regel `Instance`; der Unterschied ist
lediglich, dass das Feld `types: Vec<Type>` Entitäten
höheren Kinds trägt und der Kind-Prüfer zur Zeit der
Instanzsuche befragt wird.

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

*Typklassen werden eifrig aufgelöst.* Wird ein
klassen-eingeschränkter Ausdruck elaboriert, geschieht die
Instanzsuche sofort, und das Wörterbuch wird inline
eingesetzt. Es gibt keine Laufzeit-Suche. Das zahlt sich
später aus — die SAT- und Theorieschichten müssen nie über
ausstehende Instanzen schließen.

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
Beweis-Reflektion. Die Gewinne — eine ITP-freundliche
Oberfläche, glatte Reflektion, Ausdruckskraft für
Beweisverpflichtungen in der Nachbarschaft typisierter
Programmierung — sind das, was die Kosten rechtfertigt. Ob
es sich für *Ihren* Solver lohnt, ist eine Frage, die nur
Sie beantworten können. Die Antwort von adsmt lautet ja.

Das nächste Kapitel führt zur SAT-Schicht, die bewusst
unabhängig vom Kern ist: SAT-Lösen weiß nichts von Typen
oder höheren Kinds, nur von Boolescher Erfüllbarkeit von
CNF-Formeln. Kern und SAT-Schicht sprechen miteinander
über eine flache Schnittstelle, in der jedes Theorieatom
ein Boolesches Literal wird.
