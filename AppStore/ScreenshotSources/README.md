# Native 2.0 App Store screenshots

The current iPhone and iPad artwork uses the existing five-slide design. The four gameplay slides show the new hint button. The campaign slide shows the 260 levels and eight worlds. The daily slide also uses the existing quest panel for languages whose quest screen is unchanged. European Portuguese uses an original quest capture because the archive has no PT-PT panel.

## Storefronts and sources

The canonical mapping is in [v2/storefronts.json](v2/storefronts.json). Each language set has one copy manifest under `v2/screenshots.<set>.json`. English covers the US, UK, Australia and Canada. French covers France and Canada. Spanish for Spain and Mexico differs in promotional copy. The Brazilian and European Portuguese screens differ in native UI labels, including the Undo action.

For submission, follow the ordered entries in [v2/Generated/assets.json](v2/Generated/assets.json). Each entry points to a local PNG relative to `v2/Generated`. Reuse those paths for every listed storefront. Spain and Mexico share slides 1, 2 and 4 on both devices. Slides 3 and 5 have different copy. [The English contact sheet](v2/Generated/Review/en.png) shows the complete layout. The remaining contact sheets are in the same folder.

The November 22, 2026 Photo Maze artwork shows the updated arrow contrast from native version 2.0, build 2. The other four slides on each device retain their November 20 exports. The 10 language sets cover 14 storefronts and reference 94 unique submission PNGs across 100 device and slide combinations.

The directories `Generated/`, `Review/`, `_captures/` and the `screenshots.*.json` manifests at this README’s level belong to 1.x. The 2.0 runner reads only the expressly mapped unchanged quest panels from the old captures. It writes all new files under `v2/`.

## Capture on macOS

Use the native project's Debug simulator build with its screenshot harness and explicitly selected, booted simulators. The iPhone should produce 1320 × 2868 pixels, the iPad 2064 × 2752. Both devices must run the same app build for new captures. Use dedicated simulators. The harness sets the device's game theme to Midnight Neon and stores its progress fixture in a separate preferences suite.

```sh
AppStore/ScreenshotSources/Tools/capture_localized_screenshots.sh \
  --app-bundle "$APP_BUNDLE" --iphone-udid "$IPHONE_UDID" --ipad-udid "$IPAD_UDID"
```

Supplying just one device processes its captures. Repeated `--profile` options select individual language sets. The runner waits for the native screen-ready marker, captures from CoreSimulator and checks PNG integrity and dimensions. The app version, build and hashes of the simulator executable and debug library are recorded alongside per-device source indexes. Each index identifies the capture or reused panel for every slide. Reruns skip existing sources from the same build after checksum verification. Use `--force` to recapture the selected profiles.

For a change confined to Photo Maze, pass `--scene photo` during capture. The runner refreshes the selected scene from the new binary and keeps the other source images. The `captureIndexes` links in the export manifest identify each device's source index. Reused 2.0 images carry a `sourceBuild` reference to the executable and resource hashes that produced them. The `unchanged-v1-quest-screen` entries identify the archived quest panels.

## Render and check

The capture stage needs Xcode's simctl and ImageMagick. The Swift compositor uses CoreGraphics, CoreText and the SF Pro Rounded fonts. The renderer runs the local validation command from the asc CLI for each logical five-image set. Run from the repository root.

```sh
AppStore/ScreenshotSources/Tools/render_localized_screenshots.sh --dry-run
AppStore/ScreenshotSources/Tools/render_localized_screenshots.sh
python3 AppStore/ScreenshotSources/Tools/media_v2.py validate
```

To refresh only the Photo Maze slide in an existing package, use `AppStore/ScreenshotSources/Tools/render_localized_screenshots.sh --slide photoMaze`. The compositor copies the four previously validated exports for each language and device, renders the new slide, then builds the contact sheet and validates all five images together.

Rendering checks all source checksums and text fit. The compositor validates five opaque RGB/sRGB PNGs per language and device. The runner stores identical exports once, checks device dimensions and ordered checksums, then replaces the local 2.0 package. App Store Connect upload is a separate release step.
