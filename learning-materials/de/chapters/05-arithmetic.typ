= Arithmetik

== Zwei arithmetische Theorien

SMT-LIB unterscheidet:

- *LIA* (lineare ganzzahlige Arithmetik) — ganzzahlige
  Variablen, Bedingungen aus $+$, $-$, $*$ mit einer
  Konstanten, $<$, $<=$, $=$, $>$, $>=$.
- *LRA* (lineare reelle Arithmetik) — gleiche Form,
  aber Variablen laufen über den reellen Zahlen.

Was in beiden *nicht* enthalten ist: nichtlineare
Multiplikation (`x * y`), Division (`x / y`), modulare
Arithmetik (außer als Bitvektorkodierung). Diese gehören
zu NLA / NRA, was schwierigere Fragmente sind.

== Lineare Bedingungen

Eine *lineare Bedingung* hat die Form

$ a_1 x_1 + a_2 x_2 + dots + a_n x_n thick op thick c $

wobei die $a_i$ und $c$ Konstanten sind und $op in {< , <=
, =, >=, >, !=}$. Variablen können reell oder ganzzahlig
sein, je nach Theorie.

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

Beide Fragmente sind entscheidbar. Quantorenfreies LRA
liegt in P (Polynomialzeit); quantorenfreies LIA ist
NP-vollständig.

== Das Entscheidungsverfahren: Simplex

Für LRA ist das Arbeitspferd das *Simplex-Verfahren* —
entlehnt aus der linearen Programmierung. Bedingungen
werden als Ungleichungen über einem Tableau
geschrieben; Pivot-Schritte bewegen sich entweder
Richtung eines zulässigen Punktes oder zu einem
Farkas-Zeugen der Unzulässigkeit.

```text
     | x  y | constant
-----|------|---------
 s1  | 1  1 | s1 ≤ 10
 s2  | 1  0 | s2 ≥ 3
 s3  | 0  1 | s3 ≥ 4
```

Simplex pivotiert das Tableau iterativ unter Wahrung
der Basis-Zulässigkeit, bis entweder jede Bedingung
erfüllt ist (sat) oder eine Zeile bezeugt, dass keine
zulässige Lösung existiert (unsat).

Für LIA findet Simplex eine *rationale* Lösung; hat die
Lösung zufällig ganzzahlige Koordinaten, ist man
fertig. Andernfalls führt das *Branch-and-Bound*
zusätzliche Bedingungen ein — „$x <= 3$ oder $x >= 4$"
— und rekurriert.

`adsmt-theory::lia` und `::lra` von adsmt verwenden
einen geschichteten Ansatz: zuerst die günstige
*Schrankenpropagation* (jede Variable hat
Intervallschranken; das Einengen des relevanten
Intervalls ist schnell und oft ausreichend), danach
Simplex, wenn die Schranken allein nicht entscheiden.

== Schrankenbasierter Schnellpfad

Viele reale LIA-Probleme lassen sich allein durch
Schranken entscheiden:

```text
(assert (<= x 10))
(assert (>= x 5))
(assert (= y (+ x 3)))
(assert (>= y 15))
```

Die Schranken besagen $5 <= x <= 10$, also $8 <= y <=
13$. Die Bedingung $y >= 15$ widerspricht der oberen
Schranke 13. Entschieden, ohne Simplex überhaupt
aufzurufen.

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

Auf Simplex wird nur zurückgegriffen, wenn die Schranken
nicht ausreichen. Für den interaktiven Einsatz ist dies
ein großer Gewinn — die meisten Ziele werden in
Mikrosekunden entschieden.

== Quantifizierte Arithmetik — Presburger

*Quantifiziertes* LIA — die Presburger-Arithmetik — ist
entscheidbar, aber sehr teuer. Das
Standardentscheidungsverfahren ist *Coopers Algorithmus*
(oder Verfeinerungen wie Omega) mit dreifach
exponentiellem Worst Case.

adsmt liefert kein vollständiges Presburger-
Entscheidungsverfahren mit. Für quantifizierte LIA-Ziele
instanziiert die Engine heuristisch und fällt auf die
abduktive Schicht durch, wenn die Instanziierung
erschöpft ist. Das bedeutet, dass einige
Presburger-wahre Formeln das Urteil `abductive` statt
`unsat` erhalten; der Nutzer akzeptiert die abduktive
Hypothese oder weicht auf eine dedizierte
Presburger-Taktik aus.

== Häufige Muster

*Schleifenschranken.* „$0 <= i <= n$" in einem
Verifikationskontext. LIA behandelt das unmittelbar. Die
Kombination mit Array-Indizierung (`select A i`)
erfordert die Kombination Arrays + LIA (Kapitel 6).

*Reellwertige Bedingungen in der Regelungstechnik.* „der
Regler muss $y$ innerhalb von $[0, 1]$ halten". Das
Simplex von LRA ist hier die natürliche Wahl.

*Modulare Arithmetik.* SMT-LIB besitzt keine Theorie
für „modulare Arithmetik" direkt. Man kodiert über
Bitvektoren (Kapitel 6) oder über zusätzliche
ganzzahlige Variablen mit einer Teilbarkeitsbedingung.

== Feinheiten

*Strikt vs. nicht-strikt.* Simplex behandelt
nicht-strikte Ungleichungen ($<=$, $>=$) auf natürliche
Weise. Strikte ($<$, $>$) erfordern die
*Delta-Perturbation* — man führt ein infinitesimales
$delta > 0$ ein und behandelt $x < c$ als
$x <= c - delta$. Die Entscheidungen hängen nicht vom
konkreten $delta$ ab.

*Koeffizientenexplosion.* Wiederholte Simplex-Pivots
können Koeffizienten erzeugen, die groß werden. adsmt
verwendet in allen Arithmetikmodulen rationale Zahlen
mit beliebiger Präzision; die Kosten sind moderat, und
die Korrektheit ist es wert.

*Ganzzahlige Unzulässigkeit.* LIA über Simplex +
Branch-and-Bound kann bei adversarialen Eingaben
exponentielle Zeit benötigen (siehe „Pigeonhole"-
Benchmarks). Bei wohlkonditionierten realen Eingaben
wird der Worst Case selten erreicht.

== Durchgerechnetes Beispiel

Bedingung: zu beweisen, dass es kein ganzzahliges
Tripel $(x, y, z)$ mit $x + 2y + 3z = 10$, $x >= 5$,
$y >= 3$, $z >= 2$ gibt.

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

Der LIA-Solver: die Schranken liefern $x >= 5$,
$y >= 3$, $z >= 2$, also $x + 2y + 3z >= 5 + 6 + 6 = 17
> 10$. Die Gleichung ist unzulässig. Urteil `unsat`.

Das Zertifikat hält die Farkas-Kombination explizit
fest:

```text
(step :rule theory :theory lia :witness
  (farkas
    :combination ((1.0 c_eq) (-1.0 c_x_lb) (-2.0 c_y_lb) (-3.0 c_z_lb))
    :concludes 10 ≥ 17))
```

Dies ist das LIA-seitige Zertifikat, das die
nachgelagerten ITPs (Leans `linarith`, Rocqs `lia`,
Isabelles `arith`) konsumieren.
