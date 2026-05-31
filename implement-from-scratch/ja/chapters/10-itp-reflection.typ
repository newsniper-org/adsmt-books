= ITP リフレクション

== 「リフレクション」が買うもの

ひとたび証明書を手にすれば、判定は小さなライブラリで独立
に検査可能になる。しかし、対話的定理証明系 — Lean 4、
Rocq、Isabelle — に組み込まれているユーザにとって、別立
ての証明書チェッカを走らせるのは不格好である。彼らが望む
のは、ソルバの判定を *ITP 自身のカーネルにおける真の証明
項*へと変換することであり、そうすれば ITP 自身が信頼の権
威となる。

それが*リフレクション・ブリッジ*である。すなわち、証明書
を与えると、ITP で検査されたときに当該判定を主張命題とす
るような ITP 表層コード(タクティクスクリプトまたは項)
を発行する。adsmt は 3 つのリフレクション・バックエンドを
提供する。

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*モジュール*], [*状態*]),
  [Lean 4], [`adsmt-cert::prover_emit::lean`], [リポジトリ内のリファレンス],
  [Rocq],   [`adsmt-emit-rocq` (リポジトリ外)],   [Lean を写像],
  [Isabelle], [`adsmt-emit-isabelle` (リポジトリ外)], [Lean を写像],
)

Lean 4 経路が*リファレンス*である。出力形状に対するいか
なる変更も `lean` に最初に着地し、その後 Rocq + Isabelle
バックエンドへ歩調を揃えて伝播する(`prover_emit_policy.md`
を参照)。

== 共通アンカー

3 つのバックエンドは*アンカー*集合 — 各バックエンドが実
装する抽象操作 — を共有する。

```rust
pub trait ProverEmit {
    fn open_proof(&mut self, goal: &Term);
    fn refl_step(&mut self, t: &Term);
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term);
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness);
    fn abductive_assume(&mut self, name: &str, hyp: &Term);
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind);
    // ... 12 mandatory + abductive + classical ...
    fn close_proof(&mut self);
}
```

`adsmt-cert::prover_emit::common` は `Cert` のステップを
走査し、適切なトレイトメソッドを呼び出して下ろす。バック
エンド実装は ITP 固有の構文を整形する。この分解により 3
つのバックエンドが厳密に同期される。新たなステップ種を加
えればトレイトにメソッドが増え、変更がコンパイル可能にな
る前に 3 バックエンドすべてがそれを扱う必要が生じる。

== Lean 4 — リファレンス・バックエンド

```rust
impl ProverEmit for LeanEmitter {
    fn open_proof(&mut self, goal: &Term) {
        write!(self.out, "theorem adsmt_goal : {} := by\n",
               lean_term(goal)).unwrap();
        self.indent = 2;
    }
    fn refl_step(&mut self, t: &Term) {
        self.line(&format!("have h{} : {} = {} := rfl",
                           self.next_id(), lean_term(t), lean_term(t)));
    }
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term) {
        let id = self.next_id();
        let prev = self.prev_two();
        self.line(&format!("have h{id} : {} = {} := Trans.trans h{} h{}",
                           lean_term(a), lean_term(c), prev.0, prev.1));
    }
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness) {
        let tactic = match theory {
            TheoryName::Uf  => "congrArg",
            TheoryName::Lia => "linarith",
            TheoryName::Lra => "linarith",
            TheoryName::Bv  => "bv_decide",
            TheoryName::Arr => "simp [Array.get_set]",
            TheoryName::Dt  => "decide",
        };
        self.line(&format!("have h{} : ... := by {}", self.next_id(), tactic));
    }
    fn abductive_assume(&mut self, name: &str, hyp: &Term) {
        // Renders as a Lean sorry-shaped placeholder.
        self.line(&format!("have {} : {} := by sorry  -- abductive",
                           name, lean_term(hyp)));
    }
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind) {
        let import = match kind {
            ClassicalAxiomKind::Lem => "Classical.em",
            ClassicalAxiomKind::Peirce => "Classical.peirce",
            // ...
        };
        self.preamble.push(format!("open {}", import));
    }
}
```

17 ステップの証明書は 17 行の `have` を含む Lean タクテ
ィクブロックを生む。最後を締めるのは、最終識別子を元のゴ
ールの証明として命名する `close_proof` である。出力は
Lean のエラボレータとカーネルを通過する。Lean 自身の信頼
が健全性の義務を肩代わりする。

== Rocq / Isabelle — 写像

