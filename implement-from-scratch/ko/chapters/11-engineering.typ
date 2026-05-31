= 엔지니어링 관심사

이 마지막 장은 알고리즘적 척추(spine)에서 한 걸음 물러나,
1장부터 10장까지의 설계를 유지보수 가능하고 안정적인 솔버로
바꾸는 *엔지니어링* 관행들을 살펴본다. 주제는 다음과 같다.

- 워크스페이스 레이아웃과 크레이트 경계
- 테스트 전략(단위, 통합, 속성, 차분, 벤치마크)
- 표면 동결(Surface freeze)(ABI, 방언, 인증서)
- semver 규율과 8계층 휴리스틱 검사기
- 릴리스 엔지니어링 — Debian 스타일 채널

== 워크스페이스 레이아웃

adsmt에서 가장 큰 엔지니어링 결정은 *평면적 크레이트 분할(flat
crate split)*이다. 각 주요 컴포넌트는 자신만의 크레이트다.

```text
adsmt-core/         HOL+HKT kernel (TCB)
adsmt-cert/         Cert format + checker + emit
adsmt-theory/       Theory trait + the six theories
adsmt-class/        Type-class + dictionary passing
adsmt-quant/        Quantifier instantiation
adsmt-abduce/       Abductive layer
adsmt-engine/       DPLL(T) + CDCL + bit-blasting
adsmt-parser/       SMT-LIB v2 + lu-kb parser
adsmt-cli/          `lu-smt` binary
adsmt-lsp/          tower-lsp server
adsmt-ffi/          C ABI
adsmt-meta/         Umbrella crate
adsmt-lints/        Runtime audit library
adsmt-heuristic-checker[-macros]/  Offline semver guards
```

자명하지 않은 여러 이점이 드러난다.

1. *컴파일 병렬성.* Cargo는 14개의 adsmt 크레이트를 동시에
   빌드할 수 있다. 클린 빌드 시간은 합이 아니라 가장 긴
   단일 크레이트(`adsmt-engine`)에 의해 제한된다.
2. *표면 경계.* 각 크레이트의 공개 표면 ABI는 독자적인
   계약이다. 내부 리팩터링이 `pub(crate)` 벽을 통해 새어
   나갈 위험이 없다.
3. *선택적 기능.* 하류 소비자는 파서, LSP, CLI를 끌어들이지
   않고 `adsmt-core` (커널만)에 의존할 수 있다.
4. *동결된 표면(Frozen surfaces).* 세 개의 크레이트 —
   `adsmt-ffi`, `adsmt-cert`, `adsmt-parser` — 는 매크로로
   강제되는 명시적 표면 동결 정책을 가진다. 나머지는 더
   자유롭게 진화한다.

== 테스트 전략

모든 계층은 자신만의 테스트 규율을 가진다.

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*계층*], [*규율*]),
  [커널],     [각 규칙에 대한 단위 테스트, 그리고 TCB를 정의하는 속성 테스트: "공집합 가정으로부터 12개 규칙만으로 구성 가능한 임의의 항은 충족 가능하다."],
  [이론],     [이론별 단위 테스트와, Nelson-Oppen 스타일 등식 전파를 시험하는 polite-combination 통합 테스트.],
  [한정자], [매처(matcher) + 트리거 학습기에 대한 단위 테스트와, 각 tier 격상에 대한 golden-cert 테스트.],
  [가설추론],  [차분(differential) 테스트: 산출된 모든 후보는 *타당한* 가설(`H union phi` 가 방출됨)이며 *최소*여야 한다(어떠한 진부분집합 $H$ 도 그렇지 않음).],
  [엔진],     [`tests/smtlib/` 에 체크인된 SMT-LIB 스크립트를 통한 통합 테스트.],
  [파서],     [왕복 `parse(write(t)) == t` 에 대한 속성 테스트.],
  [인증서],       [속성 테스트: 모든 커널 실행에 대해 `check(record(...)) == Ok(())`.],
  [벤치마크],      [`target/criterion/` 아래 Criterion HTML 보고서, 모든 알고리즘 변경 후 재기준선화.],
)

