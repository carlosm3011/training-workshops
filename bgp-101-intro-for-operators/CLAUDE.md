# CLAUDE.md — bgp-101-intro-for-operators

"BGP 101: A Practical Guide to the Border Gateway Protocol", by Carlos M. Martinez (XT6 Labs). It's a hands-on BGP course using FRR and Containerlab. All content is in **English**. The shared build machinery and release process are described in the repo-root `CLAUDE.md`.

## Structure

- Two PDFs come from one set of sources, one Quarto profile each:
  - `_quarto-book.yml` lists the theory chapters (01–03, 05–06, 08–09).
  - `_quarto-labguide.yml` lists the labs (04, 07, 10, 11) and renders to `_book/labguide/`.
  - Shared settings live in `_quarto.yml`, which must not list chapters.
  - A new chapter goes in exactly one profile's list; `index.md` goes in both.
- `index.md` (the preface of both PDFs) is built from `README.md`'s introduction and references. If you change one, update the other.
- `lab-N.clab.yml` are the Containerlab topologies the lab chapters use. `references/` holds source material and is not part of the build.
- `title-page.tex.in` also keeps every code block on a single page (carried over from the old pandoc build), so keep code blocks shorter than a page.
- There are no slide decks yet (`SLIDE_MODULES` is unset).
