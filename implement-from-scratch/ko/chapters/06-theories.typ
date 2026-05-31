= 개별 이론들

이 장은 adsmt가 함께 공급하는 각 이론을 대략 구현 복잡도
오름차순으로 살펴본다.

== 해석되지 않은 함수(UF)

가장 단순한 이론. UF는 해석되지 않은 함수 기호와 상수에
대한 등식과 불등식을 단언한다:
$ f(a) = b, quad a = c, quad b != f(c) $

자연스러운 자료구조는 항에 대한 *union-find*이며,
*합동 폐포*로 증강된다: $a = c$가 union-find에 들어오면,
구조는 $f(a)$와 $f(c)$(그리고 재귀적으로 그것들 위에
세워진 더 큰 항들)를 병합해야 한다.

```rust
pub struct Uf {
    parent: HashMap<Term, Term>,        // union-find pointer
    rank: HashMap<Term, usize>,         // for rank-based union
    diseqs: Vec<(Term, Term)>,          // asserted disequalities
    scope_stack: Vec<UfSnapshot>,
}
```

`assert(t1 = t2)`는 `union(t1, t2)`를 호출한다.
`assert(t1 != t2)`는 먼저 `find(t1) == find(t2)`(즉시
충돌)인지 검사하고 그렇지 않으면 쌍을 기록한다. `check()`
는 현재의 find 루트들에 대해 불등식 스캔을 다시 실행한다.

합동: 각 동치류마다 *부모 항* 목록 — 그 동치류의 대표
중 하나를 인자로 갖는 적용 — 을 유지한다. 매 union 후
두 동치류의 부모 목록을 훑어, 그중 어느 두 개라도 이제
합동(같은 머리, 같은 인자별 동치류)인지 검사한다. 그렇다면
그것들도 union한다. 이 폭포는 e-그래프에서 이미 본 것과
같은 모양이다.

== 선형 산술 — 한계와 Simplex

LIA(정수)와 LRA(실수)는 선형 부등식을 다룬다. adsmt는
2계층 전략을 사용한다:

*계층 1 — 한계 추적.* 각 변수마다 진행 중인 하한
$ell_x$와 상한 $u_x$를 유지한다. 새 제약은 한계를
조인다. 어떤 변수에서 $ell_x > u_x$이면 모순이다.

```rust
pub struct LinArith {
    name_: &'static str,
    bounds: HashMap<String, Bounds>,
    scope_stack: Vec<LinArithSnapshot>,
    conflict: Option<TheoryWitness>,
}
struct Bounds {
    lower: Option<(i128, bool)>, // (value, strict?)
    upper: Option<(i128, bool)>,
}
```

이는 변수-대-상수 제약(`x ≤ 5`, `x ≥ 3`)을 상수 시간에
다룬다. LIA에서는 엄격 부등식이 정수 대응물로 조여진다:
`x > 5`는 `x ≥ 6`이 된다.

*계층 2 — Simplex 테이블*(OxiZ의 `oxiz-math` 경유).
여러 변수가 관여하는 제약(`x + y ≤ z + 3`)에는 한계
추적만으로는 부족하다. 그 리터럴은 표준 테이블 표현을
유지하면서 가능해(feasible) 또는 모순이 나올 때까지
피벗하는 Simplex 백엔드로 전달된다.

```rust
fn assert(&mut self, lit: Literal) -> AssertResult {
    if let Some((var, op, k)) = self.dest_var_constant(&lit.term) {
        if let Some(witness) = self.record_bound(var, op, k) {
            return AssertResult::Conflict { witness };
        }
        AssertResult::Accepted
    } else if self.is_two_var_constraint(&lit.term) {
        self.simplex.assert(lit)
    } else {
        AssertResult::Ignored
    }
}
```

2계층 설계는 제약의 대부분이 변수-대-상수일 때 보상을
얻는다 — 비싼 Simplex 피벗이 정말 필요할 때만 발화한다.

== 비트벡터

BV 제약은 고정 폭 이진 산술이다:
`(= (bvadd x 1) (bvor y 0xff))`. adsmt는 이를 세
계층으로 다룬다:

*계층 1 — 리터럴 평가.* 비트벡터 연산자의 양 피연산자가
모두 구체적 리터럴이면, 단언 시점에 평가한다:
$ "bvand"("0b1100", "0b1010") -> "0b1000" $

*계층 2 — 비트-수준 사실 전파.* 한 피연산자가 변수이고
다른 쪽이 리터럴이면, 변수에 대한 부분적인 비트 지식을
도출한다. `(bvand x 0x0F) = 0x05`의 경우: `x`의 상위 4
비트는 제약이 없고(AND가 결과에서 0으로 만든다), `x`의
하위 4비트는 `0x5`여야 한다. 부분적 지식을 변수별
`(mask, value)` 쌍으로 인코딩하고, 쌍을 누적해서 병합하며,
`mask`가 폭의 모든 비트를 덮으면 완전한 결합(binding)으로
승격시킨다.

*계층 3 — 비트-블라스팅*(`bv_blast` 경유). 변수-혼합
제약(`(bvadd x y) = (bvmul z 3)`)에서는 각 BV 비트를
새 부울 원자로 낮추고, 비트-수준 의미론을 인코딩하는
CNF를 방출한다. CNF는 SAT 백엔드로 가서 명제 문제로
결정된다. 가산기는 ripple-carry 체인으로, 곱셈기는
shift-and-add로 구현되며, AND/OR/XOR은 비트 단위이다.

