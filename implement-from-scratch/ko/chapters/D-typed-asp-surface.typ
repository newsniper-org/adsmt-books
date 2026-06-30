= typed-ASP 표면

*typed-ASP face*는 SMT-LIB 표면의 닫힌 세계(closed-world)·
최소 모델(least-model) 형제이자 **`lu-kb`(부록 B)의
후속**이다. `.smt2`와 `.kb`가 "이 식들의 집합은 충족
가능한가?"를 묻는다면, typed-ASP 프로그램은 "유도되지
않은 것은 성립하지 않는다는 *닫힌 세계* 가정 아래, 이
규칙들의 유일한 모델은 무엇인가?"를 묻는다. 다른 모든
표면과 *같은* typed CIC 커널(`adsmt-ir`)로 elaborate되므로
별도 엔진이 아니라 프런트엔드이다. 모든 규칙은 커널
admitter가 재검사하고 모든 답은 모델을 재계산해
재검증하므로, face 버그는 `FaceError`만 낼 뿐 신뢰되는
틀린 답을 내지 못한다.

== 표면 형태

프로그램은 *항목(item)*의 나열이다:

```text
sort Node.
pred edge(Node, Node).
pred reach(Node, Node).

edge(a, b).  edge(b, c).  edge(c, d).
reach(X, Y) :- edge(X, Y).
reach(X, Z) :- reach(X, Y), edge(Y, Z).

?- reach(a, X).        % a에서 도달 가능한 모든 노드
```

규약은 Prolog/clingo 형태다. term 위치에서 첫 바이트가
`[A-Z]`나 `_`인 식별자는 *변수*, 소문자 식별자는 상수
또는 생성자다. 선언 위치(sort / 술어 / 생성자 이름)는
대소문자를 가리지 않는다.

== 항목

*`sort <Name>.`* — 불투명한 유한 도메인(커널의
`open Name : Type(0)`).

*`enum <Name> = { c0, c1, … }.`* — 0-항 생성자들의 유한·
닫힌 도메인(커널 `Inductive`).

*`data <Name> = c0(S, …) | c1 | … .`* — 인자를 갖는
생성자의 귀납 데이터타입. 커널의 엄격 양성성 게이트가
재귀를 재검사한다. 생성자 항은 1차 *패턴*으로도 쓰인다
(아래 참고).

*`pred <name>(S0, S1, …).`* — 타입드 관계(결과는 `Prop`).
인자 sort는 선언된 sort / enum / datatype 또는 내장 `Int`.

*`abducible <name>(S, …).`* — 술어를 *abducible*로 선언:
그 ground 원자들이 가설 공간을 이룬다. abducible은 `def`-
완성(completion)이 *없는* `Open` 원자로, 일반 술어의
쌍대(dual)다(8장).

*`<atom>.`* — *사실(fact)*(ground 원자), 또는 머리에 변수가
있으면 본문이 빈 *규칙*.

*`<head> :- <body>.`* — 한정 규칙. 본문은 양의 원자, `not`-
부정 원자, `{ … }` 이론 원자의 논리곱이다.

*`:- <body>.`* — *무결성 제약*: 본문이 모델에서 성립하면
안 된다. 어떤 ground 사례가 성립하면 프로그램에 답 집합이
없다(`Solution.consistent = false`).

*`?- <atom>.`* — 질의. 변수는 "전부 찾기" 출력이다.
*`?- abduce <atom>.`* — 귀추 질의(목표를 성립시키는 ⊆-
최소 가설 집합들).

== 부정 사다리

