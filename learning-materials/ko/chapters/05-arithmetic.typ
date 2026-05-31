= 산술

== 두 가지 산술 이론

SMT-LIB은 다음을 구분한다.

- *LIA* (linear integer arithmetic, 선형 정수 산술) —
  정수 변수와, 상수에 의한 $+$, $-$, $*$, 그리고 $<$,
  $<=$, $=$, $>$, $>=$로 구성된 제약.
- *LRA* (linear real arithmetic, 선형 실수 산술) — 같은
  형태이나, 변수가 실수 위에서 범위(range)를 갖는다.

어느 쪽에도 *속하지 않는* 것은 비선형 곱셈(`x * y`), 나눗셈
(`x / y`), 모듈러 산술(비트벡터 인코딩을 제외하고)이다.
이것들은 NLA / NRA에 속하며, 더 어려운 단편들이다.

== 선형 제약

*선형 제약*은 다음 형태를 가진다.

$ a_1 x_1 + a_2 x_2 + dots + a_n x_n thick op thick c $

여기서 $a_i$와 $c$는 상수이고, $op in {< , <=, =, >=,
>, !=}$이다. 변수는 이론에 따라 실수이거나 정수일 수 있다.

```text
; LIA
(declare-const x Int)
(declare-const y Int)
(assert (<= (+ x y) 10))
(assert (>= x 3))
(assert (>= y 4))

; LRA
(declare-const a Real)
(assert (<= a 2.5))
(assert (>= a 1.5))
```

두 단편 모두 결정가능이다. LRA 한정자-자유는 P(다항
시간)이고, LIA 한정자-자유는 NP-완전이다.

== 결정 절차: Simplex

LRA의 주력 절차는 선형 계획법에서 차용한 *Simplex
방법*이다. 제약은 표(tableau) 위의 부등식으로 쓰여,
피벗(pivot) 단계가 실현 가능한 점이나 실현 불가능을
증명하는 Farkas 증거를 향해 움직인다.

```text
     | x  y | constant
-----|------|---------
 s1  | 1  1 | s1 ≤ 10
 s2  | 1  0 | s2 ≥ 3
 s3  | 0  1 | s3 ≥ 4
```

Simplex는 기본 실현가능성(basic feasibility)을 유지하면서
표를 반복적으로 피벗하여, 모든 제약이 만족되거나(sat)
어떤 한 행이 실현 가능한 해가 없음을 증명할(unsat)
때까지 진행한다.

LIA의 경우 Simplex는 *유리수* 해를 찾는데, 그 해가
우연히 정수 좌표라면 끝이다. 그렇지 않으면 *분기-한정
(branch-and-bound)*이 추가 제약 — "$x <= 3$이거나 $x >= 4$"
— 을 도입하고 재귀한다.

adsmt의 `adsmt-theory::lia`와 `::lra`는 계층화된 접근을
사용한다. 먼저 값싼 *경계 전파(bounds propagation)*
(모든 변수는 구간 경계를 가지며, 관심 구간을 좁히는 것은
빠르고 자주 충분하다)를 수행하고, 경계만으로 결정되지
않을 때 Simplex를 수행한다.

== 경계 전용 빠른 경로

많은 실제 LIA 문제는 경계만으로 결정 가능하다.

```text
(assert (<= x 10))
(assert (>= x 5))
(assert (= y (+ x 3)))
(assert (>= y 15))
```

경계는 $5 <= x <= 10$이라고 말하므로, $8 <= y <= 13$이다.
제약 $y >= 15$는 상한 13과 모순된다. Simplex를 한 번도
호출하지 않고 결정되었다.

```rust
pub struct LiaSolver {
    bounds: HashMap<VarId, Interval>,
    asserted: Vec<LinConstraint>,
    simplex: Option<SimplexState>,
}

impl LiaSolver {
    fn check(&mut self) -> SatVerdict {
        if let Some(c) = self.bound_propagate() {
            return SatVerdict::Unsat(c);
        }
        // Bounds didn't decide. Build Simplex.
        let simplex = self.build_simplex();
        match simplex.solve() {
            SimplexResult::Feasible(m) => SatVerdict::Sat(m),
            SimplexResult::Infeasible(farkas) => SatVerdict::Unsat(farkas),
        }
    }
}
```

