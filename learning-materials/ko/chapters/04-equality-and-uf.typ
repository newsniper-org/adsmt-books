= 동치와 해석되지 않은 함수

== 이름 붙일 가치가 있는 가장 단순한 이론

EUF — *동치(equality) + 해석되지 않은 함수(uninterpreted
functions)* — 는 토대(foundation)이다. 거의 모든 다른
이론이 그 위에 쌓인다. EUF의 시그너처에는 고정된 함수나
술어 기호가 없다 — 사용자가 직접 선언한다.

```text
(declare-sort Term 0)
(declare-fun f (Term) Term)
(declare-fun g (Term) Term)
(declare-const a Term)
(declare-const b Term)

(assert (= (f a) (g b)))
(assert (= a b))
(assert (not (= (f a) (g a))))
(check-sat)  ;; unsat
```

추론은 다음과 같다. $a = b$로부터 함수 합동(function
congruence)에 의해 $f a = f b$와 $g a = g b$를 얻는다.
$f a = g b$와 결합하면 $f b = g b$와 $f a = g a$를 얻는다.
따라서 부정 $not(f a = g a)$는 모순이 된다.

== 동치는 특별하다

동치(`=`)는 EUF에 내장된 다음과 같은 공리 도식(axiom
schema)을 가진다.

- *반사성(Reflexivity)*: $forall x. x = x$
- *대칭성(Symmetry)*: $forall x y. x = y => y = x$
- *추이성(Transitivity)*: $forall x y z. x = y and y = z =>
  x = z$
- *함수 합동(Function congruence)*: 모든 $f$에 대해
  $forall vec(x) vec(y). vec(x) = vec(y) => f(vec(x)) =
  f(vec(y))$.

이 넷이 함께 어떤 동치 집합의 *합동 폐포(congruence
closure)* — 함수 적용을 존중하는 가장 작은 동치 관계 —
를 생성한다.

== 유니온-파인드 + 합동 폐포

결정 절차는 *합동 폐포(congruence closure)*이다. 그
자료구조는 *유니온-파인드(union-find)* (서로소 집합 숲,
disjoint-set forest)이다.

- 각 항은 대표 원소(representative)를 갖는다.
- `find(t)`는 부모 포인터를 따라 대표 원소로 간다.
- `union(t1, t2)`는 두 동치류(equivalence class)를 병합한다.

합동 단계는 두 항의 대표 원소가 방금 병합되었을 때
발동한다. 두 동치류의 부모들을 훑어 — 어떤 한 쌍
$(f(s_1, …, s_n), f(t_1, …, t_n))$에 대해 모든 $i$에
대해 $find(s_i) = find(t_i)$가 성립하면, 합동에 의해
그 부모들 또한 같은 동치류에 속해야 한다. 그 부모들을
병합하고 반복한다. 항이 유한 개이기 때문에 이 폭포 단계는
결국 종료된다.

```rust
fn union(&mut self, a: TermId, b: TermId) {
    let ra = self.find(a);
    let rb = self.find(b);
    if ra == rb { return; }
    self.parent[rb] = ra;
    let parents_a = self.collect_parents(ra);
    let parents_b = self.collect_parents(rb);
    for pa in parents_a {
        for pb in &parents_b {
            if self.are_congruent(pa, *pb) {
                self.union(pa, *pb);  // cascade
            }
        }
    }
}
```

점근적 복잡도는 (적절한 소규모 조정과 함께) 항 수에
대해 거의 선형이다.

== adsmt에서의 EUF

adsmt의 `adsmt-theory::uf` 모듈은 합동 폐포를 구현한다.
표준 `Theory` 인터페이스(동반서 5장)를 노출한다.

```rust
impl Theory for UfSolver {
    fn assert_literal(&mut self, l: Literal) -> Result<(), Conflict> { ... }
    fn check(&mut self) -> SatVerdict { ... }
    fn push(&mut self) { ... }
    fn pop(&mut self)  { ... }
    fn explain(&self, t: Term) -> Vec<Literal> { ... }
}
```

