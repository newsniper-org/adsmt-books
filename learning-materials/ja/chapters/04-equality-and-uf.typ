= 等号と非解釈関数

== 名前を持つに値する最も単純な理論

EUF — *等号 + 非解釈関数 (equality + uninterpreted
functions)* — は土台である。他のほぼ全ての理論はその
上に積み上がる。そのシグネチャには固定された関数記号や
述語記号はなく、利用者が自身で宣言する。

```text
(declare-sort Term 0)
(declare-fun f (Term) Term)
(declare-fun g (Term) Term)
(declare-const a Term)
(declare-const b Term)

(assert (= (f a) (g b)))
(assert (= a b))
(assert (not (= (f a) (g a))))
(check-sat)  ;; unsat
```

推論は次のとおり。$a = b$ より $f a = f b$ および
$g a = g b$ (関数合同性) を得る。$f a = g b$ と組み合わせ、
$f b = g b$ および $f a = g a$ を得る。それゆえ否定
$not(f a = g a)$ は矛盾する。

== 等号は特別である

等号 (`=`) は EUF に組み込まれた以下の公理スキーマを持つ。

- *反射律*: $forall x. x = x$
- *対称律*: $forall x y. x = y => y = x$
- *推移律*: $forall x y z. x = y and y = z => x = z$
- *関数合同性*: $forall vec(x) vec(y). vec(x) = vec(y)
  => f(vec(x)) = f(vec(y))$ — 任意の $f$ について。

これら四つを合わせると、任意の等号の集合の *合同閉包
(congruence closure)* が生成される — すなわち、関数
適用を尊重する最小の同値関係である。

== Union-find と合同閉包

決定手続きは *合同閉包* である。そのデータ構造は
*union-find* (素集合森) である。

- 各項は代表元を持つ。
- `find(t)` は親ポインタを辿って代表元へ到達する。
- `union(t1, t2)` は二つの同値類をマージする。

合同のステップが起動するのは、二つの項の代表元が今
マージされたときである。両方の同値類の親項を歩く。
もしいずれかの組 $(f(s_1, …, s_n), f(t_1, …, t_n))$ が、
全ての $i$ について $"find"(s_i) = "find"(t_i)$ を満たせば、
合同性により、それらの親もまた同じ類に属さねばならない。
それらをマージし、繰り返す。項が有限個しか存在しない
ため、連鎖は最終的に停止する。

```rust
fn union(&mut self, a: TermId, b: TermId) {
    let ra = self.find(a);
    let rb = self.find(b);
    if ra == rb { return; }
    self.parent[rb] = ra;
    let parents_a = self.collect_parents(ra);
    let parents_b = self.collect_parents(rb);
    for pa in parents_a {
        for pb in &parents_b {
            if self.are_congruent(pa, *pb) {
                self.union(pa, *pb);  // cascade
            }
        }
    }
}
```

漸近的複雑性は項数についてほぼ線形である (適切な小細工と
組み合わせて)。

== adsmt における EUF

adsmt の `adsmt-theory::uf` モジュールは合同閉包を実装
する。標準的な `Theory` インタフェースを公開している
(姉妹巻第 5 章)。

```rust
impl Theory for UfSolver {
    fn assert_literal(&mut self, l: Literal) -> Result<(), Conflict> { ... }
    fn check(&mut self) -> SatVerdict { ... }
    fn push(&mut self) { ... }
    fn pop(&mut self)  { ... }
    fn explain(&self, t: Term) -> Vec<Literal> { ... }
}
```

`explain` は証明書経路の鍵となる。UF が事実 (例えば
等号) を導出したとき、証明書には *どの先行する等号が*
使われたかを記録する必要がある。`explain` は union-find
木を辿って経路を返す。

== なぜ「非解釈」なのか?

「非解釈」とは関数記号が固定された意味を持たないことを
意味する — 制約は合同性公理のみによる。代入則を尊重する
ものなら何でもモデル化できる。プログラム関数、詳細を
特定しないと選択した数学的演算子、抽象的関係などである。

これにより EUF は理想的な *背骨* 理論となる。他の理論
(算術、配列、ビットベクトル) はその上に重なる。配列の
理論はインデックス・値の代数を扱うのに EUF を用い、
算術の理論は線形制約中の制約のない変数をモデル化するのに
EUF を用いる。

== ありふれたパターン

*プログラム検証。* 関数呼び出しを非解釈として扱う:
`(declare-fun f (Int Int) Int)`。特定の呼び出しに関する
表明 (`(= (f 1 2) 5)`) は EUF 仮説となる。検証器は `f` を
評価する必要が一切なく、*どの呼び出しが何を返すか*
について推論するだけで済む。

*モデル抽象化。* 複雑な関係を非解釈述語で置き換える。
実際の関係を符号化するには高価過ぎる静的解析で有用である。

*等号連鎖。* 「$a = b$、$b = c$、$f a = 5$。さて $f c$
は何か?」EUF は自明に $5$ と答える。同じ連鎖を純粋な
命題論理で形式化するとはるかに冗長になる。

== 限界

EUF は以下を扱わない。

- 量化子 (第 7 章)。
- 関数定義 — `(define-fun ...)` は構文的に代入を
  行うが、部分的にしか知られていない関数についての
  事実を導出することはない。
- 高階の等号 — $f = g$ を仮説として扱うのは EUF にとって
  自明だが、ソルバは通常、特殊なケースを除いて関数の
  等号を *導出* しない。

これらの多くについての常套手段は *アブダクション* である。
アブダクション層 (第 8 章) に、ゴールを処理するために
どのような仮説が必要かを問う。答えが「$f = g$ と仮定せよ」で
あるならば、利用者はその仮定が妥当かを判断できる。

== 演習例

adsmt へ送られる短い Lean 4 証明義務。

```lean
example (a b : Nat) (h : a = b) :
    (f a) + (g b) = (f b) + (g a) := by
  smt_decide [h]
```

`smt_decide` タクティクはゴールを EUF + LIA 混合の
SMT-LIB へ変換し、その否定を表明して unsat を求める。

変換された SMT-LIB:

```text
(declare-sort Nat 0)
(declare-fun f (Nat) Nat)
(declare-fun g (Nat) Nat)
(declare-const a Nat)
(declare-const b Nat)
(assert (= a b))
(assert (not (= (+ (f a) (g b)) (+ (f b) (g a)))))
(check-sat)
;; unsat
```

証明書には次が含まれる: $f(a)$ への反射、$a = b$ と
合同性から $f(a) = f(b)$ の導出、$g$ への合同、そして
入れ替えた和の等号を証明する LIA ステップ。

これは EUF が最も得意とすることである — 関数適用を
通じた等号の追跡。下流の Lean エラボレータが証明書を
カーネル下で実際の Lean 項へと戻す。
