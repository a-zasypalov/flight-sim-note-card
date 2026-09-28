#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p ../web/public/templates
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-a4 vatsim-flight-card.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-a5 vatsim-flight-card-a5.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-fuel-a4 vatsim-flight-card-fuel.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-fuel-a5 vatsim-flight-card-fuel-a5.tex >/dev/null
if command -v pdftoppm >/dev/null; then
  for card in vatsim-flight-card-a4 vatsim-flight-card-a5 vatsim-flight-card-fuel-a4 vatsim-flight-card-fuel-a5; do
    pdftoppm -png -r 180 -singlefile "../web/public/templates/$card.pdf" "../web/public/templates/$card"
  done
elif command -v qlmanage >/dev/null; then
  for card in vatsim-flight-card-a4 vatsim-flight-card-fuel-a4; do
    qlmanage -t -s 2105 -o ../web/public/templates "../web/public/templates/$card.pdf" >/dev/null 2>&1
    mv "../web/public/templates/$card.pdf.png" "../web/public/templates/$card.png"
  done
  for card in vatsim-flight-card-a5 vatsim-flight-card-fuel-a5; do
    qlmanage -t -s 1488 -o ../web/public/templates "../web/public/templates/$card.pdf" >/dev/null 2>&1
    mv "../web/public/templates/$card.pdf.png" "../web/public/templates/$card.png"
  done
else
  echo "Install Poppler (pdftoppm) to generate web previews." >&2
  exit 1
fi
