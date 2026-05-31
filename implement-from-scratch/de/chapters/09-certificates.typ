= Zertifikate

== Wozu Zertifikate?

Ein moderner SMT-Solver umfasst Größenordnungen von $10^5$
Zeilen verwobenen Codes. Einen Nutzer zu bitten, seinen Urteilen
auf Treu und Glauben zu vertrauen, ist viel verlangt — besonders
in den sicherheitskritischen Verifikationsszenarien, in denen
SMT am wertvollsten ist.

Die Lösung ist das *Beweiszertifikat*: ein strukturierter
Datensatz darüber, wie das Urteil zustande kam, derart entworfen,
dass ein deutlich einfacherer externer Prüfer es nachverifizieren
kann. Der Prüfer muss weder CDCL noch Theoriekombination noch
Quantor-Instantiierung verstehen — er muss lediglich jeden
Schritt gegen eine feste Menge von Inferenzregeln verifizieren.

Das Zertifikatformat von adsmt heißt `adsmt-cert`, eine
S-Ausdruck-Sprache mit 12 Schrittarten, die den 12 Kernregeln
aus Kapitel 2 entsprechen, plus drei abduktiven Markern und
einer Handvoll Theorie-Zeugen.

== Format-Übersicht

```text
(cert.v1
  (preamble
    (kernel-version "0.19")
    (cert-version "1")
    (classical-axioms (lem peirce))
    (theories (uf lia bv)))
  (steps
    (step :rule refl   :id 1 :term (= x x))
    (step :rule assume :id 2 :term (P x))
    (step :rule beta   :id 3 :input 2 :term ...)
    ...
    (step :rule deduct :id 17 :conclusion (=> (P x) (Q y))))
  (verdict unsat
           :final-step 17))
```

Jeder Schritt ist durch eine eindeutige numerische `id`
gekennzeichnet. Schritte referenzieren frühere Schritte über
ihre id, sodass die Abhängigkeitsstruktur einen DAG bildet,
der am `verdict`-benannten Endschritt mündet.

== StepBody — 12 + 3 + …

Die Rust-Typen spiegeln das Format direkt wider:

```rust
pub struct Cert {
    pub preamble: Preamble,
    pub steps: Vec<Step>,
    pub verdict: Verdict,
}
pub struct Step { pub id: StepId, pub body: StepBody }

pub enum StepBody {
    Refl(Term),
    Trans { lhs: StepId, rhs: StepId },
    EqMp { lhs: StepId, rhs: StepId },
    Abs { var: Arc<Var>, body: StepId },
    Beta(Term),
    Deduct { hyp: StepId, conc: StepId },
    Inst { rule: StepId, var: Arc<Var>, term: Term },
    InstType { rule: StepId, var: Arc<TyVar>, ty: Type },
    Assume(Term),
    Theory { theory: TheoryName, witness: TheoryWitness },
    Instance { class: Term, dict: Term },
    Assumed(Term),
    AbductiveAssume { hypothesis: Vec<Term>, justification: AbductionJustification },
    AbductiveAccept { hypothesis: StepId, ground: Vec<Term> },
    ClassicalAxiom { axiom: ClassicalAxiomKind, instantiation: Vec<Term> },
}
```

Die obligatorischen 12 spiegeln den Kern aus Kapitel 2. Das
abduktive Trio behandelt die Ausnahmen aus Kapitel 8. Der
klassische Axiom-Marker handhabt Schritte, die von LEM,
Peirce oder einem anderen Axiom vom Typ ausgeschlossenes
Drittes abhängen — diese müssen in der Präambel im Voraus
deklariert werden, damit der Prüfer das Zertifikat ablehnen
kann, falls der Konsument das angegebene Axiom nicht
akzeptiert.

== Der Recorder

Die zwölf Regelimplementierungen des Kerns geben Zertifikat-Schritte
nicht direkt aus — das würde den Kern-TCB mit Format-Belangen
verstricken. Stattdessen ist der Recorder ein dünner Beobachter,
der den Kern umhüllt:

```rust
pub struct CertRecorder {
    steps: Vec<Step>,
    next_id: u64,
    preamble: PreambleBuilder,
}

impl CertRecorder {
    pub fn record_refl(&mut self, t: Term) -> StepId {
        let id = self.alloc_id();
        self.steps.push(Step { id, body: StepBody::Refl(t) });
        id
    }
    pub fn record_trans(&mut self, lhs: StepId, rhs: StepId) -> StepId {
        let id = self.alloc_id();
        self.steps.push(Step { id, body: StepBody::Trans { lhs, rhs } });
        id
    }
    // ... eine Methode pro StepBody-Variante ...

    pub fn finalize(self, verdict: Verdict) -> Cert {
        Cert { preamble: self.preamble.build(), steps: self.steps, verdict }
    }
}
```

Sobald die Engine eine Kernregel aufruft, ruft sie auch die
passende Recorder-Methode auf und webt damit den Schritt in
das Zertifikat ein. Dies ist die einzige Stelle, an der die
Kern-Zertifikat-Kopplung lebt; alles andere arbeitet mit dem
Zertifikat als gewöhnlicher Datenstruktur.

== Der Prüfer

