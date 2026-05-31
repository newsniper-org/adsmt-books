# adsmt-books

Long-form documentation for the [adsmt](https://github.com/newsniper-org/adsmt)
project, in two complementary tracks across four languages.

## Layout

```
docs/books/
├── implement-from-scratch/   # "build it yourself" guide
│   ├── en/   # English
│   ├── ko/   # 한국어
│   ├── ja/   # 日本語
│   └── de/   # Deutsch
└── learning-materials/       # introductory + conceptual track
    ├── en/   ├── ko/   ├── ja/   └── de/
```

Every language directory carries a `main.typ` and a
`chapters/NN-*.typ` series, plus any local figures. Compile
with:

```bash
typst compile main.typ
```

## Books

### `implement-from-scratch/`

Walks the reader through building an SMT solver of adsmt's
shape from a blank workspace — kernel, types, SAT, theory
combination, individual theories, quantifiers, abductive
engine, certificate format, and ITP reflection. Targets the
reader who already understands the *what* and wants to know
the *how* in implementation detail.

### `learning-materials/`

Introduces SMT solving at the conceptual + use-it-as-a-tool
level. Covers SAT, first-order logic, theory combination,
quantifier handling, abductive reasoning, certificates, and
how to drive adsmt from the CLI / LSP / Lean4 surface.
Targets the reader who wants to *use* SMT effectively
without necessarily writing one themselves.

## Audience assumption

Undergraduate graduates with at least one of: **computer
science**, **mathematics**, **philosophy**, or **mathematical
logic** (double-majors and adjacent fields covered).
Comfortable with first-order logic notation, basic data
structures + algorithms, and standard mathematical proof
style.

## Out of scope

The Rocq and Isabelle backend documentation lives in the
out-of-tree [adsmt-contrib](https://github.com/newsniper-org/adsmt-contrib)
repo. Documentation for those backends will appear there
separately; this `docs/books/` set covers only the in-tree
adsmt project itself.
