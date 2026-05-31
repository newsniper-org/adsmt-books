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
목적이다.
