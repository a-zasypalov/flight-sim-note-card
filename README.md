# VATSIM Flight Card

Pilot Notes is growing from a printable VATSIM flight card into a native note editor. A note will combine a versioned layout with editable flight values, annotations, and user assets, then save that editable content or export it as a PDF.

- `latex/` contains the reference design for the first flight-card layout.
- `web/` contains the browser-only generator and can prefill card basics from an ICAO `(FPL-...)` message.
- `ios/` contains the native SwiftUI document app for iPhone and iPad. Notes can edit layout-defined fields, add an aspect-fitted logo from Photos, Files, or drag and drop, and export the composed card as a PDF.

Run the web app with `cd web && npm install && npm run dev`. Build it with `npm run build`.

After changing the LaTeX layout, run `sh latex/build-web-templates.sh` to refresh the web app's vector PDF templates and previews.

To make local branded PDFs, put an image in `latex/logo/` and run these from the project root, replacing `logo/airline.png` with its path:

```sh
cd latex
pdflatex -interaction=nonstopmode -halt-on-error -jobname=vatsim-flight-card '\def\AirlineLogoFile{logo/airline.png}\input{vatsim-flight-card.tex}'
pdflatex -interaction=nonstopmode -halt-on-error -jobname=vatsim-flight-card-a5 '\def\AirlineLogoFile{logo/airline.png}\input{vatsim-flight-card-a5.tex}'
```

For Cloudflare Pages, set the root directory to `web`, the build command to `npm run build`, and the output directory to `dist`.

Open `ios/Pilot Notes.xcodeproj` in Xcode to run the native app. Editable notes are `.pilotnote` document packages managed by the system document browser and synchronized by iCloud Drive when stored in the Pilot Notes iCloud folder. PDF exports remain separate user-managed files.

The iCloud container `iCloud.com.gaoyun.pilot-notes` must be enabled for Apple Developer team `55554XNCXE` before testing sync on signed devices.

Native layouts live in `ios/Pilot Notes/Layouts/` as an immutable PDF and JSON geometry manifest for each revision. Add a new revision instead of replacing one already referenced by saved notes.
