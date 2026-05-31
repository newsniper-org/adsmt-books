= Der Kern

== Warum überhaupt einen Kern

Ein *Kern* im hier verwendeten Sinn ist die
kleinstmögliche Menge von Inferenzregeln, die der Rest des
Solvers aufrufen darf. Jeder Schritt in jeder Theorie muss
letztlich in Anwendungen von Kernregeln aufgelöst werden;
nichts, was ein `Theorem` produziert, darf außerhalb dieser
vertrauenswürdigen Basis liegen. Der Vertrag ist exakt: der
Kern ist klein genug, um an einem Nachmittag gelesen und
an einem Wochenende auditiert zu werden, und jeder Code,
der *behauptet*, ein `Theorem` zu produzieren, ohne durch
den Kern zu gehen, ist ein Fehler. Dies ist dieselbe
Architektur, die HOL Light, Isabelle/HOL und (mit
Anpassungen) Lean 4 und Rocq verwenden.

Der Gewinn ist enorm. Fehler in Theoriecode brechen die
Korrektheit (soundness) nicht; das Schlimmste, was sie tun
können, ist, ein Ergebnis nicht herzuleiten, das die
Theorie hätte herleiten sollen. Fehler in der SAT-Schicht
brechen die Korrektheit nicht; das Schlimmste, was sie tun
können, ist, sich aufzuhängen oder eine Propagation zu
verfehlen. Die Trusted Computing Base — der Code, der, wäre
er fehlerhaft, eine falsche Proposition herleitbar machen
würde — schrumpft auf einen winzigen, in sich
geschlossenen Kern.

== Der Kern mit 12 Regeln

Der Kern von adsmt legt genau zwölf primitive
Inferenzregeln offen. Sie kommen in drei Gruppen:
Gleichheitsschließen, Abstraktion und Reduktion sowie
Kombination im Stil des Modus ponens. Aufgelistet nach
Namen:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header(
    [*Gruppe*], [*Regel*], [*Bedeutung*]
  ),
  [Gleichheit], [`Refl(t)`], [$t = t$ für jeden Term $t$],
  [Gleichheit], [`Trans(h_1, h_2)`], [aus $a = b$ und $b = c$ folgt $a = c$],
  [Gleichheit], [`EqMp(h_iff, h_p)`], [aus $p arrow.l.r.double q$ und $p$ folgt $q$],
  [Abstraktion], [`Abs(x, h_eq)`], [aus $f x = g x$ folgt $lambda x. f x = lambda x. g x$],
  [Abstraktion], [`Beta(redex)`], [$ (lambda x. b) a = b[x := a] $],
  [Kombination], [`Deduct(h_a, h_b)`], [aus $A$ folgt $B$ folgt $A arrow.r B$],
  [Kombination], [`Inst(sigma, h_thm)`], [substituiert Variablen auf Termebene in einem Theorem],
  [Kombination], [`InstType(sigma, h_thm)`], [substituiert Variablen auf Typebene in einem Theorem],
  [Rand], [`Assume(t)`], [führt $t$ als Hypothese ein],
  [Rand], [`Theory{name, witness, parents}`], [delegiert an einen Theorie-Solver und vertraut dessen Zeugen],
  [Rand], [`Instance{relation, types, witness}`], [erfüllt eine Typklassen-Instanzpflicht],
  [Rand], [`Assumed{formula, explain}`], [abduktiver Marker — Platzhalter in Form von `sorry`],
)

Diese zwölf Regeln sind erschöpfend in dem Sinn, dass jeder
Beweisschritt, den adsmt erzeugt, genau eine von ihnen
verwendet. Sie sind ferner disjunkt: keine Regel
überlappt eine andere.

== Terme und Typen

Um die Regeln präzise anzugeben, muss die Termsprache
fixiert werden. Die Terme von adsmt sind der übliche
einfach typisierte Lambda-Kalkül, erweitert um Typklassen-Anwendung:

$ t ::= x | c | t_1 t_2 | lambda x : tau. t $

wobei $x$ über Term-Variablen läuft, $c$ über Konstanten
(zur Signaturzeit vom Typsystem eingeführt) und die Binder
Verschachtelung erlauben. Typen sind:

$ tau ::= alpha | C | tau_1 -> tau_2 $

wobei $alpha$ eine Typvariable, $C$ eine Typkonstante ist
und der Pfeil Funktionstypen bildet. Wie höhere Kinds ins
Bild kommen, wird in Kapitel 3 erörtert.

Ein *Theorem* ist formal ein Paar $(Gamma, t)$, wobei
$Gamma$ eine Multimenge von Formeln (die Hypothesen) und
$t$ ein Term Boolescher Sorte (die Konklusion) ist. Die
übliche Sequenznotation $Gamma tack t$ liest sich wie
gewohnt. Jede Kernregel ist eine partielle Funktion von
Theoremen und Termargumenten in ein neues Theorem;
schlägt die partielle Funktion fehl (z. B. der Versuch,
`Trans` auf ein Paar von Theoremen mit nicht
übereinstimmenden Mittelgliedern anzuwenden), löst sie
einen Kernfehler aus, den der umgebende Code behandeln muss.

== Repräsentation im Code

adsmt repräsentiert den Kern in Rust ungefähr so:

```rust
pub enum Term {
    Var(Arc<Var>),
    Const(Arc<Const>),
    App(Arc<Term>, Arc<Term>),
    Lam(Arc<Var>, Arc<Term>),
}

pub struct Theorem {
    hypotheses: Vec<Term>,
    conclusion: Term,
}

pub fn refl(t: Term) -> KernelResult<Theorem> {
    let eq = mk_eq(t.clone(), t)?;
    Ok(Theorem {
        hypotheses: Vec::new(),
        conclusion: eq,
    })
}
```

