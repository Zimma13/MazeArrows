#!/bin/zsh

emulate -LR zsh
set -euo pipefail
unsetopt BG_NICE

export LC_ALL=C

readonly repo_root=${0:A:h:h:h:h}
readonly script_name=${0:t}
readonly default_output_root="$repo_root/AppStore/ScreenshotSources/_captures"
readonly expected_bundle_id="zimma.MazeArrows"
readonly ready_timeout_default=45
readonly render_settle_seconds=0.65
readonly screenshot_file_settle_seconds=0.35
readonly screenshot_attempt_limit=3

typeset -Ar profile_language=(
    de de
    es es
    es-MX es-MX
    fr fr
    ja ja
    ko ko
    pt-BR pt-BR
    zh-Hant zh-Hant
)

typeset -Ar profile_locale=(
    de de_DE
    es es_ES
    es-MX es_MX
    fr fr_FR
    ja ja_JP
    ko ko_KR
    pt-BR pt_BR
    zh-Hant zh_TW
)

typeset -ar default_profiles=(
    de es es-MX fr ja ko pt-BR zh-Hant
)

typeset -ar capture_scenes=(
    photo mechanic combo worlds daily quests
)

typeset -Ar capture_filename=(
    photo photo-game.png
    mechanic free-arrow.png
    combo combo.png
    worlds worlds.png
    daily daily.png
    quests quests.png
)

usage() {
    print -r -- "
Capture deterministic localized Arrow Maze App Store source screens.

Usage:
  $script_name --app-bundle PATH --iphone-udid UDID --ipad-udid UDID [options]

Required:
  --app-bundle PATH     Debug iOS Simulator MazeArrows.app bundle
  --iphone-udid UDID    Bootable 1320x2868 iPhone simulator
  --ipad-udid UDID      Bootable 2064x2752 iPad simulator

Options:
  --profile ID          Capture one profile; repeat for more profiles
                        IDs: ${default_profiles[*]}
  --output-root PATH    Capture root (default: $default_output_root)
  --ready-timeout SEC   Ready-marker timeout (default: $ready_timeout_default)
  --force               Atomically replace existing target PNGs
  --help                 Show this help

Without --profile, all eight non-English profiles are captured.
Both devices and all scenes are processed sequentially to keep CoreSimulator
and PNG decoding deterministic."
}

die() {
    print -u2 -r -- "capture_localized_screenshots: $*"
    exit 1
}

log() {
    local worker=$1
    shift
    print -r -- "[$worker] $*"
}

require_value() {
    local option=$1
    local count=$2
    (( count >= 2 )) || die "Missing value after $option."
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_udid() {
    local label=$1
    local value=$2
    [[ "$value" =~ ^[[:xdigit:]-]{20,}$ ]] \
        || die "$label must be an explicit simulator UDID, found: $value"
}

validate_capture_png() {
    local path=$1
    local expected_width=$2
    local expected_height=$3
    local info width height color_space

    info=$(/usr/bin/sips \
        -g pixelWidth \
        -g pixelHeight \
        -g space \
        "$path" 2>/dev/null) || return 1

    width=$(print -r -- "$info" | /usr/bin/awk '$1 == "pixelWidth:" { print $2 }')
    height=$(print -r -- "$info" | /usr/bin/awk '$1 == "pixelHeight:" { print $2 }')
    color_space=$(print -r -- "$info" | /usr/bin/awk '$1 == "space:" { print $2 }')

    [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] \
        || return 1
    [[ "$color_space" == "RGB" ]] \
        || return 1
    # sips can accept a valid PNG header while missing corruption later in an
    # IDAT stream. ImageMagick fully decodes the pixels without converting or
    # rewriting the capture, and returns non-zero for invalid adaptive filters.
    "$magick_path" identify "$path" >/dev/null 2>&1
}

app_bundle=""
iphone_udid=""
ipad_udid=""
output_root=$default_output_root
ready_timeout=$ready_timeout_default
force=0
typeset -a requested_profiles=()
typeset -A seen_profiles=()

while (( $# > 0 )); do
    case "$1" in
        --app-bundle)
            require_value "$1" $#
            app_bundle=$2
            shift 2
            ;;
        --iphone-udid)
            require_value "$1" $#
            iphone_udid=$2
            shift 2
            ;;
        --ipad-udid)
            require_value "$1" $#
            ipad_udid=$2
            shift 2
            ;;
        --profile)
            require_value "$1" $#
            profile=$2
            [[ -n ${profile_language[$profile]-} ]] \
                || die "Unknown profile '$profile'. Expected one of: ${default_profiles[*]}"
            [[ -z ${seen_profiles[$profile]-} ]] \
                || die "Profile '$profile' was supplied more than once."
            requested_profiles+=("$profile")
            seen_profiles[$profile]=1
            shift 2
            ;;
        --output-root)
            require_value "$1" $#
            output_root=$2
            shift 2
            ;;
        --ready-timeout)
            require_value "$1" $#
            ready_timeout=$2
            shift 2
            ;;
        --force)
            force=1
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

