= SMT-LIB v2 Surface

This appendix documents the SMT-LIB v2 surface that
`adsmt-parser` recognises. It is a *subset* of the full
SMT-LIB v2 standard, plus a handful of adsmt-specific
extensions.

== Recognised commands

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Command*], [*Notes*]),
  [`set-logic`],   [Accepts the QF_* logics + their quantified counterparts. Polite combination is auto-selected when multiple theories appear.],
  [`set-option`],  [Standard options + adsmt-specific `:abductive-tier`, `:trigger-mode`, `:classical-axioms`.],
  [`declare-sort`, `declare-fun`, `declare-const`], [Standard.],
  [`define-fun`, `define-fun-rec`], [Standard; `define-fun-rec` is partial — termination obligation is the user's.],
  [`assert`],      [Standard.],
  [`check-sat`],   [Returns `sat`, `unsat`, `unknown`, or `abductive` (the new verdict).],
  [`get-model`],   [Standard, returns assignment for `Sat`.],
  [`get-unsat-core`], [Standard, returns labelled subset for `Unsat`.],
  [`get-abductive-candidates`], [adsmt extension — returns ranked candidate list for `Abductive`.],
  [`push`, `pop`], [Standard scope stack.],
  [`reset`, `reset-assertions`], [Standard.],
  [`exit`],        [Standard.],
)

== Theories

The following SMT-LIB theories are supported (chapter 6):

- `Core` — Bool, =, distinct, ite, and, or, not, =>
- `Ints` — LIA
- `Reals` — LRA
- `Reals_Ints` — LIRA via polite combination
- `FixedSizeBitVectors` — BV with bit-blasting fallback
- `ArraysEx` — Read-over-write Arrays
- `Datatypes` — Algebraic data types

== Logics

The standard SMT-LIB logic names are recognised:

```text
QF_UF, QF_LIA, QF_LRA, QF_BV, QF_AUFLIA, QF_AUFBV,
QF_DT, QF_AUFDT,
LIA, LRA, AUFLIA, AUFBV, AUFDT, ...
```

When the logic contains quantifiers (no `QF_` prefix), the
engine engages the quantifier instantiation pipeline of
chapter 7 automatically.

== Extensions

Three SMT-LIB extensions are adsmt-specific:

*`:abductive-tier <n>`* — Sets the maximum tier at which
quantifier handling escalates to abductive candidates.
`n=0` disables abductive surfaces (returns `unknown` on
exhaust); `n=4` (default) enables the full pipeline.

*`:trigger-mode <miller|free>`* — `miller` (default)
restricts triggers to Miller patterns; `free` allows
non-Miller triggers (with their pathologies).

*`:classical-axioms (<axiom>*)`* — Whitelists classical
axioms the solver may invoke. The accepted names are:
`lem`, `peirce`, `dne`. Steps requiring an axiom not in
the whitelist either fail or get a Tier-4 escalation.

*`get-abductive-candidates`* — When `check-sat` returns
`abductive`, this command returns the ranked candidate
list as nested S-expressions. Example output:

```text
(abductive-candidates
  (candidate :rank 1 :hypothesis ((P a) (Q b))
             :justification sld_chain)
  (candidate :rank 2 :hypothesis ((R c))
             :justification quantifier_exhausted))
```

== Non-extensions

Several SMT-LIB v2 features are *not* supported:

- `Floats` (FP theory) — out of scope.
- `Sequences` and `Strings` theories — out of scope.
- `define-fun-rec` totality checking — partial only.
- Pattern syntax `(! ... :pattern ...)` is parsed but
  Tier-1 only consults the pattern when an explicit
  `:trigger` attribute is absent.

These omissions are deliberate. A v1.0.0 commitment to FP
soundness would require either a bit-blasting fallback
that's prohibitively slow or an FP-specific decision
procedure that's a research project of its own.
