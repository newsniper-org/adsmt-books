= LSP Cheatsheet

`adsmt-lsp` is a tower-lsp-based LSP server for SMT-LIB
and lu-kb files. This appendix documents the six
capabilities and how to drive them.

== Installation

The LSP server is a single binary:

```bash
cargo install --path adsmt-lsp
# or via the meta crate
cargo install --path adsmt-meta --features lsp
```

For VS Code, the bundled extension under
`tooling/vscode-extension/` is the easiest entry.

== Editor integration

Most LSP clients need three things:

1. The LSP binary's location.
2. The file extensions it should activate for
   (`*.smt2` + `*.kb`).
3. (optional) initialization options.

```jsonc
// VS Code settings.json
{
  "adsmt.serverPath": "/path/to/adsmt-lsp",
  "adsmt.activateOn": ["smt2", "kb"]
}
```

For neovim with nvim-lspconfig:

```lua
require'lspconfig'.adsmt.setup{
  cmd = { '/path/to/adsmt-lsp' },
  filetypes = { 'smt2', 'kb' },
}
```

Helix users add to `languages.toml`:

```toml
[[language]]
name = "smt2"
language-servers = ["adsmt-lsp"]
[language-server.adsmt-lsp]
command = "/path/to/adsmt-lsp"
```

== Capability 1: `publishDiagnostics`

The server pushes diagnostics on every change. Three
categories surface:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Severity*], [*Source*]),
  [Error],   [Parse failures, type errors],
  [Warning], [Non-Miller triggers, classical-axiom uses, deprecated forms],
  [Info],    [Abductive surfaces, verdict summaries],
)

Diagnostics are positioned to the offending source range
so editors can navigate to them.

== Capability 2: `textDocument/definition`

Click-to-definition resolves symbol references *within
the current document*. Examples:

```text
(declare-fun f (Int) Int)  ;; declared here
(assert (= (f 3) 4))       ;; click on `f` jumps to declaration
```

Cross-file definition isn't supported yet (planned for
v1.1).

== Capability 3: `textDocument/hover`

Hovering reveals:

- BV literal interpretation (`#x42` → "66 decimal, 8-bit").
- Function declaration preview (signature + return type).
- Theory-tag for theory atoms.
- Last verdict for `(check-sat)` cursors.

== Capability 4: `textDocument/completion`

A static list of 39 completion items:

- Standard SMT-LIB commands (`declare-fun`, `assert`,
  `check-sat`, `get-model`, …)
- Theory names (`Int`, `Real`, `BitVec`, `Array`, …)
- Classical-axiom names (`lem`, `peirce`, `dne`)
- lu-kb keywords (`sort`, `fun`, `rule`, `class`,
  `instance`, `query`)
- Theory operators (`+`, `<`, `bvadd`, `select`,
  `store`, …)

Trigger by `Ctrl-Space` or your editor's invoke
binding. Completion is case-insensitive substring.

== Capability 5: `workspace/symbol`

Workspace-wide symbol search. Query strings match any
substring of declared sort, function, or constant
names across all open files. Results are presented
ranked by file proximity + match quality.

== Capability 6: `textDocument/codeAction`

Code actions offer concrete fixes for diagnostics:

- *KB migration.* When a `.kb` file's `kb-hash` doesn't
  match the canonical form, offer to auto-migrate to
  the current dialect version.
- *Trigger fix.* When a non-Miller trigger fires a
  warning, offer to rewrite to a Miller equivalent if
  one exists.
- *Abductive accept.* When an abductive verdict
  surfaces, offer to insert the candidate hypothesis
  as an `(assert ...)` line.

== Configuration

The LSP accepts an `initializationOptions` block at
startup:

```jsonc
{
  "abductiveTier": 4,
  "triggerMode": "miller",
  "classicalAxioms": ["lem"],
  "auditFormat": "json"
}
```

These mirror the CLI flags. Editor-specific extensions
typically expose them as settings.

== Performance

The LSP is incremental: edits trigger only re-parsing
of the changed region. Full-file re-solve happens only
when `(check-sat)` cursors are explicitly inspected (or
on demand via a code action).

For large `.kb` files (thousands of rules) the
incremental parse keeps the LSP responsive; the
re-solve can take seconds but happens off the typing
hot path.

== Editor-agnostic audit consumption

The LSP also exposes the same `--audit-json` stream
the CLI does, as a `audit/diagnostics` push
notification. Editor extensions that don't
understand the full LSP capability set can still
consume the audit stream for diagnostics — the
TypeScript reference in `tooling/vscode-extension/`'s
`audit.ts` is reusable.

== Troubleshooting

- *LSP doesn't start.* Check the binary path; check
  the file extension filter; check the editor's LSP
  log for an error.
- *No diagnostics appear.* The server might be
  parsing successfully and finding nothing. Try
  introducing a deliberate error to confirm the
  channel is working.
- *Completion lists are stale.* The static list is
  per-LSP-build. Upgrading the LSP binary refreshes
  the list.
- *Slow on large files.* The cost is in the solver
  re-run, not the parser. Use `(set-option :timeout
  1000)` to cap solver work.
