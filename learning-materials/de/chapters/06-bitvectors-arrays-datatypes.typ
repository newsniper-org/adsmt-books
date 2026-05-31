= Bitvektoren, Arrays, Datentypen

Dieses Kapitel skizziert die drei verbleibenden Theorien
aus dem Spektrum von adsmt.

== Bitvektoren (BV)

Vorzeichenlose binäre Ganzzahlen fester Breite — 32 Bit,
64 Bit oder eine beliebige andere bei der Deklaration
festgelegte Breite. Operationen: Addition, Subtraktion,
Multiplikation, Division, Shifts, bitweises and / or /
xor, Vergleiche.

```text
(declare-const x (_ BitVec 32))
(declare-const y (_ BitVec 32))
(assert (bvult x y))
(assert (= (bvadd x #x00000001) y))
(check-sat) ;; sat
```

BV ist das *Arbeitspferd* der Hardware-Verifikation und
der Low-Level-Programmanalyse. Bit-Shift-, Masken- und
Überlaufverhalten stimmen exakt mit realer Hardware
überein.

== Entscheidungsverfahren für BV: drei Schichten

Der BV-Solver von adsmt hat drei Schichten:

1. *Literalauswertung.* Konstanten auf beiden Seiten?
   Einfach auf Solver-Ebene auswerten —
   `#x00000001 + #x00000002 = #x00000003`. Günstig und
   häufig ausreichend.

2. *Bit-Fakt-Propagation.* Bei Literalen mit konkreten
   Bits werden Fakten propagiert: wenn
   `(bvand x #xff) = #x42`, sind die unteren 8 Bit von
   $x$ unabhängig von den oberen Bits auf `0x42`
   festgelegt. Dies ist schneller als vollständiges
   Bit-Blasting.

3. *Bit-Blasting-Rückfall.* Wenn die ersten beiden
   Schichten nicht entscheiden, wird die BV-Bedingung
   in reines SAT kodiert, indem pro Bit eine boolesche
   Variable eingeführt und für jedes Gatter Klauseln
   hinzugefügt werden. Das Ergebnis wird in die SAT-
   Schicht gegeben.

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

Bit-Blasting ist vollständig für QF_BV — jede
quantorenfreie BV-Formel ist auf diesem Weg
entscheidbar. Der Preis ist die Kodierungsgröße: eine
64-Bit-Multiplikation erzeugt $O(n^2) = 4096$ Klauseln.
Die Schichten 1 und 2 umgehen die Kodierung, wann immer
es möglich ist.

== Arrays

Die Array-Theorie behandelt Abbildungen von Indizes auf
Werte. Die Signatur hat zwei Operationen:

- `(select A i)` — den Wert am Index $i$ lesen.
- `(store A i v)` — ein neues Array erzeugen, bei dem
  der Index $i$ auf $v$ gesetzt ist, alle anderen
  unverändert bleiben.

Zwei Axiome:

- *Read-over-Write gleich.* $select(store(A, i, v), i) = v$.
- *Read-over-Write verschieden.* $i ne j => select(store(A,
  i, v), j) = select(A, j)$.

```text
(declare-const A (Array Int Int))
(assert (= (select (store A 0 42) 0) 42))   ;; same: 42 = 42, sat trivial
(assert (= (select (store A 0 42) 1) (select A 1)))  ;; different: tautology
```

Das Entscheidungsverfahren läuft `store`-Ketten ab. Ein
`select` in eine `store`-Kette reduziert sich entweder
auf den jüngsten passenden Store (Read-over-Write
gleich) oder rekurriert auf den Vorgänger
(Read-over-Write verschieden).

== Arrays + LIA

Die Kombination Arrays + LIA ist es, wo es spannend
wird. Indizierung mit arithmetischen Ausdrücken:

```text
(declare-const A (Array Int Int))
(declare-const i Int)
(declare-const j Int)
(assert (= i (+ j 1)))
(assert (= (select (store A i 5) j) 7))
```

Die store/select-Unstimmigkeit erfordert LIA, um
$i ne j$ zu bestimmen (aus $i = j + 1$ ergibt sich
durch LIA-Argumentation $i ne j$). Der Arrays-Solver
ruft die Kombinationsschicht auf, um LIA zu fragen, ob
$i = j$; LIA antwortet nein; Arrays schließt, dass sich
das select auf $select(A, j) = 7$ reduziert.

