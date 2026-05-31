= Die SAT-Schicht

== Architektur

Die Aufgabe der SAT-Schicht besteht darin, für eine
aussagenlogische CNF-Formel eine erfüllende Belegung zu
finden oder zu beweisen, dass keine solche existiert. Der
Vertrag mit dem Rest des Solvers ist eng: hinein geht ein
`Vec<Clause>`, in dem jede Klausel ein
`Vec<(atom, polarity)>` ist, heraus kommt eines von drei
Verdikten — `Sat`, `Unsat` oder `Unknown` — und auf dem
`Sat`-Pfad steht die erfüllende Belegung der theorieseitigen
Verifikation zur Verfügung.

adsmt liefert drei SAT-Backends aus: OxiZ (einen
CDCL-Solver in reinem Rust, die Vorgabe), CaDiCaL (einen
CDCL-Solver in C++ hinter einer FFI) und einen
eingebauten Rückfall in `adsmt-engine::cdcl`. Der Rückfall
existiert, damit der Build ohne Feature-Flag in sich
abgeschlossen ist; Produktions-Builds verwenden OxiZ.
Dieses Kapitel beschreibt, was die eingebaute
CDCL-Implementierung tut; dieselbe Architektur gilt für
jedes der externen Backends.

== Der CDCL-Algorithmus auf einen Blick

Conflict-Driven Clause Learning setzt auf eine
backtracking-basierte aussagenlogische Suche auf. Die
Grundschleife:

#enum(numbering: "(1)",
  [Propagiere die aktuelle Teilbelegung, bis keine
   weiteren von Unit-Klauseln getriebenen Belegungen mehr
   möglich sind.],
  [Hat die Propagation einen Konflikt erzeugt (irgendeine
   Klausel ist nun falsifiziert), führe Konfliktanalyse
   durch: gehe rückwärts durch den Implikationsgraphen, um
   eine *gelernte Klausel* zu finden, die den Grund des
   Konflikts erfasst. Füge die gelernte Klausel der Formel
   hinzu; springe zurück auf eine Ebene, auf der sie
   propagiert.],
  [Andernfalls, wenn jede Variable belegt ist, gib `Sat`
   zurück.],
  [Andernfalls wähle eine Entscheidungsvariable (eine
   Heuristik wählt aus, welche), belege sie und schleife.],
)

Die beiden wesentlichen Bestandteile sind die *Propagation*
(Schritt 1) und die *Konfliktanalyse* (Schritt 2). Die
Entscheidungsheuristik (Schritt 4) und die
Restart-Politik sind Optimierungen zweiter Ordnung, die in
der Praxis einen überproportionalen Einfluss auf die
Solver-Leistung haben.

== Two-Watched-Literals

Ein naiver Propagator iteriert bei jeder Belegung über
jede Klausel und prüft, ob sie nun Unit ist. Bei $n$
Klauseln mit durchschnittlich $k$ Literalen je Klausel
kostet dies $O(n k)$ pro Belegung. Das Schema mit
zwei überwachten Literalen (Two-Watched-Literals) reduziert
die amortisierten Kosten dramatisch.

Die Beobachtung: eine Klausel ist nur dann Unit, wenn alle
ihre Literale bis auf eines auf falsch gesetzt sind. Eine
Klausel muss also nur dann untersucht werden, wenn eines
ihrer derzeit überwachten Literale falsch wird. Man wähle
pro Klausel zwei beliebige Literale als „überwacht"; man
führe einen invertierten Index von jedem Literal zu den
Klauseln, die es überwachen; bei jeder neuen Belegung
untersuche man nur die Klauseln, die ihre Negation
überwachen.

Beim Untersuchen einer solchen Klausel gilt entweder:
- man findet ein anderes nicht-falsches Literal zum
  Überwachen (Kosten: $O(k)$ Durchgang durch die Literale
  der Klausel);
- man findet, dass das andere überwachte Literal erfüllt
  ist (die Klausel ist in Ordnung; überspringen);
- man findet, dass das andere überwachte Literal
  unbelegt ist (die Klausel ist Unit; propagieren);
- man findet, dass das andere überwachte Literal falsch
  ist (Konflikt).

Die Datenstruktur ist einfach:

```rust
pub struct CdclState {
    pub trail: Vec<TrailEntry>,
    pub assign: HashMap<String, bool>,
    pub clause_watches: Vec<[usize; 2]>,
    pub watches: HashMap<(String, bool), Vec<usize>>,
    pub prop_head: usize,
    // … learnt-clause storage, activity tables, etc.
}
```

Der Zeiger `prop_head` rückt Literal für Literal durch den
Trail vor; für jeden neuen Trail-Eintrag wird seine
*Negation* in `watches` nachgeschlagen und nur diese
Klauseln werden untersucht.

== Konfliktanalyse — 1-UIP

Wird eine Klausel falsifiziert, gibt der Propagator ihren
Index zurück. Die Konfliktanalyse geht rückwärts durch den
Implikationsgraphen (den Trail, wobei der `reason`-Eintrag
jedes Eintrags auf die Klausel zeigt, die ihn propagiert
hat), um eine *gelernte Klausel* zu finden, die — wäre sie
von Anfang an vorhanden gewesen — diesen Konflikt verhindert
hätte.

Der Standardalgorithmus — „1-UIP" — produziert die
gelernte Klausel, indem die Konfliktklausel gegen die
Antezedenten ihrer Literale auf der aktuellen
Entscheidungs­ebene resolviert wird, bis genau ein Literal
auf der aktuellen Entscheidungs­ebene übrigbleibt. Dieses
einzelne Literal ist der *first unique implication point*;
die resultierende Klausel ist die gelernte Klausel, und
die maximale Entscheidungs­ebene unter den *übrigen*
Literalen ist die *Backjump-Ebene* — die Ebene, auf die
man zurückrollen sollte.

