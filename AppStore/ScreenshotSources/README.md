# Localized App Store screenshots

`render_english_screenshots.swift` composes five localized App Store
screenshots for iPhone 6.9-inch and iPad 13-inch. It only works from real,
native app captures. Missing captures are reported together and no final
artwork is generated.

The screenshot package contains these storefront locales:

```text
en-US  ja  de-DE  ko  zh-Hant  pt-BR  es-MX
fr-FR  fr-CA  en-GB  en-CA  en-AU  es-ES
```

Each locale has a versioned `screenshots.<locale>.json` manifest. Headline and
supporting copy are arrays of one or two manually balanced lines; the renderer
will shrink them only within the approved type-size range and will fail instead
of silently clipping text. CoreText shaping and fallback are resolved with the
manifest locale, including Japanese, Korean, and Traditional Chinese.

## Required captures

Place opaque PNG captures below `_captures/<captureLocale>/`. A manifest's
`captureLocale` is intentionally separate from its App Store storefront:

```text
en-US, en-GB, en-CA, en-AU -> en-US
de-DE -> de                 fr-FR, fr-CA -> fr
es-ES -> es                 es-MX -> es-MX
ja -> ja                    ko -> ko
zh-Hant -> zh-Hant          pt-BR -> pt-BR
```

Every capture locale needs opaque PNGs at these paths (shown with `en-US`):

```text
_captures/en-US/iPhone-6.9/photo-game.png   1320 x 2868
_captures/en-US/iPhone-6.9/free-arrow.png   1320 x 2868
_captures/en-US/iPhone-6.9/combo.png        1320 x 2868
_captures/en-US/iPhone-6.9/worlds.png       1320 x 2868
_captures/en-US/iPhone-6.9/daily.png        1320 x 2868
_captures/en-US/iPhone-6.9/quests.png       1320 x 2868

_captures/en-US/iPad-13/photo-game.png      2064 x 2752
_captures/en-US/iPad-13/free-arrow.png      2064 x 2752
_captures/en-US/iPad-13/combo.png           2064 x 2752
_captures/en-US/iPad-13/worlds.png          2064 x 2752
_captures/en-US/iPad-13/daily.png           2064 x 2752
_captures/en-US/iPad-13/quests.png          2064 x 2752
```

The shared source photo is
`parrot-photo-maze-compact-v2.png`. `photo-game.png` must show the actual
playable maze generated from that photo.

## Render and validate

From the repository root:

```sh
swift -module-cache-path /tmp/arrow-maze-screenshot-modules \
  AppStore/ScreenshotSources/render_english_screenshots.swift --locale en-US

swift -module-cache-path /tmp/arrow-maze-screenshot-modules \
  AppStore/ScreenshotSources/render_english_screenshots.swift \
  --locale en-US --validate
```

Replace `en-US` with any supported storefront locale. `--locale` selects the
manifest and derives the capture, generated-output, and contact-sheet paths.

After all localized captures are ready, render the 12 remaining storefronts
as one guarded batch:

```sh
AppStore/ScreenshotSources/Tools/render_localized_screenshots.sh --dry-run
AppStore/ScreenshotSources/Tools/render_localized_screenshots.sh
```

The bulk runner never includes `en-US`. It renders and validates each locale
sequentially in a private `/tmp` stage, requires exactly five iPhone and five
iPad screenshots for every storefront, then publishes all 12 locales only
after the entire batch succeeds. Existing localized outputs are backed up for
rollback during the publication transaction, and the approved English files
are fingerprinted before and after it.

`fr-CA` intentionally reuses the neutral French copy and native French app
captures from `fr-FR`. The final ten storefront PNGs are byte-identical; only
the locale manifest, output folder, and review contact-sheet label differ.

Outputs:

```text
Generated/en-US/iPhone-6.9/01_your-photo-your-maze.png ... 05_*.png
Generated/en-US/iPad-13/01_your-photo-your-maze.png ... 05_*.png
Review/en-US_contact-sheet.png
```

Every final screenshot is rendered directly in sRGB, encoded as a
three-channel RGB PNG without transparency, and checked for exact size,
color space, alpha, filename order, duplicate output data, manifest structure,
font glyph coverage, and text fit.

Optional overrides are available for isolated testing:

```text
--locale LOCALE
--input-root PATH
--output-root PATH
--manifest PATH
--photo PATH
--contact-sheet PATH
```
