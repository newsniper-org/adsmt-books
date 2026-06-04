= CLI 치트시트

`lu-smt` 명령 (`adsmt-cli` 가 제공) 은 주요 명령줄
진입점이다. 이 부록은 빠른 참조이다.

== 기본 호출

```bash
# Run an SMT-LIB script
lu-smt path/to/script.smt2

# Run a lu-kb knowledge base
lu-smt path/to/base.kb

# Read from stdin
cat script.smt2 | lu-smt -

# Verbose output (warns + audit info)
lu-smt -v script.smt2
```

종료 코드는 판정을 반영한다.

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*판정*], [*종료*], [*출력*]),
  [`sat`],   [0], [`sat`],
  [`unsat`], [0], [`unsat`],
  [`unknown`], [1], [`unknown` + 사유],
  [`abductive`], [2], [요청된 경우 `abductive` + 후보들],
  [구문 분석 오류], [3], [stderr로의 진단],
)

== 일반적인 플래그

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*플래그*], [*효과*]),
  [`--emit-cert <file>`], [인증서를 `<file>` 에 쓴다 (S-식 형식)],
  [`--check-cert <file>`], [솔버를 다시 실행하지 않고 인증서를 재검증],
  [`--audit-json`], [감사 진단을 JSON으로 방출],
  [`--abductive-tier <n>`], [Tier 설정 (0 = 꺼짐, 4 = 전체)],
  [`--trigger-mode <miller|free>`], [비-Miller 트리거를 제한하거나 허용],
  [`--timeout <ms>`], [밀리초 단위의 하드 타임아웃],
  [`--seed <n>`], [난수 시드 (재현성을 위해)],
  [`-v` / `--verbose`], [장황한 출력],
  [`-h` / `--help`], [전체 도움말 텍스트],
)

== SMT-LIB 수준 옵션

이것들은 SMT-LIB 스크립트 안에서 `(set-option ...)` 을
통해 설정된다.

```text
(set-option :produce-models true)     ;; sat verdict 용
(set-option :produce-unsat-cores true);; unsat verdict 용
(set-option :produce-proofs true)     ;; cert 생성
(set-option :timeout 5000)            ;; 5초 wall-clock 예산 (ms)
(set-option :rlimit 30000000)         ;; Z3-style 리소스 한도 (~30초)

;; §3.4 GF(2) Gröbner-basis 플러그인 (opt-in)
(set-option :finite-field-periodic 32)
(set-option :finite-field-budget-exhaustion true)
```

`:finite-field-*` 키는 `--finite-field-periodic N` /
`--finite-field-budget-exhaustion` startup 플래그로도 동일하게
전달 가능. 어느 경로든 엔진에 `FiniteFieldTheory` 플러그인을
등록한다. 세션 중 `(set-option ...)`은 첫 호출 시 default knob
로 자동 등록.

== §3.1 AOT prelude bank

무거운 prelude (대표적 예: Verus의 prelude는 ~10⁵ 절)를
`.luart` v0 아티팩트로 사전 컴파일한 후, 매 per-query
호출에서 pre-assert된 상태로 로드한다.

```bash
# Prelude 1회 bake.  `.luart` 파일은 입력의 SHA-256과
# bake 시의 lu-smt 버전을 기록하므로, 호출자가 이 쌍을
# cache key로 활용 가능.
lu-smt --aot-bake --aot-output prelude.luart prelude.smt2

# 매 per-query 호출은 일반 SMT-LIB 입력을 읽기 전에
# prelude를 pre-assert.
lu-smt --aot-load prelude.luart query.smt2
```

`--aot-bake`와 `--aot-load`는 상호 배타적이다. 함께 주면
typed error로 끝난다 (exit 13).

== 감사 JSON

`--audit-json` 은 기계가 읽을 수 있는 진단 스트림을
방출한다. 에디터와 CI 통합에 유용하다.

```json
{
  "kind": "diagnostic",
  "severity": "warning",
  "code": "trigger.non-miller",
  "loc": { "file": "script.smt2", "line": 12, "col": 3 },
  "message": "Trigger pattern is non-Miller; matching will be slow."
}
```

감사는 구문 분석기 경고, 트리거 분류, 고전-공리 사용,
가설추론-tier 에스컬레이션 이벤트를 포괄한다.

== 인증서-사이클 워크플로

고-보증 실행을 위해서는 다음과 같다.

```bash
# 1. Solve, write cert
lu-smt --emit-cert proof.cert script.smt2

# 2. Re-check the cert independently
adsmt-cert-check proof.cert

# 3. (optional) Emit Lean script from cert
lu-smt-emit --lang lean proof.cert > proof.lean
```

1-3단계는 독립적이다. 2단계를 통과한 인증서는 1단계의
솔버에 버그가 있더라도 건전하다. 3단계는 자체의 신뢰
이야기를 가진 Lean 커널로 이전한다.

== 성능 플래그

```bash
# Disable abductive (deductive only)
lu-smt --abductive-tier 0 script.smt2

# Restrict to Miller patterns
lu-smt --trigger-mode miller script.smt2

# Set a hard timeout (1 second)
lu-smt --timeout 1000 script.smt2

# Disable cert emission
lu-smt --no-cert script.smt2
```

기본값 (`--abductive-tier 4`, `--trigger-mode miller`,
타임아웃 없음, `--emit-cert` 가 요청된 경우 인증서) 은
대화형 사용에 적합하다.

== 환경 변수

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*변수*], [*효과*]),
  [`ADSMT_LOG`], [로그 수준 (`error`, `warn`, `info`, `debug`, `trace`)],
  [`ADSMT_BACKEND`], [SAT 백엔드 재정의 (`oxiz`, `cadical`, `builtin`)],
  [`ADSMT_THREADS`], [엔진 스레드 수 재정의],
  [`RUST_BACKTRACE`], [표준 Rust 백트레이스 제어],
)

== 예제 디렉터리

adsmt 소스 트리는 모든 이론에 대해 작업된 SMT-LIB와
lu-kb 스크립트를 가진 `examples/` 디렉터리를 함께
제공한다. 템플릿을 찾으려면 그곳을 둘러보라.

```bash
ls ~/AD1/examples/
# qf_uf.smt2    qf_lia.smt2    qf_lra.smt2
# qf_bv.smt2    qf_dt.smt2     quant_uf.smt2
# abduce_basic.kb   abduce_chain.kb
```

각 예제는 무엇을 보여주는지를 선행 주석에 문서화한다.