Rocq および Isabelle バックエンドはリポジトリ外の
`~/adsmt-contrib/` に存在する。同一の `ProverEmit` トレ
イトを実装するが、それぞれ Rocq の Ltac2 構文または
Isabelle の Isar 構文を発行する。

```text
~/adsmt-contrib/
├── adsmt-emit-rocq/
│   └── src/lib.rs        — impl ProverEmit for RocqEmitter
└── adsmt-emit-isabelle/
    └── src/lib.rs        — impl ProverEmit for IsabelleEmitter
```

注意すべき制約がいくつかある。

- *Rocq Ltac1 は除外*される。Ltac2 のみ。Ltac1 の型付けの
  ない表層は機械生成タクティクに対して脆すぎる — 最小の証
  明書の差異が Ltac1 では不透明なパースエラーを生むが、
  Ltac2 では型付け時に捕捉される。
- *出力形状は Lean を厳密に写像する。* Lean の各 `have`
  は Isabelle の `have :` および Rocq の `Notation.notation`
  と同順序かつ同識別子名で対応する。これは prover_emit ポ
  リシーの硬い不変量である。
- *古典公理はオンデマンドでインポート*される。発行された
  各ファイルのプリアンブルは、証明書プリアンブルが名指し
  た公理のみをインポートする。オフライン優先の検査が、対
  象 ITP で名指された公理がサポートされない場合に発行を
  拒否する。

== 往復差分テスト

歩調合わせポリシーは*往復差分テスト*によって強制される。
証明書を与え、Lean 出力を発行して正規化された AST に正規
化し、次に Rocq 出力を発行・正規化、続いて Isabelle 出力
を発行・正規化して、三者を比較する。3 つの木の間の構造的
な乖離はポリシー違反であり、マージを阻む。

```rust
#[test]
fn lockstep_lean_rocq_isabelle() {
    for cert in golden_certs() {
        let lean_tree   = normalize(emit_lean(&cert));
        let rocq_tree   = normalize(emit_rocq(&cert));
        let isabelle_tree = normalize(emit_isabelle(&cert));
        assert_eq!(lean_tree.shape(), rocq_tree.shape());
        assert_eq!(lean_tree.shape(), isabelle_tree.shape());
    }
}
```

これが我々が「Lean 4 リファレンス」と言うときの意味である。
Lean は単に*3 つのうちの 1 つ*の出力形式ではない。他が複
製しなければならない形状を持つ形式である。

== `sorry` としてのアブダクティブ・ホール

アブダクティブ・ステップは ITP ネイティブの `sorry` プレ
ースホルダを発行する。Lean では `sorry`。Rocq では(アブダ
クティブ層が定義の境界にあるときは)`Admitted`、あるいは
(タクティクモードでは)`give_up`。Isabelle では `sorry`。

各プレースホルダはアブダクティブ仮説に因んだ名前が付くた
め、ユーザはエディタ上で名前付き義務のリストを目にする。
例えば次のようなものである。

```text
adsmt_h_3 : ∀ x, x > 0 → P x
adsmt_h_7 : a ≠ b
```

これらは正にアブダクティブ層が表面化した仮説 — ただし
ITP の衣をまとった姿 — である。ユーザはこれを証明するか、
公理として受理するかして消化する。証明の残りは ITP 自身
のカーネル上で通る。

== 全体の連鎖

第 1 章から第 10 章までの層をまとめると、エンドツーエン
ドのパイプラインは以下である。

```text
SMT-LIB script
   ↓ parse
Internal AST
   ↓ engine.check_sat (CDCL + theory + quantifier + abduce)
SatResult
   ↓ recorder
Cert (S-expr)
   ↓ prover_emit::lean / ::rocq / ::isabelle
ITP-surface proof script
   ↓ ITP kernel
Verified theorem
```

この連鎖のすべての繋ぎ目には、反対側に独立した検証者がい
る。カーネル(第 2 章)はそれ自身で検証される — 12 規則
が健全性の契約である。チェッカ(第 9 章)はカーネル規則
に対して証明書を検証する。ITP(第 10 章)は自身のカーネ
ルに対して発行された証明を検証する。アブダクティブ層(第
8 章)は不健全さではなく*名前付き義務*を導入する — ユー
ザはそれを明示的に目にし、判断する。

これが、SMT-as-tactic が証明アシスタントに奉仕すべきと我
々が言うときの意味である。ソルバの判定は決して最終語では
ない。最終語は ITP のカーネルである。
