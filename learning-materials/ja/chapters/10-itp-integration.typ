= ITP 統合

== 三つの統合、一つの設計

adsmt は三つのシステム向けに ITP 統合を出荷している。

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*状況*]),
  [Lean 4],   [ツリー内リファレンス (`adsmt-cert::prover_emit::lean`)],
  [Rocq],     [ツリー外 (`~/adsmt-contrib/adsmt-emit-rocq`)],
  [Isabelle], [ツリー外 (`~/adsmt-contrib/adsmt-emit-isabelle`)],
)

三つの統合は、ロックステップでの進化を強制する*アンカー*
トレイトを共有する。任意の新しい証明書ステップ種別は、
コンパイル前に三つすべてに実装が必要である(姉妹編 10 章)。
出力形状は厳密にミラーする。各 Lean の `have` は Rocq の
Ltac2 `Notation.notation` と Isabelle Isar の `have` に
対応する。

Lean 4 がリファレンスである。Rocq と Isabelle はミラーする。

== Lean 4 — リファレンス

Lean 4 の経路。

1. ユーザが証明スクリプトで `smt_decide` または
   `smt_abduce` を書く。
2. タクティクハーネスがゴールを SMT-LIB に加えて文脈仮説
   へとコンパイルする。
3. `adsmt` が解き、証明書を発する。
4. `prover_emit::lean` が証明書を Lean タクティク
   スクリプトに翻訳する。
5. Lean のエラボレータ + カーネルがスクリプトを検査する。
   通れば元のゴールが処理される。

```lean
import Adsmt

example (a b c : Nat) (h1 : a = b) (h2 : b = c) : a = c := by
  smt_decide [h1, h2]
```

舞台裏では次のようになっている。

```text
goal:         a = c
hypotheses:   h1 : a = b, h2 : b = c
to SMT-LIB:   (assert (= a b)) (assert (= b c)) (assert (not (= a c)))
solver run:   unsat with cert
              (step :rule assume :id 1 :term (= a b))
              (step :rule assume :id 2 :term (= b c))
              (step :rule trans  :id 3 :lhs 1 :rhs 2)
              (step :rule assume :id 4 :term (not (= a c)))
              (step :rule deduct :id 5 :hyp 4 :conc 3)
emit:         have h_3 : a = c := Trans.trans h1 h2
              exact absurd h_3 (by intro; assumption)
Lean kernel:  ✓ goal discharged
```

タクティクは完全にカーネル検査された証明の中へ消えていく。
証明書層はユーザからは不可視である。

== `smt_decide` と `smt_abduce`

二つのタクティク、二つの意図。

- `smt_decide` — *演繹的*モードで adsmt を呼び出す。
  `sat` / `unsat` 判定だけがゴールを閉じる。`unknown`
  は失敗する。
- `smt_abduce` — *アブダクティブ*モードで adsmt を
  呼び出す。`unsat` はゴールを閉じる。`abductive` は
  候補の `sorry` プレースホルダをスクリプトに浮上させる。

```lean
example (n : Nat) : f n ≤ g n := by
  smt_abduce
-- emits:
-- have hyp_f : ∀ n, f n ≤ n := by sorry
-- have hyp_g : ∀ n, n ≤ g n := by sorry
-- exact Nat.le_trans (hyp_f n) (hyp_g n)
```

ユーザは自分の証明で `sorry` を埋める(あるいはスコープ内の
追加公理として受け入れる)。証明の*構造*は adsmt によって
提供される。仮定の*内容*はユーザの責任である。

== `solve … by …` — 言語の中の証明項

上記のタクティクは adsmt の _外側_ に位置する。Lean や Rocq
のスクリプトが呼び込む形である。しかし lukb 後継表層
(`adsmt-ir-lukb`。ゼロから実装する lukb 付録を参照)は、
ITP 流の証明への独自の _言語内_ ブリッジを持つ。それは
一つの構文である。

```lukb
solve G by L
```

