= 비트벡터, 배열, 데이터타입

이 장은 adsmt 명단의 나머지 세 이론을 스케치한다.

== 비트벡터(BV)

선언 시 지정되는 고정 폭의 부호 없는 이진 정수 — 32비트,
64비트, 또는 기타. 연산은 덧셈, 뺄셈, 곱셈, 나눗셈, 시프트,
비트별 and / or / xor, 비교 등이다.

```text
(declare-const x (_ BitVec 32))
(declare-const y (_ BitVec 32))
(assert (bvult x y))
(assert (= (bvadd x #x00000001) y))
(check-sat) ;; sat
```

BV는 하드웨어 검증과 저수준 프로그램 분석의 *주력*이다.
비트 시프트, 마스크, 오버플로우 동작이 모두 실제 하드웨어와
정확히 일치한다.

== BV 결정 절차: 세 계층

adsmt의 BV 솔버는 세 계층을 가진다.

1. *리터럴 평가.* 양변이 상수인가? 그렇다면 솔버 수준에서
   바로 평가한다 — `#x00000001 + #x00000002 = #x00000003`.
   값싸고 자주 충분하다.

2. *비트-사실 전파.* 구체적인 비트를 가진 리터럴들에 대해
   사실을 전파한다. 예컨대 `(bvand x #xff) = #x42`라면,
   상위 비트와 무관하게 $x$의 하위 8비트는 `0x42`로
   고정된다. 이는 완전한 비트-블라스팅보다 빠르다.

3. *비트-블라스팅 폴백.* 처음 두 계층이 결정하지 못하면,
   비트마다 하나의 부울 변수를 도입하고 각 게이트에 대한
   절(clause)들을 추가함으로써 BV 제약을 순수 SAT로
   부호화한다. 결과를 SAT 계층에 떨어뜨린다.

```rust
impl Theory for BvSolver {
    fn check(&mut self) -> SatVerdict {
        if let Some(c) = self.literal_eval() { return c; }
        if let Some(c) = self.bit_fact_propagate() { return c; }
        let clauses = self.bit_blast();
        self.sat.check_with(clauses)
    }
}
```

비트-블라스팅은 QF_BV에 대해 완전(complete)하다 — 모든
한정자-자유 BV 공식은 이 방식으로 결정가능하다. 비용은
부호화 크기이다. 64비트 곱셈은 $O(n^2) = 4096$개의 절을
만든다. 계층 1과 2는 가능할 때마다 부호화를 건너뛴다.

== 배열

배열 이론은 인덱스에서 값으로의 맵을 다룬다. 시그너처는
두 연산을 가진다.

- `(select A i)` — 인덱스 $i$의 값을 읽는다.
- `(store A i v)` — 인덱스 $i$가 $v$로 설정된 새로운
  배열을 만들고, 다른 인덱스는 변하지 않는다.

두 공리는 다음과 같다.

- *같은 인덱스에 대한 read-over-write*. $"select"("store"(A, i,
  v), i) = v$.
- *다른 인덱스에 대한 read-over-write*. $i eq.not j =>
  "select"("store"(A, i, v), j) = "select"(A, j)$.

```text
(declare-const A (Array Int Int))
(assert (= (select (store A 0 42) 0) 42))   ;; same: 42 = 42, sat trivial
(assert (= (select (store A 0 42) 1) (select A 1)))  ;; different: tautology
```

결정 절차는 `store` 사슬을 따라 걷는다. `store` 사슬에
대한 `select`는 가장 최근에 일치하는 store(같은 인덱스에
대한 read-over-write)로 환원되거나, 이전 요소로 재귀한다
(다른 인덱스에 대한 read-over-write).

== 배열 + LIA

배열 + LIA의 결합에서 흥미로운 일이 벌어진다. 산술 식을
이용한 인덱싱이다.

```text
(declare-const A (Array Int Int))
(declare-const i Int)
(declare-const j Int)
(assert (= i (+ j 1)))
(assert (= (select (store A i 5) j) 7))
```

store/select의 불일치는 $i eq.not j$를 결정하기 위해 LIA를
요구한다 ($i = j + 1$로부터 LIA 추론에 의해 $i eq.not j$).
Arrays 솔버는 결합 계층을 통해 LIA에게 $i = j$ 여부를
묻는다. LIA가 아니라고 응답하면, Arrays는 select가
$"select"(A, j) = 7$로 환원된다고 결론짓는다.

정중한 결합(3장)이 이를 자동으로 처리한다.

== 데이터타입

