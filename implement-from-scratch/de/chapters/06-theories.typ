= Einzelne Theorien

Dieses Kapitel geht jede Theorie durch, die adsmt
mitliefert, ungefähr in steigender Implementierungstiefe.

== Uninterpretierte Funktionen (UF)

Die einfachste Theorie. UF behauptet Gleichheiten und
Disgleichheiten über uninterpretierten Funktionssymbolen und
Konstanten:
$ f(a) = b, quad a = c, quad b != f(c) $

Die natürliche Datenstruktur ist ein *Union-Find* über
Termen, ergänzt um *Kongruenzhülle*: tritt $a = c$ in das
Union-Find ein, muss die Struktur auch $f(a)$ und $f(c)$
fusionieren (und rekursiv alle größeren Terme, die darauf
aufbauen).

```rust
pub struct Uf {
    parent: HashMap<Term, Term>,        // union-find pointer
    rank: HashMap<Term, usize>,         // for rank-based union
    diseqs: Vec<(Term, Term)>,          // asserted disequalities
    scope_stack: Vec<UfSnapshot>,
}
```

`assert(t1 = t2)` ruft `union(t1, t2)` auf.
`assert(t1 != t2)` prüft zunächst, ob `find(t1) ==
find(t2)` (unmittelbarer Konflikt), und vermerkt sonst
das Paar. `check()` führt den Disgleichheits-Scan gegen die
aktuellen Find-Wurzeln erneut aus.

Kongruenz: man führe pro Klasse eine Liste der
*Eltern-Terme* — Anwendungen, die einen der Vertreter der
Klasse als Argument haben. Nach jeder Vereinigung
durchläuft man die Eltern-Listen beider Klassen und prüft,
ob je zwei nun kongruent sind (gleicher Kopf, gleiche
argumentweise Klasse). Wenn ja, vereinigt man auch sie.
Die Kaskade hat dieselbe Gestalt, die wir bereits beim
E-Graphen gesehen haben.

== Lineare Arithmetik — Schranken und Simplex

LIA (ganzzahlig) und LRA (reell) behandeln lineare
Ungleichungen. adsmt verwendet eine zweischichtige Strategie:

*Schicht 1 — Verfolgung von Schranken.* Pro Variable führt
man eine laufende untere Schranke $ell_x$ und obere
Schranke $u_x$. Neue Constraints verschärfen die Schranken.
Gilt $ell_x > u_x$ für irgendeine Variable: Widerspruch.

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

Das behandelt Variable-vs.-Konstante-Constraints
(`x ≤ 5`, `x ≥ 3`) in konstanter Zeit. Bei LIA verschärfen
sich strenge Ungleichungen auf ihre ganzzahligen
Gegenstücke: `x > 5` wird zu `x ≥ 6`.

*Schicht 2 — Simplex-Tableau* (via `oxiz-math` von OxiZ).
Für Constraints mit mehreren Variablen
(`x + y ≤ z + 3`) reicht die Schrankenverfolgung nicht.
Das Literal wird an ein Simplex-Backend weitergereicht, das
die übliche Tableau-Darstellung führt und pivotiert, bis
entweder eine zulässige Lösung oder ein Widerspruch
auftaucht.

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

Das zweischichtige Design zahlt sich aus, wenn der Großteil
der Constraints Variable vs. Konstante sind — die teuren
Simplex-Pivots feuern nur, wenn sie wirklich gebraucht
werden.

== Bitvektoren

BV-Constraints sind binäre Arithmetik fester Breite:
`(= (bvadd x 1) (bvor y 0xff))`. adsmt behandelt sie in
drei Schichten:

*Schicht 1 — Auswertung von Literalen.* Sind beide Operanden
eines Bitvektor-Operators konkrete Literale, wertet man
zur Assertionszeit aus:
$ "bvand"("0b1100", "0b1010") -> "0b1000" $

*Schicht 2 — Faktenfortpflanzung auf Bit-Ebene.* Ist ein
Operand eine Variable und der andere ein Literal, leitet
man partielles Bit-Wissen über die Variable her. Für
`(bvand x 0x0F) = 0x05`: die oberen vier Bits von `x` sind
nicht festgelegt (das AND hat sie im Ergebnis genullt) und
die unteren vier Bits von `x` müssen `0x5` sein. Man
codiere das partielle Wissen pro Variable als
`(mask, value)`-Paare; man mische die Paare kumulativ
zusammen; man befördere sie zu einer vollständigen Bindung,
sobald `mask` jedes Bit der Breite überdeckt.

