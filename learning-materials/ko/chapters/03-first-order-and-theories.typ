= 1차 논리와 이론들

== 명제 너머로

명제 논리의 원자는 내부 구조를 갖지 않는다. $p$에 대해
말할 수 있는 것은 "$p$가 참이다"뿐이다. *1차 논리(first-order
logic)*는 이를 다음과 같이 확장한다.

- *변수* — 어떤 정의역(domain) 위에서 범위(range)를 갖는다.
- *함수 기호(function symbols)* — `+`, `f`, `succ` —
  항(term)을 받아 항을 반환한다.
- *술어 기호(predicate symbols)* — `<`, `=`, `prime?` —
  항을 받아 부울 값을 반환한다.
- *한정자(quantifiers)* — $forall$, $exists$ — 변수를
  속박(bind)한다.

따라서 단순히 $p$ 대신 $forall x. (P(x) => Q(f(x)))$와 같이
쓸 수 있다. 이제 원자는 *적용(application)*이 되었으며 —
$P(x)$, $Q(f(x))$ — 솔버는 그 구조를 이용할 수 있다.

== 통사론과 의미론

*시그너처(signature)*는 어떤 논리의 함수 기호와 술어
기호의 이름을 지정한다. *이론(theory)*은 시그너처에
그 기호들의 행동을 제약하는 공리 집합을 더한 것이다.
이론의 *모델*은 해석(interpretation)이다 — 정의역과 함께
실제 함수 및 관계가 주어져, 공리를 만족시킨다.

예컨대 *정수 산술 이론*은 시그너처 $\{+, -, *, <, =, 0,
1, …\}$와 "이것이 통상적인 정수 산술이다"라는 공리들을
가진다. 그 모델은 통상적인 연산을 갖춘 $ZZ$이다.

이론 $T$ 위의 공식 $phi$는, $T$의 어떤 모델이 $phi$를
참으로 만들면 *T-만족가능*이라고 한다. SMT 솔버는 다양한
$T$에 대해 T-만족가능성을 결정한다.

== SMT-LIB에서의 이론들

SMT-LIB 표준은 이론들의 고정된 명단을 정의한다. adsmt는
그중 일부를 지원한다(동반서 부록 A).

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*이론*], [*원자*]),
  [`Core` / EUF], [동치 + 해석되지 않은 함수 기호],
  [`Ints` / LIA], [정수, 선형 산술],
  [`Reals` / LRA], [실수, 선형 산술],
  [`FixedSizeBitVectors`], [고정 폭 비트벡터],
  [`ArraysEx`], [읽기/쓰기를 가진 맵],
  [`Datatypes`], [대수적 데이터 타입 (리스트, 트리, …)],
)

각 이론은 *결정 절차*를 가진다. 즉 해당 이론의 원자에
대한 T-만족가능성을 결정하는 알고리즘이다. SMT 엔진은
각 원자를 적절한 결정 절차로 라우팅한다.

== 한정자-자유(QF) vs. 한정자가 있는

*한정자-자유(quantifier-free, QF)* 공식은 $forall$이나
$exists$를 포함하지 않는다. 흔한 이론들의 QF 단편은
대부분 NP 안에서 결정가능하다. SMT-LIB 논리 이름들은
이를 표시하기 위해 `QF_`로 시작한다. `QF_LIA`, `QF_BV`,
`QF_AUFLIA`처럼 말이다.

*한정자가 있는* 공식은 적어도 하나의 한정자를 포함한다.
한정자가 있는 단편의 대부분(Presburger 산술 — 한정자가
있는 LIA — 처럼 결정가능하지만 매우 비싼 경우는 주목할
예외이다)은 결정불가능이다.

실용적인 SMT 솔버는 한정자를 *휴리스틱하게* 다룬다.
공식을 처리할 만한 항 수준 인스턴스화를 찾는다. 인스턴스화로
충분하면 문제가 해결되고, 그렇지 않으면 솔버는 `unknown`
(또는 adsmt의 경우 `abductive`)을 반환한다. 7장에서
한정자 처리를 자세히 다룬다.

