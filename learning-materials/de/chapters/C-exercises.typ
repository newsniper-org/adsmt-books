= Übungen

Diese Übungen sind grob nach Kapiteln sortiert und von
*Aufwärmübung* (W) über *Kern* (C) bis *Stretch* (S)
abgestuft. Die Aufwärmübungen sollten wenige Minuten in
Anspruch nehmen; die Kernaufgaben ein bis zwei Stunden; die
Stretch-Aufgaben ein Wochenende.

== Kapitel 1 — Was ist SMT?

*W1.1.* Schreiben Sie ein SMT-LIB-Skript, das $3x + 5 = 17$
behauptet und nach $x$ fragt. Verifizieren Sie mit `lu-smt`,
dass das Modell $x = 4$ liefert.

*W1.2.* Schreiben Sie ein Skript, das die Negation einer
trivialen Tautologie behauptet (z. B. $forall x. x = x$ in
ihrer quantorenfreien Instanzform $a = a$). Verifizieren Sie,
dass das Verdikt `unsat` ist.

*C1.3.* Nehmen Sie ein kleines Problem aus einem Bereich, den
Sie kennen (Scheduling, ein Logikrätsel, ein Sudoku-Gitter),
und kodieren Sie es als SMT-LIB. Lösen Sie. Vergleichen Sie
die Laufzeit Ihrer Kodierung mit einem handgeschriebenen
spezialisierten Solver.

== Kapitel 2 — Aussagenlogik und SAT

*W2.1.* Wandeln Sie die Formel $(p => q) and (q => r) and
not (p => r)$ von Hand in CNF um. Verifizieren Sie, dass der
SAT-Solver `unsat` zurückgibt.

*W2.2.* Das *Schubfachprinzip* PHP$_n$ besagt, dass $n + 1$
Tauben nicht in $n$ Löcher passen. Schreiben Sie PHP$_3$ (4
Tauben, 3 Löcher) als SAT-Instanz und messen Sie die
Laufzeit des Solvers. Wie skaliert es zu PHP$_8$?

*C2.3.* Die *Tseitin-Transformation* verwandelt eine
beliebige aussagenlogische Formel in eine äquisatisfizierbare
CNF in Polynomialzeit. Implementieren Sie Tseitin in einer
Sprache Ihrer Wahl und testen Sie sie an der Formel
$(a or b or c) and (not(a and b) or d) and dots$ Ihrer
eigenen Konstruktion.

*S2.4.* Lesen Sie das ursprüngliche DPLL-Papier (Davis-Putnam-
Logemann-Loveland 1962). Schreiben Sie einen Spielzeug-DPLL-
Solver in ≤ 300 Zeilen, der Unit-Propagation und Pure-Literal-
Eliminierung beherrscht. Vergleichen Sie seine Geschwindigkeit
mit einer modernen CDCL bei Benchmarks wachsender Größe.

== Kapitel 3 — Logik erster Stufe und Theorien

*W3.1.* Bestimmen Sie, ob jede Formel zu QF_UF, QF_LIA,
QF_LRA, QF_BV oder einer Kombination gehört:

```text
(a) (= (f a) (f b))
(b) (and (> x 3) (< x 7))
(c) (= (select A i) (select A j))
(d) (= (bvadd #x01 #x02) #x03)
(e) (and (> x 3) (= (f x) y))
```

*C3.2.* Stellen Sie eine Formel mit mindestens drei Theorien
zusammen, bei der die *Kombination* ein Verdikt liefert,
das das Entscheidungsverfahren keiner einzelnen Theorie
alleine erbringen könnte. Nutzen Sie die `--audit-json`-
Ausgabe von adsmt, um zu bestätigen, dass alle drei Theorien
ausgeübt wurden.

*S3.3.* Lesen Sie das Nelson-Oppen-Papier von 1979.
Identifizieren Sie zwei Bedingungen, die die Theorien
erfüllen müssen, damit das einfache Nelson-Oppen-Verfahren
anwendbar ist. Finden Sie ein Beispiel in der SMT-LIB-
Benchmark-Suite, bei dem diese Bedingungen verletzt sind und
polite combination benötigt wird.

== Kapitel 4 — Gleichheit und UF

