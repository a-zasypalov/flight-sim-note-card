# VATSIM Flight Card

## Structure

- `latex/` is the canonical blank-card design. `vatsim-flight-card-layout.tex` is the shared layout; the A4 and A5 files prepare its final pages.
- `web/` is a static, browser-only Vite app. It adds user logos and imported ICAO FPL values to the generated vector PDFs locally.
- `ios/` is the native SwiftUI document app for iPhone and iPad. Editable notes are `.pilotnote` packages whose manifests tie content to a stable layout ID and revision.
- `ios/Pilot Notes/Layouts/` contains versioned PDF backgrounds and their card-local geometry manifests. Published revisions are immutable because notes retain their layout ID and revision.
- `web/public/templates/` contains generated, tracked PDFs and preview PNGs. Do not edit these files by hand.
- `web/templates.js` must stay aligned with the LaTeX card geometry because it places web preview and PDF overlays.

## Workflow

- After changing the LaTeX card layout, run `sh latex/build-web-templates.sh` from the repository root to refresh `web/public/templates/`.
- When a LaTeX change should reach the native app, add a new native layout revision and preserve every existing revision.
- For web changes, run `cd web && npm run check && npm run build`.
- For native changes, build the `Pilot Notes` scheme in `ios/Pilot Notes.xcodeproj`. Keep native tests current, but do not launch a simulator unless explicitly requested.
- Native iCloud sync uses the public `iCloud.com.gaoyun.pilot-notes` Documents container. The Apple Developer team must provision it before device testing.
- Cloudflare Pages uses `web` as the root directory, `npm run build` as the build command, and `dist` as the output directory.

## Implementation

- Keep web PDF generation entirely in the browser. Native PDF export must likewise stay on-device. Do not add a backend, accounts, analytics, or server functions.
- Prefer minimal, concise, human-readable HTML, CSS, and JavaScript. Avoid new dependencies, frameworks, and premature abstractions.
- Prefer SwiftUI, Observation, and Apple platform frameworks in the native app. Do not add a DI framework or storage abstraction before it is needed.
- Layout definitions own field geometry, labels, and writing regions. Notes own entered values, annotations, and user assets in layout coordinates. Saving preserves editable content; PDF export is a separate representation.
- Native editing and export must use the same layout geometry. Imported logos are stored as aspect-fitted PNG data and PDF export stays entirely on-device.
- A note stores its layout ID and revision. Never silently apply changed geometry to existing annotations.
- The `.pilotnote` package format stores editable values in `manifest.json` and an optional aspect-fitted logo in `logo.png`. The document filename is the note name and must not be duplicated in the manifest.
- Keep code straightforward and untangled so it can grow without speculative generalization.
- Do not add comments that restate obvious code. Keep comments only for non-obvious constraints or decisions.
- Preserve user-authored visual edits and unrelated working-tree changes. Never discard or overwrite them.

## Maintenance

Update this file when the project structure, source-of-truth relationship, build workflow, validation, or deployment settings change.
