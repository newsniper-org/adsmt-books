= 더 읽을거리

이 부록은 이 책에 들어갈 공간이 부족했던 참고문헌을
큐레이팅한 목록이다. 각 항목은 한 줄 주석을 포함한다.
거기에서 무엇을 찾을 수 있고, 왜 시간을 들일 가치가
있는지를 설명한다.

== SMT — 토대

- *The SMT-LIB Initiative.* `https://smtlib.cs.uiowa.edu/`
  표준의 홈 페이지로, 현재 언어 명세, 이론 정의, 벤치마크
  라이브러리가 있다. SMT-LIB를 작성하는 누구에게나
  필수적인 참고 자료이다.

- *Barrett, Sebastiani, Seshia, Tinelli.* "Satisfiability
  Modulo Theories." In the *Handbook of Satisfiability*
  (2nd ed., 2021). Chapter 33. 정전적인 SMT 개관 논문이다.

- *Bradley, Manna.* *The Calculus of Computation*.
  Springer 2007. 작업된 예제와 함께 결정 절차를 다루는
  교과서이다. CS 배경이 있는 사람을 위한 좋은 첫 입문서.

- *Kroening, Strichman.* *Decision Procedures: An
  Algorithmic Point of View*. Springer 2008. 다른 구성과
  추가 산업 사례 연구를 가진 자매 교과서.

== SAT — 토대

- *Biere, Heule, van Maaren, Walsh, eds.* *Handbook of
  Satisfiability*. 2nd ed., IOS Press 2021. 참고 표준.

- *Marques-Silva, Lynce, Malik.* "Conflict-Driven Clause
  Learning SAT Solvers." Handbook의 4장.

- *Eén, Sörensson.* "An Extensible SAT-Solver." SAT
  2003. MiniSAT 논문이며, 이후의 모든 CDCL 솔버가
  토대로 삼는 설계이다.

== 이론 솔버

*EUF:*
- *Detlefs, Nelson, Saxe.* "Simplify: A theorem prover
  for program checking." *JACM* 52(3), 2005. 실용적인
  합동 폐포.
- *Nieuwenhuis, Oliveras.* "Fast congruence closure and
  extensions." *Information and Computation* 2007.

*LIA/LRA:*
- *Dutertre, de Moura.* "A Fast Linear-Arithmetic Solver
  for DPLL(T)." CAV 2006.
- *Cooper.* "Theorem proving in arithmetic without
  multiplication." *Machine Intelligence* 7, 1972.
  Presburger 참고 표준.

*BV:*
- *Brummayer, Biere.* "Effective Bit-Width and Under-
  Approximation." EUROCAST 2009.
- *Niemetz, Preiner, Biere.* "Boolector at the SMT
  Competition 2018." 현대 BV 솔버 설계.

*Arrays:*
- *Stump, Barrett, Dill, Levitt.* "A decision procedure
  for an extensional theory of arrays." LICS 2001.

*Datatypes:*
- *Reynolds, Blanchette.* "A Decision Procedure for
  (Co)datatypes in SMT Solvers." *Journal of Automated
  Reasoning* 2017.

== EGraph 와 equality saturation

- *Willsey, Nandi, Wang, Flatt, Tatlock, Panchekha.* "egg:
  Fast and extensible equality saturation." POPL 2021.
  현대 E-graph 기법.

- *Detlefs-Nelson-Saxe (op. cit.).* 합동 폐포 알고리듬.

== 한정자 인스턴스화

- *Moskal, Schulte.* "E-matching with free variables." TBA.
- *de Moura, Bjørner.* "Efficient E-Matching for SMT
  Solvers." CADE 2007.
- *Reynolds et al.* "Quantifier instantiation techniques
  for finite model finding in SMT." CADE 2013. Tier-3
  배경.

== 가설추론적 추론

- *Peirce, C. S.* *Collected Papers*, vols. 1-8. Harvard
  University Press 1931-1958. 가설추론의 철학적 토대.
  특히 vol. 5 §§5.171-5.181.

- *Inoue.* "Linear resolution for consequence finding."
  *Artificial Intelligence* 1992.

- *Dillig, Dillig, Aiken.* "Automated error diagnosis
  using abductive inference." PLDI 2012. 검증을 위한
  실용적 가설추론.

- *Reynolds, Nötzli, Barrett, Tinelli.* "A decision
  procedure for separation logic in SMT." ATVA 2017.
  다른 이론을 사용한 관련 접근.

== 고차 논리 + HKT

- *Gordon, Melham.* *Introduction to HOL: A theorem
  proving environment for higher order logic*. Cambridge
  UP 1993. 12-규칙 커널 계보.

- *Pierce.* *Types and Programming Languages*. MIT Press
  2002. 타입 이론적 배경. 23장에서 시스템 $F_omega$ 가
  HKT를 다룬다.

- *Wadler, Blott.* "How to make ad-hoc polymorphism less
  ad hoc." POPL 1989. 타입 클래스.

