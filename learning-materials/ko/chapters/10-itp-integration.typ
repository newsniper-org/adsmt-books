= ITP 통합

== 세 가지 통합, 하나의 설계

adsmt는 세 시스템에 대한 ITP 통합을 함께 제공한다.

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*상태*]),
  [Lean 4],   [In-tree 레퍼런스 (`adsmt-cert::prover_emit::lean`)],
  [Rocq],     [Out-of-tree (`~/adsmt-contrib/adsmt-emit-rocq`)],
  [Isabelle], [Out-of-tree (`~/adsmt-contrib/adsmt-emit-isabelle`)],
)

세 통합은 lockstep 진화를 강제하는 *앵커* 트레이트를
공유한다. 어떤 새로운 인증서 단계 종류든 컴파일되기
전에 셋 모두에 구현되어야 한다 (컴패니언 10장). 출력
형태는 정확히 거울 대칭이다. 각 Lean의 `have` 는 Rocq의
Ltac2 `Notation.notation` 과 Isabelle Isar의 `have` 에
대응한다.

Lean 4가 레퍼런스이다. Rocq과 Isabelle은 이를 미러링한다.

== Lean 4 — 레퍼런스

Lean 4 경로는 다음과 같다.

1. 사용자가 증명 스크립트에 `smt_decide` 또는
   `smt_abduce` 를 작성한다.
2. 택틱 하네스가 목표를 SMT-LIB 더하기 맥락 가설로
   컴파일한다.
3. `adsmt` 가 풀어낸다. 인증서를 방출한다.
4. `prover_emit::lean` 이 인증서를 Lean 택틱 스크립트로
   번역한다.
5. Lean의 elaborator + 커널이 스크립트를 검사한다.
   통과하면, 원래 목표가 처리된다.

```lean
import Adsmt

example (a b c : Nat) (h1 : a = b) (h2 : b = c) : a = c := by
  smt_decide [h1, h2]
```

장막 뒤에서는 다음과 같이 진행된다.

```text
goal:         a = c
hypotheses:   h1 : a = b, h2 : b = c
to SMT-LIB:   (assert (= a b)) (assert (= b c)) (assert (not (= a c)))
solver run:   unsat with cert
              (step :rule assume :id 1 :term (= a b))
              (step :rule assume :id 2 :term (= b c))
              (step :rule trans  :id 3 :lhs 1 :rhs 2)
              (step :rule assume :id 4 :term (not (= a c)))
              (step :rule deduct :id 5 :hyp 4 :conc 3)
emit:         have h_3 : a = c := Trans.trans h1 h2
              exact absurd h_3 (by intro; assumption)
Lean kernel:  ✓ goal discharged
```

택틱은 완전히 커널이 검사한 증명 속으로 사라진다.
인증서 계층은 사용자에게 보이지 않는다.

== `smt_decide` 대 `smt_abduce`

두 가지 택틱, 두 가지 의도가 있다.

- `smt_decide` — *연역* 모드로 adsmt를 호출한다. 오직
  `sat` / `unsat` 판정만이 목표를 닫는다. `unknown` 은
  실패한다.
- `smt_abduce` — *가설추론* 모드로 adsmt를 호출한다.
  `unsat` 은 목표를 닫고, `abductive` 는 스크립트에
  후보 `sorry` 자리표시자를 노출한다.

```lean
example (n : Nat) : f n ≤ g n := by
  smt_abduce
-- emits:
-- have hyp_f : ∀ n, f n ≤ n := by sorry
-- have hyp_g : ∀ n, n ≤ g n := by sorry
-- exact Nat.le_trans (hyp_f n) (hyp_g n)
```

사용자는 자신의 증명으로 `sorry` 들을 채우거나 (또는
이를 스코프 내의 추가 공리로 받아들인다). 증명의
*구조*는 adsmt가 제공하고, 가정의 *내용*은 사용자의
책임이다.

== `solve … by …` — 언어 내부의 증명항

