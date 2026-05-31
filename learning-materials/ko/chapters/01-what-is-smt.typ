= SMT란 무엇인가?

== 한 문장으로 정리한 문제

SMT — *만족가능성 모듈로 이론(Satisfiability Modulo
Theories)* — 은 다음을 묻는다. 표준적인 수학적 구조
(정수, 실수, 비트벡터, 배열 등) 위에서 *해석된(interpreted)*
함수와 술어를 사용할 수 있는 논리 공식이 주어졌을 때,
그 공식은 만족가능한가?

*만족가능한(satisfiable)* 공식은 변수에 값을 할당하고
— 함수 기호에 일관된 해석을 부여함으로써 — 공식을 참으로
만드는 방법이 존재한다. *불만족(unsatisfiable)* 공식은
그러한 할당이 존재하지 않는다.

== 몇 가지 예시

```text
;; Satisfiable: a = 3 works.
(declare-const a Int)
(assert (> a 2))
(assert (< a 10))

;; Unsatisfiable: no real number is both > 5 and < 4.
(declare-const r Real)
(assert (> r 5.0))
(assert (< r 4.0))

;; Satisfiable: pick x = 0, y = 0, A any.
(declare-const x Int)
(declare-const y Int)
(declare-const A (Array Int Int))
(assert (= (select (store A x 1) x) 1))
(assert (= y 0))
```

첫 번째 예시는 선형 정수 산술(LIA)을 사용한다. 두 번째는
선형 실수 산술(LRA)을 사용하는데, $(5, 4)$에 속하는 실수가
존재하지 않으므로 — 이 구간은 비어 있다 — 불만족이다.
세 번째는 배열 이론을 사용한다. 인덱스 `x`에 1을 저장한
후 `x`를 읽으면 1이 반환되며, 이는 `A`와 `y`의 값에
무관하게 자명히 참이다.

== 그냥 SAT만 쓰면 안 되는가?

평범한 *명제 만족가능성(propositional satisfiability)*
즉 SAT은 부울 공식 — 참 또는 거짓만을 갖는 변수들로
이루어진 공식 — 을 다룬다. 현대 SAT 솔버는 놀라울 만큼
빠르다. 수백만 개의 변수를 갖는 산업용 SAT 인스턴스가
일상적으로 수 초 만에 해결된다.

그러나 실용적인 질문의 다수는 SAT에 직접 들어맞지 않는다.
"$3 x + 2 = 14$를 만족하는 정수 $x$가 존재하는가?"는
부울 질문이 아니라 산술 질문이다. 이를 SAT으로 *부호화*할
수는 있다 ($x$를 32비트로 비트-블라스팅하고, 덧셈을
이진 가산기로 인코딩하고, 동치를 비트별 xor + nor로
인코딩하면) — 그 결과로 만들어진 SAT 공식은 원 질문에
답을 준다. 그러나 부호화의 크기가 매우 크고 *구조*가
사라진다 — SAT 솔버는 빠른 선형 산술 결정 절차를
사용하는 대신, 산술적 사실을 처음부터 재유도해야 한다.

SMT는 그 결혼이다. 명제적 골격은 SAT 솔버로 가고, 이론
원자(산술, 비트벡터, 배열 등)는 전용 이론 솔버로
가며, 두 계층이 협력한다.

== 판정(Verdicts)

SMT 솔버는 `(check-sat)` 질의에 대해 다음 중 하나로
답한다.

- *sat* — 공식이 모델을 가진다. 모델을 보려면
  `(get-model)`을 묻는다.
- *unsat* — 모델이 존재하지 않는다. 모순을 일으키는
  주장(assertion)의 최소 부분집합을 보려면
  `(get-unsat-core)`를 묻는다.
- *unknown* — 솔버가 결정하지 못했다. 원인은 한정자
  인스턴스화 예산 소진부터 결정불가능 단편에 부딪힌
  경우까지 다양하다.
- *abductive* (adsmt 고유) — 솔버가 목표를 직접 처리하지
  못했으나, 목표를 *처리할 수 있게 해주는* 가설들의
  순위 매겨진 목록을 산출했다. 목록을 보려면
  `(get-abductive-candidates)`를 묻는다.

처음 셋은 모든 SMT 솔버에 표준적으로 존재하고, 네 번째는
adsmt의 차별화 요소이며, 이에 대해 8장에서 자세히 다룰
것이다.

== 큰 그림

전형적인 adsmt 작업 흐름이다.

```text
User writes SMT-LIB script
       ↓ (parse)
Engine asserts formulas
       ↓ (check-sat)
Verdict: sat / unsat / abductive / unknown
       ↓ (extract)
Model, core, candidates, certificate
       ↓ (downstream)
ITP integration, code generation, decision support, ...
```

이 작업 흐름의 가장 인상적인 점은 그것이 — 프로그램
검증, 계획 수립, 스케줄링, 타입 추론, 합성 등 — 엄청나게
넓은 영역에 동일하게 적용된다는 사실이다. 동일한 형태의
SMT-LIB 스크립트, 동일한 판정 의미론, 그러나 극적으로
다른 용도들.

== 왜 "모듈로 이론"인가?

이 표현은 환론(ring theory)의 "모듈로(modulo)" — 즉
몫 구조(quotient structure) 위에서 작업하는 것 — 의
울림을 가진다. SMT 공식의 원자들은 해당 이론의 공리를
*모듈로*하여 해석된다. 정수는 산술을 따르고, 배열은
read-over-write를 따르며, 비트벡터는 고정 폭(fixed-width)
대수를 따른다. SAT 계층은 `+`의 의미를 알지 못한다.
그저 (같은 공식 안에 나타나는) `(+ x 3)`과 `(+ x 3)`을
*같은 부울 변수*로 취급할 뿐이며, 이론 계층이 의미론적
내용을 채워 넣는다.

이 분해 — 한쪽은 부울 구조, 다른 한쪽은 이론 의미론 —
가 바로 SMT를 확장 가능하게 만드는 요인이다. 각 계층은
자신이 잘 풀 수 있는 문제에 맞춰 조정되어 있고, 결합은
어느 한쪽 단독으로는 다룰 수 없는 공식들을 처리한다.

== SMT 솔버의 흔한 하루

많은 독자들은 다음 세 개의 문 중 하나를 통해 SMT를
접한다.

1. *검증.* "이 C 함수가 결코 null을 역참조하지 않음을
   증명하라." 검증 조건으로 컴파일하여 SMT에게 묻는다.
2. *프로그램 합성.* "다음 조건을 만족하는 함수를
   찾아라…" — 제약을 표현하고 SMT에게 증거(witness)를
   요구한다.
3. *대화형 정리 증명.* "Lean 증명을 절반쯤 진행 중인데
   이 보조 목표가 까다롭다. SMT가 그냥 처리해 주면 안
   되나?"

adsmt는 세 번째 경우에 최적화되어 있다. 9장의 커널
(인증서 형식), 10장의 Lean 4 리플렉션(reflection),
8장의 가설추론 표면 — 모두가 "내가 ITP 안에 있는데
SMT가 이것을 좀 끝내 줬으면 좋겠다 — 그리고 못 끝내면
이유라도 알려 줬으면 좋겠다"는 작업 흐름을 지원한다.

다음 장들은 이를 가능하게 하는 계층들로 깊이 들어간다.
