= 算術

== 二つの算術理論

SMT-LIB は以下を区別する。

- *LIA* (線形整数算術) — 整数変数、$+$、$-$、$*$ を定数
  係数で、$<$、$<=$、$=$、$>$、$>=$ で組み立てた制約。
- *LRA* (線形実数算術) — 同じ形式だが、変数が実数を渡る。

いずれにも *含まれない* もの: 非線形乗算 (`x * y`)、除算
(`x / y`)、剰余演算 (ビットベクトル符号化を介する場合を
除く)。これらは NLA / NRA に属し、より難しい断片である。

== 線形制約

*線形制約* は以下の形をしている。

$ a_1 x_1 + a_2 x_2 + dots + a_n x_n thick op thick c $

ここで $a_i$ と $c$ は定数で、$op in {< , <=, =, >=, >, !=}$
である。理論に応じて変数は実数または整数を渡る。

```text
; LIA
(declare-const x Int)
(declare-const y Int)
(assert (<= (+ x y) 10))
(assert (>= x 3))
(assert (>= y 4))

; LRA
(declare-const a Real)
(assert (<= a 2.5))
(assert (>= a 1.5))
```

両断片とも決定可能である。LRA の量化子無し断片は P
(多項式時間) に属する。LIA の量化子無し断片は NP 完全で
ある。

== 決定手続き: Simplex

LRA の主力は線形計画法から借りてきた *Simplex 法* で
ある。制約はタブロー上の不等式として書かれ、ピボット
ステップを通じて、実行可能点 (feasible point)、あるいは
非実行可能性の Farkas 証拠 (Farkas-witness) へと向かう。

```text
     | x  y | constant
-----|------|---------
 s1  | 1  1 | s1 ≤ 10
 s2  | 1  0 | s2 ≥ 3
 s3  | 0  1 | s3 ≥ 4
```

Simplex はタブローを反復的にピボットし、基底実行可能性
(basic-feasibility) を維持しつつ、全ての制約が満たされる
(sat) か、ある行が実行可能解の不存在を証拠付ける (unsat)
かのいずれかに至るまで続ける。

LIA については、Simplex は *有理* 解を探し出す。もし
解が偶然整数座標を持っていれば完了。さもなくば
*分枝限定 (branch-and-bound)* が追加制約 — 「$x <= 3$ または
$x >= 4$」など — を導入し、再帰する。

adsmt の `adsmt-theory::lia` と `::lra` は階層的なアプローチを
取る。最初に安価な *境界伝播 (bounds propagation)* — 全ての
変数は区間境界を持ち、関心区間の絞り込みは高速かつ
往々にして十分である — を行い、境界だけでは決定できない
場合のみ Simplex に進む。

== 境界のみ高速経路

実用上の LIA 問題の多くは境界のみで決定可能である。

```text
(assert (<= x 10))
(assert (>= x 5))
(assert (= y (+ x 3)))
(assert (>= y 15))
```

境界は $5 <= x <= 10$ を与え、ゆえに $8 <= y <= 13$。
制約 $y >= 15$ は上限 13 と矛盾する。Simplex を一切呼ぶ
ことなく決定される。

```rust
pub struct LiaSolver {
    bounds: HashMap<VarId, Interval>,
    asserted: Vec<LinConstraint>,
    simplex: Option<SimplexState>,
}

impl LiaSolver {
    fn check(&mut self) -> SatVerdict {
        if let Some(c) = self.bound_propagate() {
            return SatVerdict::Unsat(c);
        }
        // Bounds didn't decide. Build Simplex.
        let simplex = self.build_simplex();
        match simplex.solve() {
            SimplexResult::Feasible(m) => SatVerdict::Sat(m),
            SimplexResult::Infeasible(farkas) => SatVerdict::Unsat(farkas),
        }
    }
}
```

Simplex は境界だけで足りない場合にのみ起動される。
対話的な用途ではこれは大きな利得となる — ほとんどの
ゴールがマイクロ秒単位で決定される。

== 量化付き算術 — Presburger

*量化付き* LIA — Presburger 算術 — は決定可能だが
非常に高価である。標準的な決定手続きは *Cooper の
アルゴリズム* (またはその改良である Omega など) で、
最悪ケースは三重指数である。

adsmt は完全な Presburger 決定手続きを搭載していない。
量化付き LIA ゴールについて、エンジンはヒューリスティック
にインスタンス化し、インスタンス化が尽きればアブダクション
層へと処理を委譲する。これにより、Presburger-真である
ある種の式は `unsat` ではなく `abductive` の判定を得ることに
なる。利用者はアブダクションされた仮説を受け入れるか、
専用の Presburger タクティクへ後退するかを選ぶ。

== ありふれたパターン

*ループ境界。* 検証文脈における「$0 <= i <= n$」。LIA は
これを直接扱える。配列インデックス (`select A i`) と
組み合わせる場合は Arrays + LIA の結合が必要となる
(第 6 章)。

*制御理論における実数値制約。* 「コントローラは $y$ を
$[0, 1]$ に保たねばならない」。LRA の Simplex が自然な
適合である。

*剰余算術。* SMT-LIB には「剰余算術」理論が直接は存在
しない。ビットベクトル (第 6 章) で符号化するか、可除性
制約付きの補助整数変数を介して符号化する。

== 細部の留意点

*狭義と広義。* Simplex は本質的に広義の不等式 ($<=$、$>=$)
を扱う。狭義 ($<$、$>$) は *δ-摂動 (delta-perturbation)* を
要する。無限小 $delta > 0$ を導入し、$x < c$ を
$x <= c - delta$ として扱う。判定は具体的な $delta$ に
依存しない。

*係数膨張。* 繰り返される Simplex ピボットにより、係数が
巨大化することがある。adsmt は算術モジュール全体で
任意精度有理数を用いる。コストは穏当であり、正しさが
それに値する。

*整数不可解性。* Simplex + 分枝限定による LIA は、敵対的な
入力に対しては指数時間を取り得る (「鳩の巣」ベンチマーク
を参照)。良条件の実用入力では最悪ケースが現れることは
稀である。

== 演習例

制約: 整数の三つ組 $(x, y, z)$ で、$x + 2y + 3z = 10$、
$x >= 5$、$y >= 3$、$z >= 2$ となるものは存在しないことを
証明せよ。

```text
(declare-const x Int)
(declare-const y Int)
(declare-const z Int)
(assert (= (+ x (* 2 y) (* 3 z)) 10))
(assert (>= x 5))
(assert (>= y 3))
(assert (>= z 2))
(check-sat) ;; unsat
```

LIA ソルバの推論: 境界は $x >= 5$、$y >= 3$、$z >= 2$ を
与えるため、$x + 2y + 3z >= 5 + 6 + 6 = 17 > 10$。等号は
実行不可能。判定は `unsat`。

証明書は Farkas 結合を明示的に記録する。

```text
(step :rule theory :theory lia :witness
  (farkas
    :combination ((1.0 c_eq) (-1.0 c_x_lb) (-2.0 c_y_lb) (-3.0 c_z_lb))
    :concludes 10 ≥ 17))
```

これが、下流の ITP (Lean の `linarith`、Rocq の `lia`、
Isabelle の `arith`) が消費する LIA 側の証明書である。
