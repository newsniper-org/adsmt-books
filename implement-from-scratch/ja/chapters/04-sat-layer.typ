= SAT 層

== アーキテクチャ

SAT 層の仕事は，命題 CNF 論理式に対する充足割り当てを見つけること，
あるいはそのような割り当てが存在しないことを証明することである。
ソルバの残りの部分との契約は狭い。
入力は `Vec<Clause>` であり，各節は `Vec<(atom, polarity)>` であり，
出力は三つの判定——`Sat`，`Unsat`，`Unknown`——のいずれかである。
`Sat` の経路では充足割り当てが理論側の検証のために利用可能である。

adsmt は三つの SAT バックエンドを同梱する。
すなわち OxiZ（純粋 Rust の CDCL ソルバ，デフォルト），CaDiCaL（FFI 越しの C++ CDCL ソルバ），
そして `adsmt-engine::cdcl` 内の組み込みフォールバックである。
フォールバックは機能フラグなしのビルドが自己完結となるように存在する。
本番ビルドは OxiZ を用いる。本章は組み込み CDCL 実装が何をするかを順に述べる。
同じアーキテクチャはどちらの外部バックエンドにも適用される。

== CDCL アルゴリズム概観

Conflict-Driven Clause Learning はバックトラッキングに基づく命題探索の上に座っている。
基本ループは次の通りである。

#enum(numbering: "(1)",
  [現在の部分割り当てを，これ以上単位節由来の割り当てが不可能になるまで伝播する。],
  [伝播が衝突を生じた（ある節が偽化された）場合，衝突解析を行う。
   含意グラフを遡って，衝突の理由を捉える*学習節*を見つける。
   学習節を論理式に追加し，それが伝播するレベルへバックジャンプする。],
  [そうでなく，すべての変数が割り当て済みであれば `Sat` を返す。],
  [そうでなければ決定変数を選び（ヒューリスティクスがどれにするかを決める），それに値を割り当ててループする。],
)

二つの本質的な構成要素は*伝播*（ステップ 1）と*衝突解析*（ステップ 2）である。
決定ヒューリスティクス（ステップ 4）と再開方針は二次的な最適化であるが，
実際のソルバ性能に対し過剰なほど大きな影響を及ぼす。

== 監視リテラル (two-watched literals)

素朴な伝播器は各割り当て時にすべての節を反復し，各節が単位節になっているかを検査する。
$n$ 節，平均 $k$ リテラルとすると，これは割り当て当たり $O(n k)$ の費用がかかる。
two-watched-literals 方式はその償却費用を劇的に削減する。

観察は次の通りである。節が単位節になるのは，
そのリテラルのうち一つを除くすべてが偽に割り当てられたときに限る。
したがって我々は，現在監視されているリテラルのいずれかが偽になったときにのみその節を検査する必要がある。
節ごとに任意の二つのリテラルを「監視」に選び，
各リテラルからそれを監視する節への逆引きを保つ。
新たな割り当てごとに，その否定を監視する節のみを検査する。

そのような節を検査するとき，次のいずれかが起こる。

- 監視可能な別の非偽リテラルを見つける（費用：節のリテラル列の $O(k)$ 走査）。
- もう一方の監視リテラルが充足されている（節は問題なし。スキップ）。
- もう一方の監視リテラルが未割り当てである（節は単位節，伝播）。
- もう一方の監視リテラルが偽である（衝突）。

データ構造は単純である。

```rust
pub struct CdclState {
    pub trail: Vec<TrailEntry>,
    pub assign: HashMap<String, bool>,
    pub clause_watches: Vec<[usize; 2]>,
    pub watches: HashMap<(String, bool), Vec<usize>>,
    pub prop_head: usize,
    // … learnt-clause storage, activity tables, etc.
}
```

`prop_head` カーソルはトレイル上を一リテラルずつ進む。
新たなトレイルエントリごとにその*否定*を `watches` で引き，それらの節のみを検査する。

== 衝突解析 — 1-UIP

節が偽化されると伝播器はそのインデックスを返す。
衝突解析は含意グラフ（トレイル，各エントリの `reason` が伝播させた節を指す）を遡って，
*もし最初から存在していたならこの衝突を防いだ*ような*学習節*を見つける。

標準アルゴリズム——「1-UIP」——は，衝突節を現在の決定レベルのリテラルの前件と解決していき，
現在の決定レベルにちょうど一つのリテラルが残るまで進めることによって学習節を生成する。
その一つのリテラルが*最初の唯一含意点*（first unique implication point）である。
得られる節が学習節であり，*他の*リテラルの中の最大決定レベルが*バックジャンプレベル*——巻き戻す先のレベル——となる。

