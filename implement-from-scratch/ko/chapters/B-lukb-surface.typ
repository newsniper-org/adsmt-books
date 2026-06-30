= lu-kb 표면

`lu-kb` 는 adsmt가 받아들이는 두 번째 입력 방언이다. 이
이름은 *logicutils* 프로젝트에서 비롯되었으나(RC1.4.A에서
흡수, `ABSORPTION_PLAN.md` 참조), 여기서 설명하는 표면은
*lu-kb 후속(successor)* — `adsmt-ir-lukb` 에 구현된 현대적
방언이다. 레거시 lukb가 logicutils 지식 베이스를 겨냥한
`fun` / `rule` / `class` / `instance` / `query` 블록의
느슨한 묶음이었던 반면, 후속은 작고 의무(obligation)
형태를 띤 모듈 언어이다. 즉 종(sort), 상수, 함수, 데이터
타입, 신뢰된 사실을 설정하는 *항목(item)*의 시퀀스이고,
그런 다음 방출(discharge)할 *목표(goal)*를 진술한다. 이는
손으로 작성한 검증 조건과 3장의 타입 관계 작업에 대해
adsmt가 선호하는 표면이다.

레거시 `.kb` 블록 문법은 하위 호환성을 위해 여전히
파싱되지만(`adsmt-parser/src/lukb/` 마이그레이션 체인은
손대지 않았다), 더 이상 권장되는 저작 표면은 아니며 여기서
더 다루지 않는다.

== 표면 형태

lu-kb 모듈은 *항목(item)*의 시퀀스이다.

```text
sort Shape

const c: Int

fn area(s: Shape): Int

data Nat = zero | succ(Nat)
data List = nil | cons(head: Int, tail: List)

axiom area_pos: forall s. area(s) >= 0
assume c_small: c <= 10
goal:    forall s. area(s) >= 0
```

각 항목은 `sort`, `const`, `fn`, `data`, `axiom`,
`assume`, `goal` 중 하나이다. 문법은 `adsmt-ir-lukb`
(`lexer.rs`, `parser.rs`, `ast.rs`)에 있으며, 각 항목을
3장의 커널 IR로 정련(elaborate)한다.

== 항목

*`sort <name>`* — 불투명한(uninterpreted) 종(sort)을
선언한다. SMT-LIB의 `declare-sort` 와 동등하다.

*`const <name>: <type>`* — 자유 상수, 예컨대 VC 변수이다.
타입은 정련(아래)을 포함한 임의의 타입 표현일 수 있다.

*`fn <name>(<params>): <ret> [= <body>]`* — 함수이다. 각
매개변수 그룹 `names: ty` 는 타입을 공유하므로,
`fn f(x: Int, y z: Bool): U` 는 `f : Int -> Bool ->
Bool -> U` 를 선언한다. `= body` 가 *없으면* 함수는
그 화살표 타입에서 설정된 불투명한 *시그니처*(`open`
기호, `Bool` 은 `Prop` 으로 사상)이다. `= body` 가
*있으면* 비재귀 *정의*(`f := λ(params). body`)이며,
솔버 하강(lowering) 시 δ-펼침된다. `f` 를 언급하는
본문(진짜 재귀)은 커널 `fix` 가 필요하며 이후 슬라이스에
속한다.

*`data <name> = <ctor> | ...`* — 비매개변수
귀납(inductive) 데이터 타입으로, `declare_inductive` 로
정련된다. 각 생성자는 필드 목록을 가진다. 필드는
자신의 선택자(selector)에 이름을 줄 수도 있고(`head: Int`)
위치식(`Int`)일 수도 있다. 생성자는 항(term)으로 사용
가능하다.

*`axiom [<name>]: <formula>`* — 신뢰된 가설($in H$)이다.
엔진 시작 시 단언(assert)된다.

*`assume [<name>]: <formula>`* — VC 경로 조건($in H$)이다.
`axiom` 과 신뢰 지위는 같으며, 차이는 의도이다(`assume`
은 검증 경로를 따라 운반되는 사전조건이다).

*`goal [<name>]: <formula>`* — 방출할 의무이다. 본문은
시퀀트 `H1, ..., Hk |- G` 로 작성할 수 있으며, 파싱 시
`(H1 and ... and Hk) ==> G` 로 풀어 쓴다(desugar). 목표는
`assert (not phi)` 뒤에 `check-sat` 이 따르는 것에 대응하며,
판정은 이름으로 보고된다.

== 통합 판정(unified verdict)