표제 보증 — "커널이 정확하다" — 는 커널 규칙 자체에 대한 작은
테스트에서 나온다. *솔버*의 정확성은 (커널 규칙이 정확함) +
(기록기가 커널 규칙만을 사용함) + (검사기가 커널 규칙으로
구성된 인증서만을 받아들임)의 결합(conjunction)이다. 이들 각각은
독립적으로 테스트 가능하며, 건전성 사슬은 그 곱(product)이다.

== 표면 동결(Surface freezes)

세 개의 표면이 v1.0.0에서 동결된다.

*adsmt-ffi/ABI_POLICY.md.* `adsmt-ffi` 가 노출하는 C-ABI는
비-Rust 소비자에 대한 통합 표면이다. 한 번 동결되면, 공개
함수 시그니처의 변경은 호환성을 깨는 버전 범프(breaking-version
bump)를 요구한다. 크레이트의 `lib.rs` 에 부착된
`#[breaking_changes_semver("1.0.0")]` 매크로가 오프라인 강제
수단이다. `pub extern "C" fn` 시그니처를 변경하는 모든 커밋은
선언된 버전도 함께 범프해야 한다.

*adsmt-parser/DIALECT_POLICY.md.* SMT-LIB v2와 lu-kb 입력
방언 모두 동결된다. 새로운 키워드는 추가될 수 있지만(가산적),
기존 키워드의 문법은 고정된다. 파서는 SMT-LIB v2 적합성
스위트(conformance suite)를 회귀 테스트로 통과한다.

*adsmt-cert/CERT_POLICY.md.* 12 + 3 + … 단계 종류는 동결된다.
새로운 단계 종류는 semver(가산적) 하에 추가될 수 있지만,
어떤 종류의 페이로드 형태도 호환성을 깨는 범프 없이 변경되지
않는다.

이 세 정책은 하류 도구(`adsmt-emit-rocq`, `adsmt-emit-isabelle`,
VS Code 확장, 사용자 전술 도구 모음)에 안정적인 대상(target)을
제공한다. 나머지 워크스페이스는 자유롭게 진화할 수 있다.

== semver 규율

Rust의 semver 관례가 적용된다. v1.0 이전의 유연성을 위해
$0.y.z$, 안정 API를 위해 $1.y.z$ 이후. adsmt는 2026년 5월
v0.19 개발 라인으로 v1.0 사이클을 시작하였으며,
(`feedback_stable_signoff_user_approval.md` 에 따라) v1.0.0
안정판 컷에는 사용자의 명시적 승인이 필요하다.

8계층 휴리스틱 검사기(`adsmt-heuristic-checker`)가 오프라인
안전장치다. 호환성을 깨는 버전 범프 후보를 여덟 개의 독립
계층이 교차 검사한다.

1. 크레이트의 `lib.rs` 에 부착된 매크로 속성
2. 해당 버전 헤딩 아래의 CHANGELOG 항목
3. Cargo.toml 버전 필드
4. 동결 표면 정책 마크다운 참조
5. 크레이트 간 일관성(워크스페이스 의존성 그래프)
6. 이전 버전 공개 API에 대한 스냅샷 테스트
7. 적합성 스위트 회귀 검사
8. 앞의 일곱 가지 없이는 어떤 태그도 거부하는 CI 가드

어느 한 계층이라도 실패한 버전 범프는 태그가 푸시되기 전에
거부된다. 규율은 무겁지만, 동결 표면 프로젝트를 운영하는
대가다.

== 채널

adsmt는 Debian의 채널 모델을 차용한다.

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*채널*], [*브랜치*], [*목적*]),
  [unstable], [`main`],     [활성 개발; 새로운 커밋이 여기에 들어온다.],
  [testing],  [`testing`],  [`main` 으로부터 승격된 안정화 후보.],
  [stable],   [`v1.0.0` (tag)], [릴리스된 버전; v1.0.0 태그가 최초.],
)

