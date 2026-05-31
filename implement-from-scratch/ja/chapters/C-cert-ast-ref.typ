= 証明書 AST リファレンス

本付録は `adsmt-cert`(第 9 章)の各 `StepBody` バリアン
トのリファレンスである。各項は S 式構文、Rust コンストラ
クタ、依存、チェッカ規則を列挙する。

== 必須 12 個(カーネル規則)

=== `refl`
- *Syntax*: `(step :rule refl :id <id> :term <t>)`
- *Rust*: `StepBody::Refl(t)`
- *Dependencies*: none
- *Checker*: 空の仮説集合と共に $t = t$ を発行する

=== `trans`
- *Syntax*: `(step :rule trans :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::Trans { lhs, rhs }`
- *Dependencies*: 2 つの先行ステップ。各々が等式を結論
- *Checker*: ピボットが一致しなければならない(`(a=b)`、`(c=d)` において `b == c`);結合された仮説と共に $a = d$ を発行する

=== `eq_mp`
- *Syntax*: `(step :rule eq_mp :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::EqMp { lhs, rhs }`
- *Dependencies*: 等式 $A = B$ と $A$ の証明
- *Checker*: 結合された仮説と共に $B$ を発行する

=== `abs`
- *Syntax*: `(step :rule abs :id <id> :var <var> :body <ref>)`
- *Rust*: `StepBody::Abs { var, body }`
- *Dependencies*: 等式を結論する 1 つの先行ステップ
- *Checker*: $lambda x . t_1 = lambda x . t_2$ を発行する

=== `beta`
- *Syntax*: `(step :rule beta :id <id> :term <t>)`
- *Rust*: `StepBody::Beta(t)`
- *Dependencies*: none
- *Checker*: $t$ は $(lambda x . b) a$ の形でなければならない;$(lambda x . b) a = b[x mapsto a]$ を発行する

=== `deduct`
- *Syntax*: `(step :rule deduct :id <id> :hyp <ref> :conc <ref>)`
- *Rust*: `StepBody::Deduct { hyp, conc }`
- *Dependencies*: 仮説ステップと結論ステップ
- *Checker*: $A$ が仮説項であるとき $A => B$ を発行する;仮説集合から $A$ を取り除く

=== `inst`
- *Syntax*: `(step :rule inst :id <id> :rule <ref> :var <var> :term <t>)`
- *Rust*: `StepBody::Inst { rule, var, term }`
- *Dependencies*: 全称を結論する先行ステップ
- *Checker*: `var` を `term` で置換した本体を発行する

=== `inst_type`
- *Syntax*: `(step :rule inst_type :id <id> :rule <ref> :var <tyvar> :ty <ty>)`
- *Rust*: `StepBody::InstType { rule, var, ty }`
- *Dependencies*: `var` で多相な先行ステップ
- *Checker*: 型変数を置換した本体を発行する

=== `assume`
- *Syntax*: `(step :rule assume :id <id> :term <t>)`
- *Rust*: `StepBody::Assume(t)`
- *Dependencies*: none
- *Checker*: 仮説集合 $\{t\}$ と共に $t$ を発行する

=== `theory`
- *Syntax*: `(step :rule theory :id <id> :theory <name> :witness <witness>)`
- *Rust*: `StepBody::Theory { theory, witness }`
- *Dependencies*: 証拠に依存する(UF 証拠は等式を引用し、LIA 証拠は線形境界を引用する等)
- *Checker*: 名指された理論の証拠検証器に振り分ける

=== `instance`
- *Syntax*: `(step :rule instance :id <id> :class <c> :dict <d>)`
- *Rust*: `StepBody::Instance { class, dict }`
- *Dependencies*: なし(インスタンス辞書は第一級の項である)
- *Checker*: 辞書をクラス型の項として発行する

=== `assumed`
- *Syntax*: `(step :rule assumed :id <id> :term <t>)`
- *Rust*: `StepBody::Assumed(t)`
- *Dependencies*: none
- *Checker*: グローバル「プリアンブル仮定」仮説タグと共に $t$ を発行する

== アブダクティブ 3 個

=== `abductive_assume`
- *Syntax*: `(step :rule abductive_assume :id <id> :hypothesis (<t>+) :justification <j>)`
- *Rust*: `StepBody::AbductiveAssume { hypothesis, justification }`
- *Dependencies*: 直接にはなし;`justification` が先行ステップを引用しうる
- *Checker*: 各 $t$ を別個の結論として発行する。すべてアブダクティブ由来としてタグ付けされる

=== `abductive_accept`
- *Syntax*: `(step :rule abductive_accept :id <id> :hypothesis <ref> :ground (<t>+))`
- *Rust*: `StepBody::AbductiveAccept { hypothesis, ground }`
- *Dependencies*: `AbductiveAssume` ステップとそれが消化するグラウンド項
- *Checker*: グラウンド項が名指された仮説を法として連鎖を閉じることを確認する

=== `classical_axiom`
- *Syntax*: `(step :rule classical_axiom :id <id> :axiom <kind> :instantiation (<t>+))`
- *Rust*: `StepBody::ClassicalAxiom { axiom, instantiation }`
- *Dependencies*: none
- *Checker*: `axiom` が `preamble.classical-axioms` に含まれなければ拒否する;含まれる場合は当該公理のインスタンス化形を発行する

== 証拠サブ文法

理論証拠は独自のサブ文法を持つ。

```text
witness ::= (uf  :equalities ((= <t> <t>)+))
          | (lia :bounds (<bound>+))
          | (lra :bounds (<bound>+))
          | (bv  :bits ((<i> <0|1>)+))
          | (arr :rows ((<read-or-store>)+))
          | (dt  :discriminants ((<ctor>)+))
```

各理論のチェッカはそれ自身の証拠形状を検証する。証拠形式
は*凍結*される。新たな理論は semver の下で追加的に新たな
証拠バリアントを加える。

== 判定

```text
verdict ::= (verdict sat   :model ((<var> <val>)+))
          | (verdict unsat :final-step <ref>)
          | (verdict abductive :candidates ((<ref>)+) :final-step <ref>)
          | (verdict unknown :reason <text>)
```

`verdict` は証明書の唯一必須の末尾ブロックである。チェッ
カはこれを用いて以下を確認する。`final-step` が存在する
こと、その結論が判定の形状と整合すること、仮説集合が空
(Unsat)であるか、アブダクティブ宣言と整合する(Abductive)
か、あるいはモデルと整合している(Sat)こと。
