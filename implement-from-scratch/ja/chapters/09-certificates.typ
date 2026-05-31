= 証明書

== なぜ証明書か

現代の SMT ソルバは $10^5$ 行規模の入り組んだコードであ
る。その判定を信頼せよとユーザに求めるのは無理難題である
— とりわけ SMT が最も価値を発揮する安全クリティカルな検
証の場面においては。

その解が*証明証明書*である。すなわち、判定がいかにして得
られたかの構造化された記録であり、はるかに単純な外部チェ
ッカが再検証できるように設計される。チェッカは CDCL、理
論結合、量化子インスタンス化を理解する必要はない。固定さ
れた推論規則集合に対して各ステップを検証するだけでよい。

adsmt の証明書形式は `adsmt-cert` であり、第 2 章のカー
ネル 12 規則に対応する 12 種類のステップに、3 つのアブダ
クティブ・マーカと数種類の理論証拠を加えた S 式言語であ
る。

== 形式の概観

```text
(cert.v1
  (preamble
    (kernel-version "0.19")
    (cert-version "1")
    (classical-axioms (lem peirce))
    (theories (uf lia bv)))
  (steps
    (step :rule refl   :id 1 :term (= x x))
    (step :rule assume :id 2 :term (P x))
    (step :rule beta   :id 3 :input 2 :term ...)
    ...
    (step :rule deduct :id 17 :conclusion (=> (P x) (Q y))))
  (verdict unsat
           :final-step 17))
```

各ステップは一意の数値 `id` で識別される。ステップは先行
ステップを id で参照するため、依存構造は `verdict` 名の最
終ステップで終わる DAG をなす。

== StepBody — 12 + 3 + …

Rust 型はこの形式を直接反映する。

```rust
pub struct Cert {
    pub preamble: Preamble,
    pub steps: Vec<Step>,
    pub verdict: Verdict,
}
pub struct Step { pub id: StepId, pub body: StepBody }

pub enum StepBody {
    Refl(Term),
    Trans { lhs: StepId, rhs: StepId },
    EqMp { lhs: StepId, rhs: StepId },
    Abs { var: Arc<Var>, body: StepId },
    Beta(Term),
    Deduct { hyp: StepId, conc: StepId },
    Inst { rule: StepId, var: Arc<Var>, term: Term },
    InstType { rule: StepId, var: Arc<TyVar>, ty: Type },
    Assume(Term),
    Theory { theory: TheoryName, witness: TheoryWitness },
    Instance { class: Term, dict: Term },
    Assumed(Term),
    AbductiveAssume { hypothesis: Vec<Term>, justification: AbductionJustification },
    AbductiveAccept { hypothesis: StepId, ground: Vec<Term> },
    ClassicalAxiom { axiom: ClassicalAxiomKind, instantiation: Vec<Term> },
}
```

必須の 12 個は第 2 章のカーネルを写したものである。アブ
ダクティブ・トリオは第 8 章のエスケープを扱う。古典公理
マーカは、LEM、Peirce、その他排中律型の公理に依存するス
テップを扱う。これらはプリアンブルで前もって宣言される必
要がある。そうすれば、消費者が指定された公理を受理しない
場合、チェッカは証明書を拒否できる。

== レコーダ

カーネルの 12 規則実装は直接に証明書ステップを発行しない
— そうするとカーネル TCB に形式上の関心事を絡めることに
なる。代わりに、レコーダはカーネルをラップする薄いオブザ
ーバである。

```rust
pub struct CertRecorder {
    steps: Vec<Step>,
    next_id: u64,
    preamble: PreambleBuilder,
}

impl CertRecorder {
    pub fn record_refl(&mut self, t: Term) -> StepId {
        let id = self.alloc_id();
        self.steps.push(Step { id, body: StepBody::Refl(t) });
        id
    }
    pub fn record_trans(&mut self, lhs: StepId, rhs: StepId) -> StepId {
        let id = self.alloc_id();
        self.steps.push(Step { id, body: StepBody::Trans { lhs, rhs } });
        id
    }
    // ... one method per StepBody variant ...

    pub fn finalize(self, verdict: Verdict) -> Cert {
        Cert { preamble: self.preamble.build(), steps: self.steps, verdict }
    }
}
```

エンジンがカーネル規則を呼び出すたびに、対応するレコーダ
メソッドも呼び出され、ステップが証明書に織り込まれる。こ
れがカーネルと証明書の結合が存在する唯一の箇所である。そ
れ以外はすべて、証明書を素のデータ構造として扱う。