`testing` 브랜치는 v1.0.0-rc.2 직후, 2026년 5월 커밋
`450b986` 에서 `main` 으로부터 갈라져 나왔다. 이후의 핫픽스는
`main` (다음 메이저 사이클) 또는 `testing` (현재 안정화)에
들어올 수 있으며, 체리픽 방향은 수정 사항별로 결정된다.

== 릴리스 엔지니어링

릴리스는 다섯 단계로 컷된다.

1. 모든 가드에서 녹색(green) CI 이후 `testing` 에 후보 태그.
2. RC 감사 실행(RC2.1-RC2.9가 이번 사이클의 실제 번호) —
   기능 매트릭스, publish dry-run, 경고 정리, 문서 감사,
   벤치 재기준선화, LSP 런타임 스모크, 기여 감사, 문서 경고
   침묵화, README 작성을 포함한다.
3. 명시적 사용자 사인오프(`feedback_stable_signoff_user_approval.md`).
4. 사인오프 커밋에 `v1.0.0` 태그; 원격에 push.
5. `~/adsmt-contrib/` 의 워크스페이스 핀(pin)을 새 태그로
   업데이트하고, 갓 게시된 `adsmt-cert` 와 `adsmt-core` 에
   대한 스모크 테스트를 실행한다.

`~/adsmt-contrib/` 는 *contrib* 저장소다. 즉 out-of-tree Rocq와
Isabelle 방출 백엔드다. 메인 저장소의 버전을 추적하며(`1.0.0`
대 `1.0.0`), 릴리스된 `adsmt-cert` + `adsmt-core` 를 Git 태그
핀을 통해 소비한다. 메인 저장소 아래의 `contributions/oxiz/*`
서브모듈은 adsmt 릴리스가 아니라 상류 `oxiz` 기여를 추적하면서,
독립적인 자체 버전 라인에 머문다.

== 메모리 + 설계 아카이브

소스와 나란히 두 개의 비코드 영속화 시스템이 자리 잡고 있다.

- `memory/*.md` — 프로젝트 내부 컨텍스트(사이클 이력, 로드맵,
  사인오프 정책). 각 파일은 하나의 주제이며, 색인은
  `MEMORY.md` 에 있다.
- `.claude-conversations/` — 설계 대화 전체 아카이브. 흥미로운
  결정과 막다른 길은 여기에 살며, 날짜와 주제로 검색 가능하다.

이것들이 존재하는 이유는 설계 근거가 항상 코드나 git 메시지로
표현될 수 있는 것이 아니기 때문이다. 미래의 유지보수자가 "왜
e-graph가 `adsmt-theory::uf` 안에 살지 않고 자신만의 이론으로
감싸여 있는가?"라고 물을 때, 그 답은 2026년 5월의
`memory/oxiz_relationship.md` 논의에 있다.

== 마치며

이 장이 기술한 엔지니어링 규율이 1장부터 10장까지의 알고리즘적
척추를 누군가가 실제로 사용해볼 만한 솔버로 바꾸어 놓는다.
커널은 빛날 수 있다. 그러나 파서가 다음 SMT-LIB 확장에서
부서지고, 인증서 형식이 릴리스마다 표류하며, C ABI가 버전 범프
없이 시그니처를 바꾼다면, 솔버는 도구가 아니라 과학 박람회
프로젝트일 뿐이다.

동결된 표면, 휴리스틱 검사기, 채널 규율, 속성 테스트가 적용된
계층, 명시적 메모리 시스템 — 이 중 어느 것도 흥미진진하지는
않다. 그러나 모두 필수적이다. 그것들이 v1.0.0 컷을 단지 태그
위의 숫자가 아니라 *의미 있는 것*으로 만드는 이유다.

이 시리즈의 다음 책 *Learning Materials* 는 여기에서 이어받아
adsmt를 *어떻게 사용*하는지를 — SMT-LIB와 lu-kb 표면에서부터
LSP, Lean 4 전술, 가설추론적 워크플로우에 이르기까지 — 안내한다.
현재 책은 구현에 관한 것이었다. 다음은 실제 사용에 관한 것이다.
