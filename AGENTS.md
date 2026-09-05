# VATSIM Flight Card

## Structure

- `latex/` is the canonical blank-card design. `vatsim-flight-card-layout.tex` is the shared layout; the A4 and A5 files prepare its final pages.
- `web/` is a static, browser-only Vite app. It adds user logos and imported ICAO FPL values to the generated vector PDFs locally.
- `web/public/templates/` contains generated, tracked PDFs and preview PNGs. Do not edit these files by hand.
- `web/templates.js` must stay aligned with the LaTeX card geometry because it places web preview and PDF overlays.

## Workflow

- After changing the LaTeX card layout, run `sh latex/build-web-templates.sh` from the repository root to refresh `web/public/templates/`.
- For web changes, run `cd web && npm run check && npm run build`.
- Cloudflare Pages uses `web` as the root directory, `npm run build` as the build command, and `dist` as the output directory.

## Implementation

- Keep PDF generation entirely in the browser. Do not add a backend, accounts, analytics, or server functions.
- Prefer minimal, concise, human-readable HTML, CSS, and JavaScript. Avoid new dependencies, frameworks, and premature abstractions.
- Keep code straightforward and untangled so it can grow without speculative generalization.
- Do not add comments that restate obvious code. Keep comments only for non-obvious constraints or decisions.
- Preserve user-authored visual edits and unrelated working-tree changes. Never discard or overwrite them.

## Maintenance

Update this file when the project structure, source-of-truth relationship, build workflow, validation, or deployment settings change.