lu-kb 후속 모듈은 `adsmtc` 컴파일러(배치)나 `adsmtr`
런타임/REPL이 풀이하며, *UnifiedVerdict* 를 생산한다 — SMT
정밀도 쪽과 typed-ASP 부분성(partiality) 쪽이 서로 다른 질문에
답하기에 의도적으로 하나의 격자로 융합하지 *않은* *분리곱
(separated product)* `{ smt, asp }` 이다. asp 쪽은 typed-ASP
face(부록 D)만 채우며, 순수 lu-kb 모듈은 smt 쪽을 사용한다.
통합 판정은 두 쪽의 3-값 *Kleene 논리곱*을 통해 3상태로
collapse한다 (어느 한 쪽의 `unsat` 이 전체를 지배한다).
Verus/SMT 관례에 따라 목표 `G` 는 `H ∧ ¬G` 가 unsat일 때만
valid하므로, *방출된(discharged)* 의무는 `unsat` 으로 읽힌다.
`--output-mode full` 에서 smt 쪽은 5단계 정밀도 격자
(`definite-sat` … `definite-unsat`)로 un-collapse한다. 이
표면의 완전한 문서는 `docs/design/LUKB_SUCCESSOR_SURFACE.md`
10절에 있다 (참조용이며 그 파일의 산문을 복제하지 않는다).

== 정련 타입(Refinement types)

*정련 타입* `{v: T | φ}` 은 기반 종 `T` 를 바인딩된 이름
`v` 에 대한 술어 `φ` 로 깎아낸 것이다. 타입이 올 수 있는
어디서든 사용 가능하며 — `const` 타입, `fn` 매개변수와
반환 타입, 화살표의 정의역과 공역 — *양화사 바인더*로도
쓰인다.

두 정련 사이트는 극성(polarity)으로 구분된다.

- 정련된 상수를 *설정*하는 경우. `const c: {v: T | φ}` 는
  `c: T` *와* 더불어 신뢰된 사실 `φ[v := c]` 를 도입한다.
  정련이 당신에게 주어진다.

- 정련에 대해 *양화*하는 경우. 정련된 바인더는 양화사를
  상대화(relativize)한다. `∀` 는 가드를 얻고
  (`forall x: {T | φ}. ψ` 는 `forall x: T. φ ==> ψ` 가
  된다), `∃` 는 연언지(conjunct)를 얻는다
  (`exists x: {T | φ}. ψ` 는 `exists x: T. φ and ψ` 가
  된다). 이 `∀ -> ⟹`, `∃ -> ∧` 규칙은 선검증된 상대화
  보조정리이며, sat-보존적이다.

`Nat` 과 `WNat` 는 정확히 `Int` 의 정련이다.

```text
Nat  = { x: Int | x >= 1 }
WNat = { x: Int | x >= 0 }
```

따라서 `Nat` 타입 값의 양수성(positivity)은 솔버가 받는
*사실*이지, 불투명한 종의 벽이 아니다
(`NAT_WNAT_REFINEMENT_COLLAPSE.md` 참조).

== 함수 타입과 정련된 화살표

`T -> U` 는 함수 타입이며 *우결합(right-associative)*이다.
`A -> B -> C` 는 `A -> (B -> C)` 로 파싱된다. 화살표를
정의역 위치에 놓으려면 괄호로 묶는다: `(A -> B) -> C`.

*정련된 화살표*는 화살표에 계약(contract)을 붙인다.

```text
{u: A | 'p} -> {v: A | 'q}
```

정의역 정련 `'p` 는 *사전조건*이고 공역 정련 `'q` 는
*사후조건*이다. 정련된 화살표의 *값* 종은 그냥 평범한
`A -> A` 이다 — 정련은 증명-무관(proof-irrelevant)하며
하강 시 지워진다 — 그러나 장식이 아니다. 이 타입으로
공급된 인자는 호출 지점에서 `'q` 를 사용 가능한 사실로
운반한다. 정련된 화살표는 "성질을 보존하는 함수"가 *타입
지정*되는 방식이며, 실제로 보존한다는 의무는 별도로
방출된다(아래 *일반 술어 매개변수*와 *상 바인더와 보존*
참조).

== 일반 술어 매개변수 `'p`

선행하는 작은따옴표 하나는 *일반 술어 매개변수(generic
predicate parameter)*를 표시한다 — 항목이 그에 대해
다형적(polymorphic)인 술어이다. 따옴표 없는 맨 식별자 `q`
는 *구체(concrete)* 술어이며, 따옴표가 파싱 시 둘을
구분 짓는다.

