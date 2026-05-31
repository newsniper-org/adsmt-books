= 참고문헌

이 책의 각 장은 자동 추론(automated reasoning), SMT, 타입
이론, 대화형 정리 증명에 걸친 오랜 연구 성과들에 의지하고
있다. 아래의 참고들은 본문에서 제시한 알고리즘과 설계
결정에 가장 직접적으로 영향을 준 자료들이다.

== SAT 및 SMT 토대

- Marques-Silva, Lynce, Malik. *Conflict-driven clause
  learning SAT solvers* (Handbook of Satisfiability,
  2009). CDCL의 정전(canonical) 참조. 4장은 여기 다룬 두 감시
  리터럴(two-watched-literals)과 VSIDS 처리를 따른다.

- Eén, Sörensson. *An extensible SAT-solver* (SAT
  2003). MiniSAT 논문. adsmt의 CDCL은 이 설계에 충실하다.

- Biere, Heule, van Maaren, Walsh, eds. *Handbook of
  Satisfiability* (2nd ed., 2021). 포괄적 참조. 24장
  (Sebastiani)이 SMT를 깊이 다룬다.

- Nieuwenhuis, Oliveras, Tinelli. *Solving SAT and SAT
  modulo theories: from an abstract Davis-Putnam-Logemann-
  Loveland procedure to DPLL(T)* (JACM 2006). 5장이 의존하는
  DPLL(T) 추상 프레임워크.

== 이론 솔버

- Nelson, Oppen. *Simplification by cooperating decision
  procedures* (TOPLAS 1979). 원래의 Nelson-Oppen 결합 방법.

- Tinelli, Zarba. *Combining decision procedures for
  sorted theories* (JELIA 2004). polite combination. 5장이
  adsmt의 결합 정책에 사용하는 일반화.

- Bradley, Manna. *The Calculus of Computation* (Springer
  2007). UF, LIA, LRA 결정 절차에 대한 교과서적 다룸.

- Dutertre, de Moura. *A Fast Linear-Arithmetic Solver
  for DPLL(T)* (CAV 2006). 6장이 스케치하는 Simplex 기반
  LIA / LRA 솔버.

- Niemetz, Preiner, Wolf, Biere. *CoSMT: Bit-Vector
  Solving with QF-BV* (CAV 2019). 6장의 현대적 비트-블라스팅
  참조.

== EGraph와 등식 추론

- Detlefs, Nelson, Saxe. *Simplify: a theorem prover for
  program checking* (JACM 2005). 실용적 합동 폐포 알고리즘.

- Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha. *egg:
  Fast and extensible equality saturation* (POPL 2021).
  현대적 E-graph 기법. 7장의 hash-cons + congruence
  cascade가 이 계보를 따른다.

== 한정자 인스턴스화

- Detlefs, Nelson, Saxe (op. cit.). E-매칭의 토대.

- de Moura, Bjørner. *Efficient E-Matching for SMT
  Solvers* (CADE 2007). 7장이 구현하는 E-매칭 변형.

- Reynolds, Tinelli, Goel, Krstić, Deters, Barrett.
  *Quantifier instantiation techniques for finite model
  finding in SMT* (CADE 2013). Tier-3의 제한된 열거(bounded
  enumeration)에 영감을 준다.

== 가설추론

- Inoue. *Linear resolution for consequence finding*
  (Artificial Intelligence 1992). 8장의 SLD 사슬 골격.

- Eiter, Gottlob. *The complexity of logic-based
  abduction* (JACM 1995). 이론적 경계. 최소화 전략에 정보를
  제공한다.

- Dillig, Dillig, Aiken. *Automated error diagnosis using
  abductive inference* (PLDI 2012). 검증을 위한 실용적
  가설추론 응용. 8장의 사용자 비용(user-cost) 순위는 유사한
  직관을 따른다.

== 고차 논리(higher-order logic)와 타입 이론

- Gordon, Melham. *Introduction to HOL: A theorem proving
  environment for higher order logic* (Cambridge UP
  1993). 2장의 12-규칙 커널이 이 계보를 따른다.

- Pierce. *Types and Programming Languages* (MIT Press
  2002). System F, 의존 타입, 타입 클래스 — 3장의 타입
  이론적 배경.

- Wadler, Blott. *How to make ad-hoc polymorphism less
  ad hoc* (POPL 1989). 타입 클래스 도입과 사전 전달
  (dictionary-passing) 번역.

== 인증서 형식과 반사(reflection)

- Stump, Oe, Reynolds, Hadarean, Tinelli. *SMT proof
  checking using a logical framework* (Formal Methods in
  System Design 2013). LFSC 증명 형식. adsmt-cert는 더
  작은 사촌이다.

- Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds, Barrett.
  *SMTCoq: A plug-in for integrating SMT solvers into Coq*
  (CAV 2017). Coq 측 반사. `adsmt-emit-rocq` 에서 미러링됨.

- Lochbihler. *Mechanising a type-safe model of multithreaded
  Java with a verified compiler* (Journal of Automated
  Reasoning 2018). Isabelle 측 반사 패턴. `adsmt-emit-isabelle`
  이 유사한 기제에 의지한다.

- Avigad, de Moura, Kong. *Theorem Proving in Lean 4*
  (online book, ongoing). 10장이 방출하는 Lean 4 표면.

== 소프트웨어 엔지니어링

- Klabnik, Nichols. *The Rust Programming Language*
  (Mozilla, ongoing). Rust 언어 참조.

- Cargo Book. 11장이 의존하는 워크스페이스, semver, 게시 관례.

- Debian Policy Manual §5.6 (versioning) and §2.1
  (channels). 11장이 채택하는 Debian 스타일 채널 모델.

== adsmt 내부 문서

- `~/AD1/CONTRIBUTIONS_AUDIT.md` — RC2.7 감사 기록.
- `~/AD1/DOC_AUDIT.md` — RC2.4 + RC2.8 cargo-doc 감사.
- `~/AD1/PUBLISH_AUDIT.md` — RC2.2 publish dry-run.
- `~/AD1/ABSORPTION_PLAN.md` — logicutils 흡수 이력.
- `~/AD1/memory/prover_emit_policy.md` — Lean/Rocq/Isabelle
  보조 맞춤(lockstep) 정책.
- `~/AD1/memory/oxiz_relationship.md` — OxiZ Path A+B 통합 계획.
- `~/AD1/memory/lsp_roadmap.md` — LSP 단계별 사인오프.
