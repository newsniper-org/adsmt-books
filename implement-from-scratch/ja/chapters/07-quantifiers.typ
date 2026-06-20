= 量化子

== なぜ量化子は難しいか

第 6 章の理論はいずれも*基底*（ground）アトム——論理式中に全称量化子も存在量化子もない——を仮定していた。
量化子を加えれば充足可能性問題は一般には決定不能となる。
任意の一階論理式に対して常に正しい答えを返すアルゴリズムは存在しない。

代わりに SMT ソルバが行うのは*ヒューリスティックなインスタンス化*である。
全称論理式 $forall x. phi(x)$ が主張され，論理式の残り部分が具体的な基底項を生成しているとき，
それらの基底項を候補のインスタンス化として $phi(x)$ に差し込み，基底アトムとして追加する。
これは内側のソルバループの仕事を変える。それが見るのは元の量化された論理式ではなく，
増え続けるインスタンス化の山である。*どの*項を*どの順序で*代入するかという問いが，問題の核心となる。

== E-マッチング

支配的な技法は*E-マッチング*である。
考え方は次の通りである。論理式 $forall x. phi(x)$ には*トリガ*——束縛変数 $x$ を含む $phi$ の部分パターン——が注釈される。
論理式の基底部分がトリガに（等式推論を法として）合致する項を生成するとき，
合致した部分項に $x$ をインスタンス化する。

たとえば $forall x. f(g(x)) > 0$ にトリガ $f(g(x))$ が付与され，
基底項 $f(g(a))$ が既に視野にあるなら $x := a$ をインスタンス化する。
インスタンス化されたアトム $f(g(a)) > 0$ は SAT/理論層に加わる。

```rust
pub struct Trigger {
    pub kind: TriggerKind,
    pub bound: Vec<Arc<Var>>,
}
pub enum TriggerKind {
    Single(Term),
    Multi(Vec<Term>),
}
```

マッチャは*項宇宙*——論理式中に現れる基底部分項の集合——を歩いて合致を探す。
単一パターンのトリガは，パターンの剛直部分（定数とトリガの可変集合にない束縛変数）が一致し，
可変部分が代入を取り出すとき，宇宙の項に合致する。

```rust
fn match_one(pattern: &Term, target: &Term, bound: &[Arc<Var>])
    -> Option<Vec<(Arc<Var>, Term)>>
{
    let mut sigma = IndexMap::new();
    if extend_match(pattern, target, bound, &mut sigma) {
        Some(sigma.into_iter().collect())
    } else { None }
}
```

== Miller パターン

*Miller パターン*とは，すべての可変部分適用が $F(x_1, dots, x_n)$ の形（$x_i$ は相異なる束縛変数）を持つトリガパターンである。
Miller パターンは高階単一化の病理を伴わない線形時間のマッチングアルゴリズムを許す。
adsmt は既定で Miller パターンを用い，
利用者がそれにもかかわらず非 Miller パターンを欲する正当な理由を持つ場合のためのエスケープ `:trigger!` を公開する。

== Tier エスカレーション

E-マッチングはインスタンス化を一切見つけられない可能性がある。
すなわち，宇宙にトリガの形状の項が含まれていないかもしれない。
adsmt は一連の*Tier*を辿ってエスカレートする。各 Tier は前のものより積極的である。

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Tier*], [*戦略*]),
  [1], [項宇宙に対する Miller E-マッチング。],
  [2], [衝突駆動インスタンス化——既存の基底主張と矛盾するインスタンス化を選ぶ。],
  [3], [境界付き列挙——深さ予算まで候補部分項を列挙する。],
  [4], [アブダクティブ・エスカレーション——量化された論理式をアブダクティブな候補仮説として放出する（第 8 章）。],
)

```rust
pub fn instantiate_with_tier(var, body, universe) -> (Vec<Term>, Tier) {
    let res = instantiate_one(var, body, universe);
    if !res.is_empty() {
        return (res, Tier::One);
    }
    let res = enumerate(var, body, universe, DEFAULT_TIER3_BUDGET);
    if !res.is_empty() {
        return (res, Tier::Three);
    }
    (Vec::new(), Tier::Exhausted)
}
```

Tier 2（衝突基準）と Tier 4（アブダクティブ）は隣接層からの情報を要する。Tier 4 は第 8 章で扱う。

== トリガ学習

手で選ばれたトリガは利用者の責任であるが，何も与えられないとき，
adsmt の `learn_triggers` ヘルパは被覆集合を自動的に選ぶ。
アルゴリズムは本体の適用部分項を深さ順に走査し，
すべての可変変数を覆う最小のパターンを貪欲に選ぶ。

```rust
pub fn learn_triggers(body: &Term, flex: &[Arc<Var>]) -> Option<Trigger> {
    let mut candidates = Vec::new();
    collect_apps(body, &mut candidates);
    candidates.sort_by_key(term_depth);
    let mut covered = HashSet::new();
    let mut selected = Vec::new();
    for cand in candidates {
        let cand_flex = flex_vars_in(&cand, flex);
        if cand_flex.iter().all(|v| covered.contains(v)) { continue; }
        for v in &cand_flex { covered.insert(v.clone()); }
        selected.push(cand);
        if covered.len() == flex.len() { break; }
    }
    if covered.len() != flex.len() { return None; }
    if selected.len() == 1 {
        Some(Trigger::single(selected.pop().unwrap(), flex.to_vec()))
    } else {
        Some(Trigger::multi(selected, flex.to_vec()))
    }
}
```

