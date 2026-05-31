= Engineering Concerns

This final chapter steps back from the algorithmic spine
and walks through the *engineering* practices that turn
the design of chapters 1-10 into a maintainable, stable
solver. Topics:

- Workspace layout and crate boundaries
- Testing strategy (unit, integration, property,
  differential, benchmark)
- Surface freezes (ABI, dialect, certificate)
- Semver discipline and the 8-layer heuristic checker
- Release engineering — Debian-style channels

== Workspace layout

The single biggest engineering decision in adsmt is the
*flat crate split*. Each major component is its own
crate:

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

Several non-obvious benefits emerge:

1. *Compile parallelism.* Cargo can build the 14 adsmt
   crates concurrently. A clean build is bounded by the
   longest single crate (`adsmt-engine`), not the sum.
2. *Surface boundaries.* The ABI of each crate's public
   surface is its own contract. Internal refactors don't
   risk leaking through `pub(crate)` walls.
3. *Selective features.* Downstream consumers can depend
   on `adsmt-core` (kernel only) without pulling in the
   parser, LSP, or CLI.
4. *Frozen surfaces.* Three crates — `adsmt-ffi`,
   `adsmt-cert`, `adsmt-parser` — have explicit
   surface-freeze policies enforced by macros; the others
   evolve more freely.

== Testing strategy

Every layer has its own test discipline:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Layer*], [*Discipline*]),
  [Kernel],     [Unit tests on each rule, plus a TCB-defining property test: "any term constructible only via the 12 rules from the empty assumption set is satisfiable."],
  [Theory],     [Unit tests per theory, plus a polite-combination integration test that exercises Nelson-Oppen-style equality propagation.],
  [Quantifier], [Unit tests on the matcher + trigger learner, plus golden-cert tests for each tier escalation.],
  [Abductive],  [Differential test: every produced candidate must be a *valid* hypothesis (`H union phi` discharges) and *minimal* (no proper subset of `H` does).],
  [Engine],     [Integration tests via SMT-LIB scripts checked into `tests/smtlib/`.],
  [Parser],     [Property tests on round-trip `parse(write(t)) == t`.],
  [Cert],       [Property test: `check(record(...)) == Ok(())` for every kernel run.],
  [Bench],      [Criterion HTML reports under `target/criterion/`, re-baselined after every algorithmic change.],
)

The headline guarantee — "the kernel is correct" — comes
from a tiny test of the kernel rules themselves. The
correctness of the *solver* is the conjunction of (kernel
rules correct) + (recorder uses only kernel rules) +
(checker accepts only certs built from kernel rules). Each
of these is independently testable; the soundness chain is
the product.

== Surface freezes

Three surfaces are frozen at v1.0.0:

*adsmt-ffi/ABI_POLICY.md.* The C-ABI exported by
`adsmt-ffi` is the integration surface for non-Rust
consumers. Once frozen, any change to a public function's
signature requires a breaking-version bump. The
`#[breaking_changes_semver("1.0.0")]` macro on the crate's
`lib.rs` is the offline enforcement: any commit that
changes a `pub extern "C" fn` signature must also bump the
declared version.

*adsmt-parser/DIALECT_POLICY.md.* Both SMT-LIB v2 and
lu-kb input dialects are frozen. New keywords can be
added (additive), but existing keywords' grammars are
fixed. The parser passes the SMT-LIB v2 conformance suite
as a regression test.

*adsmt-cert/CERT_POLICY.md.* The 12 + 3 + … step kinds
are frozen. New step kinds may be added under semver
(additive), but no kind's payload shape changes without a
breaking bump.

These three policies give downstream tooling
(`adsmt-emit-rocq`, `adsmt-emit-isabelle`, the VS Code
extension, user tactic harnesses) a stable target. The
rest of the workspace is free to evolve.

== Semver discipline