Die polite-Kombination (Kapitel 3) erledigt das
automatisch.

== Datentypen

Die Datentypen-Theorie behandelt algebraische
Datentypen: Listen, Bäume, Option, Records, Summentypen.
Jeder Datentyp hat:

- *Konstruktoren* — `nil`, `cons`, `Some`, `None`, …
- *Selektoren* — `head`, `tail`, `value`, …
- *Tester* — `is-nil`, `is-cons`, …

```text
(declare-datatype IntList ((nil) (cons (head Int) (tail IntList))))
(declare-const l IntList)
(assert (is-cons l))
(assert (= (head l) 3))
(check-sat) ;; sat: l = (cons 3 ?)
```

Zu den Axiomen gehören:

- *Disjunktheit.* `nil` $ne$ `cons a t`.
- *Injektivität.* `cons a1 t1 = cons a2 t2 => a1 = a2
  and t1 = t2`.
- *Azyklizität.* Kein Datenwert enthält sich selbst als
  Teilterm.

Das Entscheidungsverfahren verfolgt die
Konstruktor-Zugehörigkeit und jagt Injektivitäts- und
Disjunktheitsfakten. Die Azyklizität wird über einen
Occurs-Check geprüft.

== Das Trio mit EUF kombinieren

Bitvektoren über uninterpretierten Arrays von
Bitvektorelementen … kombinieren BV + Arrays + EUF und
möglicherweise zusätzlich LIA, wenn ganzzahlige Indizes
auftauchen. Die polite-Kombination von adsmt behandelt
beliebige Teilmengen:

```text
(declare-sort Process 0)
(declare-fun pc (Process) (_ BitVec 8))   ;; EUF + BV
(declare-fun state (Process) (Array (_ BitVec 8) Int))  ;; + Arrays + LIA
(declare-const p Process)
(assert (= (pc p) #x10))
(assert (> (select (state p) #x10) 0))
```

Jedes Atom wird an seine Theorie geleitet:
- `(pc p) = #x10` → EUF + BV
- `(select ... #x10) > 0` → Arrays + LIA
- Der gemeinsame Term `(pc p)` vermittelt zwischen den
  Schichten.

== Durchgerechnetes Beispiel: alias-behaftete Array-Schreibzugriffe

Ein klassisches Verifikationspuzzle: beweise, dass das
Speichern von $x$ am Index $i$ und anschließend von
$y$ am Index $j$ — bei $i ne j$ — mit der Vertauschung
kommutiert.

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

Der Arrays-Solver: die Extensionalität besagt, dass zwei
Arrays genau dann gleich sind, wenn sie an jedem Index
übereinstimmen. Man betrachte also drei Indexklassen $k$:

- $k = i$: linke Seite liefert $x$ (Store bei $i$, dann
  Lesen am $j$-Store vorbei, da $i ne j$). Rechte Seite
  liefert $x$ (Store bei $i$ ganz oben). Gleich.
- $k = j$: linke Seite liefert $y$. Rechte Seite liefert
  $y$. Gleich.
- $k notin {i, j}$: linke Seite liefert $A[k]$. Rechte
  Seite liefert $A[k]$. Gleich.

Also gilt überall linke Seite $=$ rechte Seite, im
Widerspruch zur Behauptung. Das Zertifikat hält die
drei Fälle als drei Teilbeweise fest, die jeweils mit
Read-over-Write-Argumentation abschließen.

== Grenzen

Jede der drei Theorien hat Lücken:

- *BV:* Multiplikationsexplosion. Die Kodierung einer
  64-Bit-Multiplikation erzeugt viele Klauseln; in
  pathologischen Fällen verschluckt sich die SAT-Schicht.
- *Arrays:* Extensionalität. Das obige Beispiel hat sie
  verwendet. Solver behandeln sie heuristisch, nicht
  immer vollständig.
- *Datentypen:* wechselseitig rekursive Typen und
  strukturelle Induktion. SMT-Solver behandeln Induktion
  *nicht* direkt. Induktion gehört zum ITP, was die
  Zertifikats- + Reflexionskette (Kapitel 10)
  überbrückt.

Die abduktive Schicht (Kapitel 8) hilft, wenn diese
Lücken zubeißen: der Solver legt offen „ich bräuchte
eine Induktionshypothese", statt einfach `unknown` zu
liefern.