`explain`은 인증서(cert) 경로의 핵심이다. UF가 어떤
사실(예컨대 어떤 동치)을 도출했을 때, 인증서는 *어떤
이전 동치들*이 사용되었는지를 기록해야 한다. `explain`은
유니온-파인드 트리를 따라가며 그 경로를 반환한다.

== 왜 "해석되지 않은"인가?

"해석되지 않은(uninterpreted)"이라는 말은 함수 기호에
고정된 의미가 없음을 뜻한다 — 그들은 오직 합동 공리들에
의해서만 제약된다. 대입 가능성(substitutivity)을 존중하는
무엇이든 모델링할 수 있다. 프로그램의 함수, 자세히
규정하지 않기로 한 수학적 연산자, 추상적 관계 등이
그렇다.

이로 인해 EUF는 이상적인 *기반(backbone)* 이론이 된다.
다른 이론들(산술, 배열, 비트벡터)이 그 위에 층을 쌓는다.
배열 이론은 EUF를 이용해 인덱스/값 대수를 다루고, 산술
이론은 EUF를 이용해 선형 제약 안의 제약 없는 변수들을
모델링한다.

== 흔한 패턴

*프로그램 검증.* 함수 호출을 해석되지 않은 것으로 다룬다.
`(declare-fun f (Int Int) Int)`처럼. 특정 호출에 대한
주장(`(= (f 1 2) 5)`)은 EUF 가설이 된다. 검증기는 `f`를
실제로 평가할 필요가 전혀 없다 — 그저 *어느 호출이
무엇을 반환하는지*만 추론한다.

*모델 추상화.* 복잡한 관계를 해석되지 않은 술어로
치환한다. 실제 관계를 인코딩하기에 비용이 너무 클 때
정적 분석에서 유용하다.

*동치 사슬.* "$a = b$, $b = c$, $f a = 5$. 그러면 $f c$는?"
EUF는 자명하게 $5$라고 답한다. 같은 사슬을 순수 명제적
형식으로 표현하면 훨씬 더 장황해진다.

== 한계

EUF는 다음을 다루지 못한다.

- 한정자(7장).
- 함수 정의 — `(define-fun ...)`은 통사적으로 치환할
  뿐, 부분적으로만 알려진 함수에 대한 사실을 도출하지
  않는다.
- 고차 등식 — 가설로서의 $f = g$는 EUF에는 자명하나,
  솔버는 보통 특별한 경우를 제외하고는 함수 동치를
  *도출하지* 않는다.

이러한 대부분의 경우, 요령은 *가설추론하는(abduce)*
것이다. 가설추론 계층(8장)에게 "목표를 처리하려면 어떤
가설이 필요한가?"를 묻는다. 답이 "$f = g$를 가정하라"라면,
사용자가 그 가정이 합당한지 판단하면 된다.

== 작성된 예제

adsmt에 들어가는 짧은 Lean 4 증명 의무이다.

```lean
example (a b : Nat) (h : a = b) :
    (f a) + (g b) = (f b) + (g a) := by
  smt_decide [h]
```

`smt_decide` 택틱은 목표를 SMT-LIB의 EUF + LIA 혼합으로
번역하고, 부정을 주장한 뒤 unsat을 요구한다.

번역된 SMT-LIB은 다음과 같다.

```text
(declare-sort Nat 0)
(declare-fun f (Nat) Nat)
(declare-fun g (Nat) Nat)
(declare-const a Nat)
(declare-const b Nat)
(assert (= a b))
(assert (not (= (+ (f a) (g b)) (+ (f b) (g a)))))
(check-sat)
;; unsat
```

인증서는 다음을 포함한다. $f(a)$에 대한 반사 규칙
(refl), $a = b$를 사용한 합동으로 $f(a) = f(b)$ 도출,
$g$에 대한 합동, 그리고 항을 교환한 합 동치를 증명하는
LIA 단계.

이것이 EUF가 가장 잘하는 일이다. 함수 적용을 가로질러
동치를 추적하는 것. 하류(downstream)의 Lean 정제기
(elaborator)는 인증서를 다시 커널 아래의 실제 Lean
항(term)으로 변환한다.
