# ---- Config ----
DOCKER_IMAGE ?= big-data-analytics-decktape

# Find all rendered slide HTML files on the host
SLIDES_HTML := $(shell find _site/slides -type f -name '*.html')

# ---- Targets ----

.PHONY: docker-image
docker-image:
	docker build -t $(DOCKER_IMAGE) .


.PHONY: decktape
decktape: docker-image
	@if [ -z "$(SLIDES_HTML)" ]; then \
	  echo "No slide HTML files found in _site/slides/*.html"; \
	  echo "Did you run 'quarto render'? Or is the output path different?"; \
	  exit 1; \
	fi
	docker run --rm \
	  -e HOST_UID=$$(id -u) \
	  -e HOST_GID=$$(id -g) \
	  -v "$(PWD)":/project \
	  -w /project \
	  $(DOCKER_IMAGE) \
	  bash -lc '\
	    QUARTO_PROJECT_OUTPUT_FILES="$$(printf "%s\n" $(SLIDES_HTML))" ./scripts/decktape.sh && \
	    chown $$HOST_UID:$$HOST_GID _site/slides/*.pdf \
	  '

# .PHONY: decktape
# decktape: docker-image
# 	@if [ -z "$(SLIDES_HTML)" ]; then \
# 	  echo "No slide HTML files found in _site/slides/*.html"; \
# 	  echo "Did you run 'quarto render'? Or is the output path different?"; \
# 	  exit 1; \
# 	fi
# 	docker run --rm \
# 	  -v "$(PWD)":/project \
# 	  -w /project \
# 	  $(DOCKER_IMAGE) \
# 	  bash -lc 'QUARTO_PROJECT_OUTPUT_FILES="$$(printf "%s\n" $(SLIDES_HTML))" ./scripts/decktape.sh'
# 	chown $$(id -u):$$(id -g) _site/slides/*.pdf
