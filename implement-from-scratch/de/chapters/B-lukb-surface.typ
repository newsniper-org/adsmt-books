= lu-kb-Oberfläche

`lu-kb` ist der zweite Eingabedialekt, den adsmt akzeptiert.
Er entstand im *logicutils*-Projekt (absorbiert bei RC1.4.A,
siehe `ABSORPTION_PLAN.md`) und wird zur Rückwärtskompatibilität
mit logicutils-Konsumenten und für adsmt-spezifische
Wissensbasis-Verfassung erhalten.

== Oberflächenform

Eine `.kb`-Datei ist eine Folge von *Blöcken*:

```text
sort Nat
fun  zero : Nat
fun  succ : Nat -> Nat

rule  succ_pos : forall n. zero != succ n
rule  succ_inj : forall n m. (succ n = succ m) => (n = m)

class Eq[T] = { eq : T -> T -> Bool }
instance Eq[Nat] = { eq = nat_eq }

query forall n. eq n n
```

Jeder Block ist einer von: `sort`, `fun`, `rule`, `class`,
`instance`, `query`. Die Grammatik des Dialekts lebt in
`adsmt-parser/src/lukb/` mit eingechecker Migrationskette
(v0.x bis v1.0).

== Blöcke

*`sort <name>`* — Deklariert eine opake Sorte. Äquivalent zu
`declare-sort` in SMT-LIB.

*`fun <name> : <type>`* — Deklariert ein Funktionssymbol mit
seinem Typ. Höher-gekindete Typen (`F[T]`, `F[T, U]`) werden
erkannt; Kapitel 3 behandelt die Kern-Semantik.

*`rule <name> : <formula>`* — Eine benannte Annahme, die zu
Engine-Start behauptet wird. Wird sowohl zur Behauptung von
Fakten verwendet als auch für Horn-Regeln, die die
abduktive Schicht (Kapitel 8) speisen.

*`class <name>[<tyvar>+] = { <field> : <type> ; ... }`* —
Deklariert eine Typklasse. Äquivalent zu T_class in
Kapitel 3.

*`instance <name>[<type>+] = { <field> = <term> ; ... }`* —
Deklariert eine Instanz einer Klasse für einen spezifischen
Typparameter.

*`query <formula>`* — Äquivalent zu `assert (not phi)`,
gefolgt von `check-sat`. Das Urteil wird namentlich
gemeldet.

== Hash-gestempelte Migrationskette

`.kb`-Dateien tragen einen optionalen K12-256-Hash ihrer
kanonischen Form. Der Hash wird beim Parsen neu berechnet;
eine Diskrepanz löst eine Migrationsprüfung aus, die die
Kette der bekannten Dialektversionen durchläuft und nötige
Transformationen anwendet.

```text
% kb-version: 1
% kb-hash:    k12-256:abc123...
```

Die Kette wird in `lu-common/src/migration.rs` mit einer
Transformation pro Breaking-Version gepflegt. Migration ist
*opt-in* — ohne die `:auto-migrate`-Option ist eine
Hash-Diskrepanz ein Fehler.

== Vergleich mit SMT-LIB

`lu-kb` ist eher auf die Verfassung von Wissensbasen
zugeschnitten als auf die Entscheidung einzelner Ziele:

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Belang*], [*SMT-LIB*], [*lu-kb*]),
  [Granularität], [Pro Ziel], [Pro Wissensbasis],
  [Wiederverwendung], [push/pop-Geltungsbereiche], [Rule- und Class-Blöcke],
  [Typklassen], [Nicht nativ], [`class`- / `instance`-Blöcke],
  [Horn-freundlich], [Manuell], [`rule`-Blöcke speisen Abduktion],
  [Migration], [Version in Präambel], [Hash-gestempelte Kette],
)

In der Praxis bevorzugen Bibliotheksautoren `.kb` (die
Wissensbasis einmal schreiben, wiederholt abfragen);
Ad-hoc-Nutzer bevorzugen `.smt2`. Beide Oberflächen
kompilieren zu demselben internen AST, sodass das
Engine-Verhalten identisch ist.

== Editor-Integration

Die VS-Code-Erweiterung (unter `tooling/vscode-extension/`)
erkennt sowohl `.smt2`- als auch `.kb`-Erweiterungen. Der
LSP-Server (`adsmt-lsp`) routet Dateien nach Erweiterung an
den passenden Parser; die Vervollständigungsliste passt sich
an (39 statische Einträge, einschließlich
`kb`-spezifischer Schlüsselwörter wie `class`, `instance`,
`query`).
