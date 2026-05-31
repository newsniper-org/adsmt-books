= Die abduktive Schicht

== Abduktion und Deduktion

Klassisches SMT ist rein *deduktiv*: Gegeben eine Formel $phi$,
beantworte "ist $phi$ erfüllbar?" Die Antwort ist ein Urteil —
Sat, Unsat oder Unknown — gegebenenfalls verbunden mit einem
Zeugen-Modell oder einem Unsat-Kern.

*Abduktion* ist die duale Frage. Gegeben eine Formel $phi$,
die der Solver *nicht* entscheiden kann: Welche zusätzliche
Hypothese $H$ würde $phi$ beweisbar machen? Konkret geht es
darum, ein minimales $H$ zu finden, sodass $H union phi$
unerfüllbar ist (falls $phi$ die Negation eines Ziels formuliert)
oder $H union phi'$ erfüllbar (falls $phi'$ das Ziel direkt
formuliert).

```rust
pub struct AbductiveCandidate {
    pub hypothesis: Vec<Term>,
    pub justification: Justification,
    pub rank: Rank,
}
pub enum Justification {
    SldChain(Vec<HornStep>),
    TheoryGap { theory: TheoryName, missing: Term },
    QuantifierExhausted { var: Arc<Var>, body: Term },
}
```

Für SMT-als-Beweisassistent — den Anwendungsfall, um den herum
adsmt aufgebaut ist — sind abduktive Kandidaten die
handlungsrelevanteste Ausgabe, die ein Solver liefern kann.
Der Nutzer (oder eine ITP-Taktik) fragt nicht "ist das wahr?" —
er fragt "was muss ich annehmen, damit mein Beweis durchgeht?"
Die in Kapitel 7 gesehene Tier-4-Eskalation bringt diese
Kandidaten direkt zum Vorschein.

== Horn-Regeln und SLD-Ketten

Der sauberste Rahmen für Abduktion sind *Horn-Klauseln* —
Klauseln mit höchstens einem positiven Literal. Eine
Horn-Regel $p_1 and p_2 and dots and p_n -> q$ besagt
"wenn die $p_i$ gelten, dann gilt $q$." Ein *Fakt* ist eine
Horn-Regel mit $n = 0$: nur $q$.

Gegeben eine Horn-Regelbasis $R$ und ein Ziel $G$ ist eine
*SLD-Kette* eine endliche Folge von Rückwärtsverkettungsschritten,
die $G$ auf atomare Teilziele reduziert, die mit keinem Regelkopf
unifizierbar sind. Diese verbleibenden Teilziele bilden die
*abduktive Hypothese*: Nimmt man sie an, geht das Ziel durch.

```rust
pub fn build_chain(goal: &Term, rules: &[HornRule], depth: usize)
    -> Option<SldChain>
{
    if depth == 0 { return None; }
    for rule in rules {
        if let Some(sigma) = unify(&rule.head, goal) {
            let mut sub_chains = Vec::new();
            let mut residual = Vec::new();
            for body_atom in &rule.body {
                let atom = apply(&sigma, body_atom);
                match build_chain(&atom, rules, depth - 1) {
                    Some(sub) => sub_chains.push(sub),
                    None => residual.push(atom),
                }
            }
            return Some(SldChain {
                steps: vec![HornStep { rule: rule.clone(), sigma }],
                sub_chains,
                residual,
            });
        }
    }
    None
}
```

Die residualen Atome sind das, was sich nicht wegunifizieren
ließ. Diese werden zur abduktiven Hypothese.

== Minimierung

Eine erste SLD-Kette ist selten minimal. Der naive
Rückwärtsverketter akkumuliert jedes nicht-gematchte Teilziel,
auch wenn manche redundant sind — impliziert durch andere oder
durch Hintergrundtheorie-Axiome. Der `minimize`-Durchlauf von
adsmt durchläuft das Residuum:

```rust
pub fn minimize(residual: &[Term], ctx: &TheoryContext) -> Vec<Term> {
    let mut keep: Vec<Term> = Vec::new();
    for atom in residual {
        if entailed_by(atom, &keep, ctx) { continue; }
        keep.retain(|kept| !entailed_by(kept, &[atom.clone()], ctx));
        keep.push(atom.clone());
    }
    keep
}
```

`entailed_by` konsultiert den aktiven Theorie-Kontext —
UF-Kongruenzen, arithmetische Schranken, BV-Literalauswertung —,
um redundante Atome auszuscheiden. Die verbleibende Liste ist
eine minimale Überdeckung unter den aktiven Theorien.

== Ranking

Mehrere distinkte minimale Hypothesen können dasselbe Ziel
entscheiden. `rank` ordnet die Kandidaten nach
*Nutzerkosten*-Heuristiken — weniger Atome bevorzugt,
einfachere Atome bevorzugt, bereits im Geltungsbereich
befindliche Atome bevorzugt gegenüber frischen:

```rust
pub fn rank(candidates: &mut Vec<AbductiveCandidate>, in_scope: &HashSet<Term>) {
    candidates.sort_by_key(|c| (
        c.hypothesis.len(),
        c.hypothesis.iter().map(term_depth).sum::<usize>(),
        c.hypothesis.iter().filter(|t| !in_scope.contains(*t)).count(),
    ));
}
```

