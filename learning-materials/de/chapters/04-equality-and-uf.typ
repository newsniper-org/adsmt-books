= Gleichheit und uninterpretierte Funktionen

== Die einfachste Theorie, die einen Namen verdient

EUF — *Gleichheit + uninterpretierte Funktionen* — ist
das Fundament. Fast jede andere Theorie baut darauf
auf. Ihre Signatur enthält keine festen Funktions- oder
Prädikatsymbole; man deklariert sie selbst:

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

Die Argumentation: aus $a = b$ erhält man $f a = f b$
und $g a = g b$ (Funktionskongruenz). Kombiniert mit
$f a = g b$ folgt $f b = g b$ und $f a = g a$. Die
Negation $not(f a = g a)$ widerspricht also.

== Gleichheit ist besonders

Die Gleichheit (`=`) trägt das folgende Axiomschema,
das in EUF eingebaut ist:

- *Reflexivität*: $forall x. x = x$
- *Symmetrie*: $forall x y. x = y => y = x$
- *Transitivität*: $forall x y z. x = y and y = z => x = z$
- *Funktionskongruenz*: $forall vec(x) vec(y). vec(x) = vec(y)
  => f(vec(x)) = f(vec(y))$ für jedes $f$.

Diese vier zusammen erzeugen die *Kongruenzhülle* einer
beliebigen Menge von Gleichungen — die kleinste
Äquivalenzrelation, die die Funktionsanwendung
respektiert.

== Union-Find + Kongruenzhülle

Das Entscheidungsverfahren ist die *Kongruenzhülle*. Die
zugrundeliegende Datenstruktur ist *Union-Find* (Wald
disjunkter Mengen):

- Jeder Term hat einen Repräsentanten.
- `find(t)` folgt den Elternzeigern zum Repräsentanten.
- `union(t1, t2)` verschmilzt zwei Äquivalenzklassen.

Der Kongruenzschritt greift, wenn zwei Terme
Repräsentanten haben, die gerade verschmolzen wurden.
Man durchläuft die Eltern beider Klassen — wenn ein Paar
$(f(s_1, …, s_n), f(t_1, …, t_n))$ die Eigenschaft hat,
dass $"find"(s_i) = "find"(t_i)$ für alle $i$ gilt, dann
müssen kraft der Kongruenz diese Eltern ebenfalls in
derselben Klasse liegen. Verschmelzen und wiederholen.
Die Kaskade terminiert schließlich, weil es nur endlich
viele Terme gibt.

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

Die asymptotische Komplexität ist nahezu linear in der
Anzahl der Terme (mit den passenden Feinjustierungen).

== EUF in adsmt

Das Modul `adsmt-theory::uf` von adsmt implementiert die
Kongruenzhülle. Es legt die Standard-`Theory`-
Schnittstelle offen (Begleitband Kap. 5):

```rust
impl Theory for UfSolver {
    fn assert_literal(&mut self, l: Literal) -> Result<(), Conflict> { ... }
    fn check(&mut self) -> SatVerdict { ... }
    fn push(&mut self) { ... }
    fn pop(&mut self)  { ... }
    fn explain(&self, t: Term) -> Vec<Literal> { ... }
}
```

`explain` ist der Schlüssel für den Zertifikatspfad:
wenn UF einen Fakt (etwa eine Gleichheit) ableitet, muss
das Zertifikat festhalten, *welche vorangehenden
Gleichheiten* verwendet wurden. `explain` durchläuft
den Union-Find-Baum und liefert den Pfad zurück.

== Warum uninterpretiert?

„Uninterpretiert" bedeutet, dass die Funktionssymbole
keine feste Bedeutung haben — sie werden nur durch die
Kongruenzaxiome eingeschränkt. Man kann alles
modellieren, was die Substitutivität respektiert:
Programmfunktionen, mathematische Operatoren, die man
nicht im Detail spezifizieren möchte, abstrakte
Relationen.

Dies macht EUF zur idealen *Rückgrat*-Theorie. Andere
Theorien (Arithmetik, Arrays, Bitvektoren) schichten
sich darauf: die Array-Theorie nutzt EUF, um die
Index-/Wert-Algebra zu behandeln, die Arithmetik-Theorie
nutzt EUF, um uneingeschränkte Variablen in linearen
Bedingungen zu modellieren.

== Häufige Muster

*Programmverifikation.* Funktionsaufrufe werden als
uninterpretiert behandelt:
`(declare-fun f (Int Int) Int)`. Behauptungen über
konkrete Aufrufe (`(= (f 1 2) 5)`) werden zu
EUF-Hypothesen. Der Verifizierer muss `f` nie auswerten
— er argumentiert lediglich darüber, *welche Aufrufe was
zurückgeben*.

*Modellabstraktion.* Eine komplexe Relation wird durch
ein uninterpretiertes Prädikat ersetzt. Nützlich in der
statischen Analyse, wenn die eigentliche Relation zu
teuer zu kodieren ist.

*Gleichheitsverkettung.* „$a = b$, $b = c$, $f a = 5$.
Was ist $f c$?" EUF antwortet trivial mit $5$. Dieselbe
Kette ist in einer rein aussagenlogischen Formulierung
deutlich umfangreicher.

== Grenzen

EUF behandelt nicht:

- Quantoren (Kapitel 7).
- Funktionsdefinitionen — `(define-fun ...)` substituiert
  syntaktisch, leitet aber keine Fakten über
  teilweise bekannte Funktionen ab.
- Gleichungen höherer Stufe — $f = g$ als Hypothese ist
  in EUF trivial, doch Solver leiten in der Regel keine
  Funktionsgleichungen *ab*, außer in Spezialfällen.

Bei den meisten dieser Fälle ist der Trick zu
*abduzieren*: man fragt die abduktive Schicht (Kapitel
8), welche Hypothese das Ziel abschließen würde. Lautet
die Antwort „nimm $f = g$ an", kann der Nutzer
entscheiden, ob die Annahme vertretbar ist.

== Durchgerechnetes Beispiel

Eine kurze Beweisverpflichtung in Lean 4, die in adsmt
eingespeist wird:

```lean
example (a b : Nat) (h : a = b) :
    (f a) + (g b) = (f b) + (g a) := by
  smt_decide [h]
```

Die Taktik `smt_decide` übersetzt das Ziel in einen
SMT-LIB-Mix aus EUF + LIA, behauptet die Negation und
fragt auf unsat.

Das übersetzte SMT-LIB:

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

Das Zertifikat enthält: Reflexivität auf $f(a)$,
Kongruenz mit $a = b$, um $f(a) = f(b)$ zu erhalten,
Kongruenz auf $g$ sowie einen LIA-Schritt, der die
Gleichheit der vertauschten Summe beweist.

Dies ist EUF in seiner Bestform: Gleichheiten durch
Funktionsanwendungen verfolgen. Der nachgelagerte
Lean-Elaborator wandelt das Zertifikat wieder in einen
echten Lean-Term unter dem Kern um.
