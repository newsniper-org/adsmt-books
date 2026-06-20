= Quantoren

== Warum Quantoren schwierig sind

Die Theorien aus Kapitel 6 setzen sämtlich *Grundatome*
voraus — keine universellen oder existenziellen Quantoren
in der Formel. Fügt man Quantoren hinzu, wird das
Erfüllbarkeitsproblem im Allgemeinen unentscheidbar: es
gibt keinen Algorithmus, der bei beliebiger Formel erster
Stufe stets die richtige Antwort liefert.

Was SMT-Solver stattdessen tun, ist *heuristische
Instanziierung*: ist eine universelle Formel
$forall x. phi(x)$ asseriert und hat der Rest der Formel
konkrete Grundterme erzeugt, setzt man jene Grundterme als
Kandidat-Instanziierungen in $phi(x)$ ein und fügt sie als
Grundatome hinzu. Damit ergibt sich die Aufgabe der
inneren Solver-Schleife: sie sieht nicht die ursprüngliche
quantifizierte Formel, sondern einen wachsenden Stapel von
Instanziierungen. Die Frage, *welche* Terme in welcher
Reihenfolge eingesetzt werden, wird zum Kern des
Problems.

== E-Matching

Die vorherrschende Technik ist *E-Matching*. Die Idee: die
Formel $forall x. phi(x)$ kommt mit einem *Trigger*
annotiert — einem Teilmuster von $phi$, das die gebundene
Variable $x$ enthält. Erzeugt der Grundanteil der Formel
einen Term, der den Trigger (modulo
Gleichheits­schließen) trifft, instanziiert man $x$ auf
den passenden Teilterm.

Beispiel: gegeben $forall x. f(g(x)) > 0$ mit Trigger
$f(g(x))$ und einem bereits im Scope befindlichen
Grundterm $f(g(a))$, instanziiert man $x := a$. Das
instanziierte Atom $f(g(a)) > 0$ tritt der SAT-/Theorie­schicht
bei.

```rust
pub struct Trigger {
    pub kind: TriggerKind,
    pub bound: Vec<Arc<Var>>,
}
pub enum TriggerKind {
    Single(Term),
    Multi(Vec<Term>),
}
```

Der Matcher geht das *Term-Universum* durch — die Menge der
in der Formel vorkommenden Grund-Teilterme — und sucht nach
Treffern. Ein Trigger mit einzelnem Muster trifft auf
einen Universum-Term, wenn die rigiden Teile des Musters
(Konstanten und gebundene Variablen, die nicht in der
Flex-Menge des Triggers liegen) übereinstimmen und die
Flex-Teile Substitutionen aufnehmen.

```rust
fn match_one(pattern: &Term, target: &Term, bound: &[Arc<Var>])
    -> Option<Vec<(Arc<Var>, Term)>>
{
    let mut sigma = IndexMap::new();
    if extend_match(pattern, target, bound, &mut sigma) {
        Some(sigma.into_iter().collect())
    } else { None }
}
```

== Miller-Muster

Ein *Miller-Muster* ist ein Trigger-Muster, in dem jede
Flex-Teilanwendung die Form $F(x_1, dots, x_n)$ hat, wobei
die $x_i$ verschiedene gebundene Variablen sind.
Miller-Muster erlauben einen linearen
Matching-Algorithmus ohne die Pathologien der
höherstufigen Unifikation. adsmt setzt standardmäßig auf
Miller-Muster und stellt einen `:trigger!`-Escape für
Nicht-Miller-Muster bereit, die der Anwender aus guten
Gründen dennoch haben möchte.

== Tier-Eskalation

E-Matching kann scheitern, irgendeine Instanziierung zu
finden: das Universum enthält vielleicht keinen Term von
der Gestalt des Triggers. adsmt eskaliert über eine Folge
von *Tiers*, jede aggressiver als die vorige:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Tier*], [*Strategie*]),
  [1], [Miller-E-Matching gegen das Term-Universum.],
  [2], [Konfliktgetriebene Instanziierung — wähle Instanziierungen, die einer bestehenden Grund-Assertion widersprechen.],
  [3], [Beschränkte Aufzählung — zähle Kandidat-Teilterme bis zu einem Tiefen-Budget auf.],
  [4], [Abduktive Eskalation — emittiere die quantifizierte Formel als abduktiven Kandidaten (Kapitel 8).],
)