Rust's semver convention applies: $0.y.z$ for pre-1.0
flexibility, $1.y.z$ onward for stable APIs. adsmt opened
its v1.0 cycle with the v0.19 development line in May
2026 and (per `feedback_stable_signoff_user_approval.md`)
the v1.0.0 stable cut requires explicit user approval.

The 8-layer heuristic checker (`adsmt-heuristic-checker`)
is the offline safeguard. Eight independent layers cross-
check every breaking-version-bump candidate:

1. Macro attribute on the crate's `lib.rs`
2. CHANGELOG entry under the version heading
3. Cargo.toml version field
4. Frozen-surface policy markdown reference
5. Cross-crate consistency (workspace dependency graph)
6. Snapshot test against the previous version's public API
7. Conformance suite regression check
8. CI guard refusing any tag without all seven preceding

A version bump that fails any layer is rejected before the
tag is pushed. The discipline is heavy, but it's the
price of running a frozen-surface project.

== Channels

adsmt borrows Debian's channel model:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Channel*], [*Branch*], [*Purpose*]),
  [unstable], [`main`],     [Active development; new commits land here.],
  [testing],  [`testing`],  [Stabilisation candidates promoted from `main`.],
  [stable],   [`v1.0.0` (tag)], [Released versions; the v1.0.0 tag is the first.],
)

The `testing` branch was forked from `main` at commit
`450b986` in May 2026, post-v1.0.0-rc.2. Subsequent
hot-fixes can land on either `main` (next major cycle) or
`testing` (current stabilisation), with cherry-pick
direction decided per-fix.

== Release engineering

A release cuts in five steps:

1. Tag candidate on `testing` after green CI on all guards.
2. Run RC audit (RC2.1-RC2.9 are the cycle's actual numbers)
   covering: feature matrix, publish dry-run, warning sweep,
   doc audit, bench re-baseline, LSP runtime smoke, contributions
   audit, doc-warning silence, README authoring.
3. Explicit user sign-off (`feedback_stable_signoff_user_approval.md`).
4. Tag `v1.0.0` on the sign-off commit; push to remote.
5. Update `~/adsmt-contrib/`'s workspace pin to the new
   tag; run its smoke test against the freshly-published
   `adsmt-cert` and `adsmt-core`.

`~/adsmt-contrib/` is the *contrib* repository: out-of-tree
Rocq and Isabelle emit backends. It tracks the main repo's
version (`1.0.0` against `1.0.0`) and consumes the
released `adsmt-cert` + `adsmt-core` via Git tag pin. The
`contributions/oxiz/*` submodules under the main repo
stay on their own version lines independently, tracking
the upstream `oxiz` contributions, not the adsmt release.

== Memory + design archive

Two non-code persistence systems sit alongside the source:

- `memory/*.md` — project-internal context (cycle history,
  roadmap, sign-off policies). Each file is one topic; the
  index lives in `MEMORY.md`.
- `.claude-conversations/` — full design conversation
  archive. The interesting decisions and dead-ends live
  here, retrievable by date and topic.

These exist because the design rationale isn't always
expressible in code or git messages. When a future
maintainer asks "why is the e-graph wrapped in its own
theory rather than living inside `adsmt-theory::uf`?", the
answer is in a `memory/oxiz_relationship.md` discussion
from May 2026.

== Closing remark

The engineering discipline this chapter describes is what
turns the algorithmic spine of chapters 1-10 into a
solver someone might actually use. The kernel can be
brilliant; if the parser breaks on the next SMT-LIB
extension, if the certificate format drifts every release,
if the C ABI changes signature without a version bump,
the solver isn't a tool — it's a science fair project.

Frozen surfaces, heuristic checkers, channel discipline,
property-tested layers, an explicit memory system — none
of these are exciting. All of them are necessary. They're
the reason a v1.0.0 cut is *meaningful* rather than just
a number on a tag.

The next book in this series, *Learning Materials*, picks
up from here and walks through how to *use* adsmt — from
the SMT-LIB and lu-kb surfaces through the LSP, the
Lean 4 tactic, and the abductive workflow. The current
book has been about implementation; the next is about
practice.
