= アブダクティブ層

== アブダクション vs 演繹

古典的な SMT は純粋に*演繹的*である。すなわち、論理式 $phi$
が与えられたとき、「$phi$ は充足可能か?」に答える。その答え
は判定 — Sat、Unsat、または Unknown — であり、場合により
証拠モデルや unsat コアが付随する。

*アブダクション*はその双対の問いである。ソルバが消化*でき
ない*論理式 $phi$ が与えられたとき、$phi$ を証明可能にする
ためにはどのような追加仮説 $H$ が必要かを問う。具体的には、
$H union phi$ が unsat となる($phi$ がゴールの否定を表す
場合)か、$H union phi'$ が sat となる($phi'$ がゴールを
直接表す場合)ような最小の $H$ を求める。

```rust
pub struct AbductiveCandidate {
    pub hypothesis: Vec<Term>,
    pub justification: Justification,
    pub rank: Rank,
}
pub enum Justification {
    SldChain(Vec<HornStep>),
    TheoryGap { theory: TheoryName, missing: Term },
    QuantifierExhausted { var: Arc<Var>, body: Term },
}
```

SMT-as-proof-assistant — adsmt が中心的に想定するユース
ケース — においては、アブダクティブ候補こそソルバが生成し
うる最も実用的な出力である。ユーザ(あるいは ITP のタクテ
ィク)は「これは真か?」を問うているのではなく、「証明を通
すには何を仮定すればよいか?」を問うている。第 7 章で見た
Tier 4 のエスカレーションは、それらの候補を直接表面化す
る。

== Horn 規則と SLD チェーン

アブダクションを扱う最も明快な舞台は *Horn 節* — 高々 1
つの正リテラルを持つ節 — である。Horn 規則
$p_1 and p_2 and dots and p_n -> q$ は「$p_i$ がすべて成
り立つならば $q$ が成り立つ」を意味する。*事実*とは $n = 0$
の Horn 規則、すなわち $q$ そのものである。

Horn 規則ベース $R$ とゴール $G$ が与えられたとき、*SLD
チェーン*とは、$G$ を、いかなる規則の頭部とも単一化できな
い原子サブゴールへ縮約する後ろ向き連鎖の有限列である。残
された原子サブゴールが*アブダクティブ仮説*である。それを
仮定すれば、ゴールは通る。

```rust
pub fn build_chain(goal: &Term, rules: &[HornRule], depth: usize)
    -> Option<SldChain>
{
    if depth == 0 { return None; }
    for rule in rules {
        if let Some(sigma) = unify(&rule.head, goal) {
            let mut sub_chains = Vec::new();
            let mut residual = Vec::new();
            for body_atom in &rule.body {
                let atom = apply(&sigma, body_atom);
                match build_chain(&atom, rules, depth - 1) {
                    Some(sub) => sub_chains.push(sub),
                    None => residual.push(atom),
                }
            }
            return Some(SldChain {
                steps: vec![HornStep { rule: rule.clone(), sigma }],
                sub_chains,
                residual,
            });
        }
    }
    None
}
```

残差原子(residual)は、我々が単一化で消し去れなかったも
のである。それらがアブダクティブ仮説となる。

== 最小化

最初の SLD チェーンは滅多に最小ではない。素朴な後ろ向き
連鎖器は、たとえ一部が冗長(他のもの、あるいは背景理論の
公理によって含意される)であっても、未解消のサブゴールを
すべて溜め込む。adsmt の `minimize` パスは残差を走査する。

```rust
pub fn minimize(residual: &[Term], ctx: &TheoryContext) -> Vec<Term> {
    let mut keep: Vec<Term> = Vec::new();
    for atom in residual {
        if entailed_by(atom, &keep, ctx) { continue; }
        keep.retain(|kept| !entailed_by(kept, &[atom.clone()], ctx));
        keep.push(atom.clone());
    }
    keep
}
```

`entailed_by` は能動的な理論文脈 — UF の合同、算術の境界、
BV のリテラル評価 — を参照し、冗長な原子を消去する。残っ
たリストが、能動的な理論の下での最小被覆である。

== ランキング

複数の異なる最小仮説が同じゴールを消化しうる。`rank` は
候補を*ユーザコスト*の代理指標 — 原子の数が少ないものが
優先、原子がより単純なものが優先、新規ではなく既にスコー
プに存在する原子が優先 — で順序付ける。

```rust
pub fn rank(candidates: &mut Vec<AbductiveCandidate>, in_scope: &HashSet<Term>) {
    candidates.sort_by_key(|c| (
        c.hypothesis.len(),
        c.hypothesis.iter().map(term_depth).sum::<usize>(),
        c.hypothesis.iter().filter(|t| !in_scope.contains(*t)).count(),
    ));
}
```

