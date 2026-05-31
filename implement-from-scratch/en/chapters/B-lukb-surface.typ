= lu-kb Surface

`lu-kb` is the second input dialect adsmt accepts. It
originated in the *logicutils* project (absorbed at
RC1.4.A, see `ABSORPTION_PLAN.md`), and is preserved for
backward compatibility with logicutils consumers and for
adsmt-specific knowledge-base authoring.

== Surface shape

A `.kb` file is a sequence of *blocks*:

```text
sort Nat
fun  zero : Nat
fun  succ : Nat -> Nat

rule  succ_pos : forall n. zero != succ n
rule  succ_inj : forall n m. (succ n = succ m) => (n = m)

class Eq[T] = { eq : T -> T -> Bool }
instance Eq[Nat] = { eq = nat_eq }

query forall n. eq n n
```

Each block is one of: `sort`, `fun`, `rule`, `class`,
`instance`, `query`. The dialect's grammar lives in
`adsmt-parser/src/lukb/` with the migration chain (v0.x
to v1.0) checked in.

== Blocks

*`sort <name>`* — Declares an opaque sort. Equivalent to
`declare-sort` in SMT-LIB.

*`fun <name> : <type>`* — Declares a function symbol with
its type. Higher-kinded types (`F[T]`, `F[T, U]`) are
recognised; chapter 3 covers the kernel semantics.

*`rule <name> : <formula>`* — A named assumption to be
asserted at engine start. Used both for asserting
facts and for Horn rules that feed the abductive layer
(chapter 8).

*`class <name>[<tyvar>+] = { <field> : <type> ; ... }`* —
Declares a type class. Equivalent to T_class in chapter 3.

*`instance <name>[<type>+] = { <field> = <term> ; ... }`* —
Declares an instance of a class for a specific type
parameter.

*`query <formula>`* — Equivalent to `assert (not phi)`
followed by `check-sat`. The verdict is reported by name.

== Hash-stamped migration chain

`.kb` files carry an optional K12-256 hash of their
canonical form. The hash is recomputed on parse; a
mismatch triggers a migration check that walks the
chain of known dialect versions and applies any
necessary transforms.

```text
% kb-version: 1
% kb-hash:    k12-256:abc123...
```

The chain is maintained in `lu-common/src/migration.rs`
with one transform per breaking version. Migration is
*opt-in* — without the `:auto-migrate` option, a hash
mismatch is an error.

== Comparison to SMT-LIB

`lu-kb` is shaped for authoring knowledge bases rather
than discharging individual goals:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Concern*], [*SMT-LIB*], [*lu-kb*]),
  [Granularity], [Per goal], [Per knowledge base],
  [Reuse],       [push/pop scopes], [Rule and class blocks],
  [Type classes], [Not native], [`class` / `instance` blocks],
  [Horn-friendly], [Manual], [`rule` blocks feed abduction],
  [Migration], [Version in preamble], [Hash-stamped chain],
)

In practice, library authors prefer `.kb` (write the
knowledge base once, query repeatedly); ad-hoc users
prefer `.smt2`. Both surfaces compile to the same
internal AST, so engine behaviour is identical.

== Editor integration

The VS Code extension (under
`tooling/vscode-extension/`) recognises both `.smt2` and
`.kb` extensions. The LSP server (`adsmt-lsp`) routes
files by extension into the appropriate parser; the
completion list adapts (39 static items, including
`kb`-specific keywords like `class`, `instance`,
`query`).
