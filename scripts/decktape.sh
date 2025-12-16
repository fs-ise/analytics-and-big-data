#!/usr/bin/env bash
set -euo pipefail

echo "${QUARTO_PROJECT_OUTPUT_FILES:-}" | while IFS= read -r out; do
  [[ -z "$out" ]] && continue

  case "$out" in
    */slides/*.html)
      html="$out"
      pdf="${out%.html}.pdf"

      echo "Decktape: $html -> $pdf"

      decktape \
        --chrome-arg=--no-sandbox \
        --chrome-arg=--disable-gpu \
        -s 1600x900 -p 2000 \
        reveal "$html" "$pdf"
      ;;
    *)
      echo "Skipping non-slide output: $out"
      ;;
  esac
done
