= Zertifikate und Vertrauen

== Warum "dem Solver vertrauen" nicht ausreicht

Moderne SMT-Solver sind groß: zehntausende Zeilen komplexen
Codes, die SAT, Theorie-Solver, Heuristiken, Kombination und
Quantoreninstanzierung umspannen. Fehler sind selten, aber
nicht unbekannt: subtile Probleme beim Simplex-Pivotieren,
ausgelassene Kongruenzschluss-Kaskaden, Lücken in der
Korrektheit der Quantoreninstanzierung. Alle diese wurden im
Lauf der Jahre in produktiven Solvern gefunden.

Für die meisten Anwendungen (Programmverifikation auf einem
"Best-Effort"-Niveau, Scheduling, Planung) ist das verbleibende
Fehlerrisiko akzeptabel. Für Arbeiten mit hoher Zusicherung
(formal verifizierte Compiler, sicherheitskritische
Spezifikationen, Beweisassistenten) ist es das nicht.

Die Abhilfe sind *Zertifikate*: eine strukturierte Spur, wie der
Solver zu seinem Verdikt gelangt ist, so gestaltet, dass ein
viel kleinerer externer Prüfer — oder der Beweisassistent
selbst — sie nachverifizieren kann.

== Die Zertifikatsidee

Wenn der Solver ein Verdikt herleitet, gibt er nicht einfach
"unsat" zurück; er gibt die Schritt-für-Schritt-Argumentation
zurück:

```text
(cert.v1
  (preamble (kernel-version "0.19") (cert-version "1"))
  (steps
    (step :rule assume :id 1 :term (P a))
    (step :rule assume :id 2 :term (=> (P a) (Q b)))
    (step :rule eq_mp  :id 3 :lhs 2 :rhs 1)
    (step :rule assume :id 4 :term (not (Q b)))
    (step :rule deduct :id 5 :hyp 4 :conc 3))
  (verdict unsat :final-step 5))
```

Jeder `step` zitiert frühere Schritte und wendet eine aus einer
festen Menge von Inferenzregeln an. Das endgültige Verdikt
verweist auf einen letzten Schritt, dessen Konklusion zur
deklarierten Verdiktform passt.

Der *Prüfer* — separat, klein (etwa 600 Zeilen) — durchläuft
die Schritte der Reihe nach, validiert jeden gegen die
Regeldefinitionen und bestätigt das Verdikt.

== Warum der Prüfer klein sein kann

Der Solver leistet enorme Arbeit, um das Zertifikat zu *finden*.
Der Prüfer muss jeden Schritt nur *verifizieren*. Die
Verifikation eines einzelnen Schritts ist einfaches
Mustervergleichen:

```rust
StepBody::Trans { lhs, rhs } => {
    let (Term::Eq(a, b), _) = concl[lhs] else { return Err(...); };
    let (Term::Eq(c, d), _) = concl[rhs] else { return Err(...); };
    if b != c { return Err(TransPivotMismatch); }
    Ok(Term::eq(a, d))
}
```

Zwölf Regeln, jede einige Zeilen lang. Der Prüfer umfasst
insgesamt etwa 600 Zeilen. Ein Fehler im Solver pflanzt sich
nicht in einen Fehler im Prüfer fort (anderer Code, andere
Autoren, andere Tests).

== Das Zertifikatsformat von adsmt

Das Format `adsmt-cert` hat 12 verpflichtende Kern-Regelarten
(passend zu den 12 Inferenzregeln des Kerns, Begleitband
Kap. 2) plus drei abduktive Marker (Kap. 8) plus
Theorie-Zeugen (Kap. 4-6):

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Art*], [*Zweck*]),
  [`refl`, `trans`, `eq_mp`], [Gleichheitsschließen],
  [`abs`, `beta`],            [Lambda-Kalkül],
  [`deduct`, `inst`, `inst_type`], [Hypothetisches Schließen, Instanzierung],
  [`assume`, `assumed`],      [Hypothesen, Axiome],
  [`theory`],                 [Theorie-Zeugen (UF, LIA, BV, …)],
  [`instance`],               [Typklassen-Instanzen],
  [`abductive_assume`, `abductive_accept`], [Abduktiver Hypothesen-Pfad],
  [`classical_axiom`],        [Schritte, die von LEM, Peirce usw. abhängen],
)

Das Format ist im Anhang C des Begleitbandes ausführlich
dokumentiert.

== Theorie-Zeugen

Theorieschritte leiten die Argumentation der Theorie nicht neu
ab; sie zitieren einen *Zeugen*, den das
Entscheidungsverfahren der Theorie separat validiert. UF
zitiert die Kette der union/find-Vereinigungen; LIA zitiert
eine Farkas-Kombination, die Unerfüllbarkeit nachweist; BV
zitiert den Beweis auf Bit-Ebene.

```text
(step :rule theory :theory lia :witness
  (farkas
    :combination ((1.0 c_eq) (-1.0 c_x_lb))
    :concludes (≥ 10 17)))
```

