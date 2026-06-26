= LSP-Cheatsheet

`adsmt-lsp` ist ein auf tower-lsp basierender LSP-Server für
SMT-LIB-, lu-kb- und typed-ASP-Dateien. Dieser Anhang
dokumentiert die sechs Fähigkeiten und wie man sie ansteuert.

== Installation

Der LSP-Server ist eine einzelne Binärdatei:

```bash
cargo install --path adsmt-lsp
# or via the meta crate
cargo install --path adsmt-meta --features lsp
```

Für VS Code ist die mitgelieferte Erweiterung unter
`tooling/vscode-extension/` der einfachste Einstieg.

== Editor-Integration

Die meisten LSP-Clients benötigen drei Dinge:

1. Den Pfad der LSP-Binärdatei.
2. Die Dateierweiterungen, für die sie aktiviert werden soll
   (`*.smt2` + `*.kb` + `*.asp` / `*.lp`).
3. (optional) Initialisierungsoptionen.

```jsonc
// VS Code settings.json
{
  "adsmt.serverPath": "/path/to/adsmt-lsp",
  "adsmt.activateOn": ["smt2", "kb", "asp", "lp"]
}
```

Für neovim mit nvim-lspconfig:

```lua
require'lspconfig'.adsmt.setup{
  cmd = { '/path/to/adsmt-lsp' },
  filetypes = { 'smt2', 'kb', 'asp', 'lp' },
}
```

Helix-Benutzer ergänzen `languages.toml`:

```toml
[[language]]
name = "smt2"
language-servers = ["adsmt-lsp"]
[language-server.adsmt-lsp]
command = "/path/to/adsmt-lsp"
```

== Fähigkeit 1: `publishDiagnostics`

Der Server schiebt bei jeder Änderung Diagnosen. Drei
Kategorien treten zutage:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Schweregrad*], [*Quelle*]),
  [Error],   [Parse-Fehler, Typfehler],
  [Warning], [Nicht-Miller-Trigger, Verwendung klassischer Axiome, veraltete Formen],
  [Info],    [Abduktive Oberflächen, Verdikt-Zusammenfassungen],
)

Die Diagnosen sind auf den verursachenden Quellbereich
positioniert, sodass Editoren zu ihnen navigieren können.

Für typed-ASP-Dokumente (`*.asp` / `*.lp`, Sprach-id `asp`)
führt der Server statt des SMT-LIB-Parsers den *beratenden
Linter* (`adsmt_ir_asp::lint_source`) aus. Er ist ein reiner
Beobachter hinter der Korrektheits-Firewall — er ändert
niemals ein Verdikt — daher ist jeder Befund auf der Stufe
`Information` und mit `adsmt-asp` markiert:

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Regel (`code`)*], [*Was sie kennzeichnet*]),
  [`asp-unsafe`],        [Eine nicht durch ein positives Rumpfatom gebundene Variable (die Grundierung würde Instanzen verlieren). An der verletzenden Regel unterschlängelt.],
  [`asp-nonstratified`], [Ein negativer Zyklus — das Programm wird durch die Stabilmodell-Semantik entschieden, nicht durch das perfekte Modell.],
  [`asp-vacuity`],       [Keine Antwortmenge — eine Integritätsbedingung oder eine seltsame negative Schleife hat jeden Kandidaten eliminiert (das Dual des SMT-LIB-Lints für vakuierten Kontext).],
)

Der pro-Element-Befund `asp-unsafe` trägt eine präzise
Quellposition; die programmweiten Befunde
`asp-nonstratified` und `asp-vacuity` verankern am Dateikopf
und erscheinen im Problems-Panel. Der ASP-Pfad wird durch das standardmäßig
aktive Build-Feature `asp` einkompiliert (`--no-default-features`
baut den reinen SMT-LIB-Server).

== Fähigkeit 2: `textDocument/definition`

Klicken-zur-Definition löst Symbolreferenzen *innerhalb des
aktuellen Dokuments* auf. Beispiele:

```text
(declare-fun f (Int) Int)  ;; declared here
(assert (= (f 3) 4))       ;; click on `f` jumps to declaration
```

Dateiübergreifende Definition wird noch nicht unterstützt
(geplant für v1.1).

== Fähigkeit 3: `textDocument/hover`

Hovern enthüllt:

- Interpretation von BV-Literalen (`#x42` → "66 dezimal, 8-Bit").
- Vorschau auf Funktionsdeklarationen (Signatur + Rückgabetyp).
- Theorie-Tag für Theorie-Atome.
- Letztes Verdikt für `(check-sat)`-Cursorpositionen.