== 부울 골격 안의 이론 원자

2장에서 본 것처럼, SAT 계층은 각 이론 원자를 새로운
부울 변수로 다룬다. 이론 계층의 역할은 그 원자에 대한
참/거짓 할당의 어느 *조합*이 일관되는지를 판정하는 것이다.

```text
SMT formula:    (< x 3) ∧ ((< x 0) ∨ (> x 5))

Theory atoms:   A := (< x 3)
                B := (< x 0)
                C := (> x 5)

Boolean skeleton: A ∧ (B ∨ C)

SAT proposes:   A=T, B=T, C=F
Theory check:   "x < 3 and x < 0 and ¬(x > 5)" — sat
                (e.g. x = -1)
Verdict:        sat with model x = -1
```

보다 흥미로운 경우, 이론 점검이 실패한다.

```text
SAT proposes:   A=T, B=F, C=T  (i.e. x < 3 and ¬(x < 0) and x > 5)
Theory check:   "x < 3 and 0 ≤ x and x > 5" — unsat
                (no integer in (-∞, 3) ∩ [0, ∞) ∩ (5, ∞))
SAT learns:     (¬A ∨ B ∨ ¬C) and tries another assignment
```

SAT과 이론 사이의 이 왕복이 *DPLL(T)* 루프이다. 매 회차마다
탐색이 정련된다.

== 이론의 결합

현실의 공식은 이론을 섞어 쓴다. "정수로 색인되는 정수
배열인데, 그 색인이 선형 산술 제약을 만족한다"는 Arrays
+ LIA의 혼합이다. SMT 솔버는 결정 절차들을 *우아하게
결합*해야 한다.

고전적 접근은 *Nelson-Oppen 결합*이다. 두 이론은 공유
변수에 대해 자신들이 도출한 동치(equality)를 교환함으로써
협력한다. 그래서 Arrays가 "$x = y$"를 도출하고 LIA가 더
도출할 것이 없다면, LIA 솔버는 다음 점검에서 $x = y$를
가설로 물려받는다.

Nelson-Oppen은 기술적 전제 조건들(안정 무한(stably
infinite), 시그너처 분리(signature disjoint) 등)을 가진다.
전제 조건들이 충족되면 결합된 결정 절차는 건전하고
완전하다. 그렇지 않을 때는 현대 솔버들은 *정중한 결합
(polite combination)* (Tinelli-Zarba)이나 다른 일반화로
물러난다.

adsmt는 기본적으로 정중한 결합을 사용한다. 사용자는
보통 이를 직접 보지 않는다 — SMT 엔진이 원자를 자동으로
라우팅하고, 결합 기제는 조용히 작동한다. 그러나 엔지니어링
난이도는 실제로 존재한다. SMT 엔진 복잡도의 대부분은
결합 계층에 자리잡고 있다.

== "모듈로 이론" — 마침내 설명되다

전체 그림은 다음과 같다.

```text
A formula's Boolean structure  ←→  SAT solver
A formula's theory atoms       ←→  theory solvers
  (one per theory in use)
Cross-theory equalities         ←→  combination layer
Quantifier instantiations       ←→  quantifier layer
```

"모듈로 이론(modulo theories)"이라는 말은 다음을 뜻한다.
SAT 계층은 이론 원자가 *마치* 그냥 부울인 것처럼 추론하고,
이론 계층이 그 실제 의미론적 내용을 채워 넣는다. 이
분해야말로 SMT가 산업 규모 문제에까지 확장 가능하게
만드는 요인이다.

== 다음 단계

다음 네 장은 전형적으로 마주치는 순서대로 개별 이론을
순회한다.

- 4장: 동치 + 해석되지 않은 함수(EUF).
- 5장: 산술 (LIA, LRA).
- 6장: 비트벡터, 배열, 데이터타입.

각 장은 그 이론이 어디에 좋은지, 그 결정 절차가 스케치
수준에서 어떻게 생겼는지, 그리고 그 이론을 잘 활용하는
SMT-LIB 스크립트는 어떻게 작성하는지를 다룬다.