Im Code (Skizze):

```rust
fn analyze_1uip(clauses, state, conflict_idx) -> (Vec<Lit>, u32) {
    let current = state.decision_level;
    let mut seen = HashSet::new();
    let mut learnt = Vec::new();
    let mut count_current = 0;
    // Seed from the conflict clause.
    for lit in &clauses[conflict_idx] {
        process(lit, ...);
    }
    // Walk the trail backwards, resolving each current-level
    // seen literal against its antecedent.
    let mut idx = state.trail.len();
    while count_current > 1 {
        idx -= 1;
        // ...
    }
    // Recover the UIP and the backjump level.
    // ...
}
```

Die vollständige Implementierung umfasst in `cdcl.rs` von
adsmt etwa 100 Zeilen; sie ist mechanisch, sobald die
Trail-Infrastruktur an Ort und Stelle ist.

== VSIDS — Variablenaktivität

Die Entscheidungsheuristik, die das CDCL-Feld seit dem
Chaff-Solver von 2001 dominiert, ist *VSIDS* — variable
state independent decaying sum. Jedes Atom trägt einen
Aktivitätswert; jeder Konflikt erhöht die Aktivitäten der
Atome in der gelernten Klausel; periodisch wird jeder Wert
mit einem Decay-Faktor multipliziert (typisch 0,95), sodass
jüngere Erhöhungen die älteren dominieren.

```rust
pub fn bump_activity(&mut self, clause: &Clause, bump: f64) {
    for lit in clause {
        *self.activity.entry(atom_key(lit)).or_insert(0.0) += bump;
    }
}
pub fn decay_activity(&mut self, factor: f64) {
    for v in self.activity.values_mut() { *v *= factor; }
}
```

Der Entscheidungs-Picker geht die offenen Klauseln durch
und wählt das unbelegte Atom mit der höchsten Aktivität.
Mit dem Zyklus aus Bumpen und Verfall wird das zu einem
starken Indikator für „welches Atom ist in den Konflikten
beteiligt, die ich gerade treffe?".

== Restarts und Luby

CDCL profitiert von periodischen Restarts — dem Vergessen
der aktuellen Entscheidungs­historie und dem Neustart der
Suche von den Top-Level-Fakten. Der Zeitplan ist wichtig:
rein geometrische Restarts (alle $2^k$ Konflikte) schneiden
schlechter ab als eine Folge, die immer wieder Epochen mit
kurzem Budget besucht. Die *Luby-Folge* —
$1, 1, 2, 1, 1, 2, 4, 1, 1, 2, 1, 1, 2, 4, 8, dots$ —
gewinnt empirisch auf randomisierten SAT-Instanzen.

Die Luby-Iteration ist Knuths
„reluctant-doubling"-Formel und passt in zehn Zeilen:

```rust
fn luby_index(i: usize) -> usize {
    let mut u = 1usize;
    let mut v = 1usize;
    for _ in 0..i {
        if (u & u.wrapping_neg()) == v { u += 1; v = 1; }
        else { v *= 2; }
    }
    v
}
```

Die äußere CDCL-Schleife ruft dann
`cdcl_solve(clauses, base_conflicts * luby_index(epoch))`
für `epoch = 0, 1, 2, ...` auf, bis ein endgültiges Verdikt
erscheint oder das Restart-Budget erschöpft ist.

== Verwaltung gelernter Klauseln

Jede gelernte Klausel auf Dauer zu speichern, treibt den
Speicher in die Höhe und verlangsamt die Propagation. Das
Standardmittel: periodisch die *am wenigsten nützlichen*
gelernten Klauseln zu löschen. „Nützlich" wird durch einen
klausenweisen Aktivitätswert gemessen (erhöht jedes Mal,
wenn der Propagator die Klausel als Unit-Antezedens
verwendet) und durch *LBD* (Literal Block Distance): die
Anzahl der unterschiedlichen Entscheidungs­ebenen unter den
Literalen der Klausel zum Zeitpunkt ihres Lernens. Klauseln
mit niedrigem LBD („Glue-Klauseln", LBD ≤ 6) sind vor dem
Löschen geschützt; der Rest unterliegt einer periodischen
Auslese.

```rust
fn reduce_learnt(state, owned, input_len, threshold) {
    // Keep glue clauses unconditionally.
    let mut candidates: Vec<_> = state.learnt_activity.iter()
        .enumerate()
        .filter(|(i, _)| state.learnt_lbd[*i] > 6)
        .collect();
    candidates.sort_by(|a, b| a.1.partial_cmp(b.1).unwrap());
    // Drop the lowest-activity half.
    // ...
}
```

== Alles zusammensetzen

Ein CDCL-Solver passt einschließlich der gesamten obigen
Maschinerie in etwa 800 Zeilen. Die Datei `cdcl.rs` von
adsmt ist ungefähr von diesem Umfang, und ein aufmerksamer
Leser kann ihre Hauptschleife in weniger als einer Stunde
durchgehen. Die wichtigste Disziplin ist die
*trail-basierte Propagation mit explizitem
Reason-Tagging*: ist die Trail- und Reason-Struktur
einmal richtig, fügt sich jedes andere Teilstück
problemlos ein.

Das nächste Kapitel wendet sich der Theorie-Kombination zu —
der Schicht über SAT, die es mehreren spezialisierten
Theorie-Solvern erlaubt, über gemeinsame Sorten zu
kooperieren.