```rust
pub fn blast_term(t: &Term, w: u32, env: &mut BlastEnv) -> Option<Vec<Bit>> {
    if let Some((value, lw)) = t.dest_bv_lit() {
        return Some(lit_bits(value, w));
    }
    if let Term::Var(v) = t {
        return Some((0..w).map(|i| Bit::Atom(bit_var(&v.name, i))).collect());
    }
    if let Some((op, ow, lhs, rhs)) = t.dest_bv_binop() {
        // lower lhs and rhs, then combine bit-by-bit
        // according to op (bvand, bvor, bvxor, bvadd, bvsub, bvmul).
    }
    None
}
```

== 배열 — 쓰기 위의 읽기

배열 이론은 `(select arr idx)`와 `(store arr idx val)`
연산을 다룬다. 핵심 추론 규칙은 *쓰기 위의 읽기*
(read over write)이다:

$ "select"("store"(a, i, v), j) = cases(
  v "if" i = j,
  "select"(a, j) "if" i != j,
) $

연산적으로: 식
`(select (store a i v) j) = expr`을 단언할 때 다시쓰기를
시도한다. 같은-인덱스 경우는 무조건 발화하고, 서로 다른
인덱스 경우는 `i != j`가 이미 알려져 있다는 증거(직접
단언되었거나 도출되었거나)를 요구한다.

```rust
fn read_over_write(t: &Term, diseqs: &[(Term, Term)]) -> Option<(Term, String)> {
    let (arr, j) = t.dest_select()?;
    let (inner_a, i, v) = arr.dest_store()?;
    if i.alpha_eq(&j) {
        Some((v, "same-index".into()))
    } else if pair_known_disequal(&i, &j, diseqs) {
        Some((mk_select(inner_a, j), "diseq-index".into()))
    } else {
        None
    }
}
```

두 번째 규칙은 store-over-store를 정규화한다:
$ "store"("store"(a, i, v_1), j, v_2) = cases(
  "store"(a, i, v_2) "if" i = j,
  "store"("store"(a, j, v_2), i, v_1) "if" i != j,
) $

같은-인덱스 우세 규칙이 더 쓸모 있는 규칙이다(중복된
쓰기들을 무너뜨린다). 인덱스가 서로 다를 때의 교환성은
중첩된 store를 정규 순서로 놓아 하류 EUF가 별명(aliasing)을
검출할 수 있게 돕는다.

음의 배열 등식 — 배열-sort 피연산자 간의 `a != b` — 은
*확장성 증거*(extensionality witness)를 대기열에 넣는다:
어떤 인덱스 $d$가 존재하여 `select(a, d) != select(b, d)`
여야 한다. 한정자 계층(7장)이 $d$를 인스턴스화할 책임을
진다.

== 대수적 자료형

대수적 자료형 — `Color = Red | Green | Blue` — 그리고
`Nat = Zero | Succ Nat`이나 `List a = Nil | Cons a (List a)`
같은 귀납적 자료형은 전용 이론을 갖는다. 두 핵심 추론
규칙:

*생성자 서로소성.* `a`가 `Red`로 만들어졌고 `b`가
`Green`으로 만들어졌다면, 그들은 같을 수 없다. `a = b`를
단언하면 즉시 충돌이 산출된다.

*단사성(Injectivity).* `Cons head1 tail1 = Cons head2 tail2`
가 성립한다면 `head1 = head2`이고 `tail1 = tail2`이다.
이론의 `derive_equalities`는 생성자 적용들 사이의 단언된
등식을 훑으며 인자별 등식을 방출한다.

```rust
fn derive_equalities(&self) -> Vec<(Term, Term)> {
    let mut out = Vec::new();
    for (a, b) in &self.asserted_eqs {
        if let (Some((ca, args_a)), Some((cb, args_b))) =
            (Self::dest_constructor_app(a), Self::dest_constructor_app(b))
        {
            if ca == cb && args_a.len() == args_b.len() {
                for (arg_a, arg_b) in args_a.into_iter().zip(args_b) {
                    out.push((arg_a, arg_b));
                }
            }
        }
    }
    out
}
```

기수: 유한 enum은 유한 기수 증거를 가지며, 귀납적
자료형은 $omega$이다. 정중한 결합은 이를 기수 클릭
검사에 사용한다.

== 정중한 결합 인터페이스

위의 모든 이론은 `Theory` 트레이트에 꽂혀 들어간다.
결합 오케스트레이터(5장)가 이들을 집합적으로 구동한다.
안무는 이론과 무관하게 균일하다: 같은 트레이트, 같은
프로토콜, 같은 `push`/`pop` 모양. 이 때문에 새 이론을
추가하는 일이 잘 봉쇄된 실습이 된다 — 트레이트를 구현하고
인스턴스를 등록하면, 결합 기구가 그것을 집어 든다.

독자에게 유용한 실습: 이러한 노선을 따라 문자열 이론을
구현해보라. 기본 연산(`length`, `concat`, `substr`)에
제약 어휘(`prefix-of`, `contains`)를 더하면 실세계 SMT
워크로드의 놀라울 정도의 비율을 다룰 수 있다. 비결은
길이 추상화이다 — 대부분의 문자열 식은 길이에 대한
산술과 문자에 대한 등식 추론으로 분해된다.
