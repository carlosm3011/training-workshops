# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context

A container for training courses/workshops. Each course lives in its own top-level directory and builds from Markdown sources into one or more PDFs (Quarto) and, optionally, one slide deck per module (python-pptx). The build machinery is shared at the repo root; course directories hold only content and a small config Makefile. Each course has its own `CLAUDE.md` with content-specific guidance.

Courses:
- `dns-dnssec-for-operators/`: Spanish, one book PDF plus slide decks. Its v0.6.x releases predate this layout.
- `bgp-101-intro-for-operators/`: English, a book PDF and a lab guide PDF (two Quarto profiles), Containerlab topologies, no decks.

## Commands

```sh
make deps                                       # macOS only: Quarto (brew), TinyTeX, chrome-headless-shell, python-pptx
make courses                                    # list course directories
make book    COURSE=dns-dnssec-for-operators    # same as: make -C dns-dnssec-for-operators book
make slides  COURSE=dns-dnssec-for-operators
make clean   COURSE=dns-dnssec-for-operators
make release COURSE=dns-dnssec-for-operators    # commit course changes, push, tag <course>/$(VERSION), push tag
make -C <course> help
```

Rebuild a single deck (what `make slides` does per module), from inside a course directory:

```sh
cp ../_templates/lacnic46.pptx slides/
(cd slides && PYTHONPATH=../../scripts/slides python3 build_module04.py)   # writes slides/<module>-wip.pptx
mv slides/04-*-wip.pptx _slides/04-Firmando-con-BIND-y-KASP.pptx && rm slides/lacnic46.pptx
```

There are no tests or linters. QA for decks: render with LibreOffice and inspect page by page for overflow, leftover placeholder text, and template validity.

## Layout

- **Shared**: `mk/course.mk` (all book/slides/release/clean rules), root `Makefile` (deps + `COURSE=` delegation), `scripts/*.sh` (each takes the course dir as an argument), `scripts/slides/deck_helpers.py`, `_templates/*.pptx`, `.github/workflows/release.yml`.
- **Per course** (`<course>/`): chapter `.md` files, `_quarto.yml`, `title-page.tex.in`, `Makefile` (sets `VERSION` and `BOOK_PDFS`, plus optionally `BOOK_PROFILES`, `SLIDE_MODULES`, `SLIDE_TEMPLATE` and `EXTRA_TAG_PATTERN`, then `include ../mk/course.mk`), optional `slides/build_moduleNN.py`, committed `_book/**/*.pdf`, gitignored `_slides/`. Quarto writes a small `.gitignore` into each course directory on first render; commit it.
- The course name is its directory name; `course.mk` derives it from `$(CURDIR)`, so courses must be top-level directories. The root Makefile discovers courses as `*/Makefile`.

To add a course: copy an existing course's `Makefile`, `_quarto.yml` and `title-page.tex.in` into a new top-level directory, change the version/title/authors/chapters, and set `BOOK_PDFS` to the filenames Quarto derives from `book.title`. For decks, add `slides/build_moduleNN.py` scripts that `from deck_helpers import ...` and list them in `SLIDE_MODULES`.

## Book pipeline (why `make book`, never bare `quarto render`)

- Chapters are plain Obsidian-compatible `.md` files using ```` ```mermaid ```` fences. Quarto only executes `{mermaid}` cells in `.qmd` files, so each `_quarto.yml` `chapters:` list names `.qmd` files that **don't exist in the repo**: `scripts/mermaid-pre-render.sh` generates disposable twins, `quarto render` runs in the course dir, then `scripts/mermaid-post-render.sh` deletes them. A Quarto pre-render hook can't do this (quarto-cli#11567). Never edit or commit `.qmd` files. `CLAUDE.md`, `README.md`, `GEMINI.md` and `AGENTS.md` are not chapters: both scripts skip them and `course.mk` leaves them out of the book's dependencies (the lists in the scripts and `course.mk` must match). A Quarto book needs an `index.md` as its first chapter.
- Several PDFs from one course: set `BOOK_PROFILES` (e.g. `book labguide`) and `make book` runs `quarto render --profile <p>` for each, in order. Quarto *appends* a profile's `book.chapters` to the base `_quarto.yml` list, so with profiles the chapter lists must live only in `_quarto-<profile>.yml`. The profile that writes to `_book/` must come first, because rendering it clears `_book/`; the others write to subdirectories (e.g. `_book/labguide/`). See `bgp-101-intro-for-operators/`.
- `scripts/generate-title-page.sh` writes the gitignored `<course>/title-page.tex` from `title-page.tex.in`, substituting `@@VERSION@@` and a version-history table built from the course's `<course>/v*` tags (prefix stripped), plus `EXTRA_TAG_PATTERN` if set. Author details are hardcoded in `title-page.tex.in` **and** in `_quarto.yml`, so change both together.

## Versioning and release

- A course's version lives only in its Makefile's `VERSION`. Bump it, `make book`, then `make release`; `make release` commits every change under that course directory, untracked files included (it runs `git add -A` there first; generated files are gitignored), and nothing outside it.
- Tags are `<course>/vX.Y.Z`. The workflow fires on `*/v*`, takes the course from the tag, and attaches every PDF **already committed** under `<course>/_book/`, including subdirectories. CI does not build them, so rebuild and commit the PDFs before tagging.

## Slide decks

- Decks are optional; `make slides` exits with a message for a course with no `SLIDE_MODULES`.
- Templates in `_templates/` are committed on purpose, so `make slides` works from a fresh clone. `lacnic46.pptx` is the LACNIC Google Slides export. Its layouts are TITLE, TITLE_1, TITLE_AND_BODY, TITLE_AND_TWO_COLUMNS, TITLE_ONLY, ONE_COLUMN_TEXT, MAIN_POINT, SECTION_TITLE_AND_DESCRIPTION, CAPTION_ONLY, BIG_NUMBER and BLANK, plus a closing "¡Gracias!" slide. Brand red is `C53425`; the font is Arial, which is safe for LibreOffice rendering.
- `course.mk` copies the template into `<course>/slides/` and runs each `build_moduleNN.py` there with `PYTHONPATH` set to `scripts/slides`. Each script loads the template by bare filename from its working directory and saves `<module>-wip.pptx`, which is then moved to `_slides/<module>.pptx`. `<module>` must start with the `NN` used in the script name.
- `deck_helpers.py` provides placeholder/bullet setters, code blocks, native tables, box-and-arrow diagrams, and `move_slide_to_end` for the closing slide.
- Deck conventions: mirror the module's headings (intro/agenda, one section per heading, a closing summary table, "¡Gracias!"). Vary the layouts instead of defaulting to bullets: build custom diagrams for anything that is a mermaid graph in the `.md`, use native tables for reference/summary content, and use two-column layouts for compare/contrast.
