= LSP 치트시트

`adsmt-lsp` 는 SMT-LIB 및 lu-kb 파일을 위한 tower-lsp
기반 LSP 서버이다. 이 부록은 여섯 가지 기능과 이를
구동하는 방법을 문서화한다.

== 설치

LSP 서버는 단일 바이너리이다.

```bash
cargo install --path adsmt-lsp
# or via the meta crate
cargo install --path adsmt-meta --features lsp
```

VS Code의 경우, `tooling/vscode-extension/` 아래의 번들된
확장이 가장 쉬운 진입점이다.

== 에디터 통합

대부분의 LSP 클라이언트는 세 가지를 필요로 한다.

1. LSP 바이너리의 위치.
2. 활성화해야 할 파일 확장자 (`*.smt2` + `*.kb`).
3. (선택) 초기화 옵션.

```jsonc
// VS Code settings.json
{
  "adsmt.serverPath": "/path/to/adsmt-lsp",
  "adsmt.activateOn": ["smt2", "kb"]
}
```

nvim-lspconfig 를 사용하는 neovim 의 경우:

```lua
require'lspconfig'.adsmt.setup{
  cmd = { '/path/to/adsmt-lsp' },
  filetypes = { 'smt2', 'kb' },
}
```

Helix 사용자는 `languages.toml` 에 추가한다:

```toml
[[language]]
name = "smt2"
language-servers = ["adsmt-lsp"]
[language-server.adsmt-lsp]
command = "/path/to/adsmt-lsp"
```

== 기능 1: `publishDiagnostics`

서버는 모든 변경에 진단을 푸시한다. 세 가지 범주가
드러난다.

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*심각도*], [*출처*]),
  [Error],   [구문 분석 실패, 타입 오류],
  [Warning], [비-Miller 트리거, 고전-공리 사용, 폐기된 형태],
  [Info],    [가설추론 표면, 판정 요약],
)

진단은 위반 소스 범위에 위치하므로 에디터가 그곳으로
탐색할 수 있다.

== 기능 2: `textDocument/definition`

정의로-점프 (click-to-definition) 는 *현재 문서 내에서*
심볼 참조를 해결한다. 예시는 다음과 같다.

```text
(declare-fun f (Int) Int)  ;; declared here
(assert (= (f 3) 4))       ;; click on `f` jumps to declaration
```

교차-파일 정의는 아직 지원되지 않는다 (v1.1로 계획됨).

== 기능 3: `textDocument/hover`

호버 시 다음이 드러난다.

- BV 리터럴 해석 (`#x42` → "66 십진, 8-비트").
- 함수 선언 미리보기 (시그니처 + 반환 타입).
- 이론 원자에 대한 이론-태그.
- `(check-sat)` 커서에 대한 최종 판정.

== 기능 4: `textDocument/completion`

39개 자동 완성 항목의 정적 목록.

- 표준 SMT-LIB 명령어 (`declare-fun`, `assert`,
  `check-sat`, `get-model`, …)
- 이론 이름 (`Int`, `Real`, `BitVec`, `Array`, …)
- 고전-공리 이름 (`lem`, `peirce`, `dne`)
- lu-kb 키워드 (`sort`, `fun`, `rule`, `class`,
  `instance`, `query`)
- 이론 연산자 (`+`, `<`, `bvadd`, `select`,
  `store`, …)

`Ctrl-Space` 또는 에디터의 호출 바인딩으로 트리거한다.
자동 완성은 대소문자 구분 없는 부분 문자열이다.

== 기능 5: `workspace/symbol`

워크스페이스 전반 심볼 검색. 질의 문자열은 모든 열린
파일에 걸쳐 선언된 정렬, 함수, 또는 상수 이름의 어떤
부분 문자열과도 매칭된다. 결과는 파일 근접성 + 매치
품질로 순위 매겨져 제시된다.

== 기능 6: `textDocument/codeAction`

코드 액션은 진단에 대한 구체적인 수정을 제공한다.

- *KB 마이그레이션.* `.kb` 파일의 `kb-hash` 가 정규
  형식과 일치하지 않을 때, 현재 방언 버전으로 자동
  마이그레이션을 제안한다.
- *트리거 수정.* 비-Miller 트리거가 경고를 발생시킬 때,
  존재한다면 Miller 등가물로 재작성을 제안한다.
- *가설추론 수용.* 가설추론 판정이 표면화될 때, 후보
  가설을 `(assert ...)` 라인으로 삽입할 것을 제안한다.

== 구성

LSP는 시작 시 `initializationOptions` 블록을 받는다.

```jsonc
{
  "abductiveTier": 4,
  "triggerMode": "miller",
  "classicalAxioms": ["lem"],
  "auditFormat": "json"
}
```

이것들은 CLI 플래그를 미러링한다. 에디터-특화 확장은
일반적으로 이것들을 설정으로 노출한다.

== 성능

LSP는 증분식이다. 편집은 변경된 영역의 재-구문 분석만을
트리거한다. 전체-파일 재-해결은 `(check-sat)` 커서가
명시적으로 검사될 때만 (또는 코드 액션을 통해 요청 시)
일어난다.

큰 `.kb` 파일 (수천 개의 규칙) 의 경우, 증분 구문 분석은
LSP의 응답성을 유지한다. 재-해결은 수 초가 걸릴 수 있지만
타이핑 핫 경로를 벗어난 곳에서 일어난다.

== 에디터-비종속적 감사 소비

LSP는 CLI가 하는 것과 동일한 `--audit-json` 스트림을
`audit/diagnostics` 푸시 알림으로 노출한다. 전체 LSP
기능 집합을 이해하지 못하는 에디터 확장도 여전히 진단을
위해 감사 스트림을 소비할 수 있다 —
`tooling/vscode-extension/` 의 `audit.ts` 에 있는
TypeScript 레퍼런스는 재사용 가능하다.

== 문제 해결

- *LSP가 시작되지 않음.* 바이너리 경로를 확인하라. 파일
  확장자 필터를 확인하라. 에디터의 LSP 로그에서 오류를
  확인하라.
- *진단이 나타나지 않음.* 서버가 성공적으로 구문
  분석하고 아무것도 발견하지 못하는 것일 수 있다. 채널이
  작동하는지 확인하기 위해 의도적인 오류를 도입해
  보라.
- *자동 완성 목록이 오래됨.* 정적 목록은 LSP 빌드별이다.
  LSP 바이너리를 업그레이드하면 목록이 갱신된다.
- *큰 파일에서 느림.* 비용은 솔버 재실행에 있지,
  구문 분석기에 있지 않다. 솔버 작업을 제한하려면
  `(set-option :timeout 1000)` 을 사용하라.