== チェッカ

証明書チェッカは独立したライブラリであり — カーネルの構
成要素ではない — `Cert` をカーネル規則に対して再検証する。
マップ `step_id |-> conclusion` を保持し、証明書を id 順
に走査する。

```rust
pub fn check(cert: &Cert) -> Result<(), CertError> {
    let mut concl: HashMap<StepId, Term> = HashMap::new();
    let mut deps:  HashMap<StepId, HashSet<Term>> = HashMap::new();
    for step in &cert.steps {
        let (term, hyps) = check_step(step, &concl, &deps, &cert.preamble)?;
        concl.insert(step.id, term);
        deps.insert(step.id, hyps);
    }
    let final_term = concl.get(&cert.verdict.final_step)
        .ok_or(CertError::DanglingFinal)?;
    cert.verdict.matches(final_term)
}
```

核心は `check_step` にある。各規則について、`concl`/`deps`
から引用された依存を読み取り、規則の前提を適用して、新た
な `(term, hypotheses)` の対を生成するか、ステップを拒否
するかいずれかである。

例えば `Trans { lhs, rhs }` は次のように検査される。

```rust
StepBody::Trans { lhs, rhs } => {
    let (Term::Eq(a, b), hyps_a) = (concl[lhs].clone(), deps[lhs].clone()) else {
        return Err(CertError::TransNeedsEq);
    };
    let (Term::Eq(c, d), hyps_b) = (concl[rhs].clone(), deps[rhs].clone()) else {
        return Err(CertError::TransNeedsEq);
    };
    if b != c { return Err(CertError::TransPivotMismatch); }
    Ok((Term::eq(a, d), &hyps_a | &hyps_b))
}
```

これが `Trans` のチェッカ全体である — 形状と等価性のアサ
ーション数行のみ。チェッカは 15 種類のステップ全部で合計
約 600 行であり、それを生成したソルバよりも 2 桁小さい。

== 出力 / パースの往復

`adsmt-cert` は S 式構文のパーサとプリティプリンタを公開
する。

```rust
pub fn parse(input: &str) -> Result<Cert, ParseError>;
pub fn write(cert: &Cert, out: &mut impl Write) -> std::io::Result<()>;
```

往復のプロパティテスト(`parse(write(c)) == c`)がテストス
イートで実行される。S 式構文は十分に行指向で人間が直接読
めるため、レコーダのデバッグにおいて何にも代えがたい価値
を持つことが分かる。

== 判定の整合

最終ステップの結論は、宣言された判定と*整合*しなければな
らない。Unsat であれば、最終ステップは仮説集合が空の状態
で $"False"$ を結論する。Sat であれば、最終ステップは(定
数割当のリストである)モデル証拠で、表明された全ての原子
と整合する。

Abductive 判定は新しい形である。すなわち、その最終ステッ
プは 1 個以上の `AbductiveAssume` ステップを参照し、残差
仮説を宣言する。チェッカは連鎖を走査し、指名された仮説を
法として判定が通ることを確認する。

== 古典公理の衛生

第 2 章のカーネルは*最小*である — 排中律、Peirce 律、その
他古典的に妥当だが直観主義的には妥当でない原理は組み込ま
ない。ソルバのステップがそうした公理に依存する場合、それ
は当該公理とそのインスタンス化を名指す `ClassicalAxiom`
ステップとして記録されなければならず、プリアンブルでもそ
の公理が `classical-axioms` ブロックで宣言されなければな
らない。

下流の消費者(とりわけ ITP)はしばしば強い選好を持つ。例
えば構成的な Lean 4 モジュールは、たとえ証明書が内部的に
妥当であっても、`lem` を名指す証明書を拒否することがある。
プリアンブル宣言は、消費者が各ステップを走査せずとも、パ
ース時点で証明書を受理するかを判断できるようにする。

== リフレクション・ブリッジ

記録された証明書は ITP リフレクション層(第 10 章)への
入力となる。`adsmt-cert::prover_emit::lean`、`::rocq`、
`::isabelle` は `Cert` を対象 ITP の表層構文へ下ろし、各
ステップ種が特定のタクティク呼び出しや項コンストラクタへ
対応付けられる。

リフレクションには独自の正当性上の懸念がある — 「adsmt 判
定 $->$ 証明書 $->$ ITP で検査された証明」という*連鎖全体*
の健全性は、リフレクション層が各ステップを忠実に翻訳する
ことを要する。その機構について次章で考察する。