*W4.1.* Das klassische EUF-Rätsel: gegeben $f(f(f(a))) = a$
und $f(f(f(f(f(a))))) = a$, beweisen Sie $f(a) = a$.
Kodieren und verifizieren Sie in SMT-LIB.

*C4.2.* Implementieren Sie eine winzige Union-Find-Struktur
in einer Sprache Ihrer Wahl. Fügen Sie Kongruenzschluss für
eine feste Menge binärer Funktionssymbole hinzu. Lassen Sie
sie auf dem oben genannten Rätsel und auf einer Kette
$(f(a) = b, f(b) = c, …, f(y) = z)$ laufen, um zu sehen, wie
sich die Form des Find-Baums entwickelt.

*S4.3.* Lesen Sie das Detlefs-Nelson-Saxe-Simplify-Papier.
Identifizieren Sie die "schnelle" Variante des
Kongruenzschlusses, die besser amortisiert als die naive
Kaskade. Implementieren Sie sie. Benchmarken Sie sie gegen
die naive Version.

== Kapitel 5 — Arithmetik

*W5.1.* Sagen Sie für jeden das Verdikt vor dem Ausführen
voraus:

```text
(a) (assert (> x 3)) (assert (< x 4)) (check-sat)
    over Int and over Real
(b) (assert (> x 3)) (assert (<= x 4)) (check-sat)
    over Int
(c) (assert (= (* 2 x) 5)) (check-sat)
    over Int and over Real
```

*C5.2.* Das *Frobenius-Münzproblem*: Gegeben Münznennwerte
$a$ und $b$ mit $gcd(a, b) = 1$, ist der größte Wert, der
*nicht* als $a x + b y$ mit $x, y >= 0$ darstellbar ist,
$a b - a - b$. Verifizieren Sie dies für $(a, b) = (3, 5)$
mit LIA.

*S5.3.* Implementieren Sie ein einfaches Simplex-Tableau in
≤ 500 Zeilen. Testen Sie an einem kleinen linearen Programm
(3-5 Variablen, 5-10 Nebenbedingungen). Vergleichen Sie mit
dem Lauf desselben Problems durch den LRA-Solver von adsmt.

== Kapitel 6 — BV, Arrays, Datentypen

*W6.1.* Der *XOR-Swap*-Trick: $x := x xor y$, $y := x xor y$,
$x := x xor y$ vertauscht $x$ und $y$ ohne temporäre
Variable. Kodieren Sie die Drei-Anweisungs-Sequenz in BV und
verifizieren Sie den Tausch.

*C6.2.* Beweisen Sie (mittels Arrays + LIA), dass die innere
Schleife von *Bubble Sort* die Multimenge der Elemente
erhält. Kodieren Sie "Vorher"- und "Nachher"-Arrays für einen
Schritt und prüfen Sie die Gleichheit der Elementzählungen.

*S6.3.* Kodieren Sie die *Azyklizitäts*-Nebenbedingung der
Datentyp-Theorie in QF_DT und finden Sie eine Formel, die
der Solver nur wegen Azyklizität erledigt. (Hinweis:
versuchen Sie, $L = "cons" 1 L$ darzustellen.)

== Kapitel 7 — Quantoren

*W7.1.* Schreiben Sie eine quantifizierte Formel, bei der
E-Matching mit dem offensichtlichen Trigger erfolgreich ist.
Führen Sie sie mit `:trigger-mode miller` aus und bestätigen
Sie.

*C7.2.* Schreiben Sie eine quantifizierte Formel, bei der
E-Matching scheitert, aber beschränkte Enumeration (Tier 3)
gelingt. Bestätigen Sie mit `--audit-json`, dass Tier 3
erreicht wurde.

*S7.3.* Schreiben Sie eine quantifizierte Formel, bei der
auch Tier 3 scheitert und Tier 4 (abduktiv) einspringt.
Inspizieren Sie die abduktiven Kandidaten; verifizieren Sie,
dass das Hinzufügen einer von ihnen als Behauptung Tier 1
erfolgreich macht.

== Kapitel 8 — Abduktion

*W8.1.* Gegeben das Ziel $p(a)$ und die leere Regelbasis,
sagen Sie das Verdikt voraus. Führen Sie aus; beobachten Sie
`abductive` mit dem erwarteten Kandidaten.