*Schicht 3 — Bit-Blasting* (via `bv_blast`). Für Constraints
mit gemischten Variablen (`(bvadd x y) = (bvmul z 3)`)
senkt man jedes BV-Bit auf ein frisches Boolesches Atom ab
und emittiert CNF, die die Semantik auf Bit-Ebene
codiert. Die CNF geht ans SAT-Backend, das sie als
aussagenlogisches Problem entscheidet. Der Addierer ist
als Ripple-Carry-Kette implementiert; der Multiplizierer
als Shift-and-Add; AND/OR/XOR sind bitweise.

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

== Arrays — read over write

Die Array-Theorie behandelt die Operationen
`(select arr idx)` und `(store arr idx val)`. Die
Schlüssel-Inferenzregel ist *read over write*:

$ "select"("store"(a, i, v), j) = cases(
  v "wenn" i = j,
  "select"(a, j) "wenn" i != j,
) $

Operationell: bei der Assertion einer Gleichung
`(select (store a i v) j) = expr` versucht man die
Umschreibung. Der Same-Index-Fall feuert
bedingungslos; der Different-Index-Fall verlangt einen
Beleg, dass `i != j` bereits bekannt ist (entweder direkt
asseriert oder hergeleitet).

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

Eine zweite Regel normalisiert Store-über-Store:
$ "store"("store"(a, i, v_1), j, v_2) = cases(
  "store"(a, i, v_2) "wenn" i = j,
  "store"("store"(a, j, v_2), i, v_1) "wenn" i != j,
) $

Die Dominanz bei gleichem Index ist die nützlichere Regel
(sie kollabiert redundante Schreibvorgänge); die
Kommutativität bei verschiedenen Indizes hilft,
verschachtelte Stores in eine kanonische Reihenfolge zu
bringen, damit nachgelagertes EUF Aliasing erkennen kann.

Negative Array-Gleichheiten — `a != b` zwischen
Array-sortigen Operanden — stellen einen
*Extensionalitäts-Zeugen* in die Warteschlange: es muss ein
Index $d$ existieren, an dem `select(a, d) != select(b, d)`.
Die Quantorenschicht (Kapitel 7) ist dafür zuständig, $d$ zu
instanziieren.

== Datentypen

Algebraische Datentypen — `Color = Red | Green | Blue` —
und induktive Datentypen wie `Nat = Zero | Succ Nat` oder
`List a = Nil | Cons a (List a)` erhalten eine eigene
Theorie. Zwei zentrale Schlussregeln:

*Konstruktor-Disjunktheit.* Wurde `a` durch `Red` und `b`
durch `Green` konstruiert, können sie nicht gleich sein. Die
Behauptung `a = b` erzeugt unmittelbar einen Konflikt.

*Injektivität.* Gilt
`Cons head1 tail1 = Cons head2 tail2`, dann
`head1 = head2` und `tail1 = tail2`. Das
`derive_equalities` der Theorie geht die asserierten
Gleichheiten zwischen Konstruktor-Anwendungen durch und
emittiert die punktweisen Argument-Gleichheiten.

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

Kardinalität: ein endlicher Enum besitzt einen endlichen
Kardinalitäts-Zeugen; ein induktiver Datentyp ist $omega$.
Die polite-Kombination nutzt diese für die
Cliquen-Prüfung der Kardinalität.

== Schnittstelle zur polite-Kombination

Jede der obigen Theorien klemmt sich an das Trait `Theory`.
Der Kombinations-Orchestrator (Kapitel 5) treibt sie
gemeinsam. Die Choreografie ist unabhängig von der Theorie
einheitlich: dasselbe Trait, dasselbe Protokoll, dieselbe
Form von `push`/`pop`. Genau deshalb ist das Hinzufügen
einer neuen Theorie eine umrissene Übung — man
implementiere das Trait, registriere eine Instanz, und die
Kombinationsmaschinerie übernimmt sie.

Eine nützliche Übung für den Leser: man implementiere eine
String-Theorie nach demselben Schema. Die
Grund­operationen (`length`, `concat`, `substr`) plus ein
Constraint-Vokabular (`prefix-of`, `contains`) genügen, um
einen überraschenden Anteil realer SMT-Lasten zu
behandeln. Der Kniff ist die Längen-Abstraktion — die
meisten String-Formeln zerfallen in Arithmetik über Längen
plus Gleichheitsschließen über Zeichen.
