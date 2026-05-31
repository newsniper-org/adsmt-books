= さらなる読書

この付録は、本書には収まらない内容を扱う参考文献の精選
リストである。各エントリには一行の注釈を付している。
そこに何があり、なぜ読む価値があるかである。

== SMT — 基礎

- *The SMT-LIB Initiative.* `https://smtlib.cs.uiowa.edu/`
  標準のホームページ。現行言語仕様、理論定義、ベンチマーク
  ライブラリを掲載する。SMT-LIB を書く者にとって不可欠な
  参照である。

- *Barrett, Sebastiani, Seshia, Tinelli.* "Satisfiability
  Modulo Theories." In the *Handbook of Satisfiability*
  (2nd ed., 2021). Chapter 33. SMT の正典的サーベイ。

- *Bradley, Manna.* *The Calculus of Computation*.
  Springer 2007. 実例付きで決定手続きを扱う教科書。CS の
  バックグラウンドがある者にとってよい入門である。

- *Kroening, Strichman.* *Decision Procedures: An
  Algorithmic Point of View*. Springer 2008. 異なる構成と
  追加的な産業事例研究を伴う姉妹教科書。

== SAT — 基礎

- *Biere, Heule, van Maaren, Walsh, eds.* *Handbook of
  Satisfiability*. 2nd ed., IOS Press 2021. リファレンス。

- *Marques-Silva, Lynce, Malik.* "Conflict-Driven Clause
  Learning SAT Solvers." Handbook の 4 章。

- *Eén, Sörensson.* "An Extensible SAT-Solver." SAT
  2003. MiniSAT 論文。後続の CDCL ソルバすべてが土台と
  する設計。

== 理論ソルバ

*EUF:*
- *Detlefs, Nelson, Saxe.* "Simplify: A theorem prover
  for program checking." *JACM* 52(3), 2005. 実践的な
  合同閉包。
- *Nieuwenhuis, Oliveras.* "Fast congruence closure and
  extensions." *Information and Computation* 2007.

*LIA/LRA:*
- *Dutertre, de Moura.* "A Fast Linear-Arithmetic Solver
  for DPLL(T)." CAV 2006.
- *Cooper.* "Theorem proving in arithmetic without
  multiplication." *Machine Intelligence* 7, 1972.
  Presburger のリファレンス。

*BV:*
- *Brummayer, Biere.* "Effective Bit-Width and Under-
  Approximation." EUROCAST 2009.
- *Niemetz, Preiner, Biere.* "Boolector at the SMT
  Competition 2018." 現代的な BV ソルバの設計。

*Arrays:*
- *Stump, Barrett, Dill, Levitt.* "A decision procedure
  for an extensional theory of arrays." LICS 2001.

*Datatypes:*
- *Reynolds, Blanchette.* "A Decision Procedure for
  (Co)datatypes in SMT Solvers." *Journal of Automated
  Reasoning* 2017.

== EGraph と equality saturation

- *Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha.* "egg:
  Fast and extensible equality saturation." POPL 2021.
  現代的な E-graph 技法。

- *Detlefs-Nelson-Saxe (op. cit.).* 合同閉包アルゴリズム。

== 量化子インスタンス化

- *Moskal, Schulte.* "E-matching with free variables." TBA.
- *de Moura, Bjørner.* "Efficient E-Matching for SMT
  Solvers." CADE 2007.
- *Reynolds et al.* "Quantifier instantiation techniques
  for finite model finding in SMT." CADE 2013. Tier-3 の
  背景。

== アブダクティブ推論

- *Peirce, C. S.* *Collected Papers*, vols. 1-8. Harvard
  University Press 1931-1958. アブダクションの哲学的
  基礎。特に vol. 5 §§5.171-5.181。

- *Inoue.* "Linear resolution for consequence finding."
  *Artificial Intelligence* 1992.

- *Dillig, Dillig, Aiken.* "Automated error diagnosis
  using abductive inference." PLDI 2012. 検証のための
  実践的アブダクション。

- *Reynolds, Nötzli, Barrett, Tinelli.* "A decision
  procedure for separation logic in SMT." ATVA 2017.
  異なる理論を用いた関連アプローチ。

== 高階論理 + HKT

- *Gordon, Melham.* *Introduction to HOL: A theorem
  proving environment for higher order logic*. Cambridge
  UP 1993. 12 規則カーネルの系譜。

- *Pierce.* *Types and Programming Languages*. MIT Press
  2002. 型理論的背景。23 章では system $F_omega$ が HKT
  に触れる。

- *Wadler, Blott.* "How to make ad-hoc polymorphism less
  ad hoc." POPL 1989. 型クラス。

