# VATSIM Flight Card

LaTeX templates live in `latex/`. The browser-only generator lives in `web/`.

Run the web app with `cd web && npm install && npm run dev`. Build it with `npm run build`.

After changing the LaTeX layout, run `sh latex/build-web-templates.sh` to refresh the web app's vector PDF templates and previews.

To make local branded PDFs, put an image in `latex/logo/` and run these from the project root, replacing `logo/airline.png` with its path:

```sh
cd latex
pdflatex -interaction=nonstopmode -halt-on-error -jobname=vatsim-flight-card '\def\AirlineLogoFile{logo/airline.png}\input{vatsim-flight-card.tex}'
pdflatex -interaction=nonstopmode -halt-on-error -jobname=vatsim-flight-card-a5 '\def\AirlineLogoFile{logo/airline.png}\input{vatsim-flight-card-a5.tex}'
```

For Cloudflare Pages, set the root directory to `web`, the build command to `npm run build`, and the output directory to `dist`.
