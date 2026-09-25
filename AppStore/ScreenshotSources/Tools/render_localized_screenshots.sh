#!/bin/zsh

emulate -LR zsh
set -euo pipefail

export LC_ALL=C

readonly repo_root=${0:A:h:h:h:h}
readonly source_root="$repo_root/AppStore/ScreenshotSources"
readonly renderer="$source_root/render_english_screenshots.swift"
readonly shared_photo="$source_root/parrot-photo-maze-compact-v2.png"
readonly script_name=${0:t}

# en-US is intentionally absent: its approved artwork must never be regenerated
# by this bulk runner.
typeset -ar storefront_locales=(
    ja de-DE ko zh-Hant pt-BR es-MX fr-FR fr-CA en-GB en-CA en-AU es-ES
)

typeset -Ar capture_locale=(
    ja ja
    de-DE de
    ko ko
    zh-Hant zh-Hant
    pt-BR pt-BR
    es-MX es-MX
    fr-FR fr
    fr-CA fr
    en-GB en-US
    en-CA en-US
    en-AU en-US
    es-ES es
)

typeset -ar devices=(iPhone-6.9 iPad-13)
typeset -ar output_filenames=(
    01_your-photo-your-maze.png
    02_find-the-free-arrow.png
    03_watch-it-all-unravel.png
    04_240-levels-7-worlds.png
    05_fresh-maze-every-day.png
)
typeset -ar capture_filenames=(
    photo-game.png
    free-arrow.png
    combo.png
    worlds.png
    daily.png
    quests.png
)

dry_run=0
stage_root=""
publish_root=""
backup_root=""
publishing=0
publish_complete=0
typeset -a touched_locales=()
typeset -A owned_temp_paths=()
typeset -A generated_had_backup=()
typeset -A contact_had_backup=()
typeset -A generated_installed=()
typeset -A contact_installed=()

usage() {
    print -r -- "
Render and publish all 12 non-en-US Arrow Maze App Store storefronts.

Usage:
  $script_name [--dry-run]
  $script_name --help

Options:
  --dry-run   Validate manifests and print the render plan without writing files
  --help      Show this help

The runner renders each locale sequentially into a private /tmp directory,
validates exactly five iPhone and five iPad PNGs per locale, and only then
publishes the complete set into Generated/ and Review/. The approved en-US
outputs are excluded and fingerprinted before and after publication."
}

die() {
    print -u2 -r -- "render_localized_screenshots: $*"
    exit 1
}

log() {
    print -r -- "[localized-render] $*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 \
        || die "Required command not found: $1"
}

register_temp_path() {
    local path=$1
    [[ -n "$path" && "$path" != "/" && "$path" != "$source_root" ]] \
        || die "Refusing to register an unsafe temporary path: $path"
    owned_temp_paths[$path]=1
}

remove_owned_tree() {
    local path=$1
    [[ -n "$path" ]] || return 0
    [[ -n ${owned_temp_paths[$path]-} ]] \
        || die "Refusing to remove an unregistered temporary path: $path"
    if [[ -e "$path" ]]; then
        /bin/rm -rf -- "$path"
    fi
    unset "owned_temp_paths[$path]"
}

manifest_value() {
    local manifest=$1
    local key=$2
    /usr/bin/plutil -extract "$key" raw -o - "$manifest" 2>/dev/null \
        || die "Unable to read '$key' from ${manifest:t}."
}

validate_manifests() {
    local locale manifest schema manifest_locale manifest_capture

    [[ -f "$renderer" ]] || die "Renderer not found: $renderer"
    [[ -f "$shared_photo" ]] || die "Shared photo not found: $shared_photo"

    for locale in "${storefront_locales[@]}"; do
        [[ "$locale" != "en-US" ]] \
            || die "Safety invariant failed: en-US entered the bulk locale list."

        manifest="$source_root/screenshots.$locale.json"
        [[ -f "$manifest" ]] || die "Manifest not found: $manifest"

        schema=$(manifest_value "$manifest" schemaVersion)
        manifest_locale=$(manifest_value "$manifest" locale)
        manifest_capture=$(manifest_value "$manifest" captureLocale)

        [[ "$schema" == "1" ]] \
            || die "${manifest:t} must use schemaVersion 1, found '$schema'."
        [[ "$manifest_locale" == "$locale" ]] \
            || die "${manifest:t} declares locale '$manifest_locale'; expected '$locale'."
        [[ "$manifest_capture" == "${capture_locale[$locale]}" ]] \
            || die "${manifest:t} declares captureLocale '$manifest_capture'; expected '${capture_locale[$locale]}'."
    done
}

