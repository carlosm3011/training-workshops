#!/usr/bin/env bash
# Run by `make book` before `quarto render` (NOT wired into _quarto.yml's
# pre-render hook: Quarto validates book chapters before running that
# hook, so it can't be used to generate them - see quarto-dev/quarto-cli#11567).
#
# Usage: mermaid-pre-render.sh <course-dir>
#
# For every source .md file in the course directory, generate a
# disposable .qmd twin with Obsidian-style ```mermaid fences converted
# to Quarto's ```{mermaid} executable-cell syntax. Quarto requires the
# .qmd extension for any file containing executable cells, so the
# book's `chapters:` list points at these generated .qmd files rather
# than the .md originals. Removed by scripts/mermaid-post-render.sh
# once rendering finishes.
set -euo pipefail
cd "$1"

# Agent/readme files that aren't book chapters. Keep in sync with
# NON_CHAPTERS in mk/course.mk.
NON_CHAPTERS=" CLAUDE.md README.md GEMINI.md AGENTS.md "

for f in *.md; do
  [[ "$NON_CHAPTERS" == *" $f "* ]] && continue
  base="${f%.md}"
  perl -pe 's/^```mermaid$/```{mermaid}/' "$f" > "${base}.qmd"
done
