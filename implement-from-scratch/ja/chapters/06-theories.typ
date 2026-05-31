= 個別の理論

本章では adsmt が同梱する各理論を，おおよそ実装複雑度の昇順に順に見ていく。

== 解釈されない関数 (UF)

最も単純な理論である。UF は解釈されない関数記号と定数上の等式と不等式を主張する。
$ f(a) = b, quad a = c, quad b != f(c) $

自然なデータ構造は項上の*union-find*であり，*合同閉包*で拡張される。
$a = c$ が union-find に入ったとき，構造は $f(a)$ と $f(c)$ も併合せねばならない
（さらに再帰的に，それらに基づく大きい項についても同様である）。

```rust
pub struct Uf {
    parent: HashMap<Term, Term>,        // union-find pointer
    rank: HashMap<Term, usize>,         // for rank-based union
    diseqs: Vec<(Term, Term)>,          // asserted disequalities
    scope_stack: Vec<UfSnapshot>,
}
```

`assert(t1 = t2)` は `union(t1, t2)` を呼ぶ。
`assert(t1 != t2)` はまず `find(t1) == find(t2)` をチェックし（即座の衝突），そうでなければ対を記録する。
`check()` は現在の find ルートに対して不等式走査を再度実行する。

合同：同値類ごとに*親項*のリスト——その同値類の代表元のいずれかを引数に持つ適用のリスト——を保持する。
各 union の後，両同値類の親リストを辿り，それらのうち任意の二つが合同（同じ頭，引数ごとに同じ同値類）であるかを確認する。
合同であればそれらも併合する。カスケードは e-グラフで既に見たのと同じ形状である。

== 線形算術 — 境界と Simplex

LIA（整数）と LRA（実数）は線形不等式を扱う。adsmt は二層戦略を用いる。

*層 1 — 境界追跡。* 各変数について，現在の下界 $ell_x$ と上界 $u_x$ を保つ。
新たな制約は境界を狭める。任意の変数で $ell_x > u_x$ となれば矛盾である。

```rust
pub struct LinArith {
    name_: &'static str,
    bounds: HashMap<String, Bounds>,
    scope_stack: Vec<LinArithSnapshot>,
    conflict: Option<TheoryWitness>,
}
struct Bounds {
    lower: Option<(i128, bool)>, // (value, strict?)
    upper: Option<(i128, bool)>,
}
```

これは変数対定数の制約（`x ≤ 5`，`x ≥ 3`）を定数時間で扱う。
LIA では厳密不等式は整数対応物に縮められる。すなわち `x > 5` は `x ≥ 6` になる。

*層 2 — Simplex タブロー*（OxiZ の `oxiz-math` を経由）。
複数の変数を含む制約（`x + y ≤ z + 3`）に対しては境界追跡では足りない。
リテラルは Simplex バックエンドに転送され，
バックエンドは標準のタブロー表現を保ち実行可能解または矛盾が現れるまでピボットする。

```rust
fn assert(&mut self, lit: Literal) -> AssertResult {
    if let Some((var, op, k)) = self.dest_var_constant(&lit.term) {
        if let Some(witness) = self.record_bound(var, op, k) {
            return AssertResult::Conflict { witness };
        }
        AssertResult::Accepted
    } else if self.is_two_var_constraint(&lit.term) {
        self.simplex.assert(lit)
    } else {
        AssertResult::Ignored
    }
}
```

二層設計は，制約の大半が変数対定数のときに効いてくる。
高価な Simplex のピボットは本当に必要なときだけ発火する。

== ビットベクトル

BV 制約は固定幅の二進算術である。例：`(= (bvadd x 1) (bvor y 0xff))`。
adsmt はこれを三層で扱う。

*層 1 — リテラル評価。* ビットベクトル演算子の両被演算子が具体的なリテラルのとき，主張時に評価する。
$ "bvand"("0b1100", "0b1010") -> "0b1000" $

*層 2 — ビットレベル事実伝播。* 一方の被演算子が変数で他方がリテラルのとき，変数上の部分的なビット知識を導出する。
`(bvand x 0x0F) = 0x05` を例にとると，
`x` の上位 4 ビットは制約されず（AND がそれらを結果でゼロ化した），
`x` の下位 4 ビットは `0x5` でなければならない。
部分的な知識を変数ごとに `(mask, value)` の対として符号化し，対を累積的に併合し，
`mask` が幅のあらゆるビットを覆ったら完全な束縛に昇格させる。

*層 3 — ビット・ブラスティング*（`bv_blast` 経由）。
変数が混在する制約（`(bvadd x y) = (bvmul z 3)`）に対しては，
各 BV ビットを新鮮なブールアトムへと下ろし，ビットレベル意味論を符号化する CNF を放出する。
CNF は SAT バックエンドに渡され，命題問題として判定される。
加算器はリプルキャリ連鎖として，乗算器はシフトと加算として，AND/OR/XOR はビット単位として実装される。