Der Zertifikat-Prüfer ist eine separate Bibliothek — keine
Kernkomponente —, die ein `Cert` gegen die Kernregeln
nachverifiziert. Er pflegt eine Abbildung
`step_id |-> conclusion` und durchläuft das Zertifikat in
id-Reihenfolge:

```rust
pub fn check(cert: &Cert) -> Result<(), CertError> {
    let mut concl: HashMap<StepId, Term> = HashMap::new();
    let mut deps:  HashMap<StepId, HashSet<Term>> = HashMap::new();
    for step in &cert.steps {
        let (term, hyps) = check_step(step, &concl, &deps, &cert.preamble)?;
        concl.insert(step.id, term);
        deps.insert(step.id, hyps);
    }
    let final_term = concl.get(&cert.verdict.final_step)
        .ok_or(CertError::DanglingFinal)?;
    cert.verdict.matches(final_term)
}
```

Der raffinierte Teil ist `check_step`. Für jede Regel liest
sie die zitierten Abhängigkeiten aus `concl`/`deps` heraus,
wendet die Prämissen der Regel an und erzeugt entweder ein
frisches `(term, hypotheses)`-Paar oder weist den Schritt
zurück.

Beispielsweise wird `Trans { lhs, rhs }` so geprüft:

```rust
StepBody::Trans { lhs, rhs } => {
    let (Term::Eq(a, b), hyps_a) = (concl[lhs].clone(), deps[lhs].clone()) else {
        return Err(CertError::TransNeedsEq);
    };
    let (Term::Eq(c, d), hyps_b) = (concl[rhs].clone(), deps[rhs].clone()) else {
        return Err(CertError::TransNeedsEq);
    };
    if b != c { return Err(CertError::TransPivotMismatch); }
    Ok((Term::eq(a, d), &hyps_a | &hyps_b))
}
```

Das ist der gesamte Prüfer für `Trans` — ein paar Form- und
Gleichheits-Behauptungen. Der Prüfer umfasst insgesamt rund
600 Zeilen für alle 15 Schrittarten, zwei Größenordnungen
kleiner als der Solver, der das Zertifikat erzeugt hat.

== Ausgabe-/Parse-Round-Trip

`adsmt-cert` exponiert einen Parser und einen Pretty-Printer
für die S-Ausdruck-Syntax:

```rust
pub fn parse(input: &str) -> Result<Cert, ParseError>;
pub fn write(cert: &Cert, out: &mut impl Write) -> std::io::Result<()>;
```

Ein Round-Trip-Property-Test (`parse(write(c)) == c`) läuft
auf der Testsuite. Die S-Ausdruck-Syntax ist hinreichend
zeilenorientiert, dass Menschen sie direkt lesen können, was
sich beim Debuggen des Recorders als unschätzbar erweist.

== Urteils-Abgleich

Die Konklusion des Endschritts muss zum deklarierten Urteil
*passen*. Für Unsat heißt das, der Endschritt schließt mit
$"False"$ und der leeren Hypothesenmenge. Für Sat ist der
Endschritt ein Modellzeuge (eine Liste von
Konstantenzuweisungen), konsistent mit allen behaupteten
Atomen.

Das Abductive-Urteil ist die neue Form: Sein Endschritt
referenziert eine oder mehrere `AbductiveAssume`-Schritte
und deklariert die residualen Hypothesen. Der Prüfer
durchläuft die Kette, um zu bestätigen, dass modulo der
benannten Hypothesen das Urteil durchgeht.

== Hygiene klassischer Axiome

Der Kern aus Kapitel 2 ist *minimal* — er backt weder das
ausgeschlossene Dritte, noch das Peirce-Gesetz, noch
irgendein anderes der klassisch-gültig-aber-intuitionistisch-
ungültigen Prinzipien ein. Hängt ein Solver-Schritt von
einem solchen Axiom ab, muss er als `ClassicalAxiom`-Schritt
protokolliert werden, der das Axiom und seine Instantiierung
benennt, und die Präambel muss das Axiom in ihrem
`classical-axioms`-Block deklarieren.

Nachgelagerte Konsumenten (insbesondere ITPs) haben oft
starke Präferenzen: Ein konstruktives Lean-4-Modul könnte
ein Zertifikat ablehnen, das `lem` nennt, selbst wenn das
Zertifikat intern gültig ist. Die Präambeldeklaration
erlaubt es dem Konsumenten, zur Parse-Zeit zu entscheiden,
ob das Zertifikat akzeptiert wird, ohne jeden Schritt
durchlaufen zu müssen.

== Reflexionsbrücke

Das aufgezeichnete Zertifikat ist die Eingabe für die
ITP-Reflexionsschicht (Kapitel 10). `adsmt-cert::prover_emit::lean`,
`::rocq` und `::isabelle` führen ein `Cert` in die
Oberflächensyntax des Ziel-ITP über, wobei jede Schrittart
einem bestimmten Taktikaufruf oder Term-Konstruktor
zugeordnet wird.

Reflexion hat ihre eigenen Korrektheitsanliegen — die
Korrektheit der *gesamten* Kette "adsmt-Urteil $->$ Zertifikat
$->$ ITP-geprüfter Beweis" erfordert, dass die Reflexionsschicht
jeden Schritt treu übersetzt. Diese Maschinerie betrachtet
man als Nächstes.