`fn` 의 정련이 `'p` 를 언급하면 `fn` 은 그것을 머리에서
`Π('p: T -> Prop)` 로 *암묵적으로* 바인딩한다. 본문은
`'p` 를 추상으로 둔 채 *한 번* 타입검사된다 —
"한-번-검사됨" 보장: 일반 정련 함수는 한 번 검증되어 모든
인스턴스화에서 재사용되며, 사용마다 재검사되지 않는다.

매개변수 정련은 사전조건이고 반환 정련은 사후조건이므로,
일반 함수는 다음 계약을 운반한다.

```text
forall 'p... . forall x... . (pre_1 and ... and pre_k) ==> post
```

이 계약은 두 `fn` 형태에 대해 반대 방향으로 읽힌다.

- *정의*(`= body`)의 경우, 계약은 *목표*이다 — 본문이
  실제로 사후조건을 만족한다는 구성-지점(construct-site)
  의무이다.

- *시그니처*(본문 없음)의 경우, 계약은 *신뢰된 공리*이다.

사용 지점에서 매개변수가 인스턴스화되고(`'p := q`), 이제
단형(monomorphic)이 된 사전조건이 방출된다 — 고전적인
사전(dictionary) 전달이다. 구체 정련 함수(정련이 `'p`
대신 맨 `q` 를 언급하는 것들)도 동일한 계약 처리를 받으며,
다만 선행하는 `Π` 가 없을 뿐이다.

== 자명 술어 `nop`

`nop` 은 항상-참인 술어이다.

```text
nop : Π(T: Type). T -> Prop := λ T x. true
```

이는 정련-인식 로직이 정련 없는 값에 대해서도 *항상*
술어를 보도록 존재한다. 정련 없는 `x: T` 는
`{x: T | nop(x)}` 로 균일하게 취급된다. `nop(x) ≡ true`
이므로 `nop` 정련은 공허(vacuous)하다. 가설도 가드도
방출하지 않으므로 `const c: {v: T | nop(v)}` 는 정확히
`const c: T` 이며 출력이 깨끗하게 유지된다. `nop` 은 정련
격자(lattice)의 바닥이다 — 위의 술어 매개변수 중 하나가
제약 없이 남았을 때 "제약 없음" 슬롯이 떨어지는 자리이다.

== `solve ... by ...` 증명항

`solve G by L` 은 *언어-내(in-language) 증명항*이다. 명제
`G` 의 증명으로서 보조정리 `L` 로 정당화된다. 이는 구조화
증명의 *컷(cut)*을 표면 구문으로 만든 것이다. `G` 와 `L`
은 각각 *블록*이다 — 항이며 어쩌면 `let`-체인일 수 있다.

그 의미론은 런타임 풀이가 아니라 *증명항 구성*이다.
`solve G by L` 은 두 의무로 정련되며, 둘 다 주변 문맥에
대해 닫혀(close) 있어 각각 최상위에서 잘 형성된다.

- *잎(leaf)* 의무 `L`, 그리고
- *다리(bridge)* 의무 `L ==> G`.

커널은 증명 골조(컷)를 세우고, 엔진은 잎을 방출한다.
건전성은 정확히 컷 규칙이며 — 새 공리도, 판정 지름길도
없다 — 건전성 핵심은 Verus에서 선검증되어 있다
(`~/solve-by-verification`, 5건 검증, 오류 0).
`SOLVE_BY_PROOF_TERMS.md` 참조.

전형적 사용은 함수가 보존 계약을 만족함을 증명하며, 증명을
중간 보조정리를 거쳐 인수분해한다.

```text
fn double(x: Int): Int = x + x

// `double` 은 비음성(nonnegativity)을 보존한다. 목표는
// 정련된 화살표 계약이고, `by` 는 본문에 대한 보조정리를
// 통해 컷한다.
goal double_preserves:
  solve (forall x: {v: Int | v >= 0}. double(x) >= 0)
  by    (forall x: Int. x >= 0 ==> x + x >= 0)
```

엔진은 산술 잎 `forall x. x >= 0 ==> x + x >= 0` 을
방출하고, 커널은 그 잎에서 정련된 화살표 목표로의 다리를
공급하며, 목표는 컷으로 증명된다.

== 상 바인더(Image binders)와 보존

*상 바인더* `{y = f(x) | c}` 는 타입 추론으로 구동되는
양화사 약칭이다. 추론된 *원상(preimage)* `x`(그 종은
`f` 의 정의역) 위를 제약 `c` 로 가드하며 순회하고, 본문
안에서 `y` 를 `f(x)` 로 펼친다.

