= ITP 반사(Reflection)

== "반사"가 가져다주는 것

인증서를 손에 넣은 뒤에는, 판정을 작은 라이브러리로 독립적으로
검사할 수 있다. 그러나 대화형 정리 증명기 — Lean 4, Rocq,
Isabelle — 에 임베드된 사용자에게는 별개의 인증서 검사기를
돌리는 것이 어색하다. 그들은 솔버의 판정이 *ITP 자체 커널 안의
진짜 증명항(real proof term)*으로 변환되어 ITP 자체가 신뢰의
권위가 되기를 원한다.

그것이 *반사 다리(reflection bridge)*다. 인증서가 주어졌을 때
ITP의 표면 코드(전술 스크립트나 항)를 방출하여, ITP가 검사할
때 그 명제(statement)가 판정이 되도록 한다. adsmt는 세 가지
반사 백엔드를 제공한다.

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*ITP*], [*모듈*], [*상태*]),
  [Lean 4], [`adsmt-cert::prover_emit::lean`], [in-tree 레퍼런스],
  [Rocq],   [`adsmt-emit-rocq` (out-of-tree)],   [Lean을 미러링],
  [Isabelle], [`adsmt-emit-isabelle` (out-of-tree)], [Lean을 미러링],
)

Lean 4 경로가 *레퍼런스*다. 출력 형태에 대한 모든 변경은 먼저
`lean` 에 반영된 뒤, Rocq + Isabelle 백엔드로 보조를 맞추어
전파된다(`prover_emit_policy.md` 참조).

== 공통 앵커(Common anchors)

세 개의 백엔드는 *앵커(anchor)* — 각 백엔드가 구현하는 추상
연산 — 의 집합을 공유한다.

```rust
pub trait ProverEmit {
    fn open_proof(&mut self, goal: &Term);
    fn refl_step(&mut self, t: &Term);
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term);
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness);
    fn abductive_assume(&mut self, name: &str, hyp: &Term);
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind);
    // ... 12 mandatory + abductive + classical ...
    fn close_proof(&mut self);
}
```

`adsmt-cert::prover_emit::common` 은 단계들을 순회하면서 적절한
트레이트 메서드를 호출하여 `Cert` 를 내려보낸다. 그러면 백엔드
구현은 ITP별 문법으로 형식화한다. 이러한 분리는 세 백엔드를
정확히 동기화 상태로 유지한다. 어떤 새로운 단계 종류도 트레이트에
메서드를 추가해야 하므로, 변경이 컴파일되기 전에 세 백엔드 모두가
이를 처리하도록 강제된다.

== Lean 4 — 레퍼런스 백엔드

```rust
impl ProverEmit for LeanEmitter {
    fn open_proof(&mut self, goal: &Term) {
        write!(self.out, "theorem adsmt_goal : {} := by\n",
               lean_term(goal)).unwrap();
        self.indent = 2;
    }
    fn refl_step(&mut self, t: &Term) {
        self.line(&format!("have h{} : {} = {} := rfl",
                           self.next_id(), lean_term(t), lean_term(t)));
    }
    fn trans_step(&mut self, a: &Term, b: &Term, c: &Term) {
        let id = self.next_id();
        let prev = self.prev_two();
        self.line(&format!("have h{id} : {} = {} := Trans.trans h{} h{}",
                           lean_term(a), lean_term(c), prev.0, prev.1));
    }
    fn theory_step(&mut self, theory: TheoryName, witness: &TheoryWitness) {
        let tactic = match theory {
            TheoryName::Uf  => "congrArg",
            TheoryName::Lia => "linarith",
            TheoryName::Lra => "linarith",
            TheoryName::Bv  => "bv_decide",
            TheoryName::Arr => "simp [Array.get_set]",
            TheoryName::Dt  => "decide",
        };
        self.line(&format!("have h{} : ... := by {}", self.next_id(), tactic));
    }
    fn abductive_assume(&mut self, name: &str, hyp: &Term) {
        // Renders as a Lean sorry-shaped placeholder.
        self.line(&format!("have {} : {} := by sorry  -- abductive",
                           name, lean_term(hyp)));
    }
    fn classical_axiom(&mut self, kind: ClassicalAxiomKind) {
        let import = match kind {
            ClassicalAxiomKind::Lem => "Classical.em",
            ClassicalAxiomKind::Peirce => "Classical.peirce",
            // ...
        };
        self.preamble.push(format!("open {}", import));
    }
}
```

17개의 단계를 가진 인증서는 17줄의 `have` 가 있는 Lean 전술
블록을 산출하며, `close_proof` 가 그것을 마감하여 마지막
식별자를 원래 목표에 대한 증명으로 명명한다. 출력은 Lean의
정련기(elaborator)와 커널을 거치며, Lean 자신의 신뢰가 건전성
의무(soundness obligation)를 위임받는다.

== Rocq / Isabelle — 미러링