被覆は，成功した任意の E-マッチがあらゆる可変変数をインスタンス化することを保証する。
深さ順の貪欲は，小さく頻繁にマッチするパターンを先に選ぶ傾向のあるヒューリスティクスである。

== E-グラフ

純粋な E-マッチャは平坦な `TermUniverse` を走る。
より高度な代替が*E-グラフ*である。
E-グラフはハッシュコンシングされた項格納と合同閉包の拡張を保ち，
明示的な宇宙の項のみならず，あらゆる*導出された合同な*項をも公開する。

```rust
pub struct EGraph {
    nodes: Vec<ENode>,
    parent: Vec<ENodeId>,
    class_parents: HashMap<ENodeId, Vec<ENodeId>>,
    hash_cons: HashMap<ENodeKey, ENodeId>,
    scope_stack: Vec<EGraphSnapshot>,
}
```

`add` は項をグラフに下ろし，その同値類 id を返す。
`merge` は二つの同値類を統一し，合同閉包をカスケードする。
二つの親 E ノードの子が同値になると親も併合される。
`as_universe` はグラフを平坦な `TermUniverse` へと射影し直して E-マッチャに渡せるようにする。

E-グラフ統合は完全性を買う。
すなわち，E-グラフの合同閉包が平坦な宇宙が見逃したトリガ合致を生成する場合，E-グラフはそれを捉える。

adsmt では，ベンダリングされた OxiZ バックエンドがこの合同を意識したマッチングを_既定_とし，
それを _CCFV_——自由変数を伴う合同閉包（congruence closure with free variables），Barbosa–Fontaine–Reynolds の E-基底（非）単一化に基づく——と呼ばれる単一の統合された中核として実現する。
トリガは基底合同を_法として_合致する。すなわち，パターン $f(g(x))$ は，$c$ と $g(a)$ が合同である限りつねに基底項 $f(c)$ に対して発火する。これはまさに平坦な宇宙上の構文的走査が見逃す合致である。
モデル補完エンジン——モデルを構築することで `sat` と答え得るエンジン——にとって，これは完全性の獲得であるだけでなく_健全性_の要件でもある。そのような合同合致を見逃せば，エンジンは，実際には `unsat` である問題において，合同を見ない盲目的なモデルを `sat` として証明してしまう。
同じ CCFV 中核は，衝突駆動インスタンス化とモデル補完探索をも表現する。両者が異なるのは，解く制約と，実際の合同を読むか既定拡張された全体ビューを読むかだけである。

== エンジンループにおける量化子インスタンス化

エンジンの `check_sat` ループは，連続する基底フラグメント検査の間に量化子インスタンス化を実行する。

```rust
const QUANTIFIER_ROUNDS: usize = 3;
let mut instantiations: Vec<Term> = Vec::new();
for round in 0..QUANTIFIER_ROUNDS {
    let mut combined = self.all_literals();
    for inst in &instantiations { combined.push((inst.clone(), true)); }
    match self.check_ground(&combined) {
        SatResult::Sat => {
            let (quants, rest) = partition_quantifiers(&combined);
            if quants.is_empty() { return SatResult::Sat; }
            let universe = collect_universe(&rest);
            for (var, body) in &quants {
                for inst in instantiate_one(var, body, &universe) {
                    if !instantiations.iter().any(|t| t.alpha_eq(&inst)) {
                        instantiations.push(inst);
                    }
                }
                // Tier 2 and Tier 3 fallback...
            }
            if instantiations.len() == prev_len { return SatResult::Sat; }
        }
        other => return other,
    }
}
// Tier 4 — abductive escalation
return SatResult::Abductive { candidates: build_tier4_candidates(...) };
```

各ラウンドは新たなインスタンス化を加え得る。
確定的判定が現れるか，新たなインスタンス化が現れなくなるか（Sat），ラウンド予算が尽きるまで
（Tier 4 のアブダクティブ・エスカレーション）ループは継続する。

== なぜこれが「ベストエフォート」なのか

Tier エスカレーション付き E-マッチングは*ヒューリスティクス*である。
インスタンス化が存在する場合でも，論理式を解消するインスタンス化を見つけ損ねる可能性がある。
SMT ソルバ一般がこの取引を受け入れる。
代替——量化子の完全な扱い——は理論結合と両立しないか，使えないほど高価かのいずれかである。

adsmt が加えるのは Tier 4 の脱出口である。
あらゆる項レベルのヒューリスティクスが尽きたとき，量化子は*アブダクティブな候補*となる。
利用者が見るのは「unknown」ではなく
「この仮説を受け入れていただければ解けます」である。
その仮説とは特定の証拠の単なる存在主張であり，
それを受け入れれば証明は通り，利用者（または下流の ITP）がその仮定が適切かどうかを決めることができる。

次にそのアブダクティブ層へと話を進める。
