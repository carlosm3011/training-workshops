# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context

"DNS y DNSSEC para Operadores" — a LACNIC Training course aimed at small/medium network operators (ISPs, IXPs, small TLDs, universities), covering DNSSEC hands-on: signing, validation, key management (KASP in BIND), and troubleshooting. All content is written in **Spanish**; keep new prose in Spanish.

Two outputs are built from the same sources: a PDF book (Quarto) and one slide deck per module (python-pptx). All 7 modules are drafted and released; content, slides, and PDF should be kept in sync when a module changes.

## Commands

```sh
make help      # list targets (default)
make deps      # macOS only: Quarto (brew), TinyTeX, chrome-headless-shell, python-pptx
make book      # render _book/DNS-y-DNSSEC-para-Operadores.pdf
make slides    # rebuild all 7 decks into _slides/
make clean     # remove _book/, .quarto/, stray .qmd and *-wip.pptx files
make release   # commit -a, push, tag $(VERSION), push tag
```

Rebuild a single deck (what `make slides` does per module):

```sh
cp _templates/lacnic46.pptx scripts/slides/
cd scripts/slides && python3 build_module04.py   # writes 04-Firmando-con-BIND-y-KASP-wip.pptx
mv 04-Firmando-con-BIND-y-KASP-wip.pptx ../../_slides/04-Firmando-con-BIND-y-KASP.pptx
rm lacnic46.pptx
```

There are no tests or linters. QA for decks is: render with LibreOffice and inspect page by page for overflow, leftover placeholder text, and template validity.

## Book pipeline (why `make book`, never bare `quarto render`)

- Chapters are authored as plain Obsidian-compatible `.md` files at the repo root (`index.md` + `01-…` through `07-…`), using ```` ```mermaid ```` fences.
- Quarto only executes `{mermaid}` cells in `.qmd` files, so `_quarto.yml`'s `chapters:` list points at `.qmd` names that **don't exist in the repo**. `scripts/mermaid-pre-render.sh` generates disposable `.qmd` twins (rewriting the fences), `quarto render` runs, then `scripts/mermaid-post-render.sh` deletes them. This can't live in a Quarto pre-render hook (quarto-cli#11567). Never edit or commit `.qmd` files.
- Adding a chapter means adding its `.qmd` name to `_quarto.yml` (and to `SLIDE_MODULES` in the Makefile if it gets a deck). Both scripts skip `CLAUDE.md`, and the Makefile excludes it from `MD_FILES`.
- `scripts/generate-title-page.sh` produces the gitignored `scripts/title-page.tex` from `scripts/title-page.tex.in`, substituting `@@VERSION@@` and a release-history table from `git tag`. Author details are hardcoded in `title-page.tex.in` **and** in `_quarto.yml` — change both together.

## Versioning and release

- The version lives only in the Makefile's `VERSION` variable (there is no VERSION file). Bump it, run `make book`, then `make release`.
- `_book/*.pdf` **is committed**: `.github/workflows/` publishes a GitHub release on `v*` tag push by attaching the PDF already in `_book/` — CI does not build it. So the PDF must be rebuilt and committed before tagging.

## Slide decks

- **Template**: `_templates/lacnic46.pptx` (LACNIC Google Slides export), committed deliberately so `make slides` works from a fresh clone. Layouts: TITLE, TITLE_1, TITLE_AND_BODY, TITLE_AND_TWO_COLUMNS, TITLE_ONLY, ONE_COLUMN_TEXT, MAIN_POINT, SECTION_TITLE_AND_DESCRIPTION, CAPTION_ONLY, BIG_NUMBER, BLANK, plus a closing "¡Gracias!" slide. Brand red `C53425`; font Arial (safe for LibreOffice rendering).
- **Output**: `_slides/NN-Name.pptx` is gitignored build output.
- **Scripts**: `scripts/slides/deck_helpers.py` holds shared primitives (placeholders/bullets, code blocks, native tables, box-and-arrow diagrams, `move_slide_to_end` for the closing slide). Each `build_moduleNN.py` loads `lacnic46.pptx` from its **own working directory** and saves `<module>-wip.pptx` there — hence the copy/move dance in the Makefile. Modules 02–07 import `deck_helpers`; `build_module01.py` predates it and inlines its own copies of the helpers.
- **Conventions**: each deck mirrors its module's headings (intro/agenda, one section per heading, closing summary table, "¡Gracias!"). Vary layouts instead of defaulting to bullets: custom diagrams for anything that is a mermaid graph in the `.md`, native tables for reference/summary content, two-column layouts for compare/contrast. Module 7 is the densest (23 slides).
