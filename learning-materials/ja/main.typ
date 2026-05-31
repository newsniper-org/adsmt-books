// adsmt — Learning Materials (Japanese)
// Compile: typst compile main.typ

#set document(
  title: "adsmt: Learning Materials",
  author: "adsmt project",
)

#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  numbering: "1",
  number-align: center,
)

#set text(
  lang: "ja",
  font: ("New Computer Modern", "Latin Modern Roman"),
  size: 11pt,
)

#set par(justify: true, leading: 0.65em)

#set heading(numbering: "1.1")

#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(1cm)
  set text(size: 22pt, weight: "bold")
  it
  v(0.5cm)
}

#show heading.where(level: 2): it => {
  v(0.5cm)
  set text(size: 14pt, weight: "bold")
  it
  v(0.2cm)
}

#show raw.where(block: true): it => {
  block(
    fill: rgb("#f5f5f5"),
    inset: 8pt,
    radius: 3pt,
    width: 100%,
    text(font: "DejaVu Sans Mono", size: 9pt, it)
  )
}

// Title page
#align(center)[
  #v(3cm)
  #text(size: 28pt, weight: "bold")[adsmt]
  #v(0.5cm)
  #text(size: 20pt)[学習教材]
  #v(2cm)
  #text(size: 14pt, style: "italic")[
    アブダクティブ・演繹型 SMT ソルバを\
    利用するための概念と実践
  ]
  #v(4cm)
  #text(size: 12pt)[The adsmt project, v1.0]
]

#pagebreak()

// Table of contents
#outline(title: "目次", depth: 2, indent: 1em)

#pagebreak()

#include "chapters/00-preface.typ"
#include "chapters/01-what-is-smt.typ"
#include "chapters/02-propositional-logic.typ"
#include "chapters/03-first-order-and-theories.typ"
#include "chapters/04-equality-and-uf.typ"
#include "chapters/05-arithmetic.typ"
#include "chapters/06-bitvectors-arrays-datatypes.typ"
#include "chapters/07-quantifiers.typ"
#include "chapters/08-abduction.typ"
#include "chapters/09-certificates-and-trust.typ"
#include "chapters/10-itp-integration.typ"
#include "chapters/A-cli-cheatsheet.typ"
#include "chapters/B-lsp-cheatsheet.typ"
#include "chapters/C-exercises.typ"
#include "chapters/99-further-reading.typ"
