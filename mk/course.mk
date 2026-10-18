# Shared build rules for one course. Each course directory has a small
# Makefile that sets the variables below and then includes this file:
#
#   VERSION        := v0.1.0                    # required
#   BOOK_PDF_NAME  := My-Course-Title.pdf       # required: Quarto names the PDF after book.title
#   SLIDE_MODULES  := 01-Intro 02-Next ...      # optional: decks built by slides/build_moduleNN.py
#   SLIDE_TEMPLATE := lacnic46.pptx             # optional: file under _templates/ (default lacnic46.pptx)
#   EXTRA_TAG_PATTERN := refs/tags/v*           # optional: extra tags to show in the title-page history
#   include ../mk/course.mk
#
# The course name is the directory name; it prefixes release tags
# (<course>/vX.Y.Z), which .github/workflows/ uses to find the PDF.
#
# Chapters are authored as plain .md files (Obsidian-compatible). Quarto
# needs .qmd files for the {mermaid} executable cells that make diagrams
# render in PDF output, so this file - not _quarto.yml - drives the
# scripts/mermaid-*.sh scripts that generate/remove disposable .qmd
# twins around the `quarto render` call. (A _quarto.yml pre-render hook
# can't do this: Quarto validates book chapters before pre-render runs,
# see quarto-dev/quarto-cli#11567. Always build via `make book`, not a
# bare `quarto render`.)

ROOT     := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
COURSE   := $(notdir $(CURDIR))
SCRIPTS  := $(ROOT)/scripts

SLIDE_TEMPLATE    ?= lacnic46.pptx
EXTRA_TAG_PATTERN ?=

MD_FILES     := $(filter-out CLAUDE.md,$(wildcard *.md))
BOOK_PDF     := _book/$(BOOK_PDF_NAME)
TAG          := $(COURSE)/$(VERSION)
BOOK_DEPS    := $(MD_FILES) _quarto.yml title-page.tex.in Makefile $(ROOT)/mk/course.mk \
                $(SCRIPTS)/mermaid-pre-render.sh $(SCRIPTS)/mermaid-post-render.sh \
                $(SCRIPTS)/generate-title-page.sh

SLIDE_SCRIPTS_DIR := slides
SLIDE_OUT_DIR     := _slides

.PHONY: help book slides clean release

help:
	@echo "Course: $(COURSE)  (version $(VERSION), next tag $(TAG))"
	@echo " "
	@echo "  make book    Render $(BOOK_PDF). Rebuilds only if a chapter .md,"
	@echo "               _quarto.yml, title-page.tex.in, a shared script, or a"
	@echo "               Makefile (e.g. a VERSION bump) changed since the last"
	@echo "               build. Title page shows VERSION and today's date."
	@echo " "
	@echo "  make slides  Rebuild every module's .pptx from _templates/$(SLIDE_TEMPLATE)"
	@echo "               via slides/build_moduleNN.py into $(SLIDE_OUT_DIR)/."
	@echo "               Requires python-pptx."
	@echo " "
	@echo "  make release Commit this course's tracked changes, push, tag $(TAG),"
	@echo "               and push the tag (CI then publishes $(BOOK_PDF))."
	@echo " "
	@echo "  make clean   Remove _book/, .quarto/, stray .qmd files, the generated"
	@echo "               title-page.tex, and stray slides/*.pptx left by an"
	@echo "               interrupted 'make slides'."

book: $(BOOK_PDF)

$(BOOK_PDF): $(BOOK_DEPS)
	bash $(SCRIPTS)/generate-title-page.sh . $(VERSION) $(EXTRA_TAG_PATTERN)
	bash $(SCRIPTS)/mermaid-pre-render.sh .
	quarto render; status=$$?; bash $(SCRIPTS)/mermaid-post-render.sh .; exit $$status

slides:
	@[ -n "$(SLIDE_MODULES)" ] || { echo "$(COURSE) defines no SLIDE_MODULES."; exit 1; }
	@python3 -c "import pptx" 2>/dev/null || { \
		echo "python-pptx not installed. Run 'make deps' or 'python3 -m pip install python-pptx'."; \
		exit 1; \
	}
	mkdir -p $(SLIDE_OUT_DIR)
	cp $(ROOT)/_templates/$(SLIDE_TEMPLATE) $(SLIDE_SCRIPTS_DIR)/$(SLIDE_TEMPLATE)
	@for m in $(SLIDE_MODULES); do \
		num=$${m%%-*}; \
		echo "==> Building $$m.pptx"; \
		(cd $(SLIDE_SCRIPTS_DIR) && PYTHONPATH="$(SCRIPTS)/slides" python3 build_module$$num.py) || { \
			rm -f $(SLIDE_SCRIPTS_DIR)/$(SLIDE_TEMPLATE); exit 1; \
		}; \
		mv "$(SLIDE_SCRIPTS_DIR)/$$m-wip.pptx" "$(SLIDE_OUT_DIR)/$$m.pptx"; \
	done
	rm -f $(SLIDE_SCRIPTS_DIR)/$(SLIDE_TEMPLATE)
	@echo "==> Done: $(COURSE)/$(SLIDE_OUT_DIR)/*.pptx rebuilt"

release:
	-git commit -m "$(COURSE): new release $(VERSION)" -- .
	git push
	git tag $(TAG)
	git push origin $(TAG)

clean:
	-rm -rf _book .quarto
	-rm -f *.qmd title-page.tex
	-rm -f $(SLIDE_SCRIPTS_DIR)/*.pptx