== 증명 인증서와 증명 검사

- *Stump, Oe, Reynolds, Hadarean, Tinelli.* "SMT proof
  checking using a logical framework." *Formal Methods in
  System Design* 2013. LFSC. adsmt-cert와 관련됨.

- *Ekici, Mebsout, Tinelli, Keller, Katz, Reynolds,
  Barrett.* "SMTCoq: A plug-in for integrating SMT
  solvers into Coq." CAV 2017.

- *de Moura, Bjørner.* "Proofs and refutations, and Z3."
  IWIL 2008. Z3의 증명 형식.

== ITP 통합

- *Avigad, de Moura, Kong.* *Theorem Proving in Lean 4*.
  온라인 책 `https://lean-lang.org/theorem_proving_in_lean4/`.
  Lean 4 참고 표준.

- *Coq Development Team.* *The Coq Reference Manual*.
  온라인. 각 Coq/Rocq 릴리스와 함께 업데이트됨.

- *Nipkow, Klein.* *Concrete Semantics with Isabelle/HOL*.
  Springer 2014. 작용 의미론 작업 예제를 가진 Isabelle
  교과서.

== 검증 — 응용 SMT

- *Cook, Khlaaf, Piterman.* "Reasoning About Infinite
  Procedures." STACS 2015.

- *Hawblitzel et al.* "IronFleet: Proving practical
  distributed systems correct." SOSP 2015. SMT-via-Dafny
  의 산업 사례 연구.

- *Leroy, Blazy.* "CompCert: Formal verification of a
  realistic compiler." *CACM* 2009. 다른 스타일 (Coq
  기반, SMT 적음) 이지만 검증-등급의 엄밀성은 비교
  가능하다.

== 합성

- *Solar-Lezama.* *Program Synthesis by Sketching*. PhD
  thesis, UC Berkeley 2008. 합성을 위한 Sketch + SMT.

- *Polikarpova, Kuraj, Solar-Lezama.* "Program synthesis
  from polymorphic refinement types." PLDI 2016.

== adsmt 특화

- `~/AD1/README.md` — 워크스페이스 개요.
- `~/AD1/memory/*.md` — 프로젝트 내부 맥락, 사이클
  이력, 설계 결정.
- `~/AD1/CONTRIBUTIONS_AUDIT.md` — RC2.7 감사 기록.
- `~/AD1/DOC_AUDIT.md` — RC2.4 + RC2.8 cargo-doc 감사.
- `~/AD1/PUBLISH_AUDIT.md` — RC2.2 publish 드라이런.
- `~/AD1/ABSORPTION_PLAN.md` — logicutils 흡수.
- `~/adsmt-contrib/README.md` — out-of-tree 백엔드.

== 관련 소프트웨어

- *OxiZ* — `https://github.com/cool-japan/oxiz`. 순수-Rust
  Z3 재구현. adsmt의 SAT/이론 위임 대상. 자매 프로젝트는
  함께 "연역적 코어는 OxiZ에 위임하고, adsmt 특화 계층을
  추가"하는 아키텍처를 보여준다 (`memory/oxiz_relationship.md`).

- *Z3* — `https://github.com/Z3Prover/z3`. 참고 표준 SMT
  솔버. 비교 기준선으로 설치할 가치가 있다.

- *CVC5* — `https://cvc5.github.io/`. 또 다른 주요 연구
  SMT 솔버. 한정자와 데이터타입에 강하다.

- *Yices2* — `https://yices.csl.sri.com/`. SRI의 솔버.
  QF_NRA에서 빠르며 Simplex가 좋다.

- *Lean 4* — `https://lean-lang.org/`. adsmt의 참고
  반사 대상인 증명 보조기.

- *Rocq* — `https://rocq-prover.org/`. 이전에 Coq으로
  알려진 증명 보조기.

- *Isabelle* — `https://isabelle.in.tum.de/`. 또 다른
  주요 증명 보조기.

- *logicutils* — adsmt가 v0.x에서 흡수한 lu-kb 방언의
  원본 저장소. 비-SMT 사용 사례를 위해 계속 유지된다.

- *leo4* — 사용자의 듀얼-ITP (OxiLean + Lean 4) 바인딩
  라이브러리. `contributions/oxiz/bindings/` 동결
  정책을 지배한다.

== 마무리 노트

이 목록은 의도적으로 선별적이다. SMT 문헌은 거대하고
빠르게 성장하고 있다. 우리는 십 년 이상 시험을 견뎌낸
참조와 이미 정전적으로 자리잡은 최근 논문 몇 편을
골랐다.

최신 정보는 CAV (Computer-Aided Verification), TACAS
(Tools and Algorithms for the Construction and Analysis
of Systems), 그리고 SAT (SAT 학회) 를 따라가라.
SMTCOMP — 연례 SMT 경연 — 는 매년 여름에 열리고
최신 기술 상태에 대한 유용한 지표가 되는 결과를
게시한다.