*C8.2.* Bauen Sie eine kleine Horn-Regelbasis mit 5-6 Regeln
auf. Reichen Sie ein Ziel ein, dessen SLD-Kette ein
nichtleeres Residuum hat. Inspizieren Sie die Kandidaten
nach Rang und diskutieren Sie, ob das Ranking Ihrer
Bereichsintuition entspricht.

*S8.3.* Implementieren Sie eine winzige SLD-Resolutions-
Engine in Ihrer bevorzugten Sprache. Führen Sie sie auf
derselben Horn-Basis wie oben aus. Vergleichen Sie deren
Residuen mit den `minimize`d Kandidaten von adsmt.

== Kapitel 9 — Zertifikate und Vertrauen

*W9.1.* Erzeugen Sie ein Zertifikat für eine einfache
`unsat`-Instanz. Lesen Sie das Zertifikat manuell.
Identifizieren Sie, welcher Schritt den Widerspruch
etabliert hat.

*C9.2.* Nehmen Sie ein erzeugtes Zertifikat und *brechen* Sie
es (lassen Sie einen Schritt aus, vertauschen Sie zwei
Schritt-IDs, ändern Sie einen Zeugen-Term). Bestätigen Sie,
dass `adsmt-cert-check` das gebrochene Zertifikat ablehnt.
Identifizieren Sie, welche Validierungsregel es erwischt
hat.

*S9.3.* Lesen Sie den Quellcode des `adsmt-cert`-Prüfers
(~600 Zeilen). Auditieren Sie ihn: gibt es eine Regel, in
der der Prüfer einer strukturellen Eigenschaft vertraut, die
*neu hergeleitet* werden sollte? Reichen Sie einen Befund
(oder einen sauberen Gesundheitszustand) als Issue ein.

== Kapitel 10 — ITP-Integration

*W10.1.* Verwenden Sie in Lean 4 mit importiertem `Adsmt`
`smt_decide`, um ein einfaches arithmetisches Ziel zu
schließen (z. B. $n + 1 > n$ für `Nat`).

*C10.2.* Verwenden Sie `smt_abduce` auf einem Ziel, von dem
Sie nicht erwarten, dass adsmt es erledigt. Lesen Sie die
zutage tretenden `sorry`-Platzhalter; erledigen Sie jeden
manuell. Bestätigen Sie, dass der vollständige Beweis
typgeprüft wird.

*S10.3.* Nehmen Sie ein Ziel aus einer Rocq- oder Isabelle-
Theoriedatei, portieren Sie es nach Lean + adsmt und
verwenden Sie `smt_decide`. Vergleichen Sie die
Erledigungszeit über die drei ITPs (mittels der
Out-of-Tree-Backends).

== Offene Abschlussprojekte

*K1.* Wählen Sie ein kleines *Verifikations*-Projekt — einen
Parser, eine Sortierroutine, einen Automaten. Spezifizieren
Sie seine Korrektheit in SMT-LIB. Verwenden Sie adsmt, um
so viele Teilziele wie möglich zu erledigen. Dokumentieren
Sie, wo SMT hilft und wo Sie auf manuelle Beweise
zurückfallen.

*K2.* Wählen Sie ein *Logikrätsel* (Einsteins Rätsel, ein
Zebra-Rätsel, eine Sudoku-Variante). Kodieren Sie es in
SMT-LIB. Messen Sie die Zeit von adsmt gegen eine
einfache SAT-Kodierung und gegen eine reine Prolog-Lösung.
Diskutieren Sie die Kompromisse.

*K3.* Bauen Sie eine *kleine DSL*, deren Semantik Sie in
SMT-LIB kodieren. Implementieren Sie einen `verify`-Befehl,
der das SMT-LIB ausgibt und adsmt aufruft. Nutzen Sie die
abduktive Oberfläche, um dem Benutzer zu helfen, wenn eine
Verifikation scheitert.

== Lösungen

Dieses Buch liefert keine Lösungsskizzen. Die Übungen sind
so kalibriert, dass das Durcharbeiten unter Ihrem eigenen
Urteil wertvoller ist, als eine autorisierte Antwort zu
sehen. Die Bibliographie in Kapitel 99 verweist auf
Referenzen für die Theorie; der Quellcode von adsmt ist die
Bodenwahrheit für die Praxis.