위의 택틱들은 adsmt _바깥에_ 산다. Lean이나 Rocq
스크립트가 안으로 호출해 들어온다. 그러나 lukb 후속
표면 (`adsmt-ir-lukb`; lukb를 밑바닥부터 구현하는 부록을
보라) 은 ITP 스타일 증명으로의 자체 _언어-내부_ 다리를
가진다. 그것은 하나의 구문이다.

```lukb
solve G by L
```

이를 "_보조정리 `L` 에 의해 정당화되는 `G` 의 증명_"
으로 읽으라. `G` 와 `L` 은 둘 다 *블록* — 항, 또는 항으로
끝나는 `let`-사슬 — 이므로, 양쪽 어느 쪽에서든 중간
사실들을 쌓아 올릴 수 있다.

이것은 *컷 규칙* 을 구문으로 만든 것이다. elaboration
(시맨틱스 B: 그것은 _증명항을 구성_ 하며, 파싱 시점에
솔버를 돌리지 않는다) 은 정확히 두 개의 의무를
방출하며, 각각은 주변 맥락에 대해 닫혀 있어 최상위
수준에서 잘-형성된다.

- *잎* `L` — 보조정리를 처리하고,
- *다리* `L ⟹ G` — 보조정리가 목표를 함의함을 보인다.

커널은 이 둘로부터 증명 골격을 조립하고, 엔진은 잎을
처리한다. 사용되는 추론이 컷뿐이므로 — 공리도, 판정-
지름길도 없으므로 — `solve` 는 구성에 의해 건전하다.
건전성 핵심은 Verus에서 선검증되어 있다
(`~/solve-by-verification`, 5개 검증, 0개 오류).

```lukb
// goal: 정렬되고 비어 있지 않은 리스트의 머리는 그 최솟값이다.
goal head_is_min : is_min(head(xs), xs) =
  solve is_min(head(xs), xs)
  by    sorted(xs) and nonempty(xs)
```

잎 `sorted(xs) ∧ nonempty(xs)` 는 _당신이_ 갚아야 할
것이고, 다리 `(sorted(xs) ∧ nonempty(xs)) ⟹
is_min(head(xs), xs)` 는 엔진이 검사하는 것이다.
`smt_abduce` 와의 유비는 정확하다 — `solve` 는 가설추론적
`sorry` 의 연역적, _이미-정당화된_ 형제이다. 구멍을
남기는 대신 보조정리를 명명하며, adsmt는 그 단계를
추측하는 대신 검증한다.

== 정제 타입이 의도를 실어 나른다

`solve` 는 당신이 _진술할_ 수 있는 명제만큼만 날카롭다.
lukb 후속 표면은 검증 의도를 *정제 타입* 으로 진술한다.
서술어로 깎아낸 기반 정렬,

```lukb
{ v: T | φ }
```

— `φ` 를 만족하는 `v` 들로 제한된 정렬 `T`. 정제는 타입이
올 수 있는 어디서든 사용 가능하다. `const` 위에, `fn`
매개변수나 반환 위에, 화살표의 어느 쪽에든, 그리고
양화사 바인더로서. `Nat` 과 `WNat` 자신이 `Int` 의
정제이다 (`Nat = {x: Int | x ≥ 1}`,
`WNat = {x: Int | x ≥ 0}`).

정제된 타입의 `const` 는 타이핑 _과_ 서술어 _둘 다_ 를
신뢰되는 사실로 가정한다.

```lukb
const c : { v: Int | v ≥ 0 }   // gives  c : Int  AND  c ≥ 0
```

양화사 바인더 위의 정제는 선검증된 상대화 보조정리에
의해 elaborate 된다 — 기억해야 할 것은 극성이다.

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*바인더*], [*elaborate 결과*]),
  [`forall {v:T|φ}. ψ`], [`forall v:T. φ ⟹ ψ`],
  [`exists {v:T|φ}. ψ`], [`exists v:T. φ ∧ ψ`],
)

