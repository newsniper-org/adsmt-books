= lu-kb 表層

`lu-kb` は adsmt が受理する第 2 の入力方言である。これは
*logicutils* プロジェクト(RC1.4.A で吸収、`ABSORPTION_PLAN.md`
を参照)に起源を持ち、logicutils 消費者との後方互換性のため、
および adsmt 固有の知識ベース執筆のために保存される。

== 表層の形状

`.kb` ファイルは*ブロック*の列である。

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

各ブロックは `sort`、`fun`、`rule`、`class`、`instance`、
`query` のいずれかである。方言の文法は
`adsmt-parser/src/lukb/` に存在し、移行連鎖(v0.x から
v1.0 まで)もチェックインされている。

== ブロック

*`sort <name>`* — 不透明なソートを宣言する。SMT-LIB の
`declare-sort` に相当。

*`fun <name> : <type>`* — 関数記号をその型と共に宣言す
る。高階種型(`F[T]`、`F[T, U]`)が認識される。カーネル
の意味論は第 3 章で扱う。

*`rule <name> : <formula>`* — エンジン起動時に表明される
名前付き仮定。事実の表明にも、アブダクティブ層(第 8 章)
に供給される Horn 規則にも用いられる。

*`class <name>[<tyvar>+] = { <field> : <type> ; ... }`* —
型クラスを宣言する。第 3 章の T_class に相当。

*`instance <name>[<type>+] = { <field> = <term> ; ... }`* —
特定の型引数に対するクラスのインスタンスを宣言する。

*`query <formula>`* — `assert (not phi)` の後に
`check-sat` を続けたものに相当。判定は名前で報告される。

== ハッシュ印付き移行連鎖

`.kb` ファイルは正規形の K12-256 ハッシュをオプションで
持つ。ハッシュはパース時に再計算される。不一致は移行検査
を引き起こし、既知の方言バージョンの連鎖を辿って必要な変
換を適用する。

```text
% kb-version: 1
% kb-hash:    k12-256:abc123...
```

連鎖は `lu-common/src/migration.rs` に保守され、破壊的バ
ージョンごとに 1 個の変換を持つ。移行は*オプトイン*であ
る — `:auto-migrate` オプションがなければ、ハッシュ不一
致はエラーとなる。

== SMT-LIB との比較

`lu-kb` は個別ゴールの消化ではなく、知識ベースの執筆に向
けて形作られている。

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*関心事*], [*SMT-LIB*], [*lu-kb*]),
  [粒度], [ゴール単位], [知識ベース単位],
  [再利用],       [push/pop スコープ], [rule および class ブロック],
  [型クラス], [ネイティブにはなし], [`class` / `instance` ブロック],
  [Horn 親和性], [手動], [`rule` ブロックがアブダクションに供給],
  [移行], [プリアンブル中のバージョン], [ハッシュ印付き連鎖],
)

実際には、ライブラリ著者は `.kb` を好む(知識ベースを一
度書き、繰り返しクエリする);アドホックなユーザは
`.smt2` を好む。両表層とも同じ内部 AST にコンパイルされ
るので、エンジンの振る舞いは同一である。

== エディタ統合

VS Code 拡張(`tooling/vscode-extension/` 配下)は
`.smt2` と `.kb` の両拡張子を認識する。LSP サーバ
(`adsmt-lsp`)は拡張子に応じてファイルを適切なパーサに
振り分ける。補完リストは適応する(`class`、`instance`、
`query` などの `kb` 固有キーワードを含む 39 個の静的項
目)。
