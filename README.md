# VATSIM Flight Card

LaTeX templates live in `latex/`. The browser-only generator lives in `web/`.

Run the web app with `cd web && npm install && npm run dev`. Build it with `npm run build`.

After changing the LaTeX layout, run `sh latex/build-web-templates.sh` to refresh the web app's vector PDF templates and previews.

For Cloudflare Pages, set the root directory to `web`, the build command to `npm run build`, and the output directory to `dist`.
