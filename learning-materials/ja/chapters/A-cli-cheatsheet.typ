= CLI チートシート

`lu-smt` コマンド(`adsmt-cli` が提供)は主要なコマンド
ライン入口である。この付録はその簡易リファレンスである。

== 基本的な呼び出し

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

終了コードは判定を反映する。

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*判定*], [*終了*], [*出力*]),
  [`sat`],   [0], [`sat`],
  [`unsat`], [0], [`unsat`],
  [`unknown`], [1], [`unknown` + 理由],
  [`abductive`], [2], [要求があれば `abductive` + 候補],
  [パースエラー], [3], [stderr への診断],
)

== 共通フラグ

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*フラグ*], [*効果*]),
  [`--emit-cert <file>`], [証明書を `<file>` に書く (S 式形式)],
  [`--check-cert <file>`], [ソルバを再実行せずに証明書を再検証する],
  [`--audit-json`], [監査診断を JSON として発する],
  [`--abductive-tier <n>`], [tier を設定する (0 = off, 4 = full)],
  [`--trigger-mode <miller|free>`], [非 Miller トリガを制限または許可],
  [`--timeout <ms>`], [ミリ秒単位のハードタイムアウト],
  [`--seed <n>`], [乱数シード (再現性のため)],
  [`-v` / `--verbose`], [冗長出力],
  [`-h` / `--help`], [ヘルプ全文],
)

== SMT-LIB レベルのオプション

これらは `(set-option ...)` を介して SMT-LIB スクリプト
内部で設定する。

```text
(set-option :produce-models true)     ;; sat verdict 用
(set-option :produce-unsat-cores true);; unsat verdict 用
(set-option :produce-proofs true)     ;; cert 出力
(set-option :timeout 5000)            ;; 5 秒 wall-clock 予算 (ms)
(set-option :rlimit 30000000)         ;; Z3-style リソース上限 (~30 秒)

;; §3.4 GF(2) Gröbner-basis プラグイン (opt-in)
(set-option :finite-field-periodic 32)
(set-option :finite-field-budget-exhaustion true)
```

`:finite-field-*` キーは `--finite-field-periodic N` /
`--finite-field-budget-exhaustion` startup フラグとしても
等価。どちらの経路でも `FiniteFieldTheory` プラグインを
エンジンに登録する。セッション中 `(set-option ...)` は
最初の呼び出しで default knob 値で自動登録される。

== Audit JSON

`--audit-json` は機械可読な診断ストリームを発する。
エディタや CI 統合に有用である。

```json
{
  "kind": "diagnostic",
  "severity": "warning",
  "code": "trigger.non-miller",
  "loc": { "file": "script.smt2", "line": 12, "col": 3 },
  "message": "Trigger pattern is non-Miller; matching will be slow."
}
```

監査はパーサ警告、トリガ分類、古典公理の利用、アブダクティブ
tier のエスカレーションイベントをカバーする。

== 証明書サイクルのワークフロー

高保証実行のためには次のとおり。

```bash
# 1. Solve, write cert
lu-smt --emit-cert proof.cert script.smt2

# 2. Re-check the cert independently
adsmt-cert-check proof.cert

# 3. (optional) Emit Lean script from cert
lu-smt-emit --lang lean proof.cert > proof.lean
```

ステップ 1-3 は独立である。ステップ 2 を通る証明書は
ステップ 1 のソルバにバグがあろうとも健全である。
ステップ 3 は独自の信頼の物語を持つ Lean カーネルへ
移譲する。

== 性能フラグ

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

デフォルト(`--abductive-tier 4`、`--trigger-mode
miller`、タイムアウトなし、`--emit-cert` が要求された場合
の証明書)は対話的利用に適する。

== 環境変数

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*変数*], [*効果*]),
  [`ADSMT_LOG`], [ログレベル (`error`, `warn`, `info`, `debug`, `trace`)],
  [`ADSMT_BACKEND`], [SAT バックエンドの上書き (`oxiz`, `cadical`, `builtin`)],
  [`ADSMT_THREADS`], [エンジンスレッド数の上書き],
  [`RUST_BACKTRACE`], [標準的な Rust バックトレース制御],
)

== Examples ディレクトリ

adsmt のソースツリーは、すべての理論について実例の SMT-LIB
と lu-kb スクリプトを含む `examples/` ディレクトリを出荷
している。テンプレートを探すならそこを参照する。

```bash
ls ~/AD1/examples/
# qf_uf.smt2    qf_lia.smt2    qf_lra.smt2
# qf_bv.smt2    qf_dt.smt2     quant_uf.smt2
# abduce_basic.kb   abduce_chain.kb
```

各例は何を例示しているかを先頭コメントに記している。