```text
forall {y = f(x) | p(x)}. q(y)
  ≡  forall x: {A | p(x)}. q(f(x))
```

이는 선검증된 `image_quantifier_desugar` 이다. 원상을
명시적으로 명명하지 않고 "`f` 의 상에 있는 값들"에 대해
양화할 수 있게 해 준다.

상 바인더는 *보존(preservation)* 진술의 자연스러운
운반체이다. 핵심 설계 지점: *보존은 고차 술어이지 타입
관계가 아니다.* 타입 관계는 정합적(coherent)이다 — 타입당
인스턴스 하나 — 그러나 단일 데이터 타입 `A` 는 성질 `'p`
를 보존하는 함수를 *여럿* 가질 수 있다. 따라서 "`'p` 를
보존함"은 *함수*의 성질이며, 고차 술어 `preserving(f)` 로
작성되어 함수마다 검사되고, 통상 정련된 화살표 인자에 대한
`solve ... by ...` 를 통한다. (이전의 `Preserving('p)`
*타입 관계* 시도는 잘못된 추상화로 폐기되었다.)

== 타입 관계는 타입 클래스이다

adsmt에서 "타입 관계"는 타입 클래스를 가리키는 *바로 그*
용어이다 — 하나의 개념이며, `adsmt-class`(문자 그대로
"타입-클래스 계층")에 구현되어 있다. 어휘는 `Relation` /
`Instance` / `Resolver` / `Dict` / `Law` 이다. 관계는 각
인스턴스가 사전 항목으로 공급하는 *술어 매개변수*
`'p : T -> Prop` 도 운반할 수 있다 — 위 `fn` 머리와
동일한 일반-술어 메커니즘이다.

*\*Like 패밀리* (`PartialOrd` -> `Ord` ->
`IntegerLike`, `RealLike`, ...)는 `Reduces` 척추를
공유하며, `IntegerLike(I, L, N)` 은 첫 번째 고차-종류
(higher-kinded) 타입-클래스 인스턴스이다. 이는 *4중
맞물림(four-way interlock)*의 연결 조직이다 — 타입 추론,
가설추론-연역 로직, ASP, SMT(그리고 HKT)가 별개의 사일로에
사는 대신 유기적으로 맞물린다는 핵심 설계 의도이다.

관계는 *증명에 의해 합법적(lawful by proof)*이다. 관계는
메서드 멤버와 나란히 *법칙(law)* 목표-멤버를 운반하며,
인스턴스는 adsmt 자신의 엔진이 *모든* 법칙을 증명할 때만
받아들여진다 — 그렇지 않으면 빌드가 *거부*된다. 이것이
`declare_instance_lawful` 에 엔진-지원 `LawProver` 를 더한
것이다. 합법성은 관례가 아니라 방출된 의무이며, 정련 `fn`
정의가 운반하는 구성-지점 목표와 같은 정신에서 비롯한다.

== SMT-LIB와의 비교

lu-kb는 풍부한 타입으로 의무를 저작하기에 맞는 형태인
반면, SMT-LIB는 평탄한 목표를 방출하기에 맞는 형태이다.

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*관심사*], [*SMT-LIB*], [*lu-kb 후속*]),
  [입자성(Granularity)], [목표별(per goal)], [모듈별(per module)],
  [상수], [`declare-const`], [`const x: T`],
  [함수], [`declare-fun` / `define-fun`], [`fn` 시그니처 / 정의],
  [정련 타입], [기본 미지원], [임의 타입 위치의 `{v: T | φ}`],
  [계약], [수동 부수 조건], [정련된 화살표 + 일반 `'p`],
  [증명 구조], [평탄한 assert/check], [`solve ... by ...` 컷],
  [타입 클래스], [기본 미지원], [타입 관계(증명에 의해 합법적)],
)

두 표면 모두 동일한 커널 IR로 컴파일되므로, 정련이 끝나면
엔진 동작은 동일하다 — 차이는 전적으로 *저자*가 앞서 무엇을
말할 수 있는가에 있다.

== 편집기 통합

VS Code 확장(`tooling/vscode-extension/` 아래)은 `.smt2`
와 lu-kb 확장자를 인식한다. LSP 서버(`adsmt-lsp`)는 확장자에
따라 파일을 적절한 파서로 라우팅한다. 완성 목록은 활성
표면에 맞추어 조정되어, 후속 키워드(`sort`, `const`, `fn`,
`data`, `axiom`, `assume`, `goal`, `solve`)를 호환성
파서가 여전히 받아들이는 레거시 블록 키워드와 함께 제공한다.
