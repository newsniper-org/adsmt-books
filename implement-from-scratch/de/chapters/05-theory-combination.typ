= Theorie-Kombination

== Das Kombinationsproblem

Man betrachte eine SMT-Formel, die Arithmetik und
Array-Operationen mischt:

$ a[i] + a[j] > 0 and a[i] = -a[j] and i != j $

Weder ein reiner Arithmetik-Solver noch ein reiner
Array-Solver kann dies allein entscheiden. Der
Arithmetik-Solver weiß nicht, wie er `a[i]` interpretieren
soll — er sieht opake Variablen. Der Array-Solver weiß
nicht, wie er `+` interpretieren soll — er kann Dinge
herleiten wie *wenn `i = j`, dann `a[i] = a[j]`*, aber nicht,
wozu eine der Seiten sich aufsummiert. Um Formeln dieser
Gestalt zu entscheiden, müssen die beiden Solver
*kooperieren*: jeder gibt die Informationen, die er über
*gemeinsame Variablen* erfährt, an den anderen weiter, bis
entweder ein Widerspruch auftritt oder ein kombiniertes
Modell existiert.

Das ist das Problem der *Theorie-Kombination*. Die
klassische Lösung ist die *Nelson-Oppen*-Kombination,
anwendbar, wenn die beteiligten Theorien *stabil unendlich*
sind und disjunkte Signaturen besitzen. adsmt verwendet
eine Verallgemeinerung namens *polite-Kombination*, welche
die Forderung nach disjunkten Signaturen gegen etwas mehr
Maschinerie eintauscht.

== Nelson-Oppen auf einen Blick

Das Nelson-Oppen-Protokoll lässt die teilnehmenden
Theorie-Solver im Gleichschritt laufen. Die gemeinsamen
Variablen sind die Variablen, die in Atomen vorkommen, die
von mehr als einer Theorie verarbeitet werden. Jede
Theorie:

#enum(numbering: "(1)",
  [Empfängt jedes asserierte Atom, das sie interpretieren kann,],
  [Meldet alle Gleichheiten zwischen gemeinsamen Variablen,
   die sie hergeleitet hat,],
  [Empfängt die Vereinigung aller von den anderen
   Theorien hergeleiteten Gleichheiten,],
  [Wiederholt, bis entweder (a) sie `false` herleitet
   (unerfüllbar) oder (b) keine neuen Gleichheiten mehr
   auftauchen (erfüllbar in der Kombination).],
)

Die Korrektheit des Protokolls beruht auf der
Stabil-Unendlich-Bedingung: jedes Modell jeder Theorie
isoliert kann so erweitert werden, dass es bei jeder Sorte
unendlich viele Elemente besitzt. Produzieren beide
Theorien nur endliche Modelle, ist zusätzliches
Kardinalitätsschließen erforderlich.

== Polite-Kombination

Die polite-Kombination verzichtet auf die Forderung
disjunkter Signaturen und behandelt das
Kardinalitäts­schließen explizit. Jede Theorie legt einen
*Politeness-Zeugen* offen, der pro Sorte beschreibt,
welche obere Schranke (wenn vorhanden) sie an die
Kardinalität von Modellen anlegt. Eine `BV<8>`-Sorte etwa
hat eine Kardinalität von höchstens $2^8 = 256$; eine
`Int`-Sorte ist $omega$; die Kombinationsmaschinerie
wählt das *Infimum* über alle teilnehmenden Theorien und
behauptet, dass das kombinierte Modell bei dieser Sorte
höchstens so viele Elemente besitzt.

Konkret implementiert jede Theorie:

```rust
pub trait Theory: Send {
    fn name(&self) -> &'static str;
    fn handles_sort(&self, ty: &Type) -> bool;
    fn assert(&mut self, lit: Literal) -> AssertResult;
    fn check(&mut self) -> CheckResult;
    fn explain(&self) -> Option<TheoryWitness>;
    fn derive_equalities(&self) -> Vec<(Term, Term)>;
    fn derive_disequalities(&self) -> Vec<(Term, Term)>;
    fn cardinality_witness(&self, sort: &Type) -> PoliteWitness;
    fn push(&mut self);
    fn pop(&mut self, levels: u32);
    fn reset(&mut self);
}
```

