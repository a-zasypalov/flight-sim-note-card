#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p ../web/public/templates
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-a4 vatsim-flight-card-web-a4.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=../web/public/templates -jobname=vatsim-flight-card-a5 vatsim-flight-card-web-a5.tex >/dev/null
pdftoppm -png -r 180 -singlefile ../web/public/templates/vatsim-flight-card-a4.pdf ../web/public/templates/vatsim-flight-card-a4
pdftoppm -png -r 180 -singlefile ../web/public/templates/vatsim-flight-card-a5.pdf ../web/public/templates/vatsim-flight-card-a5
