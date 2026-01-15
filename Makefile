# ---- Config ----
DOCKER_IMAGE ?= big-data-analytics-decktape

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

# Convenience target: build everything (HTML first, then PDF)
.PHONY: slides
slides: $(SLIDES_PDF)

# --- Quarto rendering ---
# Render one qmd -> expected html in _site/slides
# (Make sure your _quarto.yml output-dir is _site, which it is.)
$(SLIDES_DIR)/%.html: $(SRC_SLIDES_DIR)/%.qmd _quarto.yml
	@echo "Quarto: rendering $<"
	quarto render $<

# If you have shared dependencies that should also trigger rebuilds, add them above, e.g.:
#   assets/frankfurt.css assets/header.html

# --- Decktape PDF generation ---
.PHONY: decktape
pdfs: decktape-warning $(SLIDES_PDF)

# Pattern rule: one PDF depends on its HTML (which depends on the QMD)
$(SLIDES_DIR)/%.pdf: $(SLIDES_DIR)/%.html scripts/decktape.sh | docker-image
	@echo "Rendering $@ (from $<)"
	docker run --rm \
	  -e HOST_UID=$$(id -u) \
	  -e HOST_GID=$$(id -g) \
	  -v "$(PWD)":/project \
	  -w /project \
	  $(DOCKER_IMAGE) \
	  bash -lc '\
	    ./scripts/decktape.sh "$<" "$@" && \
	    chown $$HOST_UID:$$HOST_GID "$@" \
	  '

.PHONY: decktape-clean
decktape-clean:
	rm -f $(SLIDES_DIR)/*.pdf

.PHONY: slides-clean
slides-clean:
	rm -rf $(OUT_DIR)
