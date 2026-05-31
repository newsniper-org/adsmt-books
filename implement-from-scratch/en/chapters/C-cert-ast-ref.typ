= Certificate AST Reference

This appendix is a reference for every `StepBody` variant
of `adsmt-cert` (chapter 9). Each entry lists the
S-expression syntax, the Rust constructor, the
dependencies, and the checker rule.

== Mandatory 12 (kernel rules)

=== `refl`
- *Syntax*: `(step :rule refl :id <id> :term <t>)`
- *Rust*: `StepBody::Refl(t)`
- *Dependencies*: none
- *Checker*: emits `t = t` with empty hypothesis set

=== `trans`
- *Syntax*: `(step :rule trans :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::Trans { lhs, rhs }`
- *Dependencies*: two prior steps, each concluding an equality
- *Checker*: pivot must match (`b == c` in `(a=b)`, `(c=d)`); emits `a = d` with combined hypotheses

=== `eq_mp`
- *Syntax*: `(step :rule eq_mp :id <id> :lhs <ref> :rhs <ref>)`
- *Rust*: `StepBody::EqMp { lhs, rhs }`
- *Dependencies*: an equality $A = B$ and a proof of $A$
- *Checker*: emits $B$ with combined hypotheses

=== `abs`
- *Syntax*: `(step :rule abs :id <id> :var <var> :body <ref>)`
- *Rust*: `StepBody::Abs { var, body }`
- *Dependencies*: one prior step concluding an equality
- *Checker*: emits $lambda x . t_1 = lambda x . t_2$

=== `beta`
- *Syntax*: `(step :rule beta :id <id> :term <t>)`
- *Rust*: `StepBody::Beta(t)`
- *Dependencies*: none
- *Checker*: $t$ must be of form $(lambda x . b) a$; emits $(lambda x . b) a = b[x mapsto a]$

=== `deduct`
- *Syntax*: `(step :rule deduct :id <id> :hyp <ref> :conc <ref>)`
- *Rust*: `StepBody::Deduct { hyp, conc }`
- *Dependencies*: a hypothesis step and a conclusion step
- *Checker*: emits $A => B$ where $A$ is the hypothesis term; removes $A$ from the hypothesis set

=== `inst`
- *Syntax*: `(step :rule inst :id <id> :rule <ref> :var <var> :term <t>)`
- *Rust*: `StepBody::Inst { rule, var, term }`
- *Dependencies*: a prior step concluding a universal
- *Checker*: emits the body with `var` substituted by `term`

=== `inst_type`
- *Syntax*: `(step :rule inst_type :id <id> :rule <ref> :var <tyvar> :ty <ty>)`
- *Rust*: `StepBody::InstType { rule, var, ty }`
- *Dependencies*: a prior step polymorphic in `var`
- *Checker*: emits the body with type variable substituted

=== `assume`
- *Syntax*: `(step :rule assume :id <id> :term <t>)`
- *Rust*: `StepBody::Assume(t)`
- *Dependencies*: none
- *Checker*: emits $t$ with hypothesis set $\{t\}$

=== `theory`
- *Syntax*: `(step :rule theory :id <id> :theory <name> :witness <witness>)`
- *Rust*: `StepBody::Theory { theory, witness }`
- *Dependencies*: witness-dependent (UF witness cites equalities, LIA witness cites linear bounds, etc.)
- *Checker*: dispatches to the named theory's witness validator

=== `instance`
- *Syntax*: `(step :rule instance :id <id> :class <c> :dict <d>)`
- *Rust*: `StepBody::Instance { class, dict }`
- *Dependencies*: none (instance dictionaries are first-class terms)
- *Checker*: emits the dictionary as a term of the class type

=== `assumed`
- *Syntax*: `(step :rule assumed :id <id> :term <t>)`
- *Rust*: `StepBody::Assumed(t)`
- *Dependencies*: none
- *Checker*: emits $t$ with the global "preamble assumptions" hypothesis tag

== Abductive 3

=== `abductive_assume`
- *Syntax*: `(step :rule abductive_assume :id <id> :hypothesis (<t>+) :justification <j>)`
- *Rust*: `StepBody::AbductiveAssume { hypothesis, justification }`
- *Dependencies*: none directly; `justification` may cite earlier steps
- *Checker*: emits each $t$ as a separate conclusion, all tagged with abductive provenance

=== `abductive_accept`
- *Syntax*: `(step :rule abductive_accept :id <id> :hypothesis <ref> :ground (<t>+))`
- *Rust*: `StepBody::AbductiveAccept { hypothesis, ground }`
- *Dependencies*: an `AbductiveAssume` step plus the ground terms it discharges
- *Checker*: confirms ground terms close the chain modulo the named hypothesis

=== `classical_axiom`
- *Syntax*: `(step :rule classical_axiom :id <id> :axiom <kind> :instantiation (<t>+))`
- *Rust*: `StepBody::ClassicalAxiom { axiom, instantiation }`
- *Dependencies*: none
- *Checker*: refuses if `axiom` is not in `preamble.classical-axioms`; otherwise emits the axiom's instantiated form

== Witness sub-grammar

Theory witnesses have their own sub-grammar:

```text
witness ::= (uf  :equalities ((= <t> <t>)+))
          | (lia :bounds (<bound>+))
          | (lra :bounds (<bound>+))
          | (bv  :bits ((<i> <0|1>)+))
          | (arr :rows ((<read-or-store>)+))
          | (dt  :discriminants ((<ctor>)+))
```

Each theory's checker validates its own witness shape. The
witness format is *frozen*; new theories add new witness
variants under semver-additive.

== Verdict

```text
verdict ::= (verdict sat   :model ((<var> <val>)+))
          | (verdict unsat :final-step <ref>)
          | (verdict abductive :candidates ((<ref>)+) :final-step <ref>)
          | (verdict unknown :reason <text>)
```

The `verdict` is the cert's only mandatory tail block.
The checker uses it to confirm: the `final-step` exists,
its conclusion matches the verdict shape, the hypothesis
set is empty (Unsat) or matches the abductive
declarations (Abductive) or is consistent with the model
(Sat).
