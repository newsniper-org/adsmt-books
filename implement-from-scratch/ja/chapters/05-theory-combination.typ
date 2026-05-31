= 理論結合

== 結合問題

算術と配列演算を混合する SMT 論理式を考える。

$ a[i] + a[j] > 0 and a[i] = -a[j] and i != j $

純粋な算術ソルバも純粋な配列ソルバも，これを単独では判定できない。
算術ソルバは `a[i]` をどう解釈すべきか知らない——不透明な変数として見る。
配列ソルバは `+` をどう解釈すべきか知らない——*`i = j` ならば `a[i] = a[j]`* といったことは導出できるが，
どちらが何に和をなすかは分からない。
この形の論理式を判定するには，両方のソルバが*協調*する必要がある。
すなわち，各々が*共有変数*について学んだ情報を相手と共有し，
矛盾が現れるか，あるいは結合モデルが存在するまで続ける。

これが*理論結合*問題である。
古典的な解は*Nelson-Oppen*結合であり，
関与する理論が*安定的に無限*（stably infinite）であり，互いに素な署名を持つときに適用できる。
adsmt は*polite 結合*（polite 結合）と呼ばれる一般化を用いる。
これはわずかに多くの機構を追加する代償に，互いに素な署名の要件を取り除く。

== Nelson-Oppen 概観

Nelson-Oppen プロトコルは参加する理論ソルバを歩調を揃えて走らせる。
共有変数とは，二つ以上の理論によって処理されるアトムに現れる変数である。
各理論は次を行う。

#enum(numbering: "(1)",
  [自身が解釈可能なあらゆる主張されたアトムを受け取る。],
  [自身が導出した共有変数間の等式を報告する。],
  [他の理論が導出した等式の合併を受け取る。],
  [次のいずれかが起こるまで反復する。すなわち (a) `false` を導出する（充足不能），
   または (b) 新たな等式が浮上しなくなる（結合における充足可能）。],
)

このプロトコルの正当性は安定的無限条件に依存する。
すなわち，各理論の各モデルは単独で，各ソートにおいて無限個の要素を持つよう拡張できる。
両理論が有限モデルのみを生成する場合，追加の濃度推論が必要となる。

== polite 結合

polite 結合（polite 結合）は互いに素な署名の要件を取り除き，
濃度推論を明示的に扱う。
各理論は，ソートごとに，モデルの濃度に対して課す上界（存在すれば）を記述する*politeness 証拠*を公開する。
たとえば `BV<8>` ソートは高々 $2^8 = 256$ の濃度を持ち，
`Int` ソートは $omega$ を持つ。
結合機構は参加するすべての理論を通じて*下限*（infimum）を取り，
結合モデルがそのソートで高々その個数の要素を持つことを主張する。

具体的には各理論は次を実装する。

```rust
pub trait Theory: Send {
    fn name(&self) -> &'static str;
    fn handles_sort(&self, ty: &Type) -> bool;
    fn assert(&mut self, lit: Literal) -> AssertResult;
    fn check(&mut self) -> CheckResult;
    fn explain(&self) -> Option<TheoryWitness>;
    fn derive_equalities(&self) -> Vec<(Term, Term)>;
    fn derive_disequalities(&self) -> Vec<(Term, Term)>;
    fn cardinality_witness(&self, sort: &Type) -> PoliteWitness;
    fn push(&mut self);
    fn pop(&mut self, levels: u32);
    fn reset(&mut self);
}
```

結合オーケストレータ（`adsmt-theory::polite::Combination`）は `Vec<Box<dyn Theory>>` を所有し，
プロトコルを駆動する。

```rust
pub fn check(&mut self) -> CombinedCheck {
    loop {
        // 1. Per-theory check.
        for t in &mut self.theories {
            match t.check() {
                CheckResult::Unsat { witness } => return Unsat { ... },
                CheckResult::Unknown { reason } => return Unknown { ... },
                CheckResult::Sat => continue,
            }
        }
        // 2. Gather derived equalities.
        let new_eqs = self.gather_derived_equalities();
        if new_eqs.is_empty() {
            // 3. Cardinality enforcement.
            if let Some(unsat) = self.enforce_cardinality() {
                return unsat;
            }
            return Sat;
        }
        // 4. Re-broadcast new equalities.
        for (a, b) in new_eqs { self.assert(Literal::positive(mk_eq(a, b))?); }
    }
}
```

ループが収束するのは，各ラウンドが異なる同値類の個数を減らすか，新たな情報を生成しないかのいずれかであるためである。

== 濃度の強制

結合証拠が有限濃度上界 $n$ を課す各ソート $sigma$ について，
オーケストレータは $sigma$ で主張された不等式を集め，不等式グラフ上の最大クリークを計算する。
クリークサイズが $n$ を超えるなら，結合モデルは $sigma$ で要素が多すぎる——矛盾である。