Der Zertifikatsprüfer ruft das Theoriemodul zurück, um den
Zeugen zu validieren. Somit vertraut die Zertifikatsschicht
dem Theorieprüfer; der Theorieprüfer vertraut seiner
mathematischen Grundlage. Die TCB (trusted computing base)
jedes Schritts ist klein und überprüfbar.

== Klassische Axiome

Manche Schritte hängen von Axiomen der *klassischen* Logik
ab — LEM (Satz vom ausgeschlossenen Dritten), Peirce,
Doppelnegations-Elimination. Diese sind in der klassischen
Mathematik gültig, in der intuitionistischen Logik *nicht*.

Das Zertifikat verfolgt die Verwendung klassischer Axiome
explizit:

```text
(preamble
  (classical-axioms (lem peirce)))
(steps
  (step :rule classical_axiom :id 7 :axiom lem :instantiation ((P a))))
```

Ein Lean-4- (oder Rocq-, Isabelle-) Konsument, der
konstruktive Beweise bevorzugt, kann ein Zertifikat ablehnen,
das LEM benennt. Die Registrierung klassischer Axiome in der
Präambel macht die Richtlinie zur Parsezeit durchsetzbar.

== Vertrauensgrenzen

Die vollständige Kette von "ich vertraue diesem Verdikt":

1. *Dem Kern vertrauen.* 12 Inferenzregeln; etwa 1000 Zeilen
   Rust. Der Kern ist die TCB.
2. *Dem Recorder vertrauen.* Der Recorder ruft nur Kernregeln
   auf; wenn ein Schritt in einem Zertifikat erscheint, ist er
   tatsächlich im Kern passiert. (Dies ist als Eigenschaft
   testbar: jeder zertifizierte Schritt durchläuft den Kern
   und kehrt zurück.)
3. *Dem Prüfer vertrauen.* Etwa 600 Zeilen, hauptsächlich
   Mustervergleich. Unabhängig testbar.
4. *Dem ITP vertrauen.* Lean 4 / Rocq / Isabelle haben jeweils
   ihren eigenen Kern und ihre eigene Vertrauensgeschichte. Die
   Reflexionsschicht (Kapitel 10) übersetzt Zertifikate in
   Beweise *unter dem Kern jedes ITPs*, wodurch das Vertrauen
   auf den ITP übertragen wird.

Jedes Glied in dieser Kette hat seinen eigenen
Verifikationsweg, der nicht von den anderen abhängt. Das
Vertrauen in das Gesamtsystem ist nicht "adsmt vertrauen" —
es ist "einem kleinen Kern plus einem separat implementierten
Prüfer vertrauen, wobei jeder die Ausgaben des anderen
verifiziert".

== Wenn das Zertifikat dem Verdikt widerspricht

Wenn der Prüfer ein Zertifikat ablehnt, *stimmt etwas nicht*.
Entweder hat der Solver einen Fehler (er hat unsat behauptet,
aber die Kette belegt unsat nicht tatsächlich) oder der
Zertifikats-Recorder hat einen Schritt verloren. Beides ist
gravierend; beides ist auffindbar.

Für adsmt gilt die Regel *vor dem Commit prüfen*: jeder
Testlauf überprüft die erzeugten Zertifikate. Die CI lehnt
jeden Commit ab, bei dem geprüfte Zertifikate nicht validieren.
Die Disziplin kostet ein wenig CPU und bringt Seelenfrieden.

== Praktische Empfehlungen

- *Verwenden Sie Zertifikate für Arbeiten mit hoher
  Zusicherung.* Übersetzen Sie Ihr SMT-LIB-Skript mit
  `--emit-cert`, erhalten Sie eine `.cert`-Ausgabe und lassen
  Sie sie durch `adsmt-cert-check` laufen. Wenn beide
  übereinstimmen, haben Sie eine unabhängige Bestätigung.
- *Verwenden Sie Zertifikate nicht für beiläufiges
  Prototyping.* Der Aufwand für das Schreiben von Zertifikaten
  ist klein (wenige Prozent), aber von null verschieden.
  Wenn Sie an einer Spezifikation iterieren, ist das
  Zertifikat verlorene Bytes.
- *Lesen Sie Ihre Zertifikate gelegentlich.* Das
  S-Ausdrucks-Format ist menschenlesbar. Wenn ein Ziel, das
  Sie für durch linarith erledigt hielten, tatsächlich Peirce
  verwendet hat, sagt Ihnen das Zertifikat das.

== Die Kette geht weiter

Kapitel 10 nimmt das Zertifikat auf und zeigt, wie ein
nachgelagerter ITP — Lean 4 im Detail, Rocq und Isabelle im
Überblick — das Zertifikat in einen *echten Beweis unter dem
Kern des ITPs* verwandelt. Dort schließt sich die
Vertrauensgrenze vollständig.
