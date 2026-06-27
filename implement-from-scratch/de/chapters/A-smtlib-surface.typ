= SMT-LIB-v2-Oberfläche

Dieser Anhang dokumentiert die SMT-LIB-v2-Oberfläche, die
`adsmt-parser` erkennt. Es ist eine *Teilmenge* des vollen
SMT-LIB-v2-Standards, plus eine Handvoll adsmt-spezifischer
Erweiterungen.

== Erkannte Befehle

#table(
  columns: 2,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Befehl*], [*Anmerkungen*]),
  [`set-logic`],   [Akzeptiert die `QF_*`-Logiken und ihre quantifizierten Pendants. polite-Kombination wird automatisch gewählt, wenn mehrere Theorien auftreten.],
  [`set-option`],  [Standardoptionen plus adsmt-spezifische `:abductive-tier`, `:trigger-mode`, `:classical-axioms`.],
  [`declare-sort`, `declare-fun`, `declare-const`], [Standard.],
  [`define-fun`, `define-fun-rec`], [Standard; `define-fun-rec` ist partiell — die Terminationsverpflichtung obliegt dem Nutzer.],
  [`assert`],      [Standard.],
  [`check-sat`],   [Liefert `sat`, `unsat`, `unknown` oder `abductive` (das neue Urteil).],
  [`get-model`],   [Standard, liefert die Belegung für `Sat`.],
  [`get-unsat-core`], [Standard, liefert die etikettierte Teilmenge für `Unsat`.],
  [`get-abductive-candidates`], [adsmt-Erweiterung — liefert die gerangte Kandidatenliste für `Abductive`.],
  [`push`, `pop`], [Standard-Scope-Stack.],
  [`reset`, `reset-assertions`], [Standard.],
  [`exit`],        [Standard.],
)

== Theorien

Die folgenden SMT-LIB-Theorien werden unterstützt (Kapitel 6):

- `Core` — Bool, =, distinct, ite, and, or, not, =>
- `Ints` — LIA
- `Reals` — LRA
- `Reals_Ints` — LIRA via polite-Kombination
- `FixedSizeBitVectors` — BV mit Bit-Blasting-Fallback
- `ArraysEx` — Read-over-Write Arrays
- `Datatypes` — Algebraische Datentypen

== Logiken

Die Standard-SMT-LIB-Logikbezeichnungen werden erkannt:

```text
QF_UF, QF_LIA, QF_LRA, QF_BV, QF_AUFLIA, QF_AUFBV,
QF_DT, QF_AUFDT,
LIA, LRA, AUFLIA, AUFBV, AUFDT, ...
```

Wenn die Logik Quantoren enthält (kein `QF_`-Präfix),
aktiviert die Engine automatisch die Quantor-Instantiierungs-Pipeline
aus Kapitel 7.

== Erweiterungen

Drei SMT-LIB-Erweiterungen sind adsmt-spezifisch:

*`:abductive-tier <n>`* — Setzt das maximale Tier, bei dem
die Quantor-Behandlung zu abduktiven Kandidaten eskaliert.
`n=0` deaktiviert abduktive Oberflächen (liefert `unknown`
bei Erschöpfung); `n=4` (Voreinstellung) aktiviert die volle
Pipeline.

*`:trigger-mode <miller|free>`* — `miller` (Voreinstellung)
beschränkt Trigger auf Miller-Muster; `free` erlaubt
Nicht-Miller-Trigger (mit ihren Pathologien).

*`:classical-axioms (<axiom>*)`* — Whitelistet klassische
Axiome, die der Solver aufrufen darf. Die akzeptierten
Bezeichnungen sind: `lem`, `peirce`, `dne`. Schritte, die
ein Axiom erfordern, das nicht in der Whitelist steht,
scheitern entweder oder erhalten eine Tier-4-Eskalation.

*`get-abductive-candidates`* — Wenn `check-sat` `abductive`
liefert, gibt dieser Befehl die gerangte Kandidatenliste
als verschachtelte S-Ausdrücke zurück. Beispielausgabe:

```text
(abductive-candidates
  (candidate :rank 1 :hypothesis ((P a) (Q b))
             :justification sld_chain)
  (candidate :rank 2 :hypothesis ((R c))
             :justification quantifier_exhausted))
```

== Nicht-Erweiterungen

Mehrere SMT-LIB-v2-Features werden *nicht* unterstützt:

- `Floats` (FP-Theorie) — außerhalb des Geltungsbereichs.
- `Sequences`- und `Strings`-Theorien — außerhalb des
  Geltungsbereichs.
- Totalitätsprüfung von `define-fun-rec` — nur partiell.
- Muster-Syntax `(! ... :pattern ...)` wird zwar geparst,
  aber Tier-1 konsultiert das Muster nur, wenn ein explizites
  `:trigger`-Attribut fehlt.

Diese Auslassungen sind absichtlich. Eine v1.0.0-Verpflichtung
zu FP-Korrektheit würde entweder einen prohibitiv langsamen
Bit-Blasting-Fallback oder ein FP-spezifisches
Entscheidungsverfahren erfordern, das ein Forschungsprojekt
für sich ist.
