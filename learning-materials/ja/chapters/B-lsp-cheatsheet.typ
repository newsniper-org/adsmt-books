= LSP チートシート

`adsmt-lsp` は SMT-LIB および lu-kb ファイル向けの
tower-lsp ベースの LSP サーバである。この付録は六つの
ケイパビリティとその駆動方法を文書化する。

== インストール

LSP サーバは単一のバイナリである。

```bash
cargo install --path adsmt-lsp
# or via the meta crate
cargo install --path adsmt-meta --features lsp
```

VS Code については、`tooling/vscode-extension/` 配下の
同梱拡張機能が最も容易な入口である。

== エディタ統合

ほとんどの LSP クライアントは三つを必要とする。

1. LSP バイナリの場所。
2. それを起動すべきファイル拡張子(`*.smt2` + `*.kb`)。
3. (任意)初期化オプション。

```jsonc
// VS Code settings.json
{
  "adsmt.serverPath": "/path/to/adsmt-lsp",
  "adsmt.activateOn": ["smt2", "kb"]
}
```

neovim と nvim-lspconfig を使う場合は次のとおり。

```lua
require'lspconfig'.adsmt.setup{
  cmd = { '/path/to/adsmt-lsp' },
  filetypes = { 'smt2', 'kb' },
}
```

Helix ユーザは `languages.toml` に追加する。

```toml
[[language]]
name = "smt2"
language-servers = ["adsmt-lsp"]
[language-server.adsmt-lsp]
command = "/path/to/adsmt-lsp"
```

== ケイパビリティ 1: `publishDiagnostics`

サーバは変更のたびに診断をプッシュする。三つのカテゴリが
表面化する。

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*重大度*], [*ソース*]),
  [Error],   [パース失敗、型エラー],
  [Warning], [非 Miller トリガ、古典公理の使用、非推奨形式],
  [Info],    [アブダクティブな浮上、判定サマリ],
)

診断は問題のソース範囲に位置付けられるので、エディタは
そこへ移動できる。

== ケイパビリティ 2: `textDocument/definition`

クリックして定義へ移動は*現在のドキュメント内*でシンボル
参照を解決する。例。

```text
(declare-fun f (Int) Int)  ;; declared here
(assert (= (f 3) 4))       ;; click on `f` jumps to declaration
```

ファイル横断の定義はまだサポートされていない(v1.1 で
計画)。

== ケイパビリティ 3: `textDocument/hover`

ホバーは次を明らかにする。

- BV リテラルの解釈(`#x42` → 「66 進、8 ビット」)。
- 関数宣言のプレビュー(シグネチャ + 戻り型)。
- 理論アトムの理論タグ。
- `(check-sat)` カーソルにおける最新の判定。

== ケイパビリティ 4: `textDocument/completion`

39 個の静的補完項目のリスト。

- 標準 SMT-LIB コマンド(`declare-fun`, `assert`,
  `check-sat`, `get-model`, …)
- 理論名(`Int`, `Real`, `BitVec`, `Array`, …)
- 古典公理名(`lem`, `peirce`, `dne`)
- lu-kb キーワード(`sort`, `fun`, `rule`, `class`,
  `instance`, `query`)
- 理論演算子(`+`, `<`, `bvadd`, `select`,
  `store`, …)

`Ctrl-Space` あるいはエディタの呼び出しキーで起動する。
補完は大文字小文字を区別しない部分文字列照合である。

== ケイパビリティ 5: `workspace/symbol`

ワークスペース全域のシンボル検索。クエリ文字列は、開いて
いるすべてのファイルにわたって宣言された sort、関数、
定数名の任意の部分文字列にマッチする。結果はファイル
近接性 + マッチ品質で順位付けして提示される。

== ケイパビリティ 6: `textDocument/codeAction`

コードアクションは診断に対する具体的な修正を提示する。

- *KB 移行.* `.kb` ファイルの `kb-hash` が正規形と一致
  しないとき、現行方言バージョンへの自動移行を提案する。
- *トリガ修正.* 非 Miller トリガが警告を出したとき、
  存在する場合は Miller 等価物への書き換えを提案する。
- *アブダクティブな受け入れ.* アブダクティブ判定が
  浮上したとき、候補仮説を `(assert ...)` 行として
  挿入することを提案する。

== 設定

LSP は起動時に `initializationOptions` ブロックを受け取る。

```jsonc
{
  "abductiveTier": 4,
  "triggerMode": "miller",
  "classicalAxioms": ["lem"],
  "auditFormat": "json"
}
```

これらは CLI フラグをミラーする。エディタ固有の拡張は
通常それらを設定として公開する。

== 性能

LSP はインクリメンタルである。編集は変更領域の再パースだけ
を引き起こす。ファイル全体の再ソルブは `(check-sat)` カーソル
が明示的に検査されたときに限る(あるいはコードアクション
経由で要求があったとき)。

大きな `.kb` ファイル(数千の規則)については、
インクリメンタルなパースが LSP を応答的に保つ。再ソルブには
数秒かかりうるが、タイピングのホットパスからは外れる。

== エディタ非依存の監査消費

LSP は CLI が出すのと同じ `--audit-json` ストリームを
`audit/diagnostics` プッシュ通知として公開する。LSP の
ケイパビリティ集合全体を理解しないエディタ拡張機能でも、
診断のために監査ストリームを消費できる —
`tooling/vscode-extension/` の `audit.ts` の TypeScript
リファレンスが再利用可能である。

== トラブルシューティング

- *LSP が起動しない.* バイナリのパスを確認する。ファイル
  拡張子のフィルタを確認する。エディタの LSP ログにエラー
  がないかを確認する。
- *診断が現れない.* サーバはパース成功して何も見つけて
  いないかもしれない。意図的にエラーを入れて、チャネルが
  動作していることを確認する。
- *補完リストが古い.* 静的リストは LSP ビルドごとに
  決まる。LSP バイナリのアップグレードでリストが更新される。
- *大ファイルで遅い.* コストはパーサではなくソルバの
  再実行にある。`(set-option :timeout 1000)` を用いて
  ソルバの作業に上限を設ける。
