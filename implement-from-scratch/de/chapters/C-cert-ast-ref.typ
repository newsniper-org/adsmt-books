= Zertifikat-AST-Referenz

Dieser Anhang ist eine Referenz für jede `StepBody`-Variante
von `adsmt-cert` (Kapitel 9). Jeder Eintrag listet die
S-Ausdruck-Syntax, den Rust-Konstruktor, die Abhängigkeiten
und die Prüfer-Regel auf.

== Obligatorische 12 (Kernregeln)

=== `refl`
- *Syntax*: `(step :rule refl :id <id> :term <t>)`
- *Rust*: `StepBody::Refl(t)`
- *Dependencies*: none
- *Checker*: emittiert `t = t` mit leerer Hypothesenmenge

=== `trans`
- *Syntax*: `(step :rule trans :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::Trans { lhs, rhs }`
- *Dependencies*: two prior steps, each concluding an equality
- *Checker*: Pivot muss übereinstimmen (`b == c` in `(a=b)`, `(c=d)`); emittiert `a = d` mit kombinierten Hypothesen

=== `eq_mp`
- *Syntax*: `(step :rule eq_mp :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::EqMp { lhs, rhs }`
- *Dependencies*: an equality $A = B$ and a proof of $A$
- *Checker*: emittiert $B$ mit kombinierten Hypothesen

=== `abs`
- *Syntax*: `(step :rule abs :id <id> :var <var> :body <ref>)`
- *Rust*: `StepBody::Abs { var, body }`
- *Dependencies*: one prior step concluding an equality
- *Checker*: emittiert $lambda x . t_1 = lambda x . t_2$

=== `beta`
- *Syntax*: `(step :rule beta :id <id> :term <t>)`
- *Rust*: `StepBody::Beta(t)`
- *Dependencies*: none
- *Checker*: $t$ muss die Form $(lambda x . b) a$ haben; emittiert $(lambda x . b) a = b[x mapsto a]$

=== `deduct`
- *Syntax*: `(step :rule deduct :id <id> :hyp <ref> :conc <ref>)`
- *Rust*: `StepBody::Deduct { hyp, conc }`
- *Dependencies*: a hypothesis step and a conclusion step
- *Checker*: emittiert $A => B$, wobei $A$ der Hypothesenterm ist; entfernt $A$ aus der Hypothesenmenge

=== `inst`
- *Syntax*: `(step :rule inst :id <id> :rule <ref> :var <var> :term <t>)`
- *Rust*: `StepBody::Inst { rule, var, term }`
- *Dependencies*: a prior step concluding a universal
- *Checker*: emittiert den Rumpf mit durch `term` ersetzter `var`

=== `inst_type`
- *Syntax*: `(step :rule inst_type :id <id> :rule <ref> :var <tyvar> :ty <ty>)`
- *Rust*: `StepBody::InstType { rule, var, ty }`
- *Dependencies*: a prior step polymorphic in `var`
- *Checker*: emittiert den Rumpf mit ersetzter Typvariable

=== `assume`
- *Syntax*: `(step :rule assume :id <id> :term <t>)`
- *Rust*: `StepBody::Assume(t)`
- *Dependencies*: none
- *Checker*: emittiert $t$ mit Hypothesenmenge $\{t\}$

=== `theory`
- *Syntax*: `(step :rule theory :id <id> :theory <name> :witness <witness>)`
- *Rust*: `StepBody::Theory { theory, witness }`
- *Dependencies*: witness-dependent (UF witness cites equalities, LIA witness cites linear bounds, etc.)
- *Checker*: dispatcht an den Zeugen-Validator der benannten Theorie

=== `instance`
- *Syntax*: `(step :rule instance :id <id> :class <c> :dict <d>)`
- *Rust*: `StepBody::Instance { class, dict }`
- *Dependencies*: none (instance dictionaries are first-class terms)
- *Checker*: emittiert das Dictionary als Term des Klassentyps

=== `assumed`
- *Syntax*: `(step :rule assumed :id <id> :term <t>)`
- *Rust*: `StepBody::Assumed(t)`
- *Dependencies*: none
- *Checker*: emittiert $t$ mit dem globalen "Präambel-Annahmen"-Hypothesen-Tag

== Abduktive 3

=== `abductive_assume`
- *Syntax*: `(step :rule abductive_assume :id <id> :hypothesis (<t>+) :justification <j>)`
- *Rust*: `StepBody::AbductiveAssume { hypothesis, justification }`
- *Dependencies*: none directly; `justification` may cite earlier steps
- *Checker*: emittiert jedes $t$ als separate Konklusion, alle mit abduktiver Provenienz markiert

=== `abductive_accept`
- *Syntax*: `(step :rule abductive_accept :id <id> :hypothesis <ref> :ground (<t>+))`
- *Rust*: `StepBody::AbductiveAccept { hypothesis, ground }`
- *Dependencies*: an `AbductiveAssume` step plus the ground terms it discharges
- *Checker*: bestätigt, dass die Grundterme die Kette modulo der benannten Hypothese schließen

=== `classical_axiom`
- *Syntax*: `(step :rule classical_axiom :id <id> :axiom <kind> :instantiation (<t>+))`
- *Rust*: `StepBody::ClassicalAxiom { axiom, instantiation }`
- *Dependencies*: none
- *Checker*: weist zurück, falls `axiom` nicht in `preamble.classical-axioms` ist; emittiert andernfalls die instantiierte Form des Axioms

== Zeugen-Untergrammatik

Theorie-Zeugen haben ihre eigene Untergrammatik:

```text
witness ::= (uf  :equalities ((= <t> <t>)+))
          | (lia :bounds (<bound>+))
          | (lra :bounds (<bound>+))
          | (bv  :bits ((<i> <0|1>)+))
          | (arr :rows ((<read-or-store>)+))
          | (dt  :discriminants ((<ctor>)+))
```

Der Prüfer jeder Theorie validiert seine eigene Zeugenform.
Das Zeugenformat ist *eingefroren*; neue Theorien fügen
neue Zeugenvarianten semver-additiv hinzu.

== Urteil

```text
verdict ::= (verdict sat   :model ((<var> <val>)+))
          | (verdict unsat :final-step <ref>)
          | (verdict abductive :candidates ((<ref>)+) :final-step <ref>)
          | (verdict unknown :reason <text>)
```

Das `verdict` ist der einzige obligatorische Schlussblock
des Zertifikats. Der Prüfer verwendet es zur Bestätigung:
Der `final-step` existiert, seine Konklusion passt zur
Urteilsform, die Hypothesenmenge ist leer (Unsat), passt
zu den abduktiven Deklarationen (Abductive) oder ist
konsistent mit dem Modell (Sat).
