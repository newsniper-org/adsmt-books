= ビットベクトル、配列、データ型

本章は adsmt が備える理論のうち残る三つを概観する。

== ビットベクトル (BV)

固定幅の符号無し二進整数 — 32 ビット、64 ビット、あるいは
宣言時に指定する任意の幅。演算: 加減、乗除、シフト、
ビット単位の and / or / xor、比較。

```text
(declare-const x (_ BitVec 32))
(declare-const y (_ BitVec 32))
(assert (bvult x y))
(assert (= (bvadd x #x00000001) y))
(check-sat) ;; sat
```

BV はハードウェア検証と低レベルプログラム解析の
*主力* である。ビットシフト、マスク、桁あふれの挙動が
すべて実際のハードウェアと厳密に一致する。

== BV 決定手続き: 三層構成

adsmt の BV ソルバは三つの層を持つ。

1. *リテラル評価。* 両辺が定数か? ソルバ層で評価する
   だけ — `#x00000001 + #x00000002 = #x00000003`。安価で、
   しばしば十分である。

2. *ビット事実伝播。* 具体的なビットを持つリテラルに
   ついて、事実を伝播する。`(bvand x #xff) = #x42` で
   あれば、$x$ の下位 8 ビットは上位ビットに関わらず
   `0x42` に固定される。完全なビット・ブラスティングより
   高速である。

3. *ビット・ブラスティングの後段。* 最初の二つの層で
   決定できないとき、BV 制約を純粋な SAT へと符号化する。
   1 ビットにつき 1 つのブール変数を導入し、ゲート
   ごとに節を加える。結果を SAT 層へ流し込む。

```rust
impl Theory for BvSolver {
    fn check(&mut self) -> SatVerdict {
        if let Some(c) = self.literal_eval() { return c; }
        if let Some(c) = self.bit_fact_propagate() { return c; }
        let clauses = self.bit_blast();
        self.sat.check_with(clauses)
    }
}
```

ビット・ブラスティングは QF_BV について完全である —
任意の量化子無し BV 式はこの方法で決定可能である。
コストは符号化サイズにある。64 ビット乗算は $O(n^2) =
4096$ 節を生成する。可能な限り、層 1 と層 2 が符号化を
回避する。

== 配列

配列の理論はインデックスから値へのマップを扱う。
シグネチャは二つの演算を持つ。

- `(select A i)` — インデックス $i$ における値を読む。
- `(store A i v)` — インデックス $i$ を $v$ に設定し、
  他は変更しない新たな配列を生成する。

公理は二つ。

- *Read-over-write (同一インデックス)*: $"select"("store"(A, i, v), i) = v$。
- *Read-over-write (異インデックス)*: $i eq.not j => "select"("store"(A,
  i, v), j) = "select"(A, j)$。

```text
(declare-const A (Array Int Int))
(assert (= (select (store A 0 42) 0) 42))   ;; same: 42 = 42, sat trivial
(assert (= (select (store A 0 42) 1) (select A 1)))  ;; different: tautology
```

決定手続きは `store` の連鎖を辿る。`store` 連鎖中への
`select` は、最も新しい一致する store (read-over-write 同
インデックス) へと簡約されるか、あるいは前者へ再帰する
(read-over-write 異インデックス)。

== Arrays + LIA

Arrays と LIA の結合は興味深い現象を生む箇所である。
算術式をインデックスとする場合:

```text
(declare-const A (Array Int Int))
(declare-const i Int)
(declare-const j Int)
(assert (= i (+ j 1)))
(assert (= (select (store A i 5) j) 7))
```

store と select の食い違いを判定するため、LIA が $i eq.not j$
を決定する必要がある ($i = j + 1$ から、LIA の推論により
$i eq.not j$)。Arrays ソルバは結合層を呼び出して LIA に
$i = j$ かを問い、LIA は否と返し、Arrays は select が
$"select"(A, j) = 7$ に簡約されると結論する。

polite 結合 (第 3 章) がこれを自動的に処理する。

== データ型