== 証明書と証明検査

- *Stump, Oe, Reynolds, Hadarean, Tinelli.* "SMT proof
  checking using a logical framework." *Formal Methods in
  System Design* 2013. LFSC。adsmt-cert と関連がある。

- *Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds,
  Barrett.* "SMTCoq: A plug-in for integrating SMT
  solvers into Coq." CAV 2017.

- *de Moura, Bjørner.* "Proofs and refutations, and Z3."
  IWIL 2008. Z3 の証明フォーマット。

== ITP 統合

- *Avigad, de Moura, Kong.* *Theorem Proving in Lean 4*.
  オンライン書籍 `https://lean-lang.org/theorem_proving_in_lean4/`。
  Lean 4 のリファレンス。

- *Coq Development Team.* *The Coq Reference Manual*.
  オンライン。Coq/Rocq のリリースごとに更新される。

- *Nipkow, Klein.* *Concrete Semantics with Isabelle/HOL*.
  Springer 2014. 操作的意味論の実例を伴う Isabelle 教科書。

== 検証 — 応用 SMT

- *Cook, Khlaaf, Piterman.* "Reasoning About Infinite
  Procedures." STACS 2015.

- *Hawblitzel et al.* "IronFleet: Proving practical
  distributed systems correct." SOSP 2015. 産業界の
  SMT-via-Dafny 事例研究。

- *Leroy, Blazy.* "CompCert: Formal verification of a
  realistic compiler." *CACM* 2009. 異なるスタイル
  (Coq ベース、SMT 寄りでない)。しかし検証グレードの
  厳密性は比肩する。

== 合成

- *Solar-Lezama.* *Program Synthesis by Sketching*. PhD
  論文、UC Berkeley 2008. 合成のための Sketch + SMT。

- *Polikarpova, Kuraj, Solar-Lezama.* "Program synthesis
  from polymorphic refinement types." PLDI 2016.

== adsmt 固有

- `~/AD1/README.md` — ワークスペース概要。
- `~/AD1/memory/*.md` — プロジェクト内部の文脈、サイクル
  履歴、設計決定。
- `~/AD1/CONTRIBUTIONS_AUDIT.md` — RC2.7 監査記録。
- `~/AD1/DOC_AUDIT.md` — RC2.4 + RC2.8 cargo-doc 監査。
- `~/AD1/PUBLISH_AUDIT.md` — RC2.2 publish ドライラン。
- `~/AD1/ABSORPTION_PLAN.md` — logicutils 吸収。
- `~/adsmt-contrib/README.md` — ツリー外バックエンド。

== 関連ソフトウェア

- *OxiZ* — `https://github.com/cool-japan/oxiz`. 純 Rust の
  Z3 再実装。adsmt の SAT / 理論委譲先である。一緒に
  並べた companion プロジェクトとして、「演繹コアは
  OxiZ に委譲し、adsmt 固有の層を加える」アーキテクチャ
  を示す(`memory/oxiz_relationship.md`)。

- *Z3* — `https://github.com/Z3Prover/z3`. リファレンス
  SMT ソルバ。比較ベースラインとしてインストールする
  価値がある。

- *CVC5* — `https://cvc5.github.io/`. もう一つの主要な
  研究用 SMT ソルバ。量化子と datatype に強い。

- *Yices2* — `https://yices.csl.sri.com/`. SRI のソルバ。
  QF_NRA に速く、Simplex がよい。

- *Lean 4* — `https://lean-lang.org/`. adsmt のリファレンス
  リフレクション対象となる証明支援系。

- *Rocq* — `https://rocq-prover.org/`. かつて Coq として
  知られていた証明支援系。

- *Isabelle* — `https://isabelle.in.tum.de/`. もう一つの
  主要な証明支援系。

- *logicutils* — adsmt が v0.x で吸収した lu-kb 方言の
  オリジナルリポジトリ。非 SMT ユースケース向けに
  継続している。

- *leo4* — ユーザの二重 ITP(OxiLean + Lean 4)バインディング
  ライブラリ。`contributions/oxiz/bindings/` のフリーズ
  ポリシーを支配する。

== 結語

このリストは意図的に選択的である。SMT の文献は膨大で
急速に成長している。10 年以上の試練に耐えた参考文献に、
すでに正典化された近年の論文を少し加えた。

最新については、CAV(Computer-Aided Verification)、
TACAS(Tools and Algorithms for the Construction and
Analysis of Systems)、そして SAT(SAT 会議)を追うこと。
SMTCOMP — 年次 SMT 競技 — は毎夏開催され、技術の現状の
有用な動向となる結果を公開している。