Jede Regel ist eine Funktion. Die Funktionen liegen in
einem Modul, das den Konstruktor `Theorem` *ausschließlich*
über diese zwölf Regeln freigibt — die Felder der Struktur
sind privat, und es gibt kein öffentliches `Theorem::new`.
Außerhalb des Kernmoduls ist der einzige Weg, einen Wert
vom Typ `Theorem` zu erzeugen, der Aufruf einer Kernregel.
Dies ist derselbe Trick, den HOL Light mit dem Modulsystem
von OCaml verwendet; adsmt benutzt die Privatheit von Rust,
um dasselbe Ziel zu erreichen.

Die `Arc`-Wrapper sind ein Effizienz-Trick: Terme sind
unveränderlich und werden häufig geteilt, sodass
referenzgezählte Zeiger durch Teilbaum-Sharing den
Allokationsdruck mindern. Der Kern hängt für die
Korrektheit nicht von `Arc` ab; eine rein besitzende
`Box`-Variante würde dieselben Theoreme zu höheren
Speicherkosten berechnen.

== Randregeln im Detail

Die vier Randregeln — `Assume`, `Theory`, `Instance`,
`Assumed` — sind die Stellen, an denen der Kern Inhalt von
außerhalb seiner selbst aufnimmt. Jede ist ein
Vertrauenspunkt.

`Assume(t)` ist geradlinig: sie liefert $t tack t$. Die
Hypothese erscheint auf beiden Seiten, und der umgebende
Beweis muss $t$ schließlich über `Deduct` entladen. Diese
Regel führt kein Vertrauensrisiko ein: alles, was durch
`Assume` bewiesen wird, bleibt hypothetisch, bis es
entladen ist.

`Theory{name, witness, parents}` ist die Stelle, an der die
Theorie-Solver von adsmt in den Kern zurückkehren. Der
`witness` ist ein strukturierter Datensatz, der erklärt,
warum die Theorie glaubt, dass eine Konklusion aus den
Eltern folgt. Der Kern überprüft den Zeugen nicht — er
vertraut darauf, dass der Theorie-Solver etwas Korrektes
produziert hat. Es ist dasselbe Vertrauensmodell, das
SMT-Solver allgemein verwenden: Theorie-Solver sind
vertrauenswürdiger Code. Was adsmt hinzufügt, ist ein
*strukturierter Zeuge*, den nachgelagerte Konsumenten
(Beweisprüfer, ITPs) zur Rekonstruktion einer
unabhängigen Verifikation nutzen können.

`Instance{relation, types, witness}` ist das
Typklassen-Pendant: die Instanz-Erfüllung für eine Relation
zu gegebenen Typen wird an die Typklassen-Schicht
delegiert, die einen Zeugen produziert. Wieder vertraut der
Kern; der Zeuge erlaubt nachgelagerten Konsumenten die
Nachprüfung.

`Assumed{formula, explain}` ist der *abduktive* Marker —
ein gezieltes, benanntes, strukturiertes `sorry`. Wenn die
abduktive Maschinerie eine Hypothese vorschlägt, die der
Anwender noch nicht akzeptiert hat, enthält der Beweisbaum
einen `Assumed`-Schritt, der genau festhält, welche Formel
angenommen wird, sowie eine menschenlesbare Erklärung,
warum. Dies ist der formale Griff des Kerns für „dieser
Beweis ist noch nicht fertig". Nachgelagerte Konsumenten
(ITPs, Cert-Prüfer) behandeln `Assumed`-Schritte als
Beweislückenmarker, nicht als abgeschlossene Beweise.

== Korrektheit des Kerns

Die zwölf Regeln sind gemeinsam korrekt (sound): der
Small-Step-Kalkül, den sie definieren, hat die
Eigenschaft, dass — sofern jede Randregel mit einem
*korrekten* Zeugen aufgerufen wird — jedes herleitbare
Theorem $(Gamma, t)$ die übliche Semantik $Gamma models t$
besitzt. Dies wird hier nicht bewiesen — der Beweis folgt
dem üblichen Muster für einfach typisierte Lambda-Kalküle,
erweitert um Theorieatome, und ist Standard-Lehrbuchstoff
(siehe Pierces _Types and Programming Languages_ oder
Harrisons _Handbook of Practical Logic and Automated
Reasoning_). Für unsere Zwecke ist entscheidend, dass der
Beweis existiert und dass er für den spezifischen Kern,
den adsmt verwendet, geführt worden ist.

Die Korrektheit der Randregeln ist *bedingt* — bedingt
durch die Korrektheit der Theorie-Solver und des
Typklassen-Elaborators. Das ist das Vertrauen, das wir
durch das Aufnehmen dieser Regeln in Kauf nehmen; wir
mildern es ab, indem strukturierte Zeugen emittiert werden,
die eine unabhängige Nachprüfung erlauben.

== Reihenfolge der Implementierung

Wenn man das selbst baut, sollte man den Kern zuerst
implementieren und der Versuchung widerstehen, anderen
Code von Details abhängen zu lassen, die der Kern noch
nicht unterstützt. Die Disziplin ist dieselbe, die HOL
Light lehrt: den Kern richtig und klein hinbekommen, dann
lässt sich alles Übrige mit Vertrauen darauf aufbauen.
Tests auf Kernebene sollten jede Regel einzeln abdecken
sowie eine kleine Menge mehrregeliger Beweise (z. B. der
Nachweis, dass $x = y arrow.r y = x$ via `Trans` und
`Refl` gilt). Die Crate `adsmt-core` von adsmt hat genau
diese Struktur.
