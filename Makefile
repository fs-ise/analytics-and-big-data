# ---- Config ----
DOCKER_IMAGE ?= big-data-analytics-decktape

QUARTO ?= quarto

SRC_SLIDES_DIR := slides
OUT_DIR        := _site
SLIDES_DIR     := $(OUT_DIR)/slides

# All slide sources (qmd)
SLIDES_QMD  := $(shell find $(SRC_SLIDES_DIR) -type f -name '*.qmd' 2>/dev/null)

# Expected rendered outputs in _site/slides
SLIDES_HTML := $(patsubst $(SRC_SLIDES_DIR)/%.qmd,$(SLIDES_DIR)/%.html,$(SLIDES_QMD))
SLIDES_PDF  := $(SLIDES_HTML:.html=.pdf)

# ---- Targets ----

.PHONY: docker-image
docker-image:
	docker build -t $(DOCKER_IMAGE) .

.PHONY: decktape-warning
decktape-warning:
	@if [ ! -d "$(SLIDES_DIR)" ]; then \
	  echo "Warning: $(SLIDES_DIR) does not exist yet. It will be created by Quarto."; \
	elif [ -z "$(SLIDES_HTML)" ]; then \
	  echo "Warning: No slide HTML files found/expected in $(SLIDES_DIR)."; \
	fi

# --- Slides (HTML -> PDF) ---

# Convenience target: build slide PDFs (HTML first, then PDF)
.PHONY: slides
slides: pdfs

# Quarto rendering: one qmd -> expected html in _site/slides
# (Make sure your root _quarto.yml output-dir is _site, which it is.)
$(SLIDES_DIR)/%.html: $(SRC_SLIDES_DIR)/%.qmd _quarto.yml
	@echo "Quarto: rendering $<"
	$(QUARTO) render $<

# Decktape PDF generation
.PHONY: pdfs
pdfs: decktape-warning $(SLIDES_PDF)

# Pattern rule: one PDF depends on its HTML
$(SLIDES_DIR)/%.pdf: $(SLIDES_DIR)/%.html scripts/decktape.sh | docker-image
	@echo "Rendering $@ (from $<)"
	docker run --rm \
	  -e HOST_UID=$$(id -u) \
	  -e HOST_GID=$$(id -g) \
	  -v "$(PWD)":/project \
	  -w /project \
	  $(DOCKER_IMAGE) \
	  bash -lc '\
	    python3 -m http.server 8000 --directory _site >/dev/null 2>&1 & \
	    SERVER_PID=$$!; \
	    sleep 2; \
	    ./scripts/decktape.sh "http://localhost:8000/slides/$(notdir $<)" "$@" && \
	    kill $$SERVER_PID; \
	    \
	    echo "Compressing PDF with Ghostscript..."; \
	    gs -sDEVICE=pdfwrite \
	       -dCompatibilityLevel=1.4 \
	       -dPDFSETTINGS=/ebook \
	       -dNOPAUSE -dQUIET -dBATCH \
	       -sOutputFile="$@.compressed" "$@" && \
	    mv "$@.compressed" "$@"; \
	    \
	    chown $$HOST_UID:$$HOST_GID "$@" \
	  '

.PHONY: decktape-clean
decktape-clean:
	rm -f $(SLIDES_DIR)/*.pdf

.PHONY: slides-clean
slides-clean:
	rm -rf $(OUT_DIR)

# --- Exercises (dual-build via profiles in exercises subproject) ---

.PHONY: exercises-assign exercises-solution exercises

exercises-assign-ipynb:
	$(QUARTO) render exercises --profile assign --to ipynb --no-clean

exercises-assign-html:
	$(QUARTO) render exercises --profile assign --to html --no-clean

exercises-solution-ipynb:
	$(QUARTO) render exercises --profile solution --to ipynb --no-clean

exercises-solution-html:
	$(QUARTO) render exercises --profile solution --to html --no-clean

# exercises: exercises-solution # exercises-assign
exercises: exercises-assign-ipynb exercises-assign-html exercises-solution-ipynb exercises-solution-html


# --- Site build (main project renders once) ---

.PHONY: site-fast site all

site-fast:
	$(QUARTO) render --no-clean

# Full site build: exercises first (to _site/assignments + _site/solutions), then main site once
site: exercises site-fast

# One command to build everything (site + slide PDFs)
all: site pdfs
