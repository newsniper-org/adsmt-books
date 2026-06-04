= CLI Cheatsheet

The `lu-smt` command (provided by `adsmt-cli`) is the
primary command-line entry point. This appendix is a
quick reference.

== Basic invocation

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

The exit code reflects the verdict:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Verdict*], [*Exit*], [*Output*]),
  [`sat`],   [0], [`sat`],
  [`unsat`], [0], [`unsat`],
  [`unknown`], [1], [`unknown` + reason],
  [`abductive`], [2], [`abductive` + candidates if requested],
  [parse error], [3], [diagnostic to stderr],
)

== Common flags

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Flag*], [*Effect*]),
  [`--emit-cert <file>`], [Write the cert to `<file>` (S-expr format)],
  [`--check-cert <file>`], [Re-verify a cert without re-running the solver],
  [`--audit-json`], [Emit audit diagnostics as JSON],
  [`--abductive-tier <n>`], [Set tier (0 = off, 4 = full)],
  [`--trigger-mode <miller|free>`], [Restrict or allow non-Miller triggers],
  [`--timeout <ms>`], [Hard timeout in milliseconds],
  [`--seed <n>`], [Random seed (for reproducibility)],
  [`-v` / `--verbose`], [Verbose output],
  [`-h` / `--help`], [Full help text],
)

== SMT-LIB-level options

These set inside the SMT-LIB script via `(set-option ...)`:

```text
(set-option :produce-models true)     ;; for sat verdicts
(set-option :produce-unsat-cores true);; for unsat verdicts
(set-option :produce-proofs true)     ;; emit cert
(set-option :timeout 5000)            ;; 5 second wall-clock budget (ms)
(set-option :rlimit 30000000)         ;; Z3-style resource limit (~30 s)

;; §3.4 GF(2) Gröbner-basis plugin (opt-in)
(set-option :finite-field-periodic 32)
(set-option :finite-field-budget-exhaustion true)
```

The `:finite-field-*` keys can also be passed as
`--finite-field-periodic N` / `--finite-field-budget-exhaustion`
startup flags; either route registers a `FiniteFieldTheory`
plugin with the engine.  Mid-session `(set-option ...)`
auto-registers the plugin with default knobs on first call.

== Audit JSON

`--audit-json` emits a machine-readable diagnostic
stream. Useful for editors and CI integration:

```json
{
  "kind": "diagnostic",
  "severity": "warning",
  "code": "trigger.non-miller",
  "loc": { "file": "script.smt2", "line": 12, "col": 3 },
  "message": "Trigger pattern is non-Miller; matching will be slow."
}
```

The audit covers parser warnings, trigger
classification, classical-axiom usage, and abductive-
tier escalation events.

== Cert-cycle workflow

For a high-assurance run:

```bash
# 1. Solve, write cert
lu-smt --emit-cert proof.cert script.smt2

# 2. Re-check the cert independently
adsmt-cert-check proof.cert

# 3. (optional) Emit Lean script from cert
lu-smt-emit --lang lean proof.cert > proof.lean
```

Steps 1-3 are independent: a cert that passes step 2
is sound regardless of bugs in the solver of step 1.
Step 3 transfers to a Lean kernel that has its own
trust story.

== Performance flags

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

The defaults (`--abductive-tier 4`, `--trigger-mode
miller`, no timeout, cert if `--emit-cert` requested)
suit interactive use.

== Environment variables

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Variable*], [*Effect*]),
  [`ADSMT_LOG`], [Log level (`error`, `warn`, `info`, `debug`, `trace`)],
  [`ADSMT_BACKEND`], [Override SAT backend (`oxiz`, `cadical`, `builtin`)],
  [`ADSMT_THREADS`], [Override engine thread count],
  [`RUST_BACKTRACE`], [Standard Rust backtrace control],
)

== Examples directory

The adsmt source tree ships an `examples/` directory
with worked SMT-LIB and lu-kb scripts for every
theory. Browse there for templates.

```bash
ls ~/AD1/examples/
# qf_uf.smt2    qf_lia.smt2    qf_lra.smt2
# qf_bv.smt2    qf_dt.smt2     quant_uf.smt2
# abduce_basic.kb   abduce_chain.kb
```

Each example documents what it demonstrates in a
leading comment.
