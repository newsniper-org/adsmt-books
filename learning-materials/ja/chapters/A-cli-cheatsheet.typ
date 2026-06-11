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

== アブダクション推論 (abductive reasoning) — SMT-LIB サーフェス

adsmt のアブダクション verdict — _この goal を discharge する
にはどの仮説が必要か?_ — は明示的かつ cvc5 互換の SMT-LIB
サーフェスとしてアクセスできる。許容仮説の語彙を宣言し、goal に
対して abduct を要求する:

```text
;; エンジンが fix として提案しうるパターンを登録。
(declare-abducible (> x 0))
(declare-abducible (> x 0) "x must be positive")  ;; 任意の説明

;; adsmt-native: ランク付けされた全候補を単一行の `abductive`
;; JSON で出力 (Verus / Lean レポーターが parse する)。
(abduce (>= x 1))

;; cvc5 abduction 拡張: 最上位の abduct を再 parse 可能な
;; `(define-fun A () Bool (> x 0))` として出力。
(get-abduct A (>= x 1))
;; 残りのランク付き abduct を巡回; 尽きたら `(fail)`。
(get-abduct-next)
```

abduct は _助言_ にすぎない — 信頼される verdict は演繹
(`unsat`) であり、abduce された仮説は呼び出し側が (事前条件 /
不変条件 / lemma として) 正当化すべきもので、決して暗黙には
仮定しない。

既定ではエンジンは abduct が _目標を含意_ (`H ⊢ G`) する
ことのみ保証する。現在の表明と矛盾する仮説も返りうる
(その場合は目標を _空虚に_ verify する)。完全な cvc5
`(get-abduct)` セマンティクス — `H` が表明と無矛盾、
`SAT(F ∧ H)` まで要求 — は次で opt-in:

```text
(set-option :abduct-consistency true)
```

有効にすると `(abduce …)` は各 JSON 候補に `consistent` 真偽
値を付け (消費側が空虚なものを filter/dim)、`(get-abduct …)` /
`(get-abduct-next)` は矛盾する abduct を丸ごと drop する。

== §3.1 AOT prelude bank

重量級の prelude (Verus の prelude が典型例で ~10⁵ 節)
を `.luart` v0 アーティファクトに事前コンパイルし、
毎クエリ呼び出しで pre-assert 済み状態としてロードする。

```bash
# Prelude を一度 bake。`.luart` ファイルは入力の SHA-256
# と bake 時の lu-smt バージョンを記録するので、呼び出し
# 側はこのペアで cache key を作れる。
lu-smt --aot-bake --aot-output prelude.luart prelude.smt2

# 毎クエリ呼び出しは、通常の SMT-LIB 入力を読み取る
# 前に prelude を pre-assert する。
lu-smt --aot-load prelude.luart query.smt2
```

`--aot-bake` と `--aot-load` は相互排他。両方指定すると
typed error で終了する (exit 13)。

== §3.5 JIT-on-AOT-prelude

`--aot-bake` モードは v0 セクションの後に v1 CDCL セクションを
書き込む composable `--aot-include-cdcl` 拡張を持つ。v1
セクションには post-flatten clauses + 初期 BCP trail +
two-watched index + VSIDS + phase-save が含まれる。v1
ヘッダーは lu-smt バイナリの SHA-256 を記録するので、
source-level の `flatten_version` knob では見逃される
toolchain-drift も検出する。

```bash
# v0 Term-DAG + v1 CDCL セクションを bake する。
lu-smt --aot-bake --aot-include-cdcl --aot-output prelude.luart \
       prelude.smt2

# `--aot-load` は v1 セクションを自動検出し、
# `Solver::with_aot_cdcl` 経由でルーティング。専用フラグなしで
# ローダーが CDCL セクションを取得する。
lu-smt --aot-load prelude.luart query.smt2
```

`--aot-include-cdcl` は `--aot-bake` を必要とし (誤用時 exit
12)、`--aot-load` と相互排他である (exit 12)。

CLI はさらに、記録済み CDCL trace 用の `.lutrace`
アーティファクトを提供する。emit された trace は記録済み
event ストリームに加え、その formula の 32 バイト
clause-set digest を保持する。digest は逐次的に fold される:
prelude の順序非依存な clause-fold を `--aot-bake` 時に
bank へ事前計算しておくため、各 `(check-sat)` の consult は
prelude 全体ではなく query デルタに比例する。load された
trace は (`--aot-load` prelude も有効な場合) 各 `(check-sat)`
前に consult され、digest が厳密に一致すれば記録済みの
`unsat` が solve を short-circuit する:

```bash
# `.lutrace` を emit (CDCL event + clause-set digest)。
lu-smt --jit-trace-emit trace.lutrace query.smt2

# slim (verdict-only): consult が読む digest + terminal
# conflict だけを emit し、propagation ストリームを破棄。
# clean な `unsat` のときのみ。
lu-smt --jit-trace-emit-slim slim.lutrace query.smt2

# 事前 emit 済みの `.lutrace` (full または slim) を load し、
# 各 `(check-sat)` 前に consult する (--aot-load と併用)。
lu-smt --aot-load prelude.luart \
       --jit-trace-load trace.lutrace query.smt2
```

`--jit-trace-emit`、`--jit-trace-emit-slim`、`--jit-trace-load`
は相互排他である (exit 12)。

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
