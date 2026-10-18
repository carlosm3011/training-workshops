# Makefile for BGP 101 PDF Generation

# Variables
PANDOC = pandoc
FILTER = mermaid-filter
METADATA = metadata.yaml
OUTPUT = bgp-101-book.pdf
LABGOUTPUT = bgp-101-labguide.pdf

# List of chapters in order
CHAPTERS = 01-basic-concepts.md \
           02-bgp-messages.md \
           03-path-attributes-bestpath-selection.md \
           05-announcing-my-routes.md \
           06-ibgp-mechanics.md \
           08-accepting-routes-from-others.md \
           09-traffic-engineering.md

LABS = 04-lab-1.md \
       07-lab-2.md \
       10-lab-3.md \
       11-lab-4.md

# Default target
all: book labguide

# PDF target
book: $(CHAPTERS) $(METADATA)
	@echo "Generating PDF book..."
	$(PANDOC) $(METADATA) $(CHAPTERS) \
		-o $(OUTPUT) \
		--filter $(FILTER) \
		--toc \
		--number-sections \
		--pdf-engine=pdflatex \
		--variable linkcolor=blue \
		--variable urlcolor=blue
	@echo "Successfully generated $(OUTPUT)"

labguide: $(LABS) $(METADATA)
	@echo "Generating PDF lab guide..."
	$(PANDOC) $(METADATA) $(LABS) \
		-o $(LABGOUTPUT) \
		--filter $(FILTER) \
		--toc \
		--number-sections \
		--pdf-engine=pdflatex \
		--variable linkcolor=blue \
		--variable urlcolor=blue
	@echo "Successfully generated $(LABGOUTPUT)"

# Clean target
clean:
	@echo "Cleaning up..."
	rm -f $(OUTPUT)
	rm -f $(LABGOUTPUT)
	rm -f mermaid-filter-*.png

.PHONY: all book labguide clean
