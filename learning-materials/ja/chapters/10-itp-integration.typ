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