データ型の理論は代数的データ型を扱う: リスト、木、
オプション、レコード、直和型。各データ型は以下を持つ。

- *コンストラクタ* — `nil`、`cons`、`Some`、`None` など。
- *セレクタ* — `head`、`tail`、`value` など。
- *テスタ* — `is-nil`、`is-cons` など。

```text
(declare-datatype IntList ((nil) (cons (head Int) (tail IntList))))
(declare-const l IntList)
(assert (is-cons l))
(assert (= (head l) 3))
(check-sat) ;; sat: l = (cons 3 ?)
```

公理には以下が含まれる。

- *互いに排他*。`nil` $eq.not$ `cons a t`。
- *単射性 (injectivity)*。`cons a1 t1 = cons a2 t2 => a1 = a2
  and t1 = t2`。
- *非循環性 (acyclicity)*。データ値が自身を部分項として
  含むことはない。

決定手続きはコンストラクタ所属を追跡し、単射性・排他性の
事実を追う。非循環性は occurs-check で確認される。

== 三者と EUF の結合

ビットベクトル要素を持つ非解釈配列のビットベクトル...
これは BV + Arrays + EUF を結合し、加えて整数インデックスが
現れる場合は LIA をも結合する。adsmt の polite 結合は
任意の部分集合を扱う。

```text
(declare-sort Process 0)
(declare-fun pc (Process) (_ BitVec 8))   ;; EUF + BV
(declare-fun state (Process) (Array (_ BitVec 8) Int))  ;; + Arrays + LIA
(declare-const p Process)
(assert (= (pc p) #x10))
(assert (> (select (state p) #x10) 0))
```

各アトムは対応する理論へ振り分けられる:
- `(pc p) = #x10` → EUF + BV
- `(select ... #x10) > 0` → Arrays + LIA
- 共有項 `(pc p)` が層間を媒介する。

== 演習例: 別名の付いた配列書き込み

古典的な検証問題: インデックス $i$ に $x$ を、続いて
インデックス $j$ に $y$ を、$i eq.not j$ の下で格納する操作が、
入れ替えても可換であることを証明せよ。

```text
(declare-const A (Array Int Int))
(declare-const i Int)
(declare-const j Int)
(declare-const x Int)
(declare-const y Int)
(assert (not (= i j)))
(assert (not (= (store (store A i x) j y)
                (store (store A j y) i x))))
(check-sat) ;; unsat
```

Arrays ソルバの推論: 拡張性 (extensionality) によれば、
二つの配列が等しいのは全てのインデックスで一致することと
同値である。それゆえ、インデックス $k$ を三つの場合に
分けて考える。

- $k = i$: 左辺は $x$ を与える ($i$ への store、続いて
  $i eq.not j$ なので $j$ の store を通り抜けて select)。
  右辺も $x$ を与える (最上層で $i$ に store)。等しい。
- $k = j$: 左辺は $y$ を与える。右辺も $y$ を与える。等しい。
- $k in.not {i, j}$: 左辺は $A[k]$ を与える。右辺も $A[k]$ を
  与える。等しい。

それゆえ左辺と右辺はいたるところで等しく、表明と矛盾する。
証明書は三つのケースを三つの部分証明として記録し、それぞれが
read-over-write の推論で閉じる。

== 限界

三つの理論にはそれぞれ穴がある。

- *BV:* 乗算の膨張。64 ビット乗算の符号化は多数の節を
  生成する。病的なケースでは SAT 層が詰まる。
- *Arrays:* 拡張性。上記の例ではこれを用いた。ソルバは
  ヒューリスティックにこれを扱うため、常に完全とは
  限らない。
- *データ型:* 相互再帰型と構造的帰納法。SMT ソルバは
  帰納法を直接 *扱わない*。帰納法は ITP の領分であり、
  証明書とリフレクションの連鎖 (第 10 章) がそれを橋渡し
  する。

これらの穴に触れた際、アブダクション層 (第 8 章) が
助けとなる。ソルバは単に `unknown` を返すのではなく、
「帰納法の仮説が必要だ」と表に出す。