Der Kombinations-Orchestrator
(`adsmt-theory::polite::Combination`) besitzt ein
`Vec<Box<dyn Theory>>` und treibt das Protokoll:

```rust
pub fn check(&mut self) -> CombinedCheck {
    loop {
        // 1. Per-theory check.
        for t in &mut self.theories {
            match t.check() {
                CheckResult::Unsat { witness } => return Unsat { ... },
                CheckResult::Unknown { reason } => return Unknown { ... },
                CheckResult::Sat => continue,
            }
        }
        // 2. Gather derived equalities.
        let new_eqs = self.gather_derived_equalities();
        if new_eqs.is_empty() {
            // 3. Cardinality enforcement.
            if let Some(unsat) = self.enforce_cardinality() {
                return unsat;
            }
            return Sat;
        }
        // 4. Re-broadcast new equalities.
        for (a, b) in new_eqs { self.assert(Literal::positive(mk_eq(a, b))?); }
    }
}
```

Die Schleife konvergiert, weil jede Runde entweder die
Anzahl der unterschiedlichen Äquivalenzklassen reduziert
oder keine neuen Informationen liefert.

== Durchsetzung der Kardinalität

Für jede Sorte $sigma$, an der der kombinierte Zeuge eine
endliche Kardinalitätsschranke $n$ anlegt, sammelt der
Orchestrator die bei $sigma$ asserierten Disgleichheiten und
berechnet die maximale Clique im
Disgleichheits-Graphen. Übersteigt die Cliquengröße $n$,
hat das kombinierte Modell bei $sigma$ zu viele Elemente —
Widerspruch.

```rust
fn enforce_cardinality(&self) -> Option<CombinedCheck> {
    let diseqs_by_sort = self.gather_disequalities_by_sort();
    for (sort, pairs) in &diseqs_by_sort {
        let bound = self.cardinality_bound(sort);
        let Some(bound) = bound else { continue; };
        let clique = max_disequality_clique(pairs, bound + 1);
        if clique > bound {
            return Some(CombinedCheck::Unsat { /* polite witness */ });
        }
    }
    None
}
```

`max_disequality_clique` ist eine beschränkte
Cliquen-Aufzählung mit frühem Abbruch, sobald das laufende
Maximum die Schranke übersteigt — in der Praxis ein
hinreichend kleiner Suchraum, dass die brute-force-Variante
genügt.

== Literale an Theorien weiterleiten

Nicht jedes Literal ist für jede Theorie relevant. Die
Kombination entscheidet, welche Theorie welches Literal
sieht, indem sie die Operandensorte inspiziert: ein
Gleichheits-Literal `(= a b)` wird an jede Theorie geleitet,
die `a.type_of()` behandelt. Ein
Nicht-Gleichheits-Literal (ein theoriespezifisches
Prädikat, etwa `(> x y)`) geht an die Theorie, die dieses
Prädikat besitzt.

```rust
pub fn assert(&mut self, lit: Literal) -> Vec<(String, AssertResult)> {
    let routing_sort = if let Some((a, _)) = lit.term.dest_eq() {
        a.type_of()
    } else {
        lit.term.type_of()
    };
    let mut out = Vec::new();
    for t in &mut self.theories {
        if t.handles_sort(&routing_sort) {
            out.push((t.name().to_string(), t.assert(lit.clone())));
        }
    }
    out
}
```

Ein Konflikt in irgendeiner Theorie kurzschließt das
Broadcast und kehrt sofort zurück — adsmt hat diese
Optimierung explizit nachgezogen, weil der ursprüngliche
Entwurf fröhlich an jede Theorie weiterasserierte, auch
nachdem eine Unerfüllbarkeit gemeldet hatte.

