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

# Decktape PDF generation
.PHONY: pdfs
pdfs: decktape-warning $(SLIDES_PDF)

# Render PDF-export HTML, run Decktape, compress, clean up
$(SLIDES_DIR)/%.pdf: $(SRC_SLIDES_DIR)/%.qmd _quarto.yml scripts/decktape.sh | docker-image
	@echo "Quarto: rendering $< for PDF export"
	$(QUARTO) render $< --profile pdf -P execute=false --output-dir $(abspath _pdf-tmp)
	mv _pdf-tmp/slides/$*.html $(SLIDES_DIR)/$*-pdf.html
	@echo "Rendering $@"
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
	    ./scripts/decktape.sh "http://localhost:8000/slides/$*-pdf.html" "$@" && \
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
	@echo "Cleaning up"
	rm $(SLIDES_DIR)/$*-pdf.html
	rm -rf _pdf-tmp

.PHONY: decktape-clean
decktape-clean:
	rm -f $(SLIDES_DIR)/*.pdf

.PHONY: slides-clean
slides-clean:
	rm -rf $(OUT_DIR)

# --- Exercises (dual-build via profiles in exercises subproject) ---

.PHONY: exercises-assign exercises-solution exercises

exercises-assign:
	$(QUARTO) render exercises --profile assign --to ipynb --no-clean
	$(QUARTO) render exercises --profile assign --to html --no-clean
	for f in _site/exercises/*.ipynb; do \
		[ -e "$$f" ] || continue; \
		mv "$$f" "$${f%.ipynb}_assign.ipynb"; \
	done
	for f in _site/exercises/*.html; do \
		[ -e "$$f" ] || continue; \
		mv "$$f" "$${f%.html}_assign.html"; \
	done

exercises-solution:
	$(QUARTO) render exercises --profile solution --to ipynb --no-clean
	$(QUARTO) render exercises --profile solution --to html --no-clean

	for f in _site/exercises/*.ipynb; do \
		[ -e "$$f" ] || continue; \
		case "$$f" in *_assign.ipynb|*_solution.ipynb) continue ;; esac; \
		mv "$$f" "$${f%.ipynb}_solution.ipynb"; \
	done

	for f in _site/exercises/*.html; do \
		[ -e "$$f" ] || continue; \
		case "$$f" in *_assign.html|*_solution.html) continue ;; esac; \
		mv "$$f" "$${f%.html}_solution.html"; \
	done

exercises: exercises-assign exercises-solution

# --- Site build (main project renders once) ---

.PHONY: site-fast site all

site-fast:
	$(QUARTO) render --no-clean

# Full site build: exercises first, then main site once
site: exercises site-fast

# One command to build everything (site + slide PDFs)
all: site pdfs