```rust
pub fn instantiate_with_tier(var, body, universe) -> (Vec<Term>, Tier) {
    let res = instantiate_one(var, body, universe);
    if !res.is_empty() {
        return (res, Tier::One);
    }
    let res = enumerate(var, body, universe, DEFAULT_TIER3_BUDGET);
    if !res.is_empty() {
        return (res, Tier::Three);
    }
    (Vec::new(), Tier::Exhausted)
}
```

Tier 2 (konfliktbasiert) und Tier 4 (abduktiv) verlangen
Informationen aus benachbarten Schichten; Tier 4 wird in
Kapitel 8 behandelt.

== Trigger-Lernen

Handverlesene Trigger sind Sache des Anwenders, doch wenn
keine angegeben sind, wählt der `learn_triggers`-Helfer
von adsmt automatisch eine überdeckende Menge. Der
Algorithmus läuft die Anwendungs-Teilterme des Körpers in
Tiefenreihenfolge ab und wählt gierig die kleinsten Muster,
die jede Flex-Variable abdecken:

```rust
pub fn learn_triggers(body: &Term, flex: &[Arc<Var>]) -> Option<Trigger> {
    let mut candidates = Vec::new();
    collect_apps(body, &mut candidates);
    candidates.sort_by_key(term_depth);
    let mut covered = HashSet::new();
    let mut selected = Vec::new();
    for cand in candidates {
        let cand_flex = flex_vars_in(&cand, flex);
        if cand_flex.iter().all(|v| covered.contains(v)) { continue; }
        for v in &cand_flex { covered.insert(v.clone()); }
        selected.push(cand);
        if covered.len() == flex.len() { break; }
    }
    if covered.len() != flex.len() { return None; }
    if selected.len() == 1 {
        Some(Trigger::single(selected.pop().unwrap(), flex.to_vec()))
    } else {
        Some(Trigger::multi(selected, flex.to_vec()))
    }
}
```

Die Überdeckung stellt sicher, dass jedes erfolgreiche
E-Match jede Flex-Variable instanziiert. Die gierige
Tiefenreihenfolge ist eine Heuristik, die dazu neigt,
kleine, häufig matchende Muster zuerst auszuwählen.

== Der E-Graph

Der reine E-Matcher läuft auf einem flachen
`TermUniverse`. Eine ausgefeiltere Alternative — der
*E-Graph* — führt einen per Hash-Consing verwalteten
Termspeicher, ergänzt um Kongruenzhülle, und legt nicht nur
die expliziten Universum-Terme offen, sondern auch jeden
*hergeleitet kongruenten* Term.

```rust
pub struct EGraph {
    nodes: Vec<ENode>,
    parent: Vec<ENodeId>,
    class_parents: HashMap<ENodeId, Vec<ENodeId>>,
    hash_cons: HashMap<ENodeKey, ENodeId>,
    scope_stack: Vec<EGraphSnapshot>,
}
```

`add` senkt einen Term in den Graphen und gibt seine
Klassen-ID zurück. `merge` vereinigt zwei Klassen und
zieht die Kongruenzhülle nach — werden die Kinder zweier
Eltern-E-Knoten äquivalent, werden auch die Eltern
fusioniert. `as_universe` projiziert den Graphen zurück in
ein flaches `TermUniverse` zur Nutzung durch den
E-Matcher.

Die Integration des E-Graphen erkauft Vollständigkeit:
wenn das Kongruenz-Schließen im E-Graphen einen
Trigger-Treffer erzeugen würde, den das flache Universum
verfehlt, fängt der E-Graph ihn ein.