```rust
pub fn blast_term(t: &Term, w: u32, env: &mut BlastEnv) -> Option<Vec<Bit>> {
    if let Some((value, lw)) = t.dest_bv_lit() {
        return Some(lit_bits(value, w));
    }
    if let Term::Var(v) = t {
        return Some((0..w).map(|i| Bit::Atom(bit_var(&v.name, i))).collect());
    }
    if let Some((op, ow, lhs, rhs)) = t.dest_bv_binop() {
        // lower lhs and rhs, then combine bit-by-bit
        // according to op (bvand, bvor, bvxor, bvadd, bvsub, bvmul).
    }
    None
}
```

== 配列 — read-over-write

配列理論は `(select arr idx)` と `(store arr idx val)` 演算を扱う。
鍵となる推論規則は*read-over-write*である。

$ "select"("store"(a, i, v), j) = cases(
  v "if" i = j,
  "select"(a, j) "if" i != j,
) $

運用上は次のようになる。等式 `(select (store a i v) j) = expr` を主張するときに，書き換えを試みる。
同インデックス側の場合は無条件に発火する。異インデックス側の場合は，
`i != j` が既知である証拠（直接主張されたか，あるいは導出されたか）を要する。

```rust
fn read_over_write(t: &Term, diseqs: &[(Term, Term)]) -> Option<(Term, String)> {
    let (arr, j) = t.dest_select()?;
    let (inner_a, i, v) = arr.dest_store()?;
    if i.alpha_eq(&j) {
        Some((v, "same-index".into()))
    } else if pair_known_disequal(&i, &j, diseqs) {
        Some((mk_select(inner_a, j), "diseq-index".into()))
    } else {
        None
    }
}
```

第二の規則は store-over-store を正規化する。
$ "store"("store"(a, i, v_1), j, v_2) = cases(
  "store"(a, i, v_2) "if" i = j,
  "store"("store"(a, j, v_2), i, v_1) "if" i != j,
) $

同インデックス支配がより有用な規則である（冗長な書き込みを潰す）。
異インデックスの可換性は入れ子の store を正規順序に置く助けとなり，
下流の EUF がエイリアシングを検出できるようにする。

否定的な配列等式——配列ソートの被演算子の間の `a != b`——は，
*外延性証拠*をキューに入れる。
すなわち，`select(a, d) != select(b, d)` となるあるインデックス $d$ が存在しなければならない。
量化子層（第 7 章）が $d$ のインスタンス化を担当する。

== データ型

代数的データ型——`Color = Red | Green | Blue` や，
`Nat = Zero | Succ Nat`，`List a = Nil | Cons a (List a)` のような帰納的データ型——には専用の理論を与える。
二つの中核的な推論規則がある。

*構成子の互いに素性。* `a` が `Red` で構成され `b` が `Green` で構成されたなら，それらは等しくあり得ない。
`a = b` を主張すると即座に衝突を生む。

*単射性。* `Cons head1 tail1 = Cons head2 tail2` が成り立つなら，
`head1 = head2` と `tail1 = tail2` が成り立つ。
理論の `derive_equalities` は構成子適用間で主張された等式を走査し，引数ごとの等式を放出する。

```rust
fn derive_equalities(&self) -> Vec<(Term, Term)> {
    let mut out = Vec::new();
    for (a, b) in &self.asserted_eqs {
        if let (Some((ca, args_a)), Some((cb, args_b))) =
            (Self::dest_constructor_app(a), Self::dest_constructor_app(b))
        {
            if ca == cb && args_a.len() == args_b.len() {
                for (arg_a, arg_b) in args_a.into_iter().zip(args_b) {
                    out.push((arg_a, arg_b));
                }
            }
        }
    }
    out
}
```

濃度：有限な列挙は有限の濃度証拠を持ち，帰納的データ型は $omega$ である。
polite 結合は濃度クリーク検査にこれらを用いる。

== polite 結合インタフェース

上述の各理論は `Theory` トレイトに差し込まれる。
結合オーケストレータ（第 5 章）がそれらをまとめて駆動する。
振付は理論にかかわらず一様である。同じトレイト，同じプロトコル，同じ `push`/`pop` 形状である。
これが，新たな理論を追加することが封じ込められた練習問題である理由である。
トレイトを実装し，インスタンスを登録すれば，結合機構がそれを拾い上げる。

読者にとって有益な練習問題：この方針に沿って文字列理論を実装すること。
基本演算（`length`，`concat`，`substr`）と制約語彙
（`prefix-of`，`contains`）があれば，現実世界の SMT ワークロードの驚くほど多くの部分を扱える。
要は長さ抽象である。多くの文字列論理式は長さ上の算術と文字上の等式推論へと分解される。