[[ -n "$app_bundle" ]] || die "--app-bundle is required."
[[ -n "$iphone_udid" ]] || die "--iphone-udid is required."
[[ -n "$ipad_udid" ]] || die "--ipad-udid is required."
[[ "$ready_timeout" =~ ^[1-9][0-9]*$ ]] \
    || die "--ready-timeout must be a positive integer."

validate_udid "--iphone-udid" "$iphone_udid"
validate_udid "--ipad-udid" "$ipad_udid"
[[ "$iphone_udid" != "$ipad_udid" ]] \
    || die "iPhone and iPad must use different simulator UDIDs."

app_bundle=${app_bundle:A}
output_root=${output_root:A}
[[ -d "$app_bundle" ]] || die "App bundle does not exist: $app_bundle"
[[ -f "$app_bundle/Info.plist" ]] || die "App bundle has no Info.plist: $app_bundle"
[[ "$output_root" != "/" ]] || die "Refusing to use / as the output root."

if (( ${#requested_profiles} == 0 )); then
    requested_profiles=("${default_profiles[@]}")
fi

require_command xcrun
require_command /usr/bin/sips
require_command /usr/bin/awk
require_command /usr/libexec/PlistBuddy
if [[ -x /opt/homebrew/bin/magick ]]; then
    magick_path=/opt/homebrew/bin/magick
elif magick_path=$(command -v magick 2>/dev/null); then
    magick_path=${magick_path:A}
else
    die "ImageMagick is required for full PNG integrity checks (magick identify)."
fi

bundle_id=$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleIdentifier' \
    "$app_bundle/Info.plist" 2>/dev/null) \
    || die "Unable to read CFBundleIdentifier from $app_bundle/Info.plist"
[[ "$bundle_id" == "$expected_bundle_id" ]] \
    || die "Unexpected bundle identifier '$bundle_id'; expected '$expected_bundle_id'."

typeset -a existing_outputs=()
for profile in "${requested_profiles[@]}"; do
    for device_folder in iPhone-6.9 iPad-13; do
        for scene in "${capture_scenes[@]}"; do
            destination="$output_root/$profile/$device_folder/${capture_filename[$scene]}"
            if [[ -e "$destination" && $force -eq 0 ]]; then
                existing_outputs+=("$destination")
            fi
        done
    done
done

if (( ${#existing_outputs} > 0 )); then
    print -u2 -r -- "Existing target files would be replaced:"
    for path in "${existing_outputs[@]}"; do
        print -u2 -r -- "  $path"
    done
    die "Re-run with --force only after reviewing the targets above."
fi

cleanup_worker() {
    [[ -z ${raw_png:-} ]] || /bin/rm -f -- "$raw_png"
    [[ -z ${destination_tmp:-} ]] || /bin/rm -f -- "$destination_tmp"
    if [[ -n ${worker_tmp:-} && -d "$worker_tmp" ]]; then
        /bin/rmdir "$worker_tmp" 2>/dev/null || true
    fi
    if [[ -n ${worker_udid:-} ]]; then
        xcrun simctl terminate "$worker_udid" "$bundle_id" >/dev/null 2>&1 || true
    fi
}

capture_device() {
    local worker_udid=$1
    local device_folder=$2
    local expected_width=$3
    local expected_height=$4
    local worker_tmp raw_png data_container marker
    local destination_tmp
    local profile language locale scene filename destination
    local launch_output marker_ready attempt max_attempts
    local screenshot_attempt screenshot_ready

    worker_tmp=$(mktemp -d "${TMPDIR:-/tmp}/arrow-maze-${device_folder}.XXXXXX") \
        || die "Unable to create a worker temp directory for $device_folder."
    raw_png="$worker_tmp/raw.png"
    trap cleanup_worker EXIT INT TERM

    log "$device_folder" "Booting simulator $worker_udid"
    xcrun simctl boot "$worker_udid" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$worker_udid" -b

    xcrun simctl terminate "$worker_udid" "$bundle_id" >/dev/null 2>&1 || true
    log "$device_folder" "Installing ${app_bundle:t} once"
    xcrun simctl install "$worker_udid" "$app_bundle"

    data_container=$(xcrun simctl get_app_container "$worker_udid" "$bundle_id" data)
    [[ -n "$data_container" && -d "$data_container" ]] \
        || die "Unable to resolve the app data container on $device_folder."

    max_attempts=$(( ready_timeout * 10 ))
    for profile in "${requested_profiles[@]}"; do
        language=${profile_language[$profile]}
        locale=${profile_locale[$profile]}

        for scene in "${capture_scenes[@]}"; do
            filename=${capture_filename[$scene]}
            destination="$output_root/$profile/$device_folder/$filename"
            destination_tmp=""

            marker="$data_container/Documents/ScreenshotCapture/$scene.ready"
            /bin/rm -f -- "$marker"

            log "$device_folder" "$profile: launching $scene"
            launch_output=$(xcrun simctl launch \
                --terminate-running-process \
                "$worker_udid" \
                "$bundle_id" \
                -AppleLanguages "($language)" \
                -AppleLocale "$locale" \
                --screenshot-scene "$scene" \
                --screenshot-hide-status-bar \
                --debug-reduce-motion)
            [[ -n "$launch_output" ]] \
                || die "The app did not launch for $device_folder/$profile/$scene."

            marker_ready=0
            for (( attempt = 1; attempt <= max_attempts; attempt++ )); do
                if [[ -f "$marker" ]]; then
                    marker_ready=1
                    break
                fi
                /bin/sleep 0.1
            done
            (( marker_ready == 1 )) \
                || die "Timed out after ${ready_timeout}s waiting for $device_folder/$profile/$scene."

            /bin/sleep "$render_settle_seconds"
            screenshot_ready=0
            for (( screenshot_attempt = 1; screenshot_attempt <= screenshot_attempt_limit; screenshot_attempt++ )); do
                /bin/rm -f -- "$raw_png"

                if ! xcrun simctl io "$worker_udid" screenshot "$raw_png"; then
                    log "$device_folder" "$profile/$scene: screenshot attempt $screenshot_attempt failed"
                    /bin/sleep "$screenshot_file_settle_seconds"
                    continue
                fi

                # CoreSimulator can return just before the PNG is fully
                # readable. Let the file settle, then decode it end-to-end
                # with ImageMagick before it can reach the capture folder. A
                # full-screen simctl PNG may legitimately use an RGBA
                # container; the final compositor renders it into RGB.
                /bin/sleep "$screenshot_file_settle_seconds"
                if ! validate_capture_png \
                    "$raw_png" \
                    "$expected_width" \
                    "$expected_height"; then
                    log "$device_folder" "$profile/$scene: raw PNG failed full integrity QA on attempt $screenshot_attempt"
                    continue
                fi

                screenshot_ready=1
                break
            done

            (( screenshot_ready == 1 )) \
                || die "Unable to capture a readable PNG after $screenshot_attempt_limit attempts for $device_folder/$profile/$scene."

            if [[ -e "$destination" && $force -eq 0 ]]; then
                die "Target appeared during capture; refusing to replace it: $destination"
            fi
            /bin/mkdir -p -- "${destination:h}"
            destination_tmp=$(mktemp "${destination:h}/.${filename}.XXXXXX") \
                || die "Unable to create an atomic staging file beside $destination."
            /bin/cp -- "$raw_png" "$destination_tmp"
            /bin/chmod 0644 "$destination_tmp"
            validate_capture_png "$destination_tmp" "$expected_width" "$expected_height" \
                || die "Atomic staging PNG failed QA: $destination_tmp"
            /bin/mv -f -- "$destination_tmp" "$destination"
            destination_tmp=""
            /bin/rm -f -- "$raw_png"
            log "$device_folder" "$profile: captured $filename"
        done
    done

    log "$device_folder" "Completed ${#requested_profiles} profile(s)"
    cleanup_worker
    trap - EXIT INT TERM
}

print -r -- "Capturing profiles: ${requested_profiles[*]}"
print -r -- "Output root: $output_root"

capture_device "$iphone_udid" iPhone-6.9 1320 2868
capture_device "$ipad_udid" iPad-13 2064 2752
print -r -- "Localized capture completed successfully."
