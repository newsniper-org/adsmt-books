= ITP-Reflexion

== Was "Reflexion" einbringt

Sobald ein Zertifikat vorliegt, ist das Urteil durch eine
kleine Bibliothek unabhängig prüfbar. Aber für Nutzer, die
in einem interaktiven Theorembeweiser — Lean 4, Rocq,
Isabelle — eingebettet sind, ist es ungeschickt, einen
separaten Zertifikat-Prüfer zu betreiben. Sie wollen das
Urteil des Solvers in einen *echten Beweisterm im Kern des
ITP selbst* umgewandelt sehen, sodass der ITP selbst zur
vertrauenswürdigen Instanz wird.

Genau das ist die *Reflexionsbrücke*: Gegeben ein Zertifikat,
emittiere ITP-Oberflächen-Code (Taktik-Skript oder Term),
der, wenn vom ITP geprüft, das Urteil als seine Aussage
trägt. adsmt liefert drei Reflexions-Backends mit:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*Modul*], [*Status*]),
  [Lean 4], [`adsmt-cert::prover_emit::lean`], [In-Tree-Referenz],
  [Rocq],   [`adsmt-emit-rocq` (out-of-tree)],   [spiegelt Lean],
  [Isabelle], [`adsmt-emit-isabelle` (out-of-tree)], [spiegelt Lean],
)

Der Lean-4-Pfad ist die *Referenz*: Jede Änderung der
Ausgabeform landet zuerst in `lean` und propagiert dann im
Gleichschritt auf die Rocq- und Isabelle-Backends (siehe
`prover_emit_policy.md`).

== Gemeinsame Anker

Die drei Backends teilen sich eine Menge von *Ankern* —
abstrakten Operationen, die jedes Backend implementiert:

```rust
pub trait ProverEmit {
    fn open_proof(&mut self, goal: &Term);
    fn refl_step(&mut self, t: &Term);
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term);
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness);
    fn abductive_assume(&mut self, name: &str, hyp: &Term);
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind);
    // ... 12 obligatorische + abduktive + klassische ...
    fn close_proof(&mut self);
}
```

`adsmt-cert::prover_emit::common` führt ein `Cert` herunter,
indem es seine Schritte durchläuft und die passende
Trait-Methode aufruft. Die Backend-Implementierungen
formatieren dann die ITP-spezifische Syntax. Diese
Faktorisierung hält die drei Backends exakt synchron: Jede
neue Schrittart muss eine Methode zum Trait hinzufügen, was
alle drei Backends zwingt, sie zu behandeln, bevor die
Änderung kompilieren kann.

== Lean 4 — das Referenz-Backend

```rust
impl ProverEmit for LeanEmitter {
    fn open_proof(&mut self, goal: &Term) {
        write!(self.out, "theorem adsmt_goal : {} := by\n",
               lean_term(goal)).unwrap();
        self.indent = 2;
    }
    fn refl_step(&mut self, t: &Term) {
        self.line(&format!("have h{} : {} = {} := rfl",
                           self.next_id(), lean_term(t), lean_term(t)));
    }
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term) {
        let id = self.next_id();
        let prev = self.prev_two();
        self.line(&format!("have h{id} : {} = {} := Trans.trans h{} h{}",
                           lean_term(a), lean_term(c), prev.0, prev.1));
    }
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness) {
        let tactic = match theory {
            TheoryName::Uf  => "congrArg",
            TheoryName::Lia => "linarith",
            TheoryName::Lra => "linarith",
            TheoryName::Bv  => "bv_decide",
            TheoryName::Arr => "simp [Array.get_set]",
            TheoryName::Dt  => "decide",
        };
        self.line(&format!("have h{} : ... := by {}", self.next_id(), tactic));
    }
    fn abductive_assume(&mut self, name: &str, hyp: &Term) {
        // Wird als Lean-sorry-förmiger Platzhalter gerendert.
        self.line(&format!("have {} : {} := by sorry  -- abductive",
                           name, lean_term(hyp)));
    }
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind) {
        let import = match kind {
            ClassicalAxiomKind::Lem => "Classical.em",
            ClassicalAxiomKind::Peirce => "Classical.peirce",
            // ...
        };
        self.preamble.push(format!("open {}", import));
    }
}
```

Ein Zertifikat mit 17 Schritten liefert einen Lean-Taktik-Block
mit 17 `have`-Zeilen, abgeschlossen durch ein `close_proof`,
das den finalen Bezeichner als Beweis des ursprünglichen Ziels
benennt. Die Ausgabe durchläuft den Lean-Elaborator und Kern;
Leans eigene Vertrauensbasis delegiert die Korrektheitspflicht.

== Rocq / Isabelle — Spiegelung

Die Rocq- und Isabelle-Backends leben out-of-tree in
`~/adsmt-contrib/`. Sie implementieren dasselbe `ProverEmit`-Trait,
emittieren aber Rocq-Ltac2-Syntax beziehungsweise
Isabelle-Isar-Syntax.

