# Repo-level Makefile: shared dependencies, plus delegation to a course.
#
# Each course lives in its own directory with a small Makefile that sets
# its VERSION, PDF name and slide modules and includes mk/course.mk,
# where the actual build rules live. Build a course either with
#   make -C <course> book
# or, from here,
#   make book COURSE=<course>

COURSES := $(patsubst %/Makefile,%,$(wildcard */Makefile))

.PHONY: help deps courses book slides clean release

help:
	@echo "Targets:"
	@echo "  make deps    Install what 'make book' and 'make slides' need:"
	@echo "               Quarto itself (via Homebrew), then TinyTeX (PDF/LaTeX)"
	@echo "               and chrome-headless-shell (Mermaid-to-PDF rendering)"
	@echo "               via 'quarto install', plus python-pptx (pip). macOS"
	@echo "               only; safe to re-run."
	@echo " "
	@echo "  make courses List the course directories."
	@echo " "
	@echo "  make book|slides|clean|release COURSE=<course>"
	@echo "               Run that target in the course directory (same as"
	@echo "               'make -C <course> <target>'; see 'make -C <course> help')."
	@echo " "
	@echo "Courses: $(COURSES)"

courses:
	@for c in $(COURSES); do echo $$c; done

book slides clean release:
	@[ -n "$(COURSE)" ] || { echo "Set COURSE=<dir>. Courses: $(COURSES)"; exit 1; }
	$(MAKE) -C $(COURSE) $@

deps:
	@command -v brew >/dev/null 2>&1 || { \
		echo "Homebrew not found. Install it from https://brew.sh, then re-run 'make deps'."; \
		exit 1; \
	}
	@echo "==> Installing Quarto (brew cask)"
	brew install --cask quarto
	@echo "==> Installing TinyTeX (LaTeX engine for PDF output)"
	quarto install tinytex --no-prompt
	@echo "==> Installing chrome-headless-shell (renders {mermaid} cells to PDF)"
	quarto install chrome-headless-shell --no-prompt
	@echo "==> Installing python-pptx (builds the slide decks)"
	@# --user keeps this out of Homebrew's own site-packages; --break-system-packages
	@# is required on Homebrew Python (PEP 668) and is safe combined with --user.
	python3 -m pip install --quiet --upgrade --user --break-system-packages python-pptx
	@echo "==> Verifying"
	@# Run outside the repo: quarto check also validates the current project
	@# if one is present, and a course's _quarto.yml chapters are .qmd files
	@# that only exist transiently during "make book" (see mk/course.mk).
	cd /tmp && quarto check

