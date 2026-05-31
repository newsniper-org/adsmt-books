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
(set-option :abductive-tier 4)        ;; enable full abduction
(set-option :produce-models true)     ;; for sat verdicts
(set-option :produce-unsat-cores true);; for unsat verdicts
(set-option :produce-proofs true)     ;; emit cert
(set-option :classical-axioms (lem))  ;; allowed axioms
(set-option :timeout 5000)            ;; 5 second timeout
```

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
