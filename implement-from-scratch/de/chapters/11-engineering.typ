= Engineering-Belange

Dieses abschließende Kapitel tritt vom algorithmischen Rückgrat
zurück und führt durch die *Engineering*-Praktiken, die das
Design der Kapitel 1-10 in einen wartbaren, stabilen Solver
verwandeln. Themen:

- Workspace-Layout und Crate-Grenzen
- Teststrategie (Unit, Integration, Property, Differential,
  Benchmark)
- Oberflächen-Einfrierungen (ABI, Dialekt, Zertifikat)
- Semver-Disziplin und der 8-Schichten-Heuristik-Prüfer
- Release-Engineering — Debian-artige Kanäle

== Workspace-Layout

Die größte einzelne Engineering-Entscheidung in adsmt ist
der *flache Crate-Split*. Jede Hauptkomponente ist ein
eigener Crate:

```text
adsmt-core/         HOL+HKT kernel (TCB)
adsmt-cert/         Cert format + checker + emit
adsmt-theory/       Theory trait + the six theories
adsmt-class/        Type-class + dictionary passing
adsmt-quant/        Quantifier instantiation
adsmt-abduce/       Abductive layer
adsmt-engine/       DPLL(T) + CDCL + bit-blasting
adsmt-parser/       SMT-LIB v2 + lu-kb parser
adsmt-cli/          `lu-smt` binary
adsmt-lsp/          tower-lsp server
adsmt-ffi/          C ABI
adsmt-meta/         Umbrella crate
adsmt-lints/        Runtime audit library
adsmt-heuristic-checker[-macros]/  Offline semver guards
```

Mehrere nicht offensichtliche Vorteile ergeben sich:

1. *Kompilier-Parallelismus.* Cargo kann die 14 adsmt-Crates
   nebenläufig bauen. Ein sauberer Build ist durch den
   längsten einzelnen Crate (`adsmt-engine`) beschränkt,
   nicht durch die Summe.
2. *Oberflächengrenzen.* Die ABI der öffentlichen Oberfläche
   jedes Crates ist sein eigener Vertrag. Interne Refaktorierungen
   riskieren keinen Durchschlag durch `pub(crate)`-Wände.
3. *Selektive Features.* Nachgelagerte Konsumenten können
   ausschließlich auf `adsmt-core` (nur Kern) bauen, ohne
   den Parser, das LSP oder das CLI mit hereinzuziehen.
4. *Eingefrorene Oberflächen.* Drei Crates — `adsmt-ffi`,
   `adsmt-cert`, `adsmt-parser` — haben explizite
   Oberflächen-Einfrier-Policies, die durch Makros
   durchgesetzt werden; die übrigen entwickeln sich
   freier.

== Teststrategie

Jede Schicht hat ihre eigene Testdisziplin:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Schicht*], [*Disziplin*]),
  [Kern],     [Unit-Tests auf jeder Regel, plus ein TCB-definierender Property-Test: "Jeder Term, der nur über die 12 Regeln aus der leeren Annahmenmenge konstruierbar ist, ist erfüllbar."],
  [Theorie],  [Unit-Tests pro Theorie, plus ein polite-Kombinations-Integrationstest, der die Nelson-Oppen-artige Gleichheitspropagierung übt.],
  [Quantor],  [Unit-Tests auf dem Matcher + Trigger-Lerner, plus Golden-Zertifikat-Tests für jede Tier-Eskalation.],
  [Abduktiv], [Differentialtest: Jeder erzeugte Kandidat muss eine *gültige* Hypothese sein (`H union phi` entscheidet) und *minimal* (keine echte Teilmenge von `H` tut es).],
  [Engine],   [Integrationstests über SMT-LIB-Skripte, eingecheckt unter `tests/smtlib/`.],
  [Parser],   [Property-Tests auf Round-Trip `parse(write(t)) == t`.],
  [Cert],     [Property-Test: `check(record(...)) == Ok(())` für jeden Kernlauf.],
  [Bench],    [Criterion-HTML-Berichte unter `target/criterion/`, nach jeder algorithmischen Änderung neu basislinisiert.],
)

