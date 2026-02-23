#!/usr/bin/env bash
set -euo pipefail

render_one() {
  local html="$1"
  local pdf="$2"

  echo "Decktape: $html -> $pdf"

  decktape \
    --chrome-arg=--no-sandbox \
    --chrome-arg=--disable-gpu \
    -s 1600x900 -p 2000 \
    reveal "$html" "$pdf"
}

# --- Single-file mode ---
# Usage:
#   ./scripts/decktape.sh path/to/slides/foo.html
#   ./scripts/decktape.sh path/to/slides/foo.html path/to/slides/foo.pdf
if [[ $# -ge 1 ]]; then
  html="$1"
  pdf="${2:-${html%.html}.pdf}"
  render_one "$html" "$pdf"
  exit 0
fi

# --- List mode (backward compatible) ---
# Uses QUARTO_PROJECT_OUTPUT_FILES as before
echo "${QUARTO_PROJECT_OUTPUT_FILES:-}" | while IFS= read -r out; do
  [[ -z "$out" ]] && continue

  case "$out" in
    */slides/*.html)
      html="$out"
      pdf="${out%.html}.pdf"
      render_one "$html" "$pdf"
      ;;
    *)
      echo "Skipping non-slide output: $out"
      ;;
  esac
done
