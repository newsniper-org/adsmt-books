= typed-ASP Surface

The *typed-ASP face* is the closed-world, least-model
sibling of the SMT-LIB surface, and the **successor to
`lu-kb`** (appendix B). Where `.smt2` and `.kb` ask "is
this set of formulas satisfiable?", a typed-ASP program
asks "what is the unique model of these rules, under the
*closed-world* assumption that nothing holds unless it is
derived?" It elaborates to the *same* typed CIC kernel
(`adsmt-ir`) as every other surface, so it is a frontend,
not a separate engine: every rule is re-checked by the
kernel admitters, and every answer is re-verified by
recomputing the model — a face bug yields only a
`FaceError`, never a trusted wrong answer.

== Surface shape

A program is a sequence of *items*:

```text
sort Node.
pred edge(Node, Node).
pred reach(Node, Node).

edge(a, b).  edge(b, c).  edge(c, d).
reach(X, Y) :- edge(X, Y).
reach(X, Z) :- reach(X, Y), edge(Y, Z).

?- reach(a, X).        % find all nodes reachable from a
```

The convention is Prolog/clingo-shaped: an identifier
whose first byte is `[A-Z]` or `_` is a *variable* in term
position; a lowercase identifier is a constant or
constructor. Declaration positions (sort / predicate /
constructor names) are case-insensitive.

== Items

*`sort <Name>.`* — An opaque finite domain (`open Name :
Type(0)` in the kernel).

*`enum <Name> = { c0, c1, … }.`* — A finite, closed
domain of nullary constructors (a kernel `Inductive`).

*`data <Name> = c0(S, …) | c1 | … .`* — An inductive
datatype with argument-bearing constructors; the kernel's
strict-positivity gate re-checks recursion. Constructor
terms double as first-order *patterns* (see below).

*`pred <name>(S0, S1, …).`* — A typed relation
(result `Prop`). Argument sorts are declared sorts / enums
/ datatypes or the built-in `Int`.

*`abducible <name>(S, …).`* — Declares a predicate
*abducible*: its ground atoms form the hypothesis space.
An abducible is a `def`-completion-*less* `Open` atom —
the dual of an ordinary predicate (chapter 8).

*`<atom>.`* — A *fact* (a ground atom) or, with head
variables, an empty-body *rule*.

*`<head> :- <body>.`* — A definite rule. The body is a
conjunction of positive atoms, `not`-negated atoms, and
`{ … }` theory atoms.

*`:- <body>.`* — An *integrity constraint*: the body must
not hold in the model; if some ground instance does, the
program has no answer set (`Solution.consistent = false`).

*`?- <atom>.`* — A query; variables are the "find-all"
outputs. *`?- abduce <atom>.`* — an abductive query (the
⊆-minimal hypothesis sets that make the goal hold).

== The negation ladder

The elaborator *infers* a program's level and refuses to
outrun the rung whose soundness gate exists (it
parses-but-abstains above it — never approximates).

#table(
  columns: 3,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Level*], [*Adds*], [*Status*]),
  [L0], [typed sorts/preds, facts, definite rules, first-order datatype matching], [landed],
  [L1], [theory interior (`open` Int atoms) + CanEq typed (dis)equality], [landed],
  [L2], [stratified `not` + integrity constraints `:- B`], [landed],
  [L3], [full stable models + loop-formula certificate], [planned (hard-gated)],
  [L4], [choice `{…}` / disjunctive heads], [planned],
  [L5], [aggregates + weak constraints / optimization], [planned],
  [L6], [first-class abduction], [merged into the rule IR],
)

== Theory interior and CanEq (L1)

A rule body may carry a `{ … }` *theory atom*. For `Int`
operands it is arithmetic — `big(T) :- dur(T, D), { D >= 4
}.` keeps the long tasks. Comparison `=`/`!=` is routed by
**CanEq** to the operand sort: arithmetic equality on
`Int`, *structural* (dis)equality on any enum / datatype.
A cross-sort comparison (`Int = Node`) is an elaboration
error, not a silent atom — the recurring cross-sort bug
class is caught at the face boundary. Internally each
operator becomes an `open` kernel symbol (`#int.lt`,
`#eq.S`, …) that the kernel type-checks and the grounder
evaluates as the gate's `θ`.

== Stratified negation (L2)

`not p(X)` holds in the *perfect model* iff `p(X)` is not
derivable. It is sound only under **stratification**: no
predicate may depend on its own negation. The elaborator
builds the dependency graph and rejects a negative cycle
(`FaceError::NonStratified`); the solver then evaluates
strata bottom-up, so every `not` reads an already-decided
lower stratum. Every variable under `not` must also be
bound by a positive body atom (a free one would be a
universal, not a closed-world negation).

```text
single(X) :- person(X), not married(X).
```

== Abduction — the rule's dual

Deduction and abduction share *one* rule IR. The forward
least-fixpoint computes answer-set membership; the same
rules, read backward, drive abduction. `?- abduce G`
returns the ⊆-minimal sets of abducible atoms that, if
assumed, make `G` hold; an *empty* explanation means `G`
is already entailed (deduction = empty-abducible
abduction). The abductive layer of chapter 8 is reused
directly — the closed-world face is where its forward
direction lives.

== Surface sugar

Pure desugarings (each expands to the core, so the kernel
+ fixpoint re-check them — soundness is automatic):

- *anonymous `_`* — a distinct fresh variable at each
  occurrence (`p(_, _)` is not `p(X, X)`).
- *pooling `;`* — `color(red; green; blue).` expands to
  three facts; cartesian across positions.
- *integer interval `..`* — `value(1..3).` expands to
  `value(1)`, `value(2)`, `value(3)` (inclusive, literal
  bounds); poolable and bounded against blow-up.

== Soundness firewall

The kernel certifies *typing* and *positive derivations*;
an untrusted grounder + the re-checkable least-fixpoint
gate certify the closed-world model. The two never share a
judgement. A buggy grounder or heuristic can only *shrink*
the answer set or yield `Unknown` — never manufacture a
false entailment. The abstain boundary is wide and
deliberate: a non-stratified program, an unsafe rule (an
unbound variable), an infinite domain, or any "no answer
set" claim without a certificate is a `FaceError` or
`Unknown`, never an approximation.

== Comparison to lu-kb and SMT-LIB

#table(
  columns: 4,
  align: left,
  stroke: 0.5pt + gray,
  table.header([*Concern*], [*SMT-LIB*], [*lu-kb*], [*typed-ASP*]),
  [World],     [open], [open], [closed (least model)],
  [Question],  [SAT of a goal], [SAT of a KB], [the unique model],
  [Negation],  [classical], [classical], [stratified NAF],
  [Abduction], [`(abduce)`], [via `rule`], [native (rule dual)],
  [Theory],    [native], [native], [`{…}` interior, same engine],
)

All three surfaces elaborate to the same kernel, so a
sort / datatype / theory atom means the same thing across
them; only the *world assumption* and the *question*
differ.