validate_captures() {
    local locale capture device filename path
    typeset -A checked_capture_locales=()
    typeset -a missing=()

    for locale in "${storefront_locales[@]}"; do
        capture=${capture_locale[$locale]}
        [[ -z ${checked_capture_locales[$capture]-} ]] || continue
        checked_capture_locales[$capture]=1

        for device in "${devices[@]}"; do
            for filename in "${capture_filenames[@]}"; do
                path="$source_root/_captures/$capture/$device/$filename"
                [[ -s "$path" ]] || missing+=("$path")
            done
        done
    done

    if (( ${#missing} > 0 )); then
        print -u2 -r -- "Localized captures are not ready:"
        for path in "${missing[@]}"; do
            print -u2 -r -- "  $path"
        done
        die "Capture preflight failed; nothing was rendered or published."
    fi
}

png_count() {
    local directory=$1
    /usr/bin/find "$directory" -maxdepth 1 -type f -name '*.png' -print \
        | /usr/bin/wc -l \
        | /usr/bin/tr -d '[:space:]'
}

verify_locale_tree() {
    local generated_root=$1
    local contact_sheet=$2
    local locale=$3
    local device filename directory count

    [[ "$locale" != "en-US" ]] \
        || die "Safety invariant failed: refusing to verify en-US as a bulk target."

    for device in "${devices[@]}"; do
        directory="$generated_root/$locale/$device"
        [[ -d "$directory" ]] \
            || die "Missing staged output directory: $directory"

        count=$(png_count "$directory")
        [[ "$count" == "5" ]] \
            || die "$locale/$device must contain exactly 5 PNGs, found $count."

        for filename in "${output_filenames[@]}"; do
            [[ -s "$directory/$filename" ]] \
                || die "Missing or empty staged output: $directory/$filename"
        done
    done

    [[ -s "$contact_sheet" ]] \
        || die "Missing or empty contact sheet: $contact_sheet"
}

verify_complete_stage() {
    local generated_count contact_count

    generated_count=$(/usr/bin/find "$stage_root/Generated" -type f -name '*.png' -print \
        | /usr/bin/wc -l \
        | /usr/bin/tr -d '[:space:]')
    contact_count=$(/usr/bin/find "$stage_root/Review" -maxdepth 1 -type f -name '*_contact-sheet.png' -print \
        | /usr/bin/wc -l \
        | /usr/bin/tr -d '[:space:]')

    [[ "$generated_count" == "120" ]] \
        || die "Complete stage must contain exactly 120 screenshot PNGs, found $generated_count."
    [[ "$contact_count" == "12" ]] \
        || die "Complete stage must contain exactly 12 contact sheets, found $contact_count."
}

english_fingerprint() {
    local device filename path contact

    for device in "${devices[@]}"; do
        for filename in "${output_filenames[@]}"; do
            path="$source_root/Generated/en-US/$device/$filename"
            if [[ -f "$path" ]]; then
                print -r -- "$device/$filename:$(/usr/bin/shasum -a 256 "$path" | /usr/bin/awk '{ print $1 }')"
            else
                print -r -- "$device/$filename:MISSING"
            fi
        done
    done

    contact="$source_root/Review/en-US_contact-sheet.png"
    if [[ -f "$contact" ]]; then
        print -r -- "Review/en-US_contact-sheet.png:$(/usr/bin/shasum -a 256 "$contact" | /usr/bin/awk '{ print $1 }')"
    else
        print -r -- "Review/en-US_contact-sheet.png:MISSING"
    fi
}

rollback_publication() {
    local index locale target backup rollback_root

    (( ${#touched_locales} > 0 )) || return 0
    print -u2 -r -- "Rolling back localized publication."
    rollback_root="$publish_root/rollback"
    /bin/mkdir -p -- "$rollback_root/Generated" "$rollback_root/Review"

    for (( index = ${#touched_locales}; index >= 1; index-- )); do
        locale=${touched_locales[$index]}

        target="$source_root/Generated/$locale"
        backup="$backup_root/Generated/$locale"
        if [[ -n ${generated_installed[$locale]-} && -d "$target" ]]; then
            /bin/mv -- "$target" "$rollback_root/Generated/$locale" 2>/dev/null || true
        fi
        if [[ -n ${generated_had_backup[$locale]-} && -d "$backup" ]]; then
            /bin/mv -- "$backup" "$target" 2>/dev/null || true
        fi

        target="$source_root/Review/${locale}_contact-sheet.png"
        backup="$backup_root/Review/${locale}_contact-sheet.png"
        if [[ -n ${contact_installed[$locale]-} && -f "$target" ]]; then
            /bin/mv -- "$target" "$rollback_root/Review/${locale}_contact-sheet.png" 2>/dev/null || true
        fi
        if [[ -n ${contact_had_backup[$locale]-} && -f "$backup" ]]; then
            /bin/mv -- "$backup" "$target" 2>/dev/null || true
        fi
    done
}

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM

    if (( exit_code != 0 && publishing == 1 && publish_complete == 0 )); then
        set +e
        rollback_publication
        set -e
    fi

    set +e
    [[ -z "$stage_root" ]] || remove_owned_tree "$stage_root"
    [[ -z "$publish_root" ]] || remove_owned_tree "$publish_root"
    [[ -z "$backup_root" ]] || remove_owned_tree "$backup_root"
    set -e

    exit $exit_code
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run)
            dry_run=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1 (use --help)."
            ;;
    esac
done

require_command /usr/bin/plutil
validate_manifests

if (( dry_run == 1 )); then
    print -r -- "Dry run only; no files will be written."
    print -r -- "Approved en-US outputs: excluded"
    print -r -- "Sequential storefront order: ${storefront_locales[*]}"
    for locale in "${storefront_locales[@]}"; do
        print -r -- "  $locale (${capture_locale[$locale]} captures) -> Generated/$locale + Review/${locale}_contact-sheet.png"
    done
    print -r -- "Final gate: exactly 120 screenshots (12 x 5 x 2) and 12 contact sheets."
    exit 0
fi

require_command swift
require_command /usr/bin/shasum
require_command /usr/bin/find
require_command /usr/bin/wc
require_command /usr/bin/tr
require_command /usr/bin/awk
validate_captures

readonly english_before=$(english_fingerprint)

stage_root=$(mktemp -d "${TMPDIR:-/tmp}/arrow-maze-localized-render.XXXXXX") \
    || die "Unable to create the /tmp render stage."
register_temp_path "$stage_root"
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

/bin/mkdir -p -- "$stage_root/Generated" "$stage_root/Review" "$stage_root/module-cache"

for locale in "${storefront_locales[@]}"; do
    log "Rendering $locale from ${capture_locale[$locale]} captures"
    swift -module-cache-path "$stage_root/module-cache" \
        "$renderer" \
        --locale "$locale" \
        --output-root "$stage_root/Generated/$locale" \
        --contact-sheet "$stage_root/Review/${locale}_contact-sheet.png"

    log "Validating $locale"
    swift -module-cache-path "$stage_root/module-cache" \
        "$renderer" \
        --locale "$locale" \
        --output-root "$stage_root/Generated/$locale" \
        --contact-sheet "$stage_root/Review/${locale}_contact-sheet.png" \
        --validate

    verify_locale_tree \
        "$stage_root/Generated" \
        "$stage_root/Review/${locale}_contact-sheet.png" \
        "$locale"
done

verify_complete_stage
[[ "$(english_fingerprint)" == "$english_before" ]] \
    || die "Approved en-US outputs changed during staging; refusing to publish."
log "All 12 locales passed staging validation; preparing publication transaction"

# Copy the complete validated stage beside the destination first. The actual
# target replacement below is then a same-filesystem rename with rollback.
publish_root=$(mktemp -d "$source_root/.localized-publish.XXXXXX") \
    || die "Unable to create the publication stage."
register_temp_path "$publish_root"
backup_root=$(mktemp -d "$source_root/.localized-backup.XXXXXX") \
    || die "Unable to create the publication backup."
register_temp_path "$backup_root"

/bin/mkdir -p -- \
    "$publish_root/Generated" \
    "$publish_root/Review" \
    "$backup_root/Generated" \
    "$backup_root/Review"

for locale in "${storefront_locales[@]}"; do
    /bin/cp -R -- \
        "$stage_root/Generated/$locale" \
        "$publish_root/Generated/$locale"
    /bin/cp -- \
        "$stage_root/Review/${locale}_contact-sheet.png" \
        "$publish_root/Review/${locale}_contact-sheet.png"
    verify_locale_tree \
        "$publish_root/Generated" \
        "$publish_root/Review/${locale}_contact-sheet.png" \
        "$locale"
done

publishing=1
for locale in "${storefront_locales[@]}"; do
    [[ "$locale" != "en-US" ]] \
        || die "Safety invariant failed immediately before publication."
    touched_locales+=("$locale")

    if [[ -d "$source_root/Generated/$locale" ]]; then
        /bin/mv -- \
            "$source_root/Generated/$locale" \
            "$backup_root/Generated/$locale"
        generated_had_backup[$locale]=1
    fi
    if [[ -f "$source_root/Review/${locale}_contact-sheet.png" ]]; then
        /bin/mv -- \
            "$source_root/Review/${locale}_contact-sheet.png" \
            "$backup_root/Review/${locale}_contact-sheet.png"
        contact_had_backup[$locale]=1
    fi

    /bin/mv -- \
        "$publish_root/Generated/$locale" \
        "$source_root/Generated/$locale"
    generated_installed[$locale]=1
    /bin/mv -- \
        "$publish_root/Review/${locale}_contact-sheet.png" \
        "$source_root/Review/${locale}_contact-sheet.png"
    contact_installed[$locale]=1
done

for locale in "${storefront_locales[@]}"; do
    verify_locale_tree \
        "$source_root/Generated" \
        "$source_root/Review/${locale}_contact-sheet.png" \
        "$locale"
done
[[ "$(english_fingerprint)" == "$english_before" ]] \
    || die "Approved en-US outputs changed during publication."

publish_complete=1
log "Published 12 storefronts: exactly 120 screenshots and 12 contact sheets."
log "Approved en-US outputs were not rendered or modified."