ユーザは生の集合ではなく順位付けされたリストを見る。Lean4
の `smt_abduce` タクティクおよび LSP のコードアクションメ
ニューは、いずれもこの順序を尊重する。先頭候補が推奨仮説
で、残りはユーザが選択できる代替案である。

== ワークフロー統合

エンジンの `check_sat` ループ内では、アブダクションは
*ギャップ* — グラウンド推論、理論結合、量化子インスタンス
化が確定的な判定に届かない地点 — によって駆動される。

```rust
pub enum SatResult {
    Sat(Model),
    Unsat(UnsatCore),
    Abductive { candidates: Vec<AbductiveCandidate> },
    Unknown(UnknownReason),
}

fn abductive_escalation(state: &SolverState) -> Vec<AbductiveCandidate> {
    let mut out = Vec::new();
    if let Some(quant_gap) = state.exhausted_quantifier() {
        out.push(quantifier_to_candidate(quant_gap));
    }
    if let Some(theory_gap) = state.theory_unknown() {
        out.push(theory_gap_to_candidate(theory_gap));
    }
    if !out.is_empty() { return out; }
    let goal = state.current_goal();
    let chains = build_chains_with_horn_base(&goal, state.horn_rules(), MAX_DEPTH);
    chains.into_iter()
        .map(|chain| chain_to_candidate(chain, state.theory_context()))
        .collect()
}
```

4 種類のギャップ分類 — 量化子枯渇、理論未確定、Horn チェ
ーン残差、古典公理要求 — は、いずれも同じ返り値経路に候補
を供給する。呼び出し側は単一の同質な `AbductiveCandidate`
リストを得て、それを提示する。

== Tier 4 — 候補を証明書へ昇格する

ユーザ(あるいは ITP のタクティク)は、アブダクティブ候補
の仮説原子を表明集合に加えることでそれを受理する。再度の
`check_sat` では、それらの原子は今やグラウンドな仮定とな
り、候補を生んだチェーンが完結し、ソルバは確定的な判定を
出力する。

証明書形式(第 9 章)は、アブダクティブな受理を明示的に
記録する。

```text
(cert.v1
  (steps
    (step :rule abductive_assume
          :id 17
          :hypothesis ((P a) (Q b))
          :justification (sld_chain ...))
    ...))
```

下流の ITP — Lean 4、Rocq、Isabelle — は、このステップを
明示的な `sorry` 形のプレースホルダ、すなわち仮説に*条件
付けられた*証明として見る。その仮説はユーザが別手段で消化
すべき義務として表面化する。リフレクション層(第 10 章)
は、各 `abductive_assume` を、ユーザが導入できる名前付き
仮説に変換した ITP フレンドリーなタクティクスクリプトと
して、証明書を描画する。

== アブダクションが穏やかに劣化するとき

E-マッチング、理論閉包、アブダクティブ連鎖のいずれも有用
な候補を生まなかった場合、ソルバは
`Unknown(UnknownReason::AbductiveExhausted)` を返す。これ
は通常の SMT における `unknown` よりも厳密に情報量が多い。
すなわち、呼び出し側は、何らかの上流層が予算上限に達した
のではなく、アブダクティブ層が試みた上でアイデアを使い果
たしたことを知ることができる。

対話的定理証明系にとって、「unknown だが、試して破棄した
仮説候補 15 個をここに示す」というのは、それ自体が有用な
デバッグ出力である。`UnknownReason::AbductiveExhausted`
バリアントは試行ログを保持し、LSP は「アブダクティブ・ト
レースを表示」コードアクション付きの診断としてそれを表面
化する。

== なぜこれが SMT-as-tactic にとって重要か

従来の SMT-as-tactic は二値判定を証明アシスタントに渡す。
うまくいけばよい。うまくいかない場合、ユーザに実用的なフ
ィードバックはない。アブダクティブ候補はこの構図を変える。
*失敗*した消化からも、ユーザが受理するか、あるいはゴール
を精緻化するために使える具体的な仮説が得られる。

これが adsmt をそもそも構築する動機である。「演繹的判定
のみ」のモードは結構である — adsmt はそれを任意の SMT ソ
ルバと同等にうまく行う — が、*アブダクティブ・エスケープ*
こそ、既存のソルバをラップするのではなく新たなソルバを構
築する理由である。第 9 章では、アブダクティブ・ステップを
下流の ITP において回復可能にする証明書の機構を述べる。
