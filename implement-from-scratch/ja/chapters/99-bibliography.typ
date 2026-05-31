= 参考文献

本書の各章は、自動推論、SMT、型理論、対話的定理証明の長
きにわたる研究蓄積に依拠している。以下のポインタは、提示
したアルゴリズムと設計判断にとって最も直接的に支柱となっ
た文献である。

== SAT と SMT の基礎

- Marques-Silva, Lynce, Malik. *Conflict-driven clause
  learning SAT solvers* (Handbook of Satisfiability,
  2009). 標準的な CDCL リファレンス。第 4 章は two-
  watched-literals と VSIDS の扱いを本書に従う。

- Eén, Sörensson. *An extensible SAT-solver* (SAT
  2003). MiniSAT 論文。adsmt の CDCL はこの設計に忠実で
  ある。

- Biere, Heule, van Maaren, Walsh, eds. *Handbook of
  Satisfiability* (2nd ed., 2021). 包括的なリファレンス。
  第 24 章(Sebastiani)が SMT を詳しく扱う。

- Nieuwenhuis, Oliveras, Tinelli. *Solving SAT and SAT
  modulo theories: from an abstract Davis-Putnam-Logemann-
  Loveland procedure to DPLL(T)* (JACM 2006). 第 5 章が依
  拠する DPLL(T) の抽象枠組み。

== 理論ソルバ

- Nelson, Oppen. *Simplification by cooperating decision
  procedures* (TOPLAS 1979). 原典の Nelson-Oppen 結合法。

- Tinelli, Zarba. *Combining decision procedures for
  sorted theories* (JELIA 2004). polite 結合。第 5 章が
  adsmt の結合ポリシーに用いる一般化。

- Bradley, Manna. *The Calculus of Computation* (Springer
  2007). UF、LIA、LRA 決定手続きを扱う教科書。

- Dutertre, de Moura. *A Fast Linear-Arithmetic Solver
  for DPLL(T)* (CAV 2006). 第 6 章が概観する Simplex 基
  盤の LIA / LRA ソルバ。

- Niemetz, Preiner, Wolf, Biere. *CoSMT: Bit-Vector
  Solving with QF-BV* (CAV 2019). 第 6 章のための現代的
  なビット・ブラスティング・リファレンス。

== E グラフと等式推論

- Detlefs, Nelson, Saxe. *Simplify: a theorem prover for
  program checking* (JACM 2005). 実用的な合同閉包アルゴ
  リズム。

- Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha. *egg:
  Fast and extensible equality saturation* (POPL 2021).
  現代的な E グラフ技法。第 7 章のハッシュコンシング +
  合同カスケードはこの系譜に従う。

== 量化子インスタンス化

- Detlefs, Nelson, Saxe (op. cit.). E-マッチングの基礎。

- de Moura, Bjørner. *Efficient E-Matching for SMT
  Solvers* (CADE 2007). 第 7 章が実装する E-マッチングの
  変種。

- Reynolds, Tinelli, Goel, Krstić, Deters, Barrett.
  *Quantifier instantiation techniques for finite model
  finding in SMT* (CADE 2013). Tier-3 の有界列挙の着想源。

== アブダクティブ推論

- Inoue. *Linear resolution for consequence finding*
  (Artificial Intelligence 1992). 第 8 章の SLD チェーン
  の骨格。

- Eiter, Gottlob. *The complexity of logic-based
  abduction* (JACM 1995). 理論的な計算量境界。最小化戦略
  に示唆を与える。

- Dillig, Dillig, Aiken. *Automated error diagnosis using
  abductive inference* (PLDI 2012). 検証のためのアブダク
  ションの実用応用。第 8 章のユーザコスト順位付けは類似
  の直観に依拠する。

== 高階論理と型理論

- Gordon, Melham. *Introduction to HOL: A theorem proving
  environment for higher order logic* (Cambridge UP
  1993). 第 2 章の 12 規則カーネルはこの系譜に従う。

- Pierce. *Types and Programming Languages* (MIT Press
  2002). System F、依存型、型クラス — 第 3 章の型理論的
  背景。

- Wadler, Blott. *How to make ad-hoc polymorphism less
  ad hoc* (POPL 1989). 型クラス導入と辞書渡し変換。

== 証明書形式とリフレクション

- Stump, Oe, Reynolds, Hadarean, Tinelli. *SMT proof
  checking using a logical framework* (Formal Methods in
  System Design 2013). LFSC 証明形式。adsmt-cert はその
  より小さな従兄弟である。

- Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds, Barrett.
  *SMTCoq: A plug-in for integrating SMT solvers into Coq*
  (CAV 2017). Coq 側のリフレクション。
  `adsmt-emit-rocq` で写像される。

- Lochbihler. *Mechanising a type-safe model of multithreaded
  Java with a verified compiler* (Journal of Automated
  Reasoning 2018). Isabelle 側のリフレクション・パターン。
  `adsmt-emit-isabelle` は類似の機構に依拠する。

- Avigad, de Moura, Kong. *Theorem Proving in Lean 4*
  (online book, ongoing). 第 10 章が出力対象とする
  Lean 4 表層。

== ソフトウェア工学

- Klabnik, Nichols. *The Rust Programming Language*
  (Mozilla, ongoing). Rust 言語リファレンス。

- Cargo Book. 第 11 章が依拠するワークスペース、semver、
  公開の慣習。

- Debian Policy Manual §5.6 (versioning) and §2.1
  (channels). 第 11 章が採用する Debian 流チャンネル・モ
  デル。

== adsmt 内部文書

- `~/AD1/CONTRIBUTIONS_AUDIT.md` — RC2.7 監査記録。
- `~/AD1/DOC_AUDIT.md` — RC2.4 + RC2.8 cargo-doc 監査。
- `~/AD1/PUBLISH_AUDIT.md` — RC2.2 publish ドライラン。
- `~/AD1/ABSORPTION_PLAN.md` — logicutils 吸収の経緯。
- `~/AD1/memory/prover_emit_policy.md` — Lean/Rocq/Isabelle
  歩調合わせポリシー。
- `~/AD1/memory/oxiz_relationship.md` — OxiZ Path A+B 統
  合計画。
- `~/AD1/memory/lsp_roadmap.md` — LSP フェーズ・サインオ
  フ。