elaborator는 프로그램의 단계를 *추론*하고, 건전성 게이트가
존재하는 단(rung)을 넘어서지 않는다(그 위에서는 파싱은
되되 abstain — 근사하지 않는다).

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*단계*], [*추가*], [*상태*]),
  [L0], [타입드 sort/술어, 사실, 한정 규칙, 1차 datatype 매칭], [구현됨],
  [L1], [이론 내부(`open` Int 원자) + CanEq 타입드 (비)동등성], [구현됨],
  [L2], [계층화 `not` + 무결성 제약 `:- B`], [구현됨],
  [L3], [안정 모델(비계층화 `not`) — 유계 GL reduct 게이트; 완전 unfounded-set + loop-formula 솔버는 이후], [첫 슬라이스 구현됨],
  [L4], [선택 `{…}` / 분리 머리], [계획],
  [L5], [집계 + 약 제약 / 최적화], [계획],
  [L6], [1급 귀추], [규칙 IR에 병합됨],
)

== 이론 내부와 CanEq (L1)

규칙 본문은 `{ … }` *이론 원자*를 가질 수 있다. `Int`
피연산자면 산술이다 — `big(T) :- dur(T, D), { D >= 4 }.`는
긴 작업만 남긴다. 비교 `=`/`!=`는 **CanEq**가 피연산자
sort로 라우팅한다: `Int`에서는 산술 동등성, 임의의 enum /
datatype에서는 *구조적* (비)동등성. 교차-sort 비교
(`Int = Node`)는 조용한 원자가 아니라 elaboration 오류이며,
재발하던 교차-sort 버그군이 face 경계에서 잡힌다. 내부적
으로 각 연산자는 커널이 타입 검사하고 grounder가 게이트의
`θ`로 평가하는 `open` 커널 기호(`#int.lt`, `#eq.S`, …)가
된다.

== 계층화 부정 (L2)

`not p(X)`는 `p(X)`가 유도되지 *않을* 때에만 *완전 모델*
에서 성립한다. 이는 **계층화** 아래에서만 건전하다: 어떤
술어도 자기 부정에 의존할 수 없다. elaborator는 의존
그래프를 만들어 프로그램을 *분류*한다. 계층화된 것은 완전
모델로 풀리며, 계층을 아래에서 위로 평가하므로 모든 `not`은
이미 결정된 하위 계층을 읽는다. *음의 사이클*은 더 이상
elaboration을 실패시키지 않고 아래의 L3 안정 모델 게이트로
라우팅된다. `not` 아래의 모든 변수는 양의 본문 원자로도
묶여야 한다(자유 변수는 닫힌 세계 부정이 아니라 전칭이
된다).

```text
single(X) :- person(X), not married(X).
```

== 안정 모델 (L3, 첫 슬라이스)

프로그램이 *비계층화*일 때 — 짝수 사이클 `p :- not q.
q :- not p.`처럼 술어가 자기 부정에 의존할 때 — 단일 완전
모델이 아니라 *안정 모델*(답 집합)들의 집합이 있다. 첫 L3
슬라이스는 신뢰되는 최소 고정점을 그대로 재사용하는
**Gelfond–Lifschitz 환원(reduct) 게이트**로 이를 결정한다:
집합 `M`이 안정 모델인 것은, *환원* `P^M`(`not q`, `q ∈ M`인
규칙을 모두 버리고 살아남은 규칙의 `not` 리터럴을 삭제)의
최소 모델이 `M`과 같을 때다. 후보 열거기는 신뢰되지 않는다
— 버그는 비안정 `M`을 제안하거나(인증이 곧 재계산이므로
거부됨) 하나를 빠뜨릴 수 있을 뿐(건전한 과소 보고), 틀린
모델을 인증하지 못한다. 탐색은 유계다: 후보를 `L ⊆ M ⊆ U`로
가두고 작업 예산을 넘으면 *시끄럽게* abstain한다(완전한
unfounded-set + loop-formula 솔버는 이후 슬라이스). 따라서 큰
사례는 멈춤이 아니라 `FaceError`를 낸다. 여러 모델에 대한
질의는 *조심스럽게*(cautious, 모든 안정 모델에서 참) 답한다.
`Solution.stable`이 답 집합을 담는다.

```text
d(x).                     % d(x) 위 짝수 사이클:
p(X) :- d(X), not q(X).   %   두 답 집합,
q(X) :- d(X), not p(X).   %   {d(x),p(x)}와 {d(x),q(x)}
```

