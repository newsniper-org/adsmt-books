= CLI-Cheatsheet

Der Befehl `lu-smt` (bereitgestellt von `adsmt-cli`) ist der
primäre Einstiegspunkt auf der Kommandozeile. Dieser Anhang
ist eine Schnellreferenz.

== Grundlegender Aufruf

```bash
# Run an SMT-LIB script
lu-smt path/to/script.smt2

# Run a lu-kb knowledge base
lu-smt path/to/base.kb

# Read from stdin
cat script.smt2 | lu-smt -

# Verbose output (warns + audit info)
lu-smt -v script.smt2
```

Der Exit-Code spiegelt das Verdikt wider:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Verdikt*], [*Exit*], [*Ausgabe*]),
  [`sat`],   [0], [`sat`],
  [`unsat`], [0], [`unsat`],
  [`unknown`], [1], [`unknown` + Begründung],
  [`abductive`], [2], [`abductive` + Kandidaten, falls angefordert],
  [Parse-Fehler], [3], [Diagnose nach stderr],
)

== Häufige Flags

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Flag*], [*Wirkung*]),
  [`--emit-cert <file>`], [Schreibt das Zertifikat in `<file>` (S-Ausdrucks-Format)],
  [`--check-cert <file>`], [Verifiziert ein Zertifikat erneut, ohne den Solver erneut auszuführen],
  [`--audit-json`], [Gibt Audit-Diagnosen als JSON aus],
  [`--abductive-tier <n>`], [Setzt Tier (0 = aus, 4 = voll)],
  [`--trigger-mode <miller|free>`], [Beschränkt oder erlaubt Nicht-Miller-Trigger],
  [`--timeout <ms>`], [Hartes Timeout in Millisekunden],
  [`--seed <n>`], [Zufalls-Seed (für Reproduzierbarkeit)],
  [`-v` / `--verbose`], [Ausführliche Ausgabe],
  [`-h` / `--help`], [Vollständiger Hilfetext],
)

== Optionen auf SMT-LIB-Ebene

Diese werden innerhalb des SMT-LIB-Skripts via `(set-option ...)` gesetzt:

```text
(set-option :produce-models true)     ;; für Sat-Verdikte
(set-option :produce-unsat-cores true);; für Unsat-Verdikte
(set-option :produce-proofs true)     ;; Zertifikat emittieren
(set-option :timeout 5000)            ;; 5 Sekunden Wanduhrbudget (ms)
(set-option :rlimit 30000000)         ;; Z3-Stil-Ressourcenlimit (~30 s)

;; §3.4 GF(2) Gröbner-Basis-Plugin (opt-in)
(set-option :finite-field-periodic 32)
(set-option :finite-field-budget-exhaustion true)
```

Die `:finite-field-*` Schlüssel können auch als
`--finite-field-periodic N` /
`--finite-field-budget-exhaustion` Startflags übergeben
werden; beide Wege registrieren ein `FiniteFieldTheory`-Plugin
in der Engine.  Mid-Session `(set-option ...)` registriert
das Plugin beim ersten Aufruf automatisch mit Standard-Knobs.

== §3.1 AOT-Präludium-Bank

Übersetzen Sie ein gewichtiges Präludium (das Präludium von
Verus ist das kanonische Beispiel mit ~10⁵ Klauseln) einmal in
eine `.luart` v0-Artefaktdatei und laden Sie es vorab-asserted
in jeden Pro-Query-Aufruf:

```bash
# Einmaliges Bake des Präludiums.  Die `.luart`-Datei
# zeichnet einen SHA-256 der Eingabe + die lu-smt-Version
# auf, unter der gebakt wurde — der Aufrufer kann das Paar
# als Cache-Schlüssel nutzen.
lu-smt --aot-bake --aot-output prelude.luart prelude.smt2

# Jeder Pro-Query-Aufruf assertiert das Präludium vor
# dem Lesen der regulären SMT-LIB-Eingabe.
lu-smt --aot-load prelude.luart query.smt2
```

`--aot-bake` und `--aot-load` schließen sich gegenseitig
aus; ihre Kombination liefert einen typisierten Fehler
(Exit 13).

== Audit-JSON

`--audit-json` gibt einen maschinenlesbaren Diagnose-Stream
aus. Nützlich für Editoren und CI-Integration:

```json
{
  "kind": "diagnostic",
  "severity": "warning",
  "code": "trigger.non-miller",
  "loc": { "file": "script.smt2", "line": 12, "col": 3 },
  "message": "Trigger pattern is non-Miller; matching will be slow."
}
```

Der Audit umfasst Parser-Warnungen, Trigger-Klassifizierung,
Verwendung klassischer Axiome und Eskalationsereignisse der
abduktiven Tier.

== Workflow des Zertifikatszyklus

Für einen Lauf mit hoher Zusicherung:

```bash
# 1. Solve, write cert
lu-smt --emit-cert proof.cert script.smt2

# 2. Re-check the cert independently
adsmt-cert-check proof.cert

# 3. (optional) Emit Lean script from cert
lu-smt-emit --lang lean proof.cert > proof.lean
```

Die Schritte 1-3 sind unabhängig: ein Zertifikat, das
Schritt 2 besteht, ist korrekt, unabhängig von Fehlern im
Solver des Schritts 1. Schritt 3 überträgt auf einen Lean-Kern,
der seine eigene Vertrauensgeschichte besitzt.

== Performance-Flags

```bash
# Disable abductive (deductive only)
lu-smt --abductive-tier 0 script.smt2

# Restrict to Miller patterns
lu-smt --trigger-mode miller script.smt2

# Set a hard timeout (1 second)
lu-smt --timeout 1000 script.smt2

# Disable cert emission
lu-smt --no-cert script.smt2
```

Die Voreinstellungen (`--abductive-tier 4`, `--trigger-mode
miller`, kein Timeout, Zertifikat falls `--emit-cert`
angefordert) eignen sich für die interaktive Nutzung.

== Umgebungsvariablen

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Variable*], [*Wirkung*]),
  [`ADSMT_LOG`], [Log-Level (`error`, `warn`, `info`, `debug`, `trace`)],
  [`ADSMT_BACKEND`], [Überschreibt das SAT-Backend (`oxiz`, `cadical`, `builtin`)],
  [`ADSMT_THREADS`], [Überschreibt die Thread-Anzahl der Engine],
  [`RUST_BACKTRACE`], [Standard-Rust-Backtrace-Steuerung],
)

== Beispielverzeichnis

Der adsmt-Quellbaum enthält ein Verzeichnis `examples/` mit
durchgearbeiteten SMT-LIB- und lu-kb-Skripten für jede
Theorie. Durchsuchen Sie es nach Vorlagen.

```bash
ls ~/AD1/examples/
# qf_uf.smt2    qf_lia.smt2    qf_lra.smt2
# qf_bv.smt2    qf_dt.smt2     quant_uf.smt2
# abduce_basic.kb   abduce_chain.kb
```

Jedes Beispiel dokumentiert in einem führenden Kommentar,
was es demonstriert.