== Fähigkeit 4: `textDocument/completion`

Eine statische Liste von 39 Vervollständigungseinträgen:

- Standard-SMT-LIB-Befehle (`declare-fun`, `assert`,
  `check-sat`, `get-model`, …)
- Theorienamen (`Int`, `Real`, `BitVec`, `Array`, …)
- Namen klassischer Axiome (`lem`, `peirce`, `dne`)
- lu-kb-Schlüsselwörter (`sort`, `fun`, `rule`, `class`,
  `instance`, `query`)
- Theorie-Operatoren (`+`, `<`, `bvadd`, `select`,
  `store`, …)

Auslösung über `Ctrl-Space` oder das Aufruf-Tastaturkürzel
Ihres Editors. Die Vervollständigung ist
groß-/kleinschreibungsunempfindliche Teilstringsuche.

== Fähigkeit 5: `workspace/symbol`

Workspace-weite Symbolsuche. Anfragezeichenketten passen auf
jeden Teilstring deklarierter Sorten-, Funktions- oder
Konstantennamen über alle geöffneten Dateien hinweg. Die
Ergebnisse werden nach Dateinähe + Übereinstimmungsqualität
gerangt präsentiert.

== Fähigkeit 6: `textDocument/codeAction`

Code-Aktionen bieten konkrete Behebungen für Diagnosen:

- *KB-Migration.* Wenn der `kb-hash` einer `.kb`-Datei nicht
  zur kanonischen Form passt, wird eine automatische
  Migration zur aktuellen Dialektversion angeboten.
- *Trigger-Korrektur.* Wenn ein Nicht-Miller-Trigger eine
  Warnung auslöst, wird angeboten, ihn in ein
  Miller-Äquivalent umzuschreiben, falls eines existiert.
- *Abduktive Akzeptanz.* Wenn ein abduktives Verdikt zutage
  tritt, wird angeboten, die Kandidatenhypothese als
  `(assert ...)`-Zeile einzufügen.

== Konfiguration

Das LSP akzeptiert beim Start einen
`initializationOptions`-Block:

```jsonc
{
  "abductiveTier": 4,
  "triggerMode": "miller",
  "classicalAxioms": ["lem"],
  "auditFormat": "json"
}
```

Diese spiegeln die CLI-Flags. Editor-spezifische
Erweiterungen stellen sie üblicherweise als Einstellungen
zur Verfügung.

== Performance

Das LSP ist inkrementell: Bearbeitungen lösen nur das
Reparsen des geänderten Bereichs aus. Das vollständige
Neulösen einer Datei findet nur statt, wenn
`(check-sat)`-Cursors explizit inspiziert werden (oder auf
Anforderung via Code-Aktion).

Für große `.kb`-Dateien (Tausende von Regeln) hält das
inkrementelle Parsen das LSP reaktionsfähig; das Neulösen
kann Sekunden dauern, geschieht aber außerhalb des
zeitkritischen Tipp-Pfads.

== Editor-unabhängiger Audit-Konsum

Das LSP stellt zudem denselben `--audit-json`-Stream wie das
CLI als `audit/diagnostics`-Push-Benachrichtigung zur
Verfügung. Editor-Erweiterungen, die die volle
LSP-Fähigkeitsmenge nicht verstehen, können dennoch den
Audit-Stream für Diagnosen konsumieren — die
TypeScript-Referenz in `audit.ts` der
`tooling/vscode-extension/` ist wiederverwendbar.

== Fehlersuche

- *Das LSP startet nicht.* Pfad der Binärdatei prüfen; den
  Dateierweiterungsfilter prüfen; das LSP-Log des Editors auf
  einen Fehler prüfen.
- *Keine Diagnosen erscheinen.* Der Server parst möglicher-
  weise erfolgreich und findet nichts. Versuchen Sie, einen
  absichtlichen Fehler einzubauen, um zu bestätigen, dass
  der Kanal funktioniert.
- *Vervollständigungslisten sind veraltet.* Die statische
  Liste ist pro LSP-Build. Ein Upgrade der LSP-Binärdatei
  aktualisiert die Liste.
- *Langsam bei großen Dateien.* Die Kosten liegen im
  Neulauf des Solvers, nicht im Parser. Verwenden Sie
  `(set-option :timeout 1000)`, um die Arbeit des Solvers
  zu deckeln.