In adsmt macht das mitgelieferte OxiZ-Backend dieses
kongruenzbewusste Matching zu seinem _Standard_,
verwirklicht als ein einziger vereinheitlichter Kern
namens _CCFV_ — Kongruenzhülle mit freien Variablen, nach
der E-Grund-(Dis-)Unifikation von
Barbosa–Fontaine–Reynolds. Ein Trigger wird _modulo_ der
Grund-Kongruenz gematcht: ein Muster $f(g(x))$ feuert
gegen einen Grundterm $f(c)$, sobald $c$ und $g(a)$
kongruent sind — genau der Treffer, den ein syntaktischer
Durchlauf über das flache Universum fallen lässt. Für eine
Modellvervollständigungs-Engine — eine, die `sat`
beantworten kann, indem sie ein Modell baut — ist dies
nicht nur ein Vollständigkeitsgewinn, sondern eine
_Korrektheits_-Anforderung: verfehlt man einen solchen
Kongruenz-Treffer, so darf die Engine ein kongruenzblindes
Modell bei einem Problem, das tatsächlich `unsat` ist, als
`sat` zertifizieren. Derselbe CCFV-Kern drückt auch die
konfliktgetriebene Instanziierung und die
Modellvervollständigungs-Suche aus und unterscheidet sich
nur in der Bedingung, die er löst, und darin, ob er die
echte Kongruenz oder eine standard-erweiterte Totalsicht
liest.

== Quantor-Instanziierung in der Engine-Schleife

Die Schleife `check_sat` der Engine führt die
Quantor-Instanziierung zwischen aufeinanderfolgenden Checks
des Grund-Fragments aus:

```rust
const QUANTIFIER_ROUNDS: usize = 3;
let mut instantiations: Vec<Term> = Vec::new();
for round in 0..QUANTIFIER_ROUNDS {
    let mut combined = self.all_literals();
    for inst in &instantiations { combined.push((inst.clone(), true)); }
    match self.check_ground(&combined) {
        SatResult::Sat => {
            let (quants, rest) = partition_quantifiers(&combined);
            if quants.is_empty() { return SatResult::Sat; }
            let universe = collect_universe(&rest);
            for (var, body) in &quants {
                for inst in instantiate_one(var, body, &universe) {
                    if !instantiations.iter().any(|t| t.alpha_eq(&inst)) {
                        instantiations.push(inst);
                    }
                }
                // Tier 2 and Tier 3 fallback...
            }
            if instantiations.len() == prev_len { return SatResult::Sat; }
        }
        other => return other,
    }
}
// Tier 4 — abductive escalation
return SatResult::Abductive { candidates: build_tier4_candidates(...) };
```

Jede Runde kann neue Instanziierungen hinzufügen; die
Schleife setzt sich fort, bis entweder ein endgültiges
Verdikt erscheint, keine neuen Instanziierungen mehr
auftauchen (Sat) oder das Rundenbudget erschöpft ist
(abduktive Tier-4-Eskalation).

== Warum dies „best-effort" ist

E-Matching mit Tier-Eskalation ist eine *Heuristik*. Sie
kann eine Instanziierung verfehlen, die eine Formel
abarbeiten würde, selbst wenn eine existiert. SMT-Solver
akzeptieren diesen Handel allgemein: die Alternative —
eine vollständige Behandlung von Quantoren — ist entweder
mit der Theorie-Kombination unverträglich oder so teuer,
dass sie unbrauchbar wird.

Was adsmt hinzufügt, ist der Notausgang über Tier 4: ist
jede termebene-Heuristik erschöpft, wird der Quantor zu
einem *abduktiven Kandidaten*. Der Anwender sieht nicht
„unknown", sondern „ich könnte das lösen, wenn Sie diese
Hypothese akzeptierten." Diese Hypothese ist die bloße
Existenz eines bestimmten Zeugen; ihre Akzeptanz lässt den
Beweis durchgehen, und der Anwender (oder der
nachgelagerte ITP) entscheidet, ob die Annahme angemessen
ist.

Wir wenden uns als nächstes dieser abduktiven Schicht zu.