コード（概略）は次の通りである。

```rust
fn analyze_1uip(clauses, state, conflict_idx) -> (Vec<Lit>, u32) {
    let current = state.decision_level;
    let mut seen = HashSet::new();
    let mut learnt = Vec::new();
    let mut count_current = 0;
    // Seed from the conflict clause.
    for lit in &clauses[conflict_idx] {
        process(lit, ...);
    }
    // Walk the trail backwards, resolving each current-level
    // seen literal against its antecedent.
    let mut idx = state.trail.len();
    while count_current > 1 {
        idx -= 1;
        // ...
    }
    // Recover the UIP and the backjump level.
    // ...
}
```

完全な実装は adsmt の `cdcl.rs` でおよそ 100 行である。
トレイル基盤が整いさえすれば，あとは機械的である。

== VSIDS — 変数活動度

2001 年の Chaff ソルバ以来 CDCL を支配してきた決定ヒューリスティクスが*VSIDS*——
variable state independent decaying sum である。
各アトムは活動度スコアを持つ。あらゆる衝突は学習節中のアトムの活動度を加算する。
周期的にあらゆるスコアに減衰係数（典型的には 0.95）が掛けられ，
最近の加算が古いものを支配するようになる。

```rust
pub fn bump_activity(&mut self, clause: &Clause, bump: f64) {
    for lit in clause {
        *self.activity.entry(atom_key(lit)).or_insert(0.0) += bump;
    }
}
pub fn decay_activity(&mut self, factor: f64) {
    for v in self.activity.values_mut() { *v *= factor; }
}
```

決定選択器は開かれた節を走査し，未割り当てかつ活動度最大のアトムを選ぶ。
加算 + 減衰サイクルにより，これは「いま当たっている衝突に関わっているアトムはどれか？」の強い代理指標となる。

== 再開と Luby

CDCL は周期的な再開——現在の決定履歴を忘れて最上位レベルの事実から探索を再開すること——から恩恵を受ける。
スケジュールが重要である。純粋な幾何的再開（$2^k$ 衝突ごと）は，
短期予算エポックを繰り返し訪問する列に比べて性能が劣る。
*Luby 列*——$1, 1, 2, 1, 1, 2, 4, 1, 1, 2, 1, 1, 2, 4, 8, dots$——は，
ランダム化された SAT インスタンスで経験的に勝つ。

Luby の反復は Knuth の reluctant-doubling 公式であり，10 行に収まる。

```rust
fn luby_index(i: usize) -> usize {
    let mut u = 1usize;
    let mut v = 1usize;
    for _ in 0..i {
        if (u & u.wrapping_neg()) == v { u += 1; v = 1; }
        else { v *= 2; }
    }
    v
}
```

外側の CDCL ループは `epoch = 0, 1, 2, ...` について
`cdcl_solve(clauses, base_conflicts * luby_index(epoch))` を呼び，
確定的判定が現れるか再開予算が尽きるまで継続する。

== 学習節管理

すべての学習節を永続的に保持するとメモリが膨張し伝播が遅くなる。
標準的な対処は，最も役に立たない学習節を周期的に削除することである。
「有用」は節ごとの活動度スコア
（伝播器がその節を単位前件として利用するたびに加算される）と*LBD*（Literal Block Distance）
——節を学習した瞬時にその節のリテラル中の異なる決定レベルの個数——で測られる。
低 LBD の節（「グルー節」，LBD ≤ 6）は削除から保護される。残りは周期的な間引きの対象となる。

```rust
fn reduce_learnt(state, owned, input_len, threshold) {
    // Keep glue clauses unconditionally.
    let mut candidates: Vec<_> = state.learnt_activity.iter()
        .enumerate()
        .filter(|(i, _)| state.learnt_lbd[*i] > 6)
        .collect();
    candidates.sort_by(|a, b| a.1.partial_cmp(b.1).unwrap());
    // Drop the lowest-activity half.
    // ...
}
```

== 全体を組み合わせる

CDCL ソルバは上述の機構をすべて含めて約 800 行に収まる。
adsmt の `cdcl.rs` はおよそこの規模であり，
注意深い読者は主ループを 1 時間以内にステップ実行できる。
最も重要な規律は*明示的な理由タグ付きのトレイル基盤伝播*である。
トレイルと理由の構造が正しくなりさえすれば，他のあらゆる要素は所定の位置に収まる。

次章は理論結合へと舵を切る。
これは SAT の上位にあり，複数の専門化された理論ソルバが共有ソートの上で協調できるようにする層である。