Rocq와 Isabelle 백엔드는 `~/adsmt-contrib/` 에서 out-of-tree로
유지된다. 그들은 동일한 `ProverEmit` 트레이트를 구현하지만,
각각 Rocq Ltac2 문법과 Isabelle Isar 문법을 방출한다.

```text
~/adsmt-contrib/
├── adsmt-emit-rocq/
│   └── src/lib.rs        — impl ProverEmit for RocqEmitter
└── adsmt-emit-isabelle/
    └── src/lib.rs        — impl ProverEmit for IsabelleEmitter
```

짚어둘 만한 몇 가지 제약이 있다.

- *Rocq Ltac1은 배제된다.* Ltac2만 사용한다. Ltac1의 무타입
  표면은 기계 생성 전술에 너무 취약하다 — 사소한 인증서
  변형에서도 Ltac1은 불투명한 파싱 오류를 내며, Ltac2는 그
  오류를 타입 검사 시점에 잡아낸다.
- *출력 형태는 Lean을 정확히 미러링한다.* Lean의 각 `have` 는
  같은 순서와 같은 식별자 이름으로 Isabelle의 `have :` 그리고
  Rocq의 `Notation.notation` 에 대응한다. 이것은 prover_emit
  정책의 강한 불변식(hard invariant)이다.
- *고전 공리는 필요에 따라 import된다.* 각 방출 파일의
  preamble은 인증서의 preamble에 명명된 공리만 import한다.
  오프라인 우선(offline-first) 검사는 명명된 공리가 대상 ITP에서
  지원되지 않으면 방출을 거부한다.

== 왕복 diff 테스트

보조 맞춤(lockstep) 정책은 *왕복 diff 테스트(round-trip diff
test)*로 강제된다. 인증서가 주어지면, Lean 출력을 방출하여
정규 AST로 정규화하고, Rocq 출력을 방출하여 정규화하고,
Isabelle 출력을 방출하여 정규화한 뒤 비교한다. 세 트리 사이의
구조적 차이가 있다면 그것은 병합을 차단하는 정책 위반이다.

```rust
#[test]
fn lockstep_lean_rocq_isabelle() {
    for cert in golden_certs() {
        let lean_tree   = normalize(emit_lean(&cert));
        let rocq_tree   = normalize(emit_rocq(&cert));
        let isabelle_tree = normalize(emit_isabelle(&cert));
        assert_eq!(lean_tree.shape(), rocq_tree.shape());
        assert_eq!(lean_tree.shape(), isabelle_tree.shape());
    }
}
```

이것이 "Lean 4 레퍼런스"라고 말할 때의 의미다 — Lean은 단지
*세 가지 출력 형식 중 하나*가 아니라, 나머지가 그 형태를 따라야
하는 형식이다.

== `sorry` 로서의 가설추론적 구멍

가설추론적 단계는 ITP 고유의 `sorry` 자리표시자를 방출한다.
Lean: `sorry`. Rocq: `Admitted` (가설추론 계층이 정의 경계에
있을 때) 또는 `give_up` (전술 모드). Isabelle: `sorry`.

각 자리표시자는 가설추론적 가설의 이름을 따서 명명되므로,
사용자는 자신의 편집기에서 다음과 같은 이름 있는 의무 목록을
보게 된다.

```text
adsmt_h_3 : ∀ x, x > 0 → P x
adsmt_h_7 : a ≠ b
```

이것들은 가설추론 계층이 표면화한 바로 그 가설들이며 — 이제
ITP의 옷을 입고 있다. 사용자는 증명으로 방출하거나 공리로 받아
들임으로써 처리하고, 나머지 증명은 ITP 자체 커널 하에서
통과된다.

== 전체 사슬

1장부터 10장까지의 계층을 모두 묶으면, 종단 간 파이프라인은
다음과 같다.

```text
SMT-LIB script
   ↓ parse
Internal AST
   ↓ engine.check_sat (CDCL + theory + quantifier + abduce)
SatResult
   ↓ recorder
Cert (S-expr)
   ↓ prover_emit::lean / ::rocq / ::isabelle
ITP-surface proof script
   ↓ ITP kernel
Verified theorem
```

이 사슬의 모든 연결고리는 반대편에 독립적인 검증기가 있다.
커널(2장)은 자기 자신이 검증한다 — 12개의 규칙이 건전성
계약(soundness contract)이다. 검사기(9장)는 커널 규칙에 대해
인증서를 검증한다. ITP(10장)는 자신의 커널에 대해 방출된 증명을
검증한다. 가설추론 계층(8장)은 *불건전성*이 아니라 *이름 있는
의무*를 도입한다 — 사용자는 그것을 명시적으로 보고 결정한다.

이것이 전술로서의 SMT가 증명 보조 도구를 섬겨야 한다는 말의
의미다. 솔버의 판정은 결코 최종 발언이 아니다 — ITP의 커널이
최종이다.
