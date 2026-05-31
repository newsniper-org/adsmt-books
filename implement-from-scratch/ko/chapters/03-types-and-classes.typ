= 타입과 클래스

== 왜 higher-kinded types인가

고전적 SMT 솔버는 다중-sort 1차 논리에서 작업한다. 그
설정에서 "sort"는 평평하다: `Int` sort, `Real` sort,
`Bool` sort, 그리고 인덱스 sort와 원소 sort의 각 쌍에
대해 배열 sort `(Array I E)` 등이 있다. 타입 추상 —
한 sort를 받아 다른 sort로 매개변수화하는 것 — 은
시그니처 빌더가 메타 수준에서 수행하며, 식 언어 자체에서는
보이지 않는다.

이는 SMT 워크로드의 대부분에서 잘 작동한다. 대화형 정리
증명기와의 경계에서 마찰이 생긴다. 정리 증명기는
일상적으로 함자, 타입-수준 함수, 다형적 구조에 *관한*
증명을 다루기 때문이다. Lean 4의 증명 의무를 SMT 솔버로
반영했다가 다시 받아오려면, 솔버가 Lean과 같은 것에
대해 이야기할 수 있어야 한다: 타입을 매개변수로 받는 타입,
higher kinds에서의 인스턴스, 그리고 진정한 타입-수준
다형성 같은 것 말이다.

adsmt의 해법은 솔버 자신의 표면에서 *higher-kinded
types*를 받아들이는 것이다. 한 타입이 다른 타입으로
매개변수화될 수 있다. 마치 Haskell의 `List`가 임의의 원소
타입에 적용되어 `List Int`, `List String`,
`List (List Bool)` 등을 산출하는 것과 같다. 구체적으로,
kind 시스템은 표준적인 kind 형성자들을 추가한다:

$ kappa ::= "Type" | kappa_1 -> kappa_2 $

그리고 타입은 이제 계층화된다:

$ tau ::= alpha^kappa | C^kappa | tau_1 tau_2 | tau_1 -> tau_2 $

여기서 각 변수와 상수 위의 kind 표기 $kappa$는 그 엔터티가
받기를 기대하는 타입 인자의 개수를 추적한다. `Int`는
kind `Type`을 가지고, `List`는 kind `Type -> Type`을
가지며, `Functor` 클래스는 kind `Type -> Type`의 엔터티
위에서 동작한다.

== 다형 상수

`id : forall alpha. alpha -> alpha`와 같은 다형 상수는
단일 타입이 아니라 *타입 스킴* — 보편적으로 양화된 타입
— 을 갖는다. `id`가 특정 인스턴스화(`id @Int` 등)로
사용되면 커널 규칙 `InstType`이 치환을 수행한다. 이는
ML 양식의 다형성과 같은 기구를 higher kinds를 받아들이도록
올린 것이다.

코드로는:

```rust
pub struct TyVar { pub name: String, pub kind: Kind }
pub enum Type {
    Var(Arc<TyVar>),
    Const(Arc<TyConst>),
    App(Arc<Type>, Arc<Type>),
    Fun(Arc<Type>, Arc<Type>),
}

pub fn inst_type(
    sigma: &[(Arc<TyVar>, Type)],
    thm: &Theorem,
) -> KernelResult<Theorem> {
    // Substitute every TyVar matching sigma's left-hand sides;
    // produce a new Theorem at the substituted types.
}
```

`inst_type`은 12개의 커널 규칙 중 하나이다. 치환이
kind를 존중해야 하므로 형식적으로는 부분함수다.

== 타입 클래스

*타입 클래스*는 타입에 대한 술어 양식의 관계이며,
연산들의 명시적 사전(dictionary)을 동반한다. adsmt의
표면에서 사용자는 다음과 같이 쓴다:

```
class Ord (a : Type) where
  le : a -> a -> Bool
```

그리고 사용 지점에서는:

```
instance Ord Int where
  le = int_le
```

클래스는 문법적 설탕이다. 커널이 보는 것은 다음과
같다:

- 고정된 항수의 *관계*(`Ord`) — 하나 이상의 타입을 받으며,
  kind 제약이 있을 수 있다.
- 특정 타입들이 그 관계의 원소임을 주장하는 *인스턴스
  증거*들 — 연산의 사전을 동반한다.