これは「_補題 `L` によって正当化された `G` の証明_」と読む。
`G` と `L` はともに*ブロック* — 一つの項、または項で終わる
`let` 連鎖 — であり、どちらの側でも中間事実を組み上げられる。

これは*カット規則*を構文にしたものである。エラボレーション
(意味論 B。これは _証明項を構築する_ のであって、解析時に
ソルバを走らせるわけではない)は、ちょうど二つの義務を発し、
それぞれが周囲の文脈で閉じられているのでトップレベルで
整形式となる。

- *葉* `L` — 補題を処理する、そして
- *ブリッジ* `L ⟹ G` — 補題がゴールを含意することを示す。

カーネルはこの二つから証明の足場を組み立て、エンジンは葉を
処理する。用いられる推論はカットのみ — 公理なし、判定の
近道なし — であるから、`solve` は構成上健全である。健全性
コアは Verus で事前検証されている
(`~/solve-by-verification`、検証済み 5、エラー 0)。

```lukb
// goal: the head of a sorted, non-empty list is its minimum.
goal head_is_min : is_min(head(xs), xs) =
  solve is_min(head(xs), xs)
  by    sorted(xs) and nonempty(xs)
```

葉 `sorted(xs) ∧ nonempty(xs)` は _あなた_ が負うものであり、
ブリッジ `(sorted(xs) ∧ nonempty(xs)) ⟹ is_min(head(xs), xs)`
はエンジンが検査するものである。`smt_abduce` との類比は
正確である — `solve` はアブダクティブな `sorry` の、演繹的で
_既に正当化された_ 兄弟である。穴を残す代わりに補題に名前を
与え、adsmt はそのステップを推測するのではなく検証する。

== 篩型が意図を運ぶ

`solve` は、あなたが _述べられる_ 命題と同じだけしか鋭く
ならない。lukb 後継表層は*篩型* — 述語によって切り出された
基底ソート — で検証の意図を述べる。

```lukb
{ v: T | φ }
```

— `φ` を満たす `v` に制限されたソート `T`。篩型は型が
使える場所ならどこでも使える。`const` 上、`fn` の引数や
戻り値上、矢印のどちら側でも、そして量化子の束縛子として。
`Nat` と `WNat` はそれ自体 `Int` の篩型である
(`Nat = {x: Int | x ≥ 1}`、`WNat = {x: Int | x ≥ 0}`)。

篩型を持つ `const` は、型付けと述語の _両方_ を信頼された
事実として仮定する。

```lukb
const c : { v: Int | v ≥ 0 }   // gives  c : Int  AND  c ≥ 0
```

量化子の束縛子上の篩型は、事前検証された相対化補題によって
エラボレートされる — 覚えておくべきは極性である。

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*束縛子*], [*エラボレート先*]),
  [`forall {v:T|φ}. ψ`], [`forall v:T. φ ⟹ ψ`],
  [`exists {v:T|φ}. ψ`], [`exists v:T. φ ∧ ψ`],
)

つまり `∀` は含意へと弱まり、`∃` は連言へと強まる。極性を
逆にすると、空虚な義務か充足不能な義務のどちらかになる。
adsmt のエラボレータが代わりに直してくれるが、脱糖された
ゴールを読むときには頭の片隅に置く価値がある。

*関数型と篩型の矢印.* `T -> U` は矢印である(右結合。
`(A -> B) -> C` は _矢印の定義域_ を括弧で括る)。両端を
篩型にすると、矢印は契約を運ぶ。

```lukb
{ u: A | 'p } -> { v: A | 'q }
```

— 定義域上の前提条件 `'p`、余定義域上の事後条件 `'q`。
_値_ のソートは依然として素の `A -> A` である。篩型は
証明無関係であり、低位化時に消去される。見返りは、この型で
供給される引数が _その事後条件 `'q` を使える事実として
手渡してくれる_ ことである — まさに下流の `solve` が欲しがる
仮説である。

== ジェネリック述語パラメータ `'p`

