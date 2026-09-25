# Arrow Maze promotional site

Source for `https://kinapp.dev/arrowmaze/`.

The landing page is deliberately dependency-free: static HTML, CSS and JavaScript plus optimized local images. Privacy, Terms and Support remain separate server routes and are not part of this directory.

## Local preview

```sh
python3 -m http.server 8765 --directory AppStore/Landing
```

Open `http://127.0.0.1:8765/`.

## Supported locales

English, English (India), German, Spanish, Spanish (Mexico), French, Hindi, Indonesian, Japanese, Korean, Portuguese (Brazil), Portuguese (Portugal), Russian, Thai and Traditional Chinese.

The page detects the browser language on first visit. A manual selection is stored locally and takes precedence. Unsupported locales fall back to English.

## Themes and accessibility

System appearance is used by default. Visitors can select Aurora or Midnight Neon manually. The page supports reduced motion, increased contrast, reduced transparency, keyboard navigation and responsive layouts from 320 px upward.

## Release checklist

- Run `node --check AppStore/Landing/app.js`.
- Confirm every locale has the same translation keys as English.
- Test 320 px phone, 834 px tablet and 1440 px desktop layouts.
- Test Aurora, Neon and system appearance.
- Complete and reset the mini maze.
- Move the Photo Maze comparison slider.
- Verify `/arrowmaze/privacy/`, `/arrowmaze/terms/` and `/arrowmaze/support/` return HTTP 200.
- Back up the current server landing before replacing the root page and assets.
