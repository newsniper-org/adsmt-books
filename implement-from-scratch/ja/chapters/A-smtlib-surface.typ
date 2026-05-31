= SMT-LIB v2 表層

本付録は、`adsmt-parser` が認識する SMT-LIB v2 表層を文
書化する。これは完全な SMT-LIB v2 標準の*部分集合*に、若
干の adsmt 固有拡張を加えたものである。

== 認識されるコマンド

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*コマンド*], [*備考*]),
  [`set-logic`],   [QF_* ロジックおよびその量化子付きの対応物を受理する。複数の理論が現れる場合は polite 結合が自動選択される。],
  [`set-option`],  [標準オプションに加え adsmt 固有の `:abductive-tier`、`:trigger-mode`、`:classical-axioms`。],
  [`declare-sort`, `declare-fun`, `declare-const`], [標準。],
  [`define-fun`, `define-fun-rec`], [標準。`define-fun-rec` は部分的 — 停止性の義務はユーザの責任。],
  [`assert`],      [標準。],
  [`check-sat`],   [`sat`、`unsat`、`unknown`、または(新たな判定である)`abductive` を返す。],
  [`get-model`],   [標準。`Sat` に対する割当を返す。],
  [`get-unsat-core`], [標準。`Unsat` に対するラベル付き部分集合を返す。],
  [`get-abductive-candidates`], [adsmt 拡張 — `Abductive` に対する順位付き候補リストを返す。],
  [`push`, `pop`], [標準のスコープスタック。],
  [`reset`, `reset-assertions`], [標準。],
  [`exit`],        [標準。],
)

== 理論

以下の SMT-LIB 理論がサポートされる(第 6 章)。

- `Core` — Bool、=、distinct、ite、and、or、not、=>
- `Ints` — LIA
- `Reals` — LRA
- `Reals_Ints` — polite 結合による LIRA
- `FixedSizeBitVectors` — ビット・ブラスティングをフォー
  ルバックとする BV
- `ArraysEx` — read-over-write 配列
- `Datatypes` — 代数的データ型

== ロジック

標準の SMT-LIB ロジック名が認識される。

```text
QF_UF, QF_LIA, QF_LRA, QF_BV, QF_AUFLIA, QF_AUFBV,
QF_DT, QF_AUFDT,
LIA, LRA, AUFLIA, AUFBV, AUFDT, ...
```

ロジックが量化子を含む(`QF_` 接頭辞がない)とき、エンジ
ンは第 7 章の量化子インスタンス化パイプラインを自動で起
動する。

== 拡張

3 つの SMT-LIB 拡張は adsmt 固有である。

*`:abductive-tier <n>`* — 量化子処理がアブダクティブ候
補へエスカレートする最大 tier を設定する。`n=0` はアブダ
クティブ表層を無効化する(枯渇時に `unknown` を返す);
`n=4`(既定)は完全なパイプラインを有効化する。

*`:trigger-mode <miller|free>`* — `miller`(既定)はトリ
ガを Miller パターンに限定する;`free` は非 Miller トリ
ガを許容する(それに伴う病理を抱える)。

*`:classical-axioms (<axiom>*)`* — ソルバが呼び出してよ
い古典公理をホワイトリスト化する。受理される名前は
`lem`、`peirce`、`dne`。ホワイトリストに含まれない公理を
要求するステップは失敗するか Tier-4 エスカレーションを得
る。

*`get-abductive-candidates`* — `check-sat` が
`abductive` を返したとき、このコマンドは順位付き候補リス
トを入れ子の S 式として返す。出力例:

```text
(abductive-candidates
  (candidate :rank 1 :hypothesis ((P a) (Q b))
             :justification sld_chain)
  (candidate :rank 2 :hypothesis ((R c))
             :justification quantifier_exhausted))
```

== 非拡張

SMT-LIB v2 のいくつかの機能は*サポートされない*。

- `Floats`(FP 理論) — 対象外。
- `Sequences` および `Strings` 理論 — 対象外。
- `define-fun-rec` の全域性検査 — 部分的のみ。
- パターン構文 `(! ... :pattern ...)` はパースされるが、
  Tier-1 は明示的な `:trigger` 属性がない場合にのみパター
  ンを参照する。

これらの省略は意図的である。FP 健全性に対する v1.0.0 の
コミットメントは、法外に遅いビット・ブラスティング・フ
ォールバックか、それ自体が研究プロジェクト級である FP 専
用の決定手続きを要求するためである。