Die Schlagzeilen-Garantie — "der Kern ist korrekt" — kommt
aus einem winzigen Test der Kernregeln selbst. Die Korrektheit
des *Solvers* ist die Konjunktion aus (Kernregeln korrekt) +
(Recorder verwendet nur Kernregeln) + (Prüfer akzeptiert nur
Zertifikate, die aus Kernregeln gebaut sind). Jeder dieser
Punkte ist unabhängig testbar; die Korrektheitskette ist
das Produkt.

== Oberflächen-Einfrierungen

Drei Oberflächen sind bei v1.0.0 eingefroren:

*adsmt-ffi/ABI_POLICY.md.* Die von `adsmt-ffi` exportierte
C-ABI ist die Integrationsoberfläche für Nicht-Rust-Konsumenten.
Einmal eingefroren, erfordert jede Änderung an der Signatur
einer öffentlichen Funktion einen Breaking-Versionssprung.
Das Makro `#[breaking_changes_semver("1.0.0")]` auf der
`lib.rs` des Crates ist die Offline-Durchsetzung: Jeder
Commit, der eine `pub extern "C" fn`-Signatur ändert, muss
auch die deklarierte Version anheben.

*adsmt-parser/DIALECT_POLICY.md.* Sowohl SMT-LIB v2 als auch
die lu-kb-Eingabedialekte sind eingefroren. Neue Schlüsselwörter
können hinzugefügt werden (additiv), aber die Grammatiken
bestehender Schlüsselwörter sind fixiert. Der Parser besteht
die SMT-LIB-v2-Konformanzsuite als Regressionstest.

*adsmt-cert/CERT_POLICY.md.* Die 12 + 3 + …-Schrittarten sind
eingefroren. Neue Schrittarten dürfen unter Semver hinzugefügt
werden (additiv), aber die Payload-Form einer Art ändert sich
nicht ohne Breaking-Sprung.

Diese drei Policies geben nachgelagertem Tooling
(`adsmt-emit-rocq`, `adsmt-emit-isabelle`, der
VS-Code-Erweiterung, Nutzer-Taktikgeschirren) ein stabiles
Ziel. Der Rest des Workspace ist frei, sich weiterzuentwickeln.

== Semver-Disziplin

Die Rust-Semver-Konvention gilt: $0.y.z$ für
Vor-1.0-Flexibilität, $1.y.z$ ab da für stabile APIs. adsmt
eröffnete seinen v1.0-Zyklus mit der v0.19-Entwicklungslinie
im Mai 2026, und (gemäß `feedback_stable_signoff_user_approval.md`)
erfordert der v1.0.0-Stable-Cut die explizite Zustimmung des
Nutzers.

Der 8-Schichten-Heuristik-Prüfer (`adsmt-heuristic-checker`)
ist die Offline-Absicherung. Acht unabhängige Schichten
querprüfen jeden Breaking-Versionssprung-Kandidaten:

1. Makro-Attribut auf der `lib.rs` des Crates
2. CHANGELOG-Eintrag unter der Versions-Überschrift
3. Versionsfeld in Cargo.toml
4. Markdown-Referenz auf die Frozen-Surface-Policy
5. Cross-Crate-Konsistenz (Workspace-Abhängigkeitsgraph)
6. Snapshot-Test gegen die öffentliche API der Vorgängerversion
7. Konformanzsuite-Regressionsprüfung
8. CI-Wache, die jeden Tag ohne die sieben vorhergehenden
   ablehnt

Ein Versionssprung, der irgendeine Schicht verfehlt, wird
abgelehnt, bevor das Tag gepusht wird. Die Disziplin ist
schwer, aber es ist der Preis, ein Projekt mit eingefrorener
Oberfläche zu betreiben.

== Kanäle

adsmt entleiht sich Debians Kanalmodell:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Kanal*], [*Branch*], [*Zweck*]),
  [unstable], [`main`],     [Aktive Entwicklung; neue Commits landen hier.],
  [testing],  [`testing`],  [Stabilisierungskandidaten, befördert aus `main`.],
  [stable],   [`v1.0.0` (Tag)], [Veröffentlichte Versionen; das v1.0.0-Tag ist das erste.],
)

