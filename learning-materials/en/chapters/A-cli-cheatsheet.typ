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

== Abductive reasoning (SMT-LIB surface)

adsmt's abductive verdict — _what hypothesis would discharge
this goal?_ — is reachable as an explicit, cvc5-compatible
SMT-LIB surface. Declare the vocabulary of allowed
hypotheses, then ask for an abduct on a goal:

```text
;; Register the patterns the engine may propose as a fix.
(declare-abducible (> x 0))
(declare-abducible (> x 0) "x must be positive")  ;; optional explanation

;; adsmt-native: emit the full ranked candidate set as the
;; single-line `abductive` JSON (the Verus / Lean reporters
;; parse this).
(abduce (>= x 1))

;; cvc5 abduction extension: emit the top-ranked abduct as a
;; re-parseable `(define-fun A () Bool (> x 0))`.
(get-abduct A (>= x 1))
;; Walk the remaining ranked abducts; `(fail)` when exhausted.
(get-abduct-next)
```

An abduct is _advisory_ — the deductive (`unsat`) verdict is
the trusted one; an abduced hypothesis is something the caller
must justify (as a precondition / invariant / lemma), never
silently assume.

== §3.1 AOT prelude bank

Pre-compile a heavyweight prelude (Verus's prelude is the
canonical example, ~10⁵ clauses) into a `.luart` v0
artifact, then load it pre-asserted on every per-query
invocation:

```bash
# One-shot bake of the prelude.  The `.luart` file records
# a SHA-256 of the input + the lu-smt version it was baked
# under, so callers can cache-key on the pair.
lu-smt --aot-bake --aot-output prelude.luart prelude.smt2

# Every per-query invocation pre-asserts the prelude before
# reading the regular SMT-LIB input.
lu-smt --aot-load prelude.luart query.smt2
```

`--aot-bake` and `--aot-load` are mutually exclusive; pairing
them surfaces a typed error (exit 13).

== §3.5 JIT-on-AOT-prelude

The `--aot-bake` mode grows a composable `--aot-include-cdcl`
extension that writes a v1 CDCL section after the v0
sections — post-flatten clauses + initial BCP trail +
two-watched index + VSIDS + phase-save.  The v1 header
carries a SHA-256 of the lu-smt binary so reloading detects
silent tooling-drift the source-level `flatten_version` knob
misses.

```bash
# Bake the v0 Term-DAG + the v1 CDCL section.
lu-smt --aot-bake --aot-include-cdcl --aot-output prelude.luart \
       prelude.smt2

# `--aot-load` auto-detects the v1 section and routes through
# `Solver::with_aot_cdcl`; the loader picks up the CDCL
# section without needing a dedicated flag.
lu-smt --aot-load prelude.luart query.smt2
```

`--aot-include-cdcl` requires `--aot-bake` (exit 12 on
misuse) and is mutually exclusive with `--aot-load` (exit
12).

The CLI additionally surfaces a `.lutrace` artefact for
recorded CDCL traces. The emitted trace carries the recorded
event stream plus a 32-byte clause-set digest of the formula.
The digest is folded incrementally: the prelude's
order-independent clause-fold is precomputed into the bank at
`--aot-bake`, so the per-`(check-sat)` consult scales with the
query delta, not the whole prelude. A loaded trace is consulted
at every `(check-sat)` (when an `--aot-load` prelude is also
active), and on an exact digest match the recorded `unsat`
short-circuits the solve:

```bash
# Emit a `.lutrace` (CDCL events + clause-set digest).
lu-smt --jit-trace-emit trace.lutrace query.smt2

# Slim (verdict-only): emit just the digest + a terminal
# conflict — what the consult reads — dropping the propagation
# stream. Only on a clean `unsat`.
lu-smt --jit-trace-emit-slim slim.lutrace query.smt2

# Load a previously-emitted `.lutrace` (full or slim) and
# consult it before every `(check-sat)` (pair with --aot-load).
lu-smt --aot-load prelude.luart \
       --jit-trace-load trace.lutrace query.smt2
```

`--jit-trace-emit`, `--jit-trace-emit-slim` and
`--jit-trace-load` are mutually exclusive (exit 12).

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