그래서 `∀` 는 함의로 약해지고, `∃` 는 연언으로 강해진다.
극성을 거꾸로 잡으면 공허한 의무이거나 충족불가능한
의무를 얻는다. adsmt의 elaborator가 당신을 위해 이를
고쳐 주지만, desugar 된 목표를 읽을 때 머릿속에 담아
둘 가치가 있다.

*함수 타입과 정제된 화살표.* `T -> U` 는 화살표이다
(오른쪽-결합. `(A -> B) -> C` 는 _화살표 정의역_ 을
괄호로 묶는다). 양 끝을 정제하면 화살표는 계약을
실어 나른다.

```lukb
{ u: A | 'p } -> { v: A | 'q }
```

— 정의역 위의 선행조건 `'p`, 공역 위의 후행조건 `'q`.
_값_ 정렬은 여전히 평범한 `A -> A` 이다. 정제는 증명-
무관하며 lowering 시 지워진다. 그 보상은, 이 타입으로
공급된 인자가 _그 후행조건 `'q` 를 사용 가능한 사실로
당신에게 건네준다_ 는 것이다 — 정확히 하류의 `solve` 가
원하는 가설이다.

== 일반 서술어 매개변수 `'p`

위의 `'p` 에서 앞에 붙은 작은따옴표는 장식이 아니다.
그것은 *일반 서술어 매개변수* 를 표시하며, 정의를
서술어-_다형적_ 으로 만든다. 정제가 `'p` 를 언급하는
`fn` 은 머리에서 그것을 `Π('p : T → Prop)` 로 암묵적으로
바인딩하며, 본문은 `'p` 를 추상적으로 잡은 채 *한 번*
타입체크된다 — "한-번-검사" 보장. 매개변수 정제는
선행조건이, 반환 정제는 후행조건이 되고, 전체 계약