Datatypes 이론은 대수적 데이터 타입을 다룬다 — 리스트,
트리, 옵션, 레코드, 합 타입 등. 각 데이터타입은 다음을
가진다.

- *생성자(Constructors)* — `nil`, `cons`, `Some`, `None`,
  …
- *선택자(Selectors)* — `head`, `tail`, `value`, …
- *판별자(Testers)* — `is-nil`, `is-cons`, …

```text
(declare-datatype IntList ((nil) (cons (head Int) (tail IntList))))
(declare-const l IntList)
(assert (is-cons l))
(assert (= (head l) 3))
(check-sat) ;; sat: l = (cons 3 ?)
```

공리에는 다음이 포함된다.

- *서로소성(Disjointness)*. `nil` $eq.not$ `cons a t`.
- *단사성(Injectivity)*. `cons a1 t1 = cons a2 t2 => a1 = a2
  and t1 = t2`.
- *비순환성(Acyclicity)*. 어떤 데이터 값도 자신을 부분
  항으로 포함하지 않는다.

결정 절차는 생성자 소속(membership)을 추적하고 단사성/
서로소성 사실을 추적해 나간다. 비순환성은 발생-검사
(occurs-check)를 통해 확인된다.

== 셋의 EUF와의 결합

비트벡터 원소로 이루어진 해석되지 않은 배열의 비트벡터…
BV + Arrays + EUF, 그리고 정수 인덱스가 등장한다면
LIA까지 결합한다. adsmt의 정중한 결합은 임의의 부분집합을
처리한다.

```text
(declare-sort Process 0)
(declare-fun pc (Process) (_ BitVec 8))   ;; EUF + BV
(declare-fun state (Process) (Array (_ BitVec 8) Int))  ;; + Arrays + LIA
(declare-const p Process)
(assert (= (pc p) #x10))
(assert (> (select (state p) #x10) 0))
```

각 원자는 자신의 이론으로 라우팅된다.
- `(pc p) = #x10` → EUF + BV
- `(select ... #x10) > 0` → Arrays + LIA
- 공유 항 `(pc p)`가 계층 사이를 매개한다.

== 작성된 예제: 별칭화(aliased) 배열 쓰기

고전적인 검증 퍼즐 — $i$에 $x$를 저장한 뒤 $j$에 $y$를
저장하는 동작이, $i eq.not j$일 때, 그 순서를 바꾼 동작과
일치함을 증명하라.

```text
(declare-const A (Array Int Int))
(declare-const i Int)
(declare-const j Int)
(declare-const x Int)
(declare-const y Int)
(assert (not (= i j)))
(assert (not (= (store (store A i x) j y)
                (store (store A j y) i x))))
(check-sat) ;; unsat
```

Arrays 솔버의 추론: 외연성(extensionality)은 두 배열이
모든 인덱스에서 일치하면 동일하다고 말한다. 따라서 인덱스
$k$를 세 부류로 본다.

- $k = i$: 좌변은 $x$를 준다 ($i$에 store한 뒤 $i eq.not j$이므로
  $j$-store를 통과해서 select). 우변은 $x$를 준다 ($i$에
  대한 store가 맨 위이므로). 일치.
- $k = j$: 좌변은 $y$. 우변은 $y$. 일치.
- $k in.not {i, j}$: 좌변은 $A[k]$. 우변은 $A[k]$. 일치.

따라서 좌변 $=$ 우변이 모든 곳에서 성립하므로 주장이
모순이다. 인증서는 세 사례를 세 개의 하위 증명으로
기록하며, 각각이 read-over-write 추론으로 마무리된다.

== 한계

세 이론은 각각 빈틈을 가진다.

- *BV:* 곱셈 폭증. 64비트 곱셈을 부호화하면 많은 절들이
  만들어지며, 병리적인 경우 SAT 계층이 막힌다.
- *Arrays:* 외연성. 위 예제가 그것을 사용했다. 솔버는
  이를 휴리스틱하게 다루며, 항상 완전하지는 않다.
- *Datatypes:* 상호 재귀 타입과 구조적 귀납. SMT 솔버는
  귀납을 *직접* 다루지 *못한다*. 귀납은 ITP에 속하며,
  인증서 + 리플렉션 체인(10장)이 이를 잇는다.

가설추론 계층(8장)은 이러한 빈틈이 드러날 때 도움이 된다.
솔버는 단지 `unknown`이라고 답하는 대신 "여기서 귀납
가설이 필요하다"를 표면화한다.