- 모든 사용 지점에서 인스턴스 조회를 해소하는 *클래스
  적용*.

`Instance` 경계 규칙(2장)이 정확히 이 계층으로의
경계이다: 인스턴스 해소를 타입-클래스 구체화기에 위임하고
반환된 증거를 신뢰한다.

== 사전 전달

클래스는 *사전 전달*(dictionary passing)로 컴파일되어
사라진다: 모든 클래스 제약이 있는 함수는 사용 지점마다
명시적 사전 매개변수를 얻는다. 함수

```
sort : (Ord a) => List a -> List a
```

는 다음과 같이 된다:

```
sort_with_dict : OrdDict a -> List a -> List a
```

사전을 명시적으로 전달하면서 말이다. 솔버는 내부적으로
1급 클래스 인스턴스를 결코 필요로 하지 않는다. 사전
전달이 수행되고 나면, 시스템의 나머지는 보통의 함수
적용을 보게 된다.

이는 GHC가 Haskell 클래스를 컴파일하는 데 사용하는 것과
같은 기법이며, Lean 4가 자신의 타입-클래스 계층에 쓰는
것과도 같다. 사전은 그대로 운반될 수 있는 평범한
항-수준 구조이므로 증명 반영을 단순하게 만든다.

== Higher-kinded 관계

`Functor` 클래스는 kind `Type -> Type`의 엔터티 위에서
동작한다:

```
class Functor (f : Type -> Type) where
  map : (a -> b) -> f a -> f b
```

이 kind에서의 인스턴스는 다음과 같이 생겼다:

```
instance Functor List where
  map = list_map
```

인스턴스 조회는 kind `Type -> Type`에서 일어난다 — 정확히
higher-kinded 위치다. 커널은 이를 같은 `Instance` 규칙으로
처리한다. 차이는 `types: Vec<Type>` 필드가 더 높은 kind의
엔터티들을 운반한다는 점, 그리고 인스턴스 조회 시점에
kind-검사기가 참조된다는 점뿐이다.

== 구현 노트

몇 가지 표시해둘 만한 엔지니어링 결정.

*Kind 추론은 양방향이다.* 사용자가 타입 표현식을
작성하면 보통 위치로부터 kind가 분명해진다. 구체화기는
이를 추론하고 모호함을 거부한다. 이는 Haskell의
`KindSignatures` 기구가 하는 일과 일치하며, Lean 4가
하는 것에도 근사하다. 구현은 수백 줄 정도에 들어간다.

*타입 클래스는 적극적으로(eagerly) 해소된다.* 클래스
제약이 있는 식이 구체화될 때 인스턴스 조회가 즉시
일어나고 사전이 인라인된다. 런타임 조회는 없다. 이는
나중에 보상으로 돌아온다 — SAT/이론 계층은 보류 중인
인스턴스에 대해 추론할 필요가 결코 없다.

*Higher-kinded 다형성은 표면에서 선택적이다.* 결코
`(f : Type -> Type)` 제약을 쓰지 않는 사용자는 1차
같은 느낌의 경험을 얻는다. HKT 기구는 표면 아래에
있으면서 필요할 때 준비되어 있으며, 필요하지 않을 때는
비용이 들지 않는다.

== HOL+HKT의 비용

이 설계 선택은 공짜가 아니다. HOL+HKT용 올바른 커널을
작성하는 것은 1차 논리용보다 더 어렵고, 일반성을 온전히
다루는 이론 솔버를 작성하는 것도 더 어려우며, 증명
반영에서 더 많은 주의를 요구한다. 이익 — ITP-친화적
표면, 매끄러운 반영, 타입화된 프로그래밍에 인접한 증명
의무에 대한 표현력 — 이 그 비용을 정당화한다. *당신의*
솔버에 그것이 가치가 있는지는 당신만이 답할 수 있는
질문이다. adsmt의 답은 그렇다이다.

다음 장은 우리를 SAT 계층으로 데려간다. SAT 계층은
의도적으로 커널과 독립이다: SAT 풀이는 타입이나 higher
kinds에 대해 아무것도 모르며, 오직 CNF 식의 부울
충족 가능성만 안다. 커널과 SAT 계층은 모든 이론 원자가
부울 리터럴이 되는 평평한 인터페이스를 통해 서로
이야기한다.