== Push und Pop

Die SAT-Schicht treibt Entscheidungen und Backtracks; jede
Assertion muss möglicherweise rückgängig gemacht werden,
wenn die SAT-Schicht über die Entscheidung hinaus
zurückspringt, die sie eingeführt hat. Die Kombination
unterstützt `push`-/`pop`-Operationen, die dasselbe an jede
Theorie senden:

```rust
pub fn push(&mut self) {
    for t in &mut self.theories { t.push(); }
}
pub fn pop(&mut self, levels: u32) {
    for t in &mut self.theories { t.pop(levels); }
}
```

Jede Theorie implementiert ihr eigenes Snapshot-Schema. UF
etwa snapshottet die Union-Find-Struktur; LIA snapshottet
die Schranken­tabelle; Arrays snapshottet die lokale
Disgleichheits­tabelle und die Warteschlange ausstehender
Extensionalität. Das Muster ist einheitlich: jede Theorie
besitzt einen `scope_stack` von Snapshots und stellt bei
`pop` wieder her.

== Routing auf Engine-Seite

In `adsmt-engine` treibt die Funktion `dpllt::run_once` eine
einzelne Iteration: Literale → Assertion in die Kombination
→ Kombinations-Check. Der frühe Kurzschluss bei Konflikten
ist in der Schleife sichtbar:

```rust
pub fn run_once(combo: &mut Combination, literals: &[(Term, bool)]) -> LoopOutcome {
    for (atom, polarity) in literals {
        let lit = build_lit(atom, *polarity);
        for (name, r) in combo.assert(lit) {
            if let AssertResult::Conflict { witness } = r {
                return LoopOutcome::Unsat { theory: name, witness };
            }
        }
    }
    match combo.check() {
        CombinedCheck::Sat => LoopOutcome::Sat,
        CombinedCheck::Unsat { theory, witness } => LoopOutcome::Unsat { theory, witness },
        CombinedCheck::Unknown { theory, reason } => LoopOutcome::Unknown { theory, reason },
    }
}
```

Dies ist die Ebene, auf der die SAT- und die
Theorie­schicht kommunizieren. Die SAT-Schicht übergibt
`run_once` eine Liste von Literalen, die mit ihrem
aktuellen Trail vereinbar sind; `run_once` meldet zurück,
ob die Theorien übereinstimmen, und wenn nicht, welchen
Zeugen sie hervorgebracht haben.

== Eine optionale Ergänzung — der E-Graph

`adsmt-theory::egraph_theory` von adsmt wickelt einen
EUF-E-Graphen in das Trait `Theory` ein. Der E-Graph führt
ein per Hash-Consing verwaltetes Term-Universum sowie eine
Union-Find-Struktur, ergänzt um *Kongruenzhülle*: sobald
zwei Funktionsanwendungen $f(a)$ und $f(b)$ mit $a$ und
$b$ in derselben Äquivalenzklasse beobachtet werden, fusioniert
der Wrapper auch $f(a)$ und $f(b)$. Die Kaskade läuft bis
zu einem Fixpunkt und erzeugt kongruenzgeschlossene
Gleichheiten, die über `derive_equalities` offengelegt werden.

Dies ist *additiv* — sowohl UF als auch der E-Graph können
nebeneinander registriert werden. Der E-Graph trägt
kongruente Funktionsanwendungen bei, die UF nur bei
direkter Eingabe von Literalpaaren bemerkt.

== Zusammenfassung

Die Theorie-Kombination ist die Schicht, die SMT-Solver
von SAT-Solvern unterscheidet. Das Protokoll — polite oder
Nelson-Oppen — ist ein wohldefinierter kooperativer
Algorithmus über Solver-Komponenten hinweg, und jede
Komponente ist klein und auditierbar. Das nächste Kapitel
geht die einzelnen Theorie-Solver durch.