$ forall arrow('p). thin forall arrow(x). thin
  (and.big_i "pre"_i) arrow.r.double "post" $

은 함수를 _정의할_ 때는 *목표* 이고 (구성-자리 의무로,
엔진이 처리한다), 그것이 _시그니처_ 일 뿐일 때는 *신뢰
되는 공리* 이다. 사용 자리에서는 `'p := q` 를 인스턴스화
한다. 이제 단형이 된 선행조건은 그 자리에서 처리된다.
이것이 *딕셔너리-패싱* 이다. 호출자가 피호출자가 추상화
한 서술어를 공급한다.

작은따옴표는 파싱 시점에 일반적 `'q` 를 *구체적* 서술어
`q` (따옴표 없음) 와 구별해 주는 것이다. 구체적 정제
`fn` 도 같은 계약 취급을 받는다 — 일반성이 유일한
차이이다.

*자명한 서술어 `nop`.* 균일성을 위해 정제-인지 로직은
항상 서술어를 보고 싶어 하므로, _정제되지 않은_ `x: T` 는
`{x: T | nop(x)}` 로 읽힌다. 여기서

```lukb
nop : Π(T: Type). T → Prop := λ T x. true
```

`nop(x) ≡ true` 이므로 `nop` 정제는 공허하다. 그것은
버려진다 — 가설도, 가드도 방출되지 않는다 — 그래서
desugar 된 출력은 깔끔하게 유지되고,
`const c: {v:T|nop(v)}` 는 그냥 `const c: T` 이다. 당신은
`nop` 을 결코 직접 쓰지 않을 것이다. 그것은 "정제됨" 과
"정제되지 않음" 이 하나의 코드 경로를 공유하게 하는
항등원이다.

== 한데 엮기: 보존

이 조각들은 작지만 실제적인 검증 관용구로 조합된다.
데이터타입 `A` 가 많은 함수를 가지고 있고, "_`f` 가 속성
`'p` 를 보존한다_" 고 말하고 싶다고 하자.

솔깃한 수는 `Preserving('p)` 를 *타입 관계* (타입
클래스에 대한 adsmt 자신의 용어. 다음 절을 보라) 로
만드는 것이다. 그것은 시도되었고 *철회되었다* — 잘못된
추상화이다. 타입 관계는 _정합적_ 이다. 타입당 하나의
인스턴스이다. 그러나 `A` 는 _많은_ `'p`-보존 함수를,
그리고 그렇지 않은 많은 함수를 가질 수 있다. 따라서
보존은 타입의 속성이 아니다 — 그것은 *함수* 의 속성,
고차 서술어 `preserving(f)` 이며, 각 `f` 마다 독립적으로
검사된다.

_재사용 가능한_ 서술어로서, 보존은 *정의되는* 것이
가장 낫다 — 명제를 진술하는 `Bool` 값 고차 서술어로서,
`'p`/`'q` 는 정제된-화살표 인자로부터 거두어진다 (`Bool`
반환 자체는 어떤 의무도 실어 나르지 않는다).

```lukb
fn preserving( f: { u: A | 'p(u) } -> { v: A | 'q(v) } ) : Bool =
  forall x: A. 'p(x) ==> 'p(f(x))
```

일은 오직 구체적인 *사용* 자리에서만 나타난다 — 그리고
바로 그곳에서 `solve … by …` 가 제값을 한다. (`f` 의
정제된-화살표 타입에서 온, 여기서는 명시적 `axiom` 인)
`f` 의 후행조건이 사용 가능해지면, 컷은 구체적인 "`f` 는
`p` 를 보존한다" 목표를 처리한다.

```lukb
const p: A -> Bool    const q: A -> Bool    const f: A -> A
axiom post_f: forall {x: A | p(x)}. q(f(x))
goal:
  solve forall {x: A | p(x)}. p(f(x))
  by    forall {y = f(x) | p(x)}. q(y) ==> p(y)
```

잎 — "상(image) 위의 `q ==> p`" — 이 진짜 내용이고,
다리가 그것을 `post_f` 와 조합해 목표를 닫는다. 왜
증명을-생성하는 `fn` 이 아니라 *정의* 인가? 본문에서
`solve … by …` 를 돌리고 _일반적_ `'p`/`'q` 에 대해 한 번
검사된 `preserving` 은 *불건전* 할 것이다. 그 잎
`∀'p 'q f. 'q(f x) ==> 'p(f x)` 는 일반적으로 거짓이기
때문이다. 그래서 서술어는 한 번 *진술되고*, 구체적인
사용마다 *처리된다*.

== 상 바인더 — 추론이 일을 한다

거의 전적으로 타입 추론에 의해 구동되는 바인더 형태가
하나 더 있다. *상(image) 바인더*

```lukb
forall { y = f(x) | c }. q(y)
```

는 추론된 _원상_ `x` (그 정렬은 `f` 의 정의역) 에 걸쳐
변역하고, `c` 로 그것을 가드하며, 본문에서 `y` 를 `f(x)`
로 펼친다. 선검증된 `image_quantifier_desugar` 에 의해
그것은 정확히

```lukb
forall x: { A | c }. q(f(x))
```

이다. 당신은 양화사를 _당신이 관심 있는 값_ (`f` 의 상에
있는 `y`) 의 관점에서 쓰고, adsmt는 그것이 실제로 걸쳐
변역해야 하는 변수 (정의역에 있는 `x`) 를 복원한다.
수학이 읽히는 방식대로 읽히는 작은 편의이다.

== 타입 관계는 타입 클래스이다

"_타입 관계_" 는 타입 클래스에 대한 adsmt의 이름이다 —
*하나의* 개념이며, `adsmt-class` 는 문자 그대로 타입-
클래스 계층이다 (`Relation` / `Instance` / `Resolver` /
`Dict` / `Law`). *\*Like 가족* — `PartialOrd` → `Ord` →
`IntegerLike`, `RealLike`, `ComplexLike` — 은 `Reduces` 척추를
공유하며, `IntegerLike(I, L, N)` 은 첫 번째 _고차 종류_
(higher-kinded) 인스턴스이다.

검증에 중요한 두 가지 속성이 있다.

- *증명에-의한-적법성.* 관계는 메서드 멤버 옆에 *법칙*
  목표-멤버를 실어 나른다. 인스턴스는 adsmt _자신의
  엔진_ 이 모든 법칙을 증명할 때에만 인정된다 —
  그렇지 않으면 빌드가 *거부된다*
  (`declare_instance_lawful` + 엔진-기반 `LawProver`).
  `solve` 잎을 처리하는 그 동일한 솔버가, 당신 타입의
  `Ord` 가 실제로 전순서임을 증명한다.
- *서술어 매개변수.* 관계는 인스턴스가 *딕셔너리*
  항목으로 공급하는 서술어 매개변수 `'p : T → Prop` 을
  실어 나를 수 있다 — 일반적 `fn` 에서 본 그 동일한
  딕셔너리-패싱이, 이제 인스턴스 수준에서.

이것은 adsmt의 핵심 설계 의도인 *네-방향 맞물림* 의 한
면이다. 타입 추론, 가설추론-연역 로직, ASP, 그리고
SMT (더하기 HKT) 는 별개의 사일로에 앉아 있는 대신
_유기적으로_ 맞물리도록 의도되어 있다.
`IntegerLike(I, L, N)` 은 연결 조직이다 — 타입 정보가,
고차 종류 인스턴스를 통해, `solve` 가 호출하는 엔진들로
흘러 들어간다.

== Rocq 통합

Rocq 백엔드 (`~/adsmt-contrib/adsmt-emit-rocq`) 는 Ltac2
택틱을 방출한다 (Ltac1이 아니다 — Ltac1은 prover_emit
정책에 따라 제외된다). 출력 형태는 Lean 레퍼런스를
미러링한다.

```coq
From Adsmt Require Import AdsmtTactic.

Example example_eq : forall (a b c : nat), a = b -> b = c -> a = c.
Proof.
  intros a b c h1 h2.
  adsmt_decide [h1; h2].
Qed.
```

택틱은 adsmt를 호출하여 인증서를 얻고, 인증서의 단계들을
순회하는 Ltac2 스크립트를 생성한다. 각 인증서 단계는
작은 증거 택틱을 가진 Ltac2 `assert` 가 된다.

== Isabelle 통합

Isabelle 백엔드 (`~/adsmt-contrib/adsmt-emit-isabelle`)
는 Isar 구문을 방출하며, 역시 Lean을 미러링한다.

```isabelle
lemma example_eq:
  fixes a b c :: nat
  assumes h1: "a = b" and h2: "b = c"
  shows "a = c"
proof -
  have h_3: "a = c" by (rule trans, fact h1, fact h2)
  show ?thesis by fact
qed
```

증명 구조는 Lean / Rocq을 정확히 미러링한다. 표면 구문만
다르다. lockstep 속성은 왕복 diff 테스트에 의해 강제된다
(컴패니언 10장).

== 고전-공리 위생

각 백엔드는 인증서의 프리앰블에 명명된 고전 공리들을
*요청 시*에 임포트한다. LEM을 인용하는 Lean 인증서는
`Classical.em` 을 임포트한다. Rocq 인증서는
`Classical_Prop.classic` 을 임포트한다. Isabelle 인증서는
`HOL.Classical` 을 임포트한다.

만약 백엔드의 대상이 명명된 공리를 지원하지 않는다면 —
예컨대 `Classical.em` 을 거부하는 엄격한 구성주의 Lean
모듈 — 방출은 진단을 내며 거부한다. 사용자는 고전
임포트를 받아들이거나, 솔버에게 고전 공리를 비활성화한
채로 다시 시도하도록 요청한다.

== 성능 고려사항

알아둘 만한 노브가 세 가지 있다.

*1. 인증서 크기.* 큰 목표는 수 kB의 인증서를 생성할 수
있다. 방출 시간은 선형으로 증가한다. ITP elaboration도
선형으로 증가한다. 대화형 사용을 위해서는 1초 미만이
목표이며, LSP 경로 (저렴한 재검사) 는 이를 유지한다.

*2. 택틱 입도.* 하위 목표별 `smt_decide` 는 괜찮다.
거대한 선언(disjunction)에 걸친 `smt_decide` 는 느리다.
호출 전에 분할하라.

*3. 가설추론 비용.* 가설추론 검색 예산은 제한되어 있다
(SMT-LIB에서 `:abductive-tier 0..4` 또는 택틱 표면에서
이에 상응하는 것). Tier 4가 가장 공격적이고 가장
비싸다.

== SMT-as-tactic이 빛나는 경우

- *동등성 사슬.* "$a = b$, $b = c$, $c = d$, …, prove
  $a = z$." adsmt의 EUF는 이를 마이크로초 단위로 처리한다.
  Lean의 `congr` 택틱 체인도 비슷하지만 더 장황하게
  써야 한다.
- *선형 산술.* "$x >= 1$, $y >= 1$ 이 주어졌을 때
  $3x + 2y >= 5$ 를 증명하라." Simplex를 통한 LIA. Lean의
  `linarith` 도 이를 한다 — adsmt는 투명성을 위해
  Farkas-증거 인증서 경로로 확장한다.
- *비트-벡터 항등식.* "`(x ^ y) ^ x = y` 를 증명하라."
  비트-블라스팅이 결정한다. Lean의 `bv_decide` 가
  Lean 내에서 가장 가까운 등가물이다.

== SMT-as-tactic이 어려워하는 경우

- *귀납.* SMT는 귀납을 하지 않는다. ITP가 한다.
- *단일화가 필요한 고차 추론.* SMT는 Miller 패턴을
  사용한다. Lean의 고차 단일화기가 훨씬 더 강력하다.
- *영역 특화 자동화* — 범주론, 입방체, 집합-이론적 구성.
  SMT는 범용이다. 특화된 택틱이 이를 이긴다.

조합이 강점이다. SMT가 빛나는 곳 (구체적 1차, 동등성,
산술) 에는 SMT를 쓰고, SMT가 도울 수 없는 곳에는 ITP의
네이티브 택틱을 쓴다. adsmt의 설계 — 가설추론 탈출구,
투명한 인증서, ITP-친화적 방출 — 는 이 분업 주위에
구축되어 있다.

== 완전한 작업 예제

`smt_abduce` 를 사용하는 작은 Lean 4 증명.

```lean
import Adsmt

example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  smt_abduce
```

가설추론 출력:

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := by
    sorry  -- abductive candidate 1
  exact h xs.head! h_head_in
```

사용자는 후보 가설 (`xs.head! ∈ xs` 는 비어 있지 않은
리스트에 대해 참이다) 을 읽고, `exact
List.head!_mem_of_ne_nil hne` 로 그것을 처리한다. 전체
증명은 다음과 같다.

```lean
example (xs : List Nat) (h : ∀ x ∈ xs, x > 0) :
    xs ≠ [] → xs.head! > 0 := by
  intro hne
  have h_head_in : xs.head! ∈ xs := List.head!_mem_of_ne_nil hne
  exact h xs.head! h_head_in
```

adsmt가 구조를 찾고, 사용자가 영역 지식을 제공했다.

이것 — *솔버와 증명기 사이의 협업* — 이 adsmt의
목적이다. 외부 택틱 (`smt_decide`, `smt_abduce`) 과
언어-내부 증명항 (`solve … by …`) 은 같은 곳으로 가는 두
경로이다. 둘 모두에서, 인간은 의도를 명명하고 — 채울
가설, 실어 나를 정제, 컷할 보조정리 — 엔진은 커널이
검사한 골격 아래에서 의무를 처리한다. 증명이 Lean에
살든 lukb `goal` 에 살든, 분업은 동일하다.