上の `'p` の先頭の単一引用符は飾りではない。これは*ジェネ
リック述語パラメータ*を表し、定義を述語 _多相的_ にする。
篩型が `'p` に言及する `fn` は、それを頭部で暗黙に
`Π('p : T → Prop)` として束縛し、本体は `'p` を抽象的に
保ったまま *一度だけ* 型検査される — 「一度検査」保証である。
パラメータの篩型は前提条件となり、戻り値の篩型は事後条件と
なり、契約全体

$ forall arrow('p). thin forall arrow(x). thin
  (and.big_i "pre"_i) arrow.r.double "post" $

は、関数を _定義している_ ときには*ゴール*(構築地点の義務、
エンジンが処理する)であり、_シグネチャ_ にすぎないときには
*信頼された公理*である。使用地点では `'p := q` を具体化する。
今や単相となった前提条件はその場で処理される。これが
*辞書渡し*である。呼び出し側が、呼び出される側が抽象化した
述語を供給する。

単一引用符は、解析時にジェネリックな `'q` を*具体的*な述語
`q`(引用符なし)から曖昧性なく区別するものである。具体的な
篩型 `fn` も同じ契約の扱いを受ける — ジェネリック性が
唯一の違いである。

*自明な述語 `nop`.* 一様性のために、篩型対応の論理は常に
述語を見たがる。そこで _篩型なし_ の `x: T` は
`{x: T | nop(x)}` と読まれる。ここで

```lukb
nop : Π(T: Type). T → Prop := λ T x. true
```

`nop(x) ≡ true` であるから、`nop` 篩型は空虚である。それは
落とされる — 仮説も発せられず、ガードも発せられない — ので
脱糖出力はきれいなままであり、`const c: {v:T|nop(v)}` は
ただの `const c: T` である。`nop` を自分で書くことは決して
ない。これは「篩型あり」と「篩型なし」に一つのコード経路を
共有させる単位元である。

== 組み合わせる: 保存

これらの部品は、小さいが現実的な検証イディオムへと合成
される。あるデータ型 `A` が多くの関数を持ち、「_`f` は性質
`'p` を保存する_」と言いたいとしよう。

惹かれる手は `Preserving('p)` を*型関係*(adsmt 独自の型
クラスの呼称。次節を参照)にすることである。それは試され、
そして*退役した* — 誤った抽象だからである。型関係は
_コヒーレント_ である。型ごとに一つのインスタンス。しかし
`A` は _多くの_ `'p` 保存関数を持ちうるし、保存しない関数も
多く持ちうる。したがって保存は型の性質ではない — それは
*関数*の性質であり、高階述語 `preserving(f)` であって、各 `f`
について独立に検査される。

*再利用可能*な述語としての保存は、*定義*するのが最善で
ある — 命題を述べる `Bool` 値の高階述語であり、`'p`/`'q` は
篩型の矢印の引数から収集される(`Bool` の戻り値はそれ自体
何の義務も負わない)。

```lukb
fn preserving( f: { u: A | 'p(u) } -> { v: A | 'q(v) } ) : Bool =
  forall x: A. 'p(x) ==> 'p(f(x))
```

仕事が現れるのは具体的な*使用*地点だけであり — そこでこそ
`solve … by …` が真価を発揮する。`f` の事後条件が手に入って
いれば(ここでは `f` の篩型の矢印型から来る明示的な `axiom`)、
カットは具体的な「`f` は `p` を保存する」というゴールを処理
する。

```lukb
const p: A -> Bool    const q: A -> Bool    const f: A -> A
axiom post_f: forall {x: A | p(x)}. q(f(x))
goal:
  solve forall {x: A | p(x)}. p(f(x))
  by    forall {y = f(x) | p(x)}. q(y) ==> p(y)
```

葉 — 「像の上での `q ==> p`」 — が真の中身であり、ブリッジは
それを `post_f` と合成してゴールを閉じる。なぜ証明を生む `fn`
ではなく*定義*なのか。本体で `solve … by …` を走らせ、
_ジェネリック_ な `'p`/`'q` の上で一度だけ検査される
`preserving` は*不健全*だろう — その葉
`∀'p 'q f. 'q(f x) ==> 'p(f x)` は一般には偽だからである。
ゆえに述語は一度だけ*述べられ*、具体的な使用ごとに*処理*
される。

== 像束縛子 — 推論が仕事をする

もう一つの束縛子形式で、ほぼ全面的に型推論に駆動される。
*像束縛子*

```lukb
forall { y = f(x) | c }. q(y)
```

は推論された _原像_ `x`(そのソートは `f` の定義域)上を
動き、`c` でガードし、本体中で `y` を `f(x)` に展開する。
事前検証された `image_quantifier_desugar` により、これは
ちょうど

```lukb
forall x: { A | c }. q(f(x))
```

である。量化子を _気にかけている値_(`y`、`f` の像の中)の
言葉で書き、adsmt は実際に動かねばならない変数(`x`、定義域
の中)を回復する。数学が読まれる通りに読める、ささやかな
便利さである。

== 型関係は型クラスである

「_型関係_」は adsmt による型クラスの呼称である — *一つ*の
概念であり、`adsmt-class` は文字通り型クラス層である
(`Relation` / `Instance` / `Resolver` / `Dict` / `Law`)。
*\*Like 族* — `PartialOrd` → `Ord` → `IntegerLike`、
`RealLike`、… — は `Reduces` の背骨を共有し、
`IntegerLike(I, L, N)` は最初の _高階種_ インスタンスである。

検証にとって二つの性質が重要である。

- *証明による合法性.* 関係はメソッドメンバの傍らに*法則*
  ゴールメンバを持つ。インスタンスは、adsmt の _自前の
  エンジン_ がすべての法則を証明する場合にのみ受理される —
  さもなくばビルドは*拒否される*(`declare_instance_lawful`
  + エンジン裏付けの `LawProver`)。`solve` の葉を処理する
  のと同じソルバが、あなたの型の `Ord` が実際に全順序で
  あることを証明する。
- *述語パラメータ.* 関係は、インスタンスが*辞書*エントリ
  として供給する述語パラメータ `'p : T → Prop` を持ちうる —
  ジェネリックな `fn` で見たのと同じ辞書渡しが、今度は
  インスタンスのレベルで現れる。

これは adsmt の中核的設計意図である*四方インターロック*の
一面である。型推論、アブダクティブ・演繹論理、ASP、そして
SMT(加えて HKT)は、別々の縦穴に座すのではなく
_有機的_ にインターロックすることを意図されている。
`IntegerLike(I, L, N)` は連結組織である — 型情報が、高階種
インスタンスを通して、`solve` が頼るエンジンへと流れ込む。

== Rocq 統合

Rocq バックエンド(`~/adsmt-contrib/adsmt-emit-rocq`)は
Ltac2 タクティクを発する(Ltac1 ではなく — Ltac1 は
prover_emit ポリシーにより除外されている)。出力形状は
Lean リファレンスをミラーする。

```coq
From Adsmt Require Import AdsmtTactic.

Example example_eq : forall (a b c : nat), a = b -> b = c -> a = c.
Proof.
  intros a b c h1 h2.
  adsmt_decide [h1; h2].
Qed.
```

タクティクは adsmt を呼び出し、証明書を取得し、証明書の
ステップを辿る Ltac2 スクリプトを生成する。各証明書ステップ
は小さな証拠タクティクを伴う Ltac2 `assert` になる。

== Isabelle 統合

Isabelle バックエンド
(`~/adsmt-contrib/adsmt-emit-isabelle`)は Isar 構文を
発し、これも Lean をミラーする。

```isabelle
lemma example_eq:
  fixes a b c :: nat
  assumes h1: "a = b" and h2: "b = c"
  shows "a = c"
proof -
  have h_3: "a = c" by (rule trans, fact h1, fact h2)
  show ?thesis by fact
qed
```

証明構造は Lean / Rocq を厳密にミラーする。異なるのは
表層構文だけである。ロックステップ性は往復差分テストに
よって強制される(姉妹編 10 章)。

== 古典公理の衛生

各バックエンドは、証明書のプリアンブルに名前のある古典
公理を*必要に応じて*インポートする。LEM を引用する Lean
証明書は `Classical.em` をインポートし、Rocq 証明書は
`Classical_Prop.classic` を、Isabelle 証明書は
`HOL.Classical` をインポートする。

バックエンドの対象が指名された公理をサポートしない場合 —
たとえば `Classical.em` を拒絶する厳格な構成的 Lean モジュール
の場合 — emit は診断を伴って拒否する。ユーザは古典インポート
を受け入れるか、古典公理を無効化して再試行するようソルバに
求める。

== 性能上の考慮

知っておくに値する三つのつまみ。

*1. 証明書サイズ.* 大きなゴールは数 kB の証明書を生成
しうる。emit 時間は線形にスケールし、ITP のエラボレーション
も線形にスケールする。対話的利用ではサブ秒が目標であり、
LSP 経路(安価な再チェック)はそこを保つ。

*2. タクティクの粒度.* サブゴール毎の `smt_decide` は
問題ない。巨大な選言上の `smt_decide` は遅い。呼び出す
前に分割すること。

*3. アブダクティブコスト.* アブダクティブ探索の予算は
有界である(SMT-LIB では `:abductive-tier 0..4`、タクティク
表層では同等のもの)。Tier 4 が最も積極的かつ最も高コスト
である。

== SMT をタクティクとして用いて輝く場面

- *等号の連鎖.* 「$a = b$、$b = c$、$c = d$、…、$a = z$
  を証明せよ」。adsmt の EUF はこれをマイクロ秒単位で
  処理する。Lean の `congr` タクティク連鎖は同様だが、
  書くのにより冗長である。
- *線形算術.* 「$x >= 1$、$y >= 1$ を所与として
  $3x + 2y >= 5$ を証明せよ」。Simplex 経由の LIA。
  Lean の `linarith` もこれを行う — adsmt は透明性
  のために Farkas 証拠の証明書経路で拡張する。
- *ビットベクトル恒等式.* 「`(x ^ y) ^ x = y` を
  証明せよ」。ビット・ブラスティングで決定する。
  Lean の `bv_decide` が Lean 内では最も近い等価物
  である。

== SMT をタクティクとして用いて苦しむ場面

- *帰納.* SMT は帰納を扱わない。ITP が扱う。
- *単一化を要する高階推論.* SMT は Miller パターンを
  使う。Lean の高階単一化器は遥かに強力である。
- *ドメイン固有の自動化* — 圏論、立方体、集合論的構成。
  SMT は汎用である。特化したタクティクが勝つ。

組合せこそが強みである。SMT が輝く場所(具体的な一階、
等号、算術)では SMT を使い、SMT が助けにならない場所では
ITP の native タクティクを使う。adsmt の設計 — アブダク
ティブな脱出、透明な証明書、ITP に親しい emission — は
この分業の周りに構築されている。

== 完全な例題

`smt_abduce` を使った小さな Lean 4 証明。

```lean
import Adsmt

example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  smt_abduce
```

アブダクティブな出力。

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := by
    sorry  -- abductive candidate 1
  exact h xs.head! h_head_in
```

ユーザは候補仮説(`xs.head! ∈ xs`、空でないリストに
ついては真)を読み、`exact List.head!_mem_of_ne_nil hne`
で処理する。完全な証明。

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := List.head!_mem_of_ne_nil hne
  exact h xs.head! h_head_in
```

adsmt は構造を見出し、ユーザはドメイン知識を供給した。

これ — *ソルバと証明者の協働* — こそ adsmt の目的である。
外部タクティク(`smt_decide`、`smt_abduce`)と言語内の
証明項(`solve … by …`)は、同じ場所への二つの経路である。
どちらでも、人間が意図に名前を与え — 埋めるべき仮説、運ぶ
べき篩型、カットすべき補題 — エンジンがカーネル検査された
足場の下で義務を処理する。証明が Lean に宿ろうと lukb の
`goal` に宿ろうと、分業は同じである。
