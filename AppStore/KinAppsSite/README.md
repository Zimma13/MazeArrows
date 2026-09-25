# KinApps product catalog

Local source snapshot for the homepage and All Products catalog at `https://kinapp.dev/`, updated on 2026-09-06.

The server document root is `/var/www/kinapp.dev/html`. This directory contains the homepage, product catalog, shared styles, scripts and EN/RU dictionaries used for the Arrow Maze addition. It is a partial snapshot, not a complete website mirror; do not deploy it with deletion enabled.

Arrow Maze cards link directly to `/arrowmaze/` and use `/arrowmaze/assets/app-icon.webp`, the optimized version of the application's primary `AppIco.png`. Landing source lives in `../Landing/` and maps to the server's `landings/arrowmaze/` directory.

The 2026-09-06 update added the game to both product grids and site search, enabled the landing's App Store download button, and updated its CTA in all 15 locales. JavaScript syntax, translation keys, card links, the App Store destination and published file hashes were checked.

Server backup before this update: `/var/backups/kinapp/arrowmaze-20260906T032507Z`.

The 2026-09-12 update replaced the iCleanse placeholder glyph with the app's real icon and removed the intermediate product modal for that card. Both product grids now use `<a class="product-card" href="/icleanse/">` with `/icleanse/icons/app-icon.webp` (512x512 WebP, 10 KB, generated from the app's `iCleanse-AppIcon-1024-Any.png`), matching the Arrow Maze pattern. `APPS.icleanse` in `assets/js/site.js` is left in place but is now unreachable, since no card carries `data-app="icleanse"`.

Server backup before this update: `/var/backups/kinapp/icleanse-card-20260912T062052Z`.

A second 2026-09-12 update applied the identical treatment to the Fonts & Tags card: both grids now use `<a class="product-card" href="/fnt/">` with `/assets/img/fnt-app-icon.webp` (512x512 WebP, 4 KB, generated from `MagicKeyboard/Assets.xcassets/AppIcon.appiconset/iTunesArtwork@2x.png` in the Fonts&Tagz repo). Unlike the iCleanse card, the now-unreachable `APPS.fnt` entry in `assets/js/site.js` and the `.thumb-fnt` gradient in `assets/css/site.css` were deleted, so the `site.css`/`site.js` cache-busting query on both pages was bumped to `?v=20260912-1`.

Server backup before this update: `/var/backups/kinapp/fnt-card-20260912T062827Z`.

A later 2026-09-12 update fixed the site logo. The header and footer mark is `/assets/img/kinapps-logo.webp` (256x256 lossless WebP, 20 KB), rendered from `/img/logo.jpeg` — the company mark as designed, on its own `rgb(235,236,240)` ground. That is exactly the `.page` background the logo sits on, so the artwork reads as part of the page instead of a badge. `.logo-mark` lost its disc, ring and crop (`border-radius`, `overflow: hidden`, `background: #dfe1e7`, inset `box-shadow`), and the `.logo-mark::after` red dot was deleted; the `--sh-dot` token stays in `:root` should the dot ever come back. Do not rebuild this mark by keying the black `kinapps-logo.jpg` to transparency: that render lacks the mark's soft shadows and its premultiplied edges turn into dark fringes on a light ground. If the `.page` colour ever changes, re-render the mark on the new colour. The favicon set was rebuilt from the same mark: `/assets/img/kinapps-favicon-{16,32,180}.png` (light `rgb(235,236,240)` ground, a touch of unsharp at 16 and 32 px so the petals survive the downscale) plus a 16+32 `/favicon.ico` at the document root, which did not exist before. The 180 px file serves as the apple-touch-icon. Only `og:image`/`twitter:image` still point at the black-background `kinapps-logo.jpg`, where a dark card reads better, and the Arrow Maze landing subpages (`landings/arrowmaze/{privacy,support,terms}`) still use that JPG in their own headers and icon links.

Server backups for the logo steps: `/var/backups/kinapp/logo-20260912T065602Z`, `/var/backups/kinapp/logo2-20260912T071014Z` and `/var/backups/kinapp/favicon-20260912T072109Z`.
