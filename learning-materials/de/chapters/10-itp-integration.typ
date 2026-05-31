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
wofür adsmt da ist.
