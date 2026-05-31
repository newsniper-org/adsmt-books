= lu-kb 표면

`lu-kb` 는 adsmt가 받아들이는 두 번째 입력 방언이다.
*logicutils* 프로젝트에서 비롯되었으며(RC1.4.A에서 흡수,
`ABSORPTION_PLAN.md` 참조), logicutils 소비자와의 하위 호환성과
adsmt 고유 지식 베이스 저작(knowledge-base authoring)을 위해
보존된다.

== 표면 형태

`.kb` 파일은 *블록(block)*의 시퀀스이다.

```text
sort Nat
fun  zero : Nat
fun  succ : Nat -> Nat

rule  succ_pos : forall n. zero != succ n
rule  succ_inj : forall n m. (succ n = succ m) => (n = m)

class Eq[T] = { eq : T -> T -> Bool }
instance Eq[Nat] = { eq = nat_eq }

query forall n. eq n n
```

각 블록은 `sort`, `fun`, `rule`, `class`, `instance`, `query`
중 하나이다. 방언의 문법은 `adsmt-parser/src/lukb/` 에 있으며,
이전 사용 가능 마이그레이션 체인(v0.x에서 v1.0까지)도 함께
체크인되어 있다.

== 블록

*`sort <name>`* — 불투명한(opaque) 종(sort)을 선언한다.
SMT-LIB의 `declare-sort` 와 동등하다.

*`fun <name> : <type>`* — 함수 기호를 그 타입과 함께 선언한다.
higher-kinded types(`F[T]`, `F[T, U]`)가 인식된다. 커널 의미론은
3장에서 다룬다.

*`rule <name> : <formula>`* — 엔진 시작 시 단언(assert)될 이름
있는 가정이다. 사실의 단언과 가설추론 계층(8장)에 공급되는
Horn 규칙 양쪽 모두에 사용된다.

*`class <name>[<tyvar>+] = { <field> : <type> ; ... }`* — 타입
클래스를 선언한다. 3장의 T_class에 해당한다.

*`instance <name>[<type>+] = { <field> = <term> ; ... }`* —
특정 타입 매개변수에 대한 클래스의 인스턴스를 선언한다.

*`query <formula>`* — `assert (not phi)` 뒤에 `check-sat` 이
따라오는 것과 동등하다. 판정은 이름으로 보고된다.

== 해시 스탬프 마이그레이션 체인

`.kb` 파일은 표준 형식(canonical form)에 대한 K12-256 해시를
선택적으로 가진다. 해시는 파싱 시 재계산되며, 불일치는 마이그
레이션 검사를 발동한다. 그 검사는 알려진 방언 버전들의 체인을
순회하며 필요한 변환을 적용한다.

```text
% kb-version: 1
% kb-hash:    k12-256:abc123...
```

체인은 `lu-common/src/migration.rs` 에서 호환성을 깨는 버전마다
하나의 변환과 함께 유지된다. 마이그레이션은 *옵트인(opt-in)*
이다 — `:auto-migrate` 옵션이 없으면 해시 불일치는 오류이다.

== SMT-LIB와의 비교

`lu-kb` 는 개별 목표를 방출하기보다 지식 베이스를 저작하기에
맞는 형태로 짜여 있다.

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*관심사*], [*SMT-LIB*], [*lu-kb*]),
  [입자성(Granularity)], [목표별(per goal)], [지식 베이스별(per knowledge base)],
  [재사용(Reuse)],       [push/pop 범위], [Rule과 class 블록],
  [타입 클래스], [기본 미지원], [`class` / `instance` 블록],
  [Horn 친화성], [수동], [`rule` 블록이 가설추론에 공급],
  [마이그레이션], [preamble의 버전], [해시 스탬프 체인],
)

실제로 라이브러리 저자는 `.kb` 를 선호한다(지식 베이스를 한 번
작성해 두고 반복적으로 질의). 임시 사용자는 `.smt2` 를 선호한다.
두 표면 모두 동일한 내부 AST로 컴파일되므로, 엔진 동작은
동일하다.

== 편집기 통합

VS Code 확장(`tooling/vscode-extension/` 아래)은 `.smt2` 와
`.kb` 확장자 모두를 인식한다. LSP 서버(`adsmt-lsp`)는 확장자에
따라 파일을 적절한 파서로 라우팅한다. 완성 목록은 그에 맞추어
조정된다(`class`, `instance`, `query` 같은 `kb` 고유 키워드를
포함한 39개의 정적 항목).