```rust
fn enforce_cardinality(&self) -> Option<CombinedCheck> {
    let diseqs_by_sort = self.gather_disequalities_by_sort();
    for (sort, pairs) in &diseqs_by_sort {
        let bound = self.cardinality_bound(sort);
        let Some(bound) = bound else { continue; };
        let clique = max_disequality_clique(pairs, bound + 1);
        if clique > bound {
            return Some(CombinedCheck::Unsat { /* polite witness */ });
        }
    }
    None
}
```

`max_disequality_clique` は，現在の最大値が境界を超えたら早期離脱する境界付きクリーク列挙である。
実際の探索空間は十分小さく，総当たりで足りる。

== リテラルの理論への振り分け

すべてのリテラルがすべての理論に関係するわけではない。
結合は，どの理論がどのリテラルを見るべきかを，被演算子のソートを調べて決定する。
等式リテラル `(= a b)` は `a.type_of()` を処理するあらゆる理論に振り分けられる。
非等式リテラル（理論固有の述語，たとえば `(> x y)`）はその述語を所有する理論に振り分けられる。

```rust
pub fn assert(&mut self, lit: Literal) -> Vec<(String, AssertResult)> {
    let routing_sort = if let Some((a, _)) = lit.term.dest_eq() {
        a.type_of()
    } else {
        lit.term.type_of()
    };
    let mut out = Vec::new();
    for t in &mut self.theories {
        if t.handles_sort(&routing_sort) {
            out.push((t.name().to_string(), t.assert(lit.clone())));
        }
    }
    out
}
```

ある理論での衝突はブロードキャストを短絡し，即座にリターンする。
adsmt がこの最適化を明示的に着地させたのは，
当初の草案ではある理論が実行不可能性を報告した後でもすべての理論に主張を続けてしまっていたからである。

== push と pop

SAT 層は決定とバックトラックを駆動する。
各主張は SAT 層が当該主張を導入した決定を越えてバックトラックすると取り消す必要がある。
結合はあらゆる理論に同じ操作をブロードキャストする `push` / `pop` 操作を支援する。

```rust
pub fn push(&mut self) {
    for t in &mut self.theories { t.push(); }
}
pub fn pop(&mut self, levels: u32) {
    for t in &mut self.theories { t.pop(levels); }
}
```

各理論は独自のスナップショット方式を実装する。
たとえば UF は union-find 構造をスナップショットし，
LIA は境界表を，配列は局所不等式表と保留中の外延性キューをスナップショットする。
パターンは一様である。各理論はスナップショットの `scope_stack` を所有し，`pop` で復元する。

== エンジン側の振り分け

`adsmt-engine` では関数 `dpllt::run_once` が単一イテレーションを駆動する。
すなわち，リテラル → 結合への主張 → 結合のチェック，である。
早期衝突の短絡はループに見える。

```rust
pub fn run_once(combo: &mut Combination, literals: &[(Term, bool)]) -> LoopOutcome {
    for (atom, polarity) in literals {
        let lit = build_lit(atom, *polarity);
        for (name, r) in combo.assert(lit) {
            if let AssertResult::Conflict { witness } = r {
                return LoopOutcome::Unsat { theory: name, witness };
            }
        }
    }
    match combo.check() {
        CombinedCheck::Sat => LoopOutcome::Sat,
        CombinedCheck::Unsat { theory, witness } => LoopOutcome::Unsat { theory, witness },
        CombinedCheck::Unknown { theory, reason } => LoopOutcome::Unknown { theory, reason },
    }
}
```

これは SAT 層と理論層が通信するレベルである。
SAT 層は `run_once` に，現在のトレイルと整合するリテラルのリストを与える。
`run_once` は理論が同意するかどうか，そうでないならどの証拠を生成したかを報告する。

== オプションの追加 — EGraph

adsmt の `adsmt-theory::egraph_theory` は EUF e-グラフを `Theory` トレイトの内側に包む。
e-グラフはハッシュコンシングされた項宇宙と，
*合同閉包*で拡張された union-find 構造を保つ。
$a$ と $b$ が同じ同値類にあり二つの関数適用 $f(a)$ と $f(b)$ が観察されると，
ラッパは $f(a)$ と $f(b)$ も併合する。
カスケードは不動点まで発火し，合同閉包された等式を生成して `derive_equalities` から公開する。

これは*加法的*である。UF と EGraph はどちらも並存して登録できる。
EGraph は UF が直接的なリテラル対の入力でしか気付けない合同な関数適用を提供する。

== まとめ

理論結合は SMT ソルバを SAT ソルバから区別する層である。
プロトコル——polite または Nelson-Oppen——はソルバ構成要素間にわたる定義済みの協調アルゴリズムであり，
各構成要素は小さく監査可能である。次章では個別の理論ソルバを順に見ていく。