== well-founded 모델 (full 출력 모드)

typed-ASP face는 런타임에서 `adsmtr --asp`(또는 REPL의
`:asp`)로 도달한다. 기본값(`--output-mode z3`)에서는 답이
3상태로 collapse한다. `--output-mode full`(`:full`)에서는
face가 대신 *3-값 well-founded 모델*을 노출한다: 모든 ground
원자가 `true`, `false`, `undefined` 중 하나로 분류되며,
`undefined` 집합은 well-founded 의미론이 미해소로 남기는 원자
정확히 그것이다 — 예컨대 짝수 루프(`p :- not q. q :- not p.`)의
진동하는 원자들은 추측되는 대신 `undefined`다. 렌더 형식은
`well-founded true={…} false={…} undefined={…}`이다
(true = well-founded 하계, undefined = 아직 추측할 잔여,
false = 나머지). 이는 관찰/출력 표면이며(실험적, AFT 채택),
collapse된 판정은 바뀌지 않는다.

== 귀추 — 규칙의 쌍대

연역과 귀추는 *하나의* 규칙 IR을 공유한다. 전방 최소
고정점은 답-집합 소속을 계산하고, 같은 규칙을 후방으로
읽으면 귀추가 된다. `?- abduce G`는 가정하면 `G`를
성립시키는 ⊆-최소 abducible 원자 집합들을 반환한다. *빈*
설명은 `G`가 이미 함의됨을 뜻한다(연역 = 빈-abducible
귀추). 8장의 귀추 계층을 그대로 재사용한다 — 닫힌 세계
face가 그 전방 방향이 사는 곳이다.

== 표면 설탕

순수 desugaring(각각 코어로 펼쳐지므로 커널 + 고정점이
재검사 — 건전성 자동):

- *익명 `_`* — 출현마다 서로 다른 새 변수(`p(_, _)`는
  `p(X, X)`가 아니다).
- *풀링 `;`* — `color(red; green; blue).`는 세 사실로
  펼쳐지며 위치 간 데카르트 곱.
- *정수 구간 `..`* — `value(1..3).`은 `value(1)`,
  `value(2)`, `value(3)`으로 펼쳐진다(포함, 리터럴 경계).
  풀링 가능하며 폭발에 대해 한도가 걸린다.

== 건전성 방화벽

커널은 *타이핑*과 *양의 유도*를 인증하고, 신뢰되지 않는
grounder + 재검산 가능한 최소-고정점 게이트가 닫힌 세계
모델을 인증한다. 둘은 판단을 공유하지 않는다. 버그 있는
grounder나 휴리스틱은 답 집합을 *줄이거나* `Unknown`만
낼 뿐 거짓 함의를 만들지 못한다. abstain 경계는 넓고
의도적이다: 안전하지 않은 규칙(미묶임 변수), 무한 도메인,
작업 예산을 넘긴 안정 모델 탐색은 근사가 아니라 `FaceError`나
`Unknown`이다. 비계층화 프로그램은 더 이상 거부되지 않고 L3
게이트로 라우팅되며, 그 "답 집합 없음" 판정은 그 한도 *안에서*
건전하다(유계 탐색이 완전하고 재검산 가능하다).

== lu-kb·SMT-LIB와의 비교

#table(
  columns: 4,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*관심사*], [*SMT-LIB*], [*lu-kb*], [*typed-ASP*]),
  [세계],   [열린], [열린], [닫힌(최소 모델)],
  [질문],   [목표의 SAT], [KB의 SAT], [유일 모델],
  [부정],   [고전], [고전], [계층화 + 안정 NAF],
  [귀추],   [`(abduce)`], [`rule` 경유], [네이티브(규칙 쌍대)],
  [이론],   [네이티브], [네이티브], [`{…}` 내부, 같은 엔진],
)

세 표면 모두 같은 커널로 elaborate되므로 sort / datatype /
이론 원자는 셋 사이에서 같은 것을 뜻한다. 다른 것은
*세계 가정*과 *질문*뿐이다.
