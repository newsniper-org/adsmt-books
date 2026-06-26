// adsmt — Von Grund auf implementieren (Deutsch)
// Compile: typst compile main.typ

#set document(
  title: "adsmt: Von Grund auf implementieren",
  author: "adsmt project",
)

#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  numbering: "1",
  number-align: center,
)

#set text(
  lang: "de",
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
  #text(size: 20pt)[Von Grund auf implementieren]
  #v(2cm)
  #text(size: 14pt, style: "italic")[
    Eine geführte Konstruktion eines abduktiv-deduktiven\
    HOL+HKT-SMT-Solvers
  ]
  #v(4cm)
  #text(size: 12pt)[Das adsmt-Projekt, v1.0]
]

#pagebreak()

// Table of contents
#outline(title: "Inhaltsverzeichnis", depth: 2, indent: 1em)

#pagebreak()

#include "chapters/00-preface.typ"
#include "chapters/01-introduction.typ"
#include "chapters/02-kernel.typ"
#include "chapters/03-types-and-classes.typ"
#include "chapters/04-sat-layer.typ"
#include "chapters/05-theory-combination.typ"
#include "chapters/06-theories.typ"
#include "chapters/07-quantifiers.typ"
#include "chapters/08-abductive.typ"
#include "chapters/09-certificates.typ"
#include "chapters/10-itp-reflection.typ"
#include "chapters/11-engineering.typ"
#include "chapters/A-smtlib-surface.typ"
#include "chapters/B-lukb-surface.typ"
#include "chapters/C-cert-ast-ref.typ"
#include "chapters/D-typed-asp-surface.typ"
#include "chapters/99-bibliography.typ"
