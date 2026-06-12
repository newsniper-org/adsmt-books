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

== 가설추론(abductive reasoning) — SMT-LIB 표면

adsmt의 가설추론 verdict — _이 goal을 discharge하려면 어떤
가설이 필요한가?_ — 는 명시적이고 cvc5 호환인 SMT-LIB 표면으로
접근할 수 있다. 허용 가설의 어휘를 선언한 뒤, goal에 대해
abduct를 요청한다:

```text
;; 엔진이 fix로 제안할 수 있는 패턴을 등록.
(declare-abducible (> x 0))
(declare-abducible (> x 0) "x must be positive")  ;; 선택적 설명

;; adsmt-native: 랭킹된 전체 후보를 단일 라인 `abductive`
;; JSON으로 방출 (Verus / Lean 리포터가 파싱).
(abduce (>= x 1))

;; cvc5 abduction 확장: 최상위 abduct를 재파싱 가능한
;; `(define-fun A () Bool (> x 0))`로 방출.
(get-abduct A (>= x 1))
;; 남은 랭킹 abduct들을 순회; 소진되면 `(fail)`.
(get-abduct-next)
```

abduct는 _권고_일 뿐이다 — 신뢰되는 verdict는 연역(`unsat`)이고,
abduce된 가설은 호출자가 (사전조건 / 불변식 / lemma로)
정당화해야 하는 것이지 절대 조용히 가정하지 않는다.

기본적으로 엔진은 abduct가 _목표를 함의_ (`H ⊢ G`)함만
보장한다. 현재 assertion과 모순인 가설도 반환될 수 있고
(그러면 목표를 _공허하게_ verify함). 완전한 cvc5
`(get-abduct)` 시맨틱 — `H`가 assertion과 무모순,
`SAT(F ∧ H)` 까지 요구 — 은 다음으로 opt-in:

```text
(set-option :abduct-consistency true)
```

켜면 `(abduce …)`는 각 JSON 후보에 `consistent` 불리언을
붙이고 (소비자가 공허한 것을 필터/딤), `(get-abduct …)` /
`(get-abduct-next)`는 inconsistent abduct를 아예 드롭한다.

기본 *검색*은 구문적(SLD / α-match + Horn 규칙)이다 — 목표가
선언된 abducible 자신일 때(또는 Horn 해소될 때)만 후보를
낸다. 이론 목표(`x>0 ∧ y>0 ⊢ x+y>0`, `x>0 ⊢ x≥1`) — 즉 사실상
모든 산술 / SMT 의무 — 에는 아무것도 못 찾는다. 이론-aware
검색을 켜면, 선언된 abducible들의 최소 결합 `H` 중 이론 하에서
`F ∧ H ⊨ G`인 것을 찾는다 (`SAT(F ∧ H)`도 강제하므로 단독으로
완전한 cvc5 `(get-abduct)` 계약):

```text
(set-option :abduct-theory true)
```

opt-in이다: 기본 SLD 검색은 그것이 설계된 선언적 목표를 위해
유지되고, 이론 검색(bounded 부분집합 검색, 후보당 `check-sat`
1회)은 요청 시에만 비용을 치른다.

후보당 `check-sat`은 최상위 `(check-sat)`과 *동일한 완전한
풀이 경로* — OxiZ 위임 포함 — 를 탄다. 따라서 이론 검색은
공리화된 함수(`Add`, `Poly` … — 실제 검증기 의무가 쓰는 인코딩으로,
네이티브 엔진은 `unknown`이지만 e-matching / MBQI가 해소한다)
뒤의 목표까지 추론한다. 네이티브 산술에 국한되지 않는다.

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

== §3.5 JIT-on-AOT-prelude

`--aot-bake` 모드는 v0 섹션 다음에 v1 CDCL 섹션을 작성하는
composable `--aot-include-cdcl` 확장을 갖는다. v1 섹션은
post-flatten clauses + 초기 BCP trail + two-watched index +
VSIDS + phase-save를 포함한다. v1 header에는 lu-smt 바이너리의
SHA-256이 기록되어 source-level `flatten_version` knob가
놓치는 toolchain-drift도 catch한다.

```bash
# v0 Term-DAG + v1 CDCL 섹션 bake.
lu-smt --aot-bake --aot-include-cdcl --aot-output prelude.luart \
       prelude.smt2

# `--aot-load`는 v1 섹션을 자동 감지하여
# `Solver::with_aot_cdcl` 경로로 라우팅. 별도의 플래그 없이도
# 로더가 CDCL 섹션을 가져온다.
lu-smt --aot-load prelude.luart query.smt2
```

`--aot-include-cdcl`는 `--aot-bake`을 요구하며 (오용 시 exit
12), `--aot-load`와 상호 배타적이다 (exit 12).

CLI는 또한 기록된 CDCL trace를 위한 `.lutrace` 아티팩트를
제공한다. emit된 trace는 기록된 event 스트림과 더불어 그
formula의 32바이트 clause-set digest를 싣는다. digest는
점진적으로 fold된다: prelude의 순서 독립적 clause-fold를
`--aot-bake` 시점에 bank에 미리 계산해 두므로, 매
`(check-sat)` consult는 prelude 전체가 아니라 query 델타에
비례한다. load된 trace는 (`--aot-load` prelude가 함께 활성화된
경우) 매 `(check-sat)` 전에 consult되며, digest가 정확히
일치하면 기록된 `unsat`이 solve를 short-circuit한다:

```bash
# `.lutrace` emit (CDCL event + clause-set digest).
lu-smt --jit-trace-emit trace.lutrace query.smt2

# slim(verdict-only): consult가 읽는 digest + terminal
# conflict만 emit하고 propagation 스트림은 드롭.
# clean `unsat`일 때만.
lu-smt --jit-trace-emit-slim slim.lutrace query.smt2

# 미리 emit된 `.lutrace`(full 또는 slim)을 load하여 매
# `(check-sat)` 전에 consult (--aot-load와 함께 사용).
lu-smt --aot-load prelude.luart \
       --jit-trace-load trace.lutrace query.smt2
```

`--jit-trace-emit`, `--jit-trace-emit-slim`, `--jit-trace-load`는
상호 배타적이다 (exit 12).

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