```text
~/adsmt-contrib/
├── adsmt-emit-rocq/
│   └── src/lib.rs        — impl ProverEmit for RocqEmitter
└── adsmt-emit-isabelle/
    └── src/lib.rs        — impl ProverEmit for IsabelleEmitter
```

Einige hervorzuhebende Randbedingungen:

- *Rocq Ltac1 ist ausgeschlossen.* Nur Ltac2. Die ungetypte
  Oberfläche von Ltac1 ist für maschinell erzeugte Taktiken
  zu spröde — die kleinste Zertifikatvariation erzeugt in
  Ltac1 einen opaken Parse-Fehler, den Ltac2 zur Typisierungszeit
  abfängt.
- *Die Ausgabeform spiegelt Lean exakt.* Jedem `have` in Lean
  entspricht ein `have :` in Isabelle und eine
  `Notation.notation` in Rocq, in derselben Reihenfolge, mit
  denselben Bezeichnernamen. Dies ist eine harte Invariante
  der prover_emit-Policy.
- *Klassische Axiome werden auf Anforderung importiert.* Die
  Präambel jeder emittierten Datei importiert nur die in der
  Präambel des Zertifikats genannten Axiome. Eine
  Offline-First-Prüfung verweigert die Ausgabe, wenn ein
  benanntes Axiom im Ziel-ITP nicht unterstützt wird.

== Round-Trip-Diff-Tests

Die Gleichschritt-Policy wird durch einen *Round-Trip-Diff-Test*
durchgesetzt: Gegeben ein Zertifikat, emittiere die Lean-Ausgabe,
normalisiere zu einem kanonischen AST, emittiere dann die
Rocq-Ausgabe, normalisiere, emittiere dann die Isabelle-Ausgabe,
normalisiere und vergleiche. Jede strukturelle Divergenz zwischen
den drei Bäumen ist eine Policy-Verletzung, die das Mergen
blockiert.

```rust
#[test]
fn lockstep_lean_rocq_isabelle() {
    for cert in golden_certs() {
        let lean_tree   = normalize(emit_lean(&cert));
        let rocq_tree   = normalize(emit_rocq(&cert));
        let isabelle_tree = normalize(emit_isabelle(&cert));
        assert_eq!(lean_tree.shape(), rocq_tree.shape());
        assert_eq!(lean_tree.shape(), isabelle_tree.shape());
    }
}
```

Genau das meint man mit "Lean 4 Referenz" — Lean ist nicht
einfach *eines von drei* Ausgabeformaten, es ist das Format,
dessen Form die anderen replizieren müssen.

== Abduktive Lücken als `sorry`

Abduktive Schritte emittieren ITP-eigene `sorry`-Platzhalter.
Lean: `sorry`. Rocq: `Admitted` (wenn die abduktive Schicht
an einer Definitionsgrenze liegt) oder `give_up` (im
Taktikmodus). Isabelle: `sorry`.

Jeder Platzhalter ist nach der abduktiven Hypothese benannt,
sodass der Nutzer im Editor eine Liste benannter
Verpflichtungen sieht wie:

```text
adsmt_h_3 : ∀ x, x > 0 → P x
adsmt_h_7 : a ≠ b
```

Es sind genau die Hypothesen, die die abduktive Schicht
hervorgebracht hat — nun im ITP-Gewand. Der Nutzer erfüllt
sie durch Beweis oder durch Akzeptanz als Axiome; der Rest
des Beweises geht unter dem ITP-eigenen Kern durch.

== Die volle Kette

Stellt man die Schichten der Kapitel 1-10 zusammen, ergibt
sich die End-to-End-Pipeline:

```text
SMT-LIB script
   ↓ parse
Internal AST
   ↓ engine.check_sat (CDCL + theory + quantifier + abduce)
SatResult
   ↓ recorder
Cert (S-expr)
   ↓ prover_emit::lean / ::rocq / ::isabelle
ITP-surface proof script
   ↓ ITP kernel
Verified theorem
```

Jedes Glied dieser Kette hat einen unabhängigen Verifizierer
auf der anderen Seite. Der Kern (Kapitel 2) verifiziert sich
durch sich selbst — die 12 Regeln sind der Korrektheitsvertrag.
Der Prüfer (Kapitel 9) verifiziert das Zertifikat gegen die
Kernregeln. Der ITP (Kapitel 10) verifiziert den emittierten
Beweis gegen seinen eigenen Kern. Die abduktive Schicht
(Kapitel 8) führt *benannte Verpflichtungen* ein, keine
Unkorrektheit — der Nutzer sieht sie explizit und entscheidet.

Genau das meint man, wenn man sagt, SMT-als-Taktik solle
einem Beweisassistenten dienen. Das Urteil des Solvers ist
nie das letzte Wort; der Kern des ITP ist es.