Der Nutzer sieht eine geordnete Liste, keine rohe Menge. Die
Lean4-Taktik `smt_abduce` und das LSP-Code-Action-Menü
respektieren beide diese Ordnung: Der oberste Kandidat ist
die vorgeschlagene Hypothese, der Rest sind Alternativen,
unter denen der Nutzer wählen kann.

== Integration in den Arbeitsablauf

Innerhalb der `check_sat`-Schleife der Engine wird Abduktion
durch *Lücken* angestoßen — Stellen, an denen Grund-Reasoning,
Theoriekombination oder Quantor-Instantiierung etwas
hervorbringen, das kurz vor einem definitiven Urteil
zurückbleibt.

```rust
pub enum SatResult {
    Sat(Model),
    Unsat(UnsatCore),
    Abductive { candidates: Vec<AbductiveCandidate> },
    Unknown(UnknownReason),
}

fn abductive_escalation(state: &SolverState) -> Vec<AbductiveCandidate> {
    let mut out = Vec::new();
    if let Some(quant_gap) = state.exhausted_quantifier() {
        out.push(quantifier_to_candidate(quant_gap));
    }
    if let Some(theory_gap) = state.theory_unknown() {
        out.push(theory_gap_to_candidate(theory_gap));
    }
    if !out.is_empty() { return out; }
    let goal = state.current_goal();
    let chains = build_chains_with_horn_base(&goal, state.horn_rules(), MAX_DEPTH);
    chains.into_iter()
        .map(|chain| chain_to_candidate(chain, state.theory_context()))
        .collect()
}
```

Die vier Lückenkategorien — erschöpfter Quantor, unbekannte
Theorie, Horn-Ketten-Residuum, Anforderung eines klassischen
Axioms — speisen jeweils Kandidaten in denselben Rückgabepfad.
Der Aufrufer erhält eine einzige homogene
`AbductiveCandidate`-Liste zur Präsentation.

== Tier 4 — Beförderung von Kandidaten zu Zertifikaten

Ein Nutzer (oder eine ITP-Taktik) akzeptiert einen abduktiven
Kandidaten, indem er dessen Hypothese-Atome zur Behauptungsmenge
hinzufügt. Beim erneuten `check_sat` sind diese Atome nun
Grundannahmen, die Kette, die den Kandidaten erzeugt hat,
schließt sich, und der Solver gibt ein definitives Urteil ab.

Das Zertifikatformat (Kapitel 9) protokolliert die abduktive
Akzeptanz explizit:

```text
(cert.v1
  (steps
    (step :rule abductive_assume
          :id 17
          :hypothesis ((P a) (Q b))
          :justification (sld_chain ...))
    ...))
```

Der nachgelagerte ITP — Lean 4, Rocq oder Isabelle — sieht
diesen Schritt als expliziten `sorry`-förmigen Platzhalter:
einen Beweis, der *bedingt* zu den Hypothesen ist, wobei die
Hypothesen als Verpflichtungen sichtbar werden, die der
Nutzer auf anderem Wege erfüllen muss. Die Reflexionsschicht
(Kapitel 10) rendert das Zertifikat als ITP-freundliches
Taktik-Skript, in dem jedes `abductive_assume` zu einer
benannten Hypothese wird, die der Nutzer einführen kann.

== Wann Abduktion gnädig versagt

Wenn weder E-Matching, Theorie-Abschluss noch abduktive
Verkettung einen brauchbaren Kandidaten liefern, gibt der
Solver `Unknown(UnknownReason::AbductiveExhausted)` zurück.
Das ist strikt informativer als das gewöhnliche SMT-`unknown`:
Der Aufrufer weiß, dass die abduktive Schicht versucht wurde
und an Ideen ausging, nicht dass irgendeine vorgelagerte
Schicht ihr Budget erreicht hat.

Für einen interaktiven Theorembeweiser ist "unbekannt, aber
hier sind fünfzehn Kandidaten-Hypothesen, die ich versucht
und verworfen habe" an sich nützliche Debug-Ausgabe. Die
Variante `UnknownReason::AbductiveExhausted` trägt das
Versuchsprotokoll; das LSP bringt es als Diagnose mit einer
Code-Action "abduktive Spur zeigen" zum Vorschein.

== Warum das für SMT-als-Taktik wichtig ist

Konventionelles SMT-als-Taktik liefert dem Beweisassistenten
ein binäres Urteil. Wenn es funktioniert, prima; wenn nicht,
hat der Nutzer kein handlungsrelevantes Feedback. Abduktive
Kandidaten verändern das Spiel: Selbst eine *fehlgeschlagene*
Entscheidung liefert konkrete Hypothesen, die der Nutzer
entweder akzeptieren oder zur Verfeinerung des Ziels nutzen
kann.

Genau das motiviert den Bau von adsmt überhaupt. Der Modus
"nur deduktives Urteil" ist in Ordnung — adsmt erledigt ihn
ebenso gut wie jeder SMT-Solver —, aber der *abduktive Ausweg*
ist der Grund, weshalb ein neuer Solver gebaut wird, statt
einen bestehenden zu umhüllen. Kapitel 9 beschreibt die
Zertifikat-Maschinerie, die abduktive Schritte in
nachgelagerten ITPs wiederherstellbar macht.
