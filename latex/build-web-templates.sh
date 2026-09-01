#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p ../web/public/templates
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-a4 vatsim-flight-card.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-a5 vatsim-flight-card-a5.tex >/dev/null
if command -v pdftoppm >/dev/null; then
  pdftoppm -png -r 180 -singlefile ../web/public/templates/vatsim-flight-card-a4.pdf ../web/public/templates/vatsim-flight-card-a4
  pdftoppm -png -r 180 -singlefile ../web/public/templates/vatsim-flight-card-a5.pdf ../web/public/templates/vatsim-flight-card-a5
elif command -v qlmanage >/dev/null; then
  qlmanage -t -s 2105 -o ../web/public/templates ../web/public/templates/vatsim-flight-card-a4.pdf >/dev/null 2>&1
  qlmanage -t -s 1488 -o ../web/public/templates ../web/public/templates/vatsim-flight-card-a5.pdf >/dev/null 2>&1
  mv ../web/public/templates/vatsim-flight-card-a4.pdf.png ../web/public/templates/vatsim-flight-card-a4.png
  mv ../web/public/templates/vatsim-flight-card-a5.pdf.png ../web/public/templates/vatsim-flight-card-a5.png
else
  echo "Install Poppler (pdftoppm) to generate web previews." >&2
  exit 1
fi