Simplex는 경계로 충분하지 않을 때에만 등판한다. 대화형
사용에서 이는 큰 이득이다 — 대부분의 목표는 마이크로초
단위로 결정된다.

== 한정자가 있는 산술 — Presburger

*한정자가 있는* LIA — Presburger 산술 — 은 결정가능이지만
매우 비싸다. 표준 결정 절차는 *Cooper의 알고리즘*
(또는 Omega와 같은 정련) 이며, 최악의 경우 삼중 지수의
복잡도를 가진다.

adsmt는 완전한 Presburger 결정 절차를 탑재하지 않는다.
한정자가 있는 LIA 목표에 대해 엔진은 휴리스틱하게
인스턴스화를 시도하고, 인스턴스화가 고갈되면 가설추론
계층으로 떨어진다. 이는 Presburger-참인 일부 공식이
`unsat` 대신 `abductive`라는 판정을 받는다는 뜻이다.
사용자는 가설추론 가설을 받아들이거나, 전용 Presburger
택틱으로 물러난다.

== 흔한 패턴

*루프 경계.* 검증 맥락에서의 "$0 <= i <= n$". LIA가
직접 다룬다. 배열 인덱싱(`select A i`)과 결합하려면
Arrays + LIA 결합(6장)이 필요하다.

*제어 이론에서의 실수 값 제약.* "제어기가 $y$를 $[0, 1]$
안에 유지해야 한다." LRA의 Simplex가 자연스럽게 맞는다.

*모듈러 산술.* SMT-LIB에는 "모듈러 산술" 이론이 직접
존재하지 않는다. 비트벡터(6장)를 통해 인코딩하거나,
가분성(divisibility) 제약을 갖는 보조 정수 변수를 통해
인코딩한다.

== 미묘한 점들

*엄격한 vs 비엄격한.* Simplex는 비엄격 부등식($<=$,
$>=$)을 자연스럽게 다룬다. 엄격한 부등식($<$, $>$)은
*델타-섭동(delta-perturbation)*을 요구한다 — 무한소 $delta
> 0$을 도입하고 $x < c$를 $x <= c - delta$로 다룬다.
결정 결과는 특정 $delta$에 의존하지 않는다.

*계수 폭증.* Simplex 피벗을 반복하면 계수가 크게 자랄
수 있다. adsmt는 산술 모듈 전반에 임의 정밀도 유리수를
사용한다. 비용은 적정하고 정확성은 그만한 가치가 있다.

*정수 실현 불가능성.* Simplex + 분기-한정에 의한 LIA는
적대적인 입력에 대해 지수 시간이 걸릴 수 있다("Pigeonhole"
벤치마크 참고). 잘 조건화된 현실 입력에 대해서는 최악의
경우가 거의 나타나지 않는다.

== 작성된 예제

제약: $x + 2y + 3z = 10$, $x >= 5$, $y >= 3$, $z >= 2$를
만족하는 정수 트리플 $(x, y, z)$가 존재하지 않음을 증명하라.

```text
(declare-const x Int)
(declare-const y Int)
(declare-const z Int)
(assert (= (+ x (* 2 y) (* 3 z)) 10))
(assert (>= x 5))
(assert (>= y 3))
(assert (>= z 2))
(check-sat) ;; unsat
```

LIA 솔버의 추론: 경계는 $x >= 5$, $y >= 3$, $z >= 2$를
주고, 따라서 $x + 2y + 3z >= 5 + 6 + 6 = 17 > 10$이다.
등식은 실현 불가능하다. 판정 `unsat`.

인증서는 Farkas 결합을 명시적으로 기록한다.

```text
(step :rule theory :theory lia :witness
  (farkas
    :combination ((1.0 c_eq) (-1.0 c_x_lb) (-2.0 c_y_lb) (-3.0 c_z_lb))
    :concludes 10 ≥ 17))
```

이것이 하류의 ITP들(Lean의 `linarith`, Rocq의 `lia`,
Isabelle의 `arith`)이 소비하는 LIA-측 인증서이다.