Der `testing`-Branch wurde im Mai 2026, nach v1.0.0-rc.2, an
Commit `450b986` aus `main` abgespalten. Nachfolgende
Hot-Fixes können entweder auf `main` (nächster Major-Zyklus)
oder `testing` (laufende Stabilisierung) landen, mit per Fix
entschiedener Cherry-Pick-Richtung.

== Release-Engineering

Ein Release wird in fünf Schritten geschnitten:

1. Kandidat auf `testing` taggen, nachdem alle Wachen in CI
   grün sind.
2. RC-Audit durchführen (RC2.1-RC2.9 sind die tatsächlichen
   Nummern des Zyklus), das abdeckt: Feature-Matrix,
   Publish-Dry-Run, Warnungsdurchsicht, Doc-Audit,
   Bench-Neubasislinierung, LSP-Laufzeit-Smoke,
   Contributions-Audit, Doc-Warnung-Schweigen, README-Verfassung.
3. Explizite Freigabe durch den Nutzer
   (`feedback_stable_signoff_user_approval.md`).
4. `v1.0.0` auf dem Freigabe-Commit taggen; ans Remote pushen.
5. Den Workspace-Pin von `~/adsmt-contrib/` auf das neue Tag
   aktualisieren; seinen Smoke-Test gegen die frisch
   veröffentlichten `adsmt-cert` und `adsmt-core` laufen
   lassen.

`~/adsmt-contrib/` ist das *contrib*-Repository: out-of-tree
Rocq- und Isabelle-Emit-Backends. Es verfolgt die Version
des Hauptrepos (`1.0.0` gegen `1.0.0`) und konsumiert die
veröffentlichten `adsmt-cert` + `adsmt-core` über Git-Tag-Pin.
Die `contributions/oxiz/*`-Submodule unterhalb des Hauptrepos
bleiben unabhängig auf ihren eigenen Versionslinien und
verfolgen die Upstream-`oxiz`-Beiträge, nicht das adsmt-Release.

== Speicher- und Designarchiv

Zwei Nicht-Code-Persistenzsysteme stehen neben dem Quelltext:

- `memory/*.md` — projektinterner Kontext (Zyklusgeschichte,
  Roadmap, Freigabe-Policies). Jede Datei ist ein Thema; der
  Index liegt in `MEMORY.md`.
- `.claude-conversations/` — vollständiges Archiv der
  Designkonversationen. Die interessanten Entscheidungen und
  Sackgassen leben hier, abrufbar nach Datum und Thema.

Diese existieren, weil das Designrationale nicht immer in
Code oder Git-Nachrichten ausdrückbar ist. Wenn ein
zukünftiger Maintainer fragt "warum ist der E-Graph in seine
eigene Theorie verpackt, statt in `adsmt-theory::uf` zu
leben?", liegt die Antwort in einer Diskussion in
`memory/oxiz_relationship.md` aus dem Mai 2026.

== Schlussbemerkung

Die Engineering-Disziplin, die dieses Kapitel beschreibt, ist
das, was das algorithmische Rückgrat der Kapitel 1-10 in
einen Solver verwandelt, den jemand tatsächlich verwenden
könnte. Der Kern mag brillant sein; wenn der Parser beim
nächsten SMT-LIB-Zusatz bricht, wenn das Zertifikatformat
mit jedem Release driftet, wenn die C-ABI ihre Signatur ohne
Versionssprung ändert, ist der Solver kein Werkzeug — er ist
ein Schülerwettbewerbsprojekt.

Eingefrorene Oberflächen, Heuristik-Prüfer, Kanaldisziplin,
property-getestete Schichten, ein explizites Speichersystem —
nichts davon ist aufregend. Alles davon ist notwendig. Sie
sind der Grund, weshalb ein v1.0.0-Schnitt *bedeutsam* ist
und nicht nur eine Zahl auf einem Tag.

Das nächste Buch dieser Reihe, *Lernmaterialien*, knüpft hier
an und führt durch die *Verwendung* von adsmt — von den
SMT-LIB- und lu-kb-Oberflächen über das LSP, die
Lean-4-Taktik und den abduktiven Arbeitsablauf. Das
vorliegende Buch handelte von Implementierung; das nächste
handelt von Praxis.
