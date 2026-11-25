# Training Workshops

Hands-on training courses for network operators. Each course is written in Markdown and published as PDF books, with slide decks and lab topologies where the course has them.

## Courses

| Course | Language | What you get | Latest |
|---|---|---|---|
| [**BGP 101: A Practical Guide to the Border Gateway Protocol**](bgp-101-intro-for-operators/README.md) | English | Book, lab guide, 4 Containerlab/FRR labs | v0.2.0 |
| [**DNS y DNSSEC para Operadores**](dns-dnssec-for-operators/README.md) | Spanish | Book, 7 slide decks | v0.6.4 |

### BGP 101

An introduction to BGP for operators who want to build and fix real networks, not just read about them. It covers autonomous systems and sessions, BGP messages, path attributes and best-path selection, iBGP and route reflectors, announcing and accepting routes, and traffic engineering. Four labs run FRR routers in Containerlab on your own machine, ending with a capstone regional-ISP topology.

→ [Course README](bgp-101-intro-for-operators/README.md)

### DNS y DNSSEC para Operadores

A practical DNSSEC course for small and medium operators (ISPs, IXPs, small TLDs, universities). It goes from the fundamentals of signing and validation to running signed zones in BIND with KASP: monitoring and troubleshooting, a hidden-signer architecture, NSEC3, rollovers, CDS/CDNSKEY and multi-signer setups.

→ [Course README](dns-dnssec-for-operators/README.md)

## Getting the PDFs

Every release attaches the course's PDFs on the [Releases page](https://github.com/carlosm3011/training-workshops/releases). Release tags are per course: `<course>/vX.Y.Z`. The current PDFs are also committed under each course's `_book/` directory.

## Building from source

The build runs on macOS and needs Quarto, TinyTeX, a headless Chrome (for Mermaid diagrams) and python-pptx (for the decks). `make deps` installs all of them.

```sh
make deps                                    # one-time setup (macOS, Homebrew)
make courses                                 # list the courses
make book   COURSE=bgp-101-intro-for-operators
make slides COURSE=dns-dnssec-for-operators  # decks land in <course>/_slides/
```

Always build books with `make book`, not a bare `quarto render`: chapters are plain Obsidian-compatible `.md` files, and the build generates the `.qmd` files Quarto needs for Mermaid diagrams, then removes them.

## Repository layout

```
<course>/            one directory per course: chapters (.md), Quarto config,
                     a small Makefile with the course VERSION, committed PDFs
                     in _book/, and optional slides/ and labs/
mk/course.mk         shared build and release rules every course includes
scripts/             Mermaid pre/post-render, title page and deck helpers
_templates/          PowerPoint templates for the decks
```

To add a course, copy an existing course's `Makefile`, `_quarto.yml` and `title-page.tex.in` into a new top-level directory and adjust them. [CLAUDE.md](CLAUDE.md) documents the build and release pipeline in detail.
