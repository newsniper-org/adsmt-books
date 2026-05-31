= SMT-LIB v2 표면

이 부록은 `adsmt-parser` 가 인식하는 SMT-LIB v2 표면을
문서화한다. 이것은 전체 SMT-LIB v2 표준의 *부분집합(subset)*
이며, 더불어 adsmt 고유의 확장 몇 가지가 포함된다.

== 인식되는 명령

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*명령*], [*비고*]),
  [`set-logic`],   [QF_* 로직들과 그에 대응하는 한정자 버전을 받아들인다. 여러 이론이 등장하면 polite combination이 자동 선택된다.],
  [`set-option`],  [표준 옵션들 + adsmt 고유의 `:abductive-tier`, `:trigger-mode`, `:classical-axioms`.],
  [`declare-sort`, `declare-fun`, `declare-const`], [표준.],
  [`define-fun`, `define-fun-rec`], [표준; `define-fun-rec` 은 부분적(partial)이다 — 종료(termination) 의무는 사용자의 몫이다.],
  [`assert`],      [표준.],
  [`check-sat`],   [`sat`, `unsat`, `unknown`, 또는 `abductive` (새로운 판정)를 반환한다.],
  [`get-model`],   [표준; `Sat` 에 대한 할당을 반환한다.],
  [`get-unsat-core`], [표준; `Unsat` 에 대해 레이블이 붙은 부분집합을 반환한다.],
  [`get-abductive-candidates`], [adsmt 확장 — `Abductive` 에 대해 순위가 매겨진 후보 목록을 반환한다.],
  [`push`, `pop`], [표준 범위 스택(scope stack).],
  [`reset`, `reset-assertions`], [표준.],
  [`exit`],        [표준.],
)

== 이론들

다음 SMT-LIB 이론들이 지원된다(6장).

- `Core` — Bool, =, distinct, ite, and, or, not, =>
- `Ints` — LIA
- `Reals` — LRA
- `Reals_Ints` — polite combination을 통한 LIRA
- `FixedSizeBitVectors` — 비트-블라스팅(bit-blasting) 폴백이
  있는 BV
- `ArraysEx` — Read-over-write Arrays
- `Datatypes` — 대수적 자료형(Algebraic data types)

== 로직

표준 SMT-LIB 로직 이름들이 인식된다.

```text
QF_UF, QF_LIA, QF_LRA, QF_BV, QF_AUFLIA, QF_AUFBV,
QF_DT, QF_AUFDT,
LIA, LRA, AUFLIA, AUFBV, AUFDT, ...
```

로직이 한정자를 포함할 때(`QF_` 접두사가 없을 때), 엔진은
7장의 한정자 인스턴스화 파이프라인을 자동으로 가동한다.

== 확장

세 가지 SMT-LIB 확장은 adsmt 고유이다.

*`:abductive-tier <n>`* — 한정자 처리가 가설추론적 후보로
격상되는 최대 tier를 설정한다. `n=0` 은 가설추론 표면을
비활성화한다(고갈 시 `unknown` 을 반환). `n=4` (기본값)는
전체 파이프라인을 활성화한다.

*`:trigger-mode <miller|free>`* — `miller` (기본값)는 트리거를
Miller 패턴으로 제한한다. `free` 는 비-Miller 트리거를 허용한다
(그에 따른 병리들을 감수하고).

*`:classical-axioms (<axiom>*)`* — 솔버가 호출할 수 있는 고전
공리들을 화이트리스트로 지정한다. 받아들여지는 이름은 다음이다.
`lem`, `peirce`, `dne`. 화이트리스트에 없는 공리를 요구하는
단계는 실패하거나 Tier-4로 격상된다.

*`get-abductive-candidates`* — `check-sat` 이 `abductive` 를
반환할 때, 이 명령은 순위가 매겨진 후보 목록을 중첩
S-식으로 반환한다. 출력 예시.

```text
(abductive-candidates
  (candidate :rank 1 :hypothesis ((P a) (Q b))
             :justification sld_chain)
  (candidate :rank 2 :hypothesis ((R c))
             :justification quantifier_exhausted))
```

== 비확장(미지원)

다음 SMT-LIB v2 기능 일부는 *지원되지 않는다*.

- `Floats` (FP 이론) — 범위 외(out of scope).
- `Sequences` 와 `Strings` 이론 — 범위 외.
- `define-fun-rec` 의 전체성(totality) 검사 — 부분적 지원만.
- 패턴 문법 `(! ... :pattern ...)` 은 파싱되지만, Tier-1은
  명시적 `:trigger` 속성이 없을 때만 패턴을 참조한다.

이러한 누락은 의도적이다. FP 건전성에 대한 v1.0.0 약속은,
지나치게 느린 비트-블라스팅 폴백을 요구하거나, 그 자체로
독립적인 연구 프로젝트인 FP 전용 결정 절차를 요구할 것이다.
