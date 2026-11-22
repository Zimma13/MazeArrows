#!/usr/bin/env python3
"""Capture the native app and render its localized 2.0 App Store screenshots."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess
import sys
import tempfile
import time

SOURCE = Path(__file__).resolve().parents[1]
V2 = SOURCE / "v2"
CONFIG = json.loads((V2 / "storefronts.json").read_text())
SETS = CONFIG["sets"]
DEVICES = {"iPhone-6.9": (1320, 2868), "iPad-13": (2064, 2752)}
ASC_DEVICE_TYPES = {"iPhone-6.9": "IPHONE_69", "iPad-13": "IPAD_PRO_3GEN_129"}
SCENES = {"photo": "photo-game", "mechanic": "free-arrow", "combo": "combo",
          "worlds": "worlds", "daily": "daily", "quests": "quests"}


def read_json(path):
    return json.loads(path.read_text())


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.chmod(handle.name, 0o644)
    os.replace(handle.name, path)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare_source_index(index, build, scenes, languages):
    if index["app"] == build:
        return index
    if not scenes:
        return {"app": build, "sets": {}}

    # A targeted refresh keeps each reused simulator image tied to the
    # binary and resources that actually produced it.
    old_build = index["app"]
    old_id = hashlib.sha256(json.dumps(old_build, sort_keys=True).encode()).hexdigest()
    index.setdefault("sourceBuilds", {})[old_id] = old_build
    for lang, entries in index["sets"].items():
        for scene, name in SCENES.items():
            entry = entries.get(name)
            if not entry:
                continue
            if lang in languages and scene in scenes:
                del entries[name]
            elif entry["origin"] == "2.0-simulator":
                entry.setdefault("sourceBuild", old_id)
    index["app"] = build
    return index


def inspect_png(path, device):
    with path.open("rb") as handle:
        header = handle.read(33)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG header: {path}")
    if struct.unpack(">II", header[16:24]) != DEVICES[device]:
        raise ValueError(f"Incorrect dimensions for {device}: {path}")


def checked(command):
    subprocess.run(command, check=True)


def capture(args):
    info = plistlib.loads((args.app / "Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != CONFIG["bundleID"] or info["CFBundleShortVersionString"] != CONFIG["appVersion"]:
        raise ValueError(f"Expected native {CONFIG['bundleID']} {CONFIG['appVersion']}")
    files = [args.app / info["CFBundleExecutable"], *sorted(args.app.glob("*.debug.dylib"))]
    visual_resources = sorted([*args.app.glob("*.lproj/*"), *args.app.glob("*.car"), *args.app.glob("*.json")])
    build = {"version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
             "binaries": {p.name: digest(p) for p in files},
             "resources": {str(p.relative_to(args.app)): digest(p) for p in visual_resources if p.is_file()}}
    ids = [("iPhone-6.9", args.iphone_udid), ("iPad-13", args.ipad_udid)]
    if not any(udid for _, udid in ids) or (args.iphone_udid and args.iphone_udid == args.ipad_udid):
        raise ValueError("Supply an explicit simulator UDID for each requested device")
    for device, udid in ids:
        if not udid:
            continue
        iphones_and_ipads = [d for ds in json.loads(subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "booted", "-j"]))["devices"].values() for d in ds]
        if not any(d["udid"] == udid and device.split("-")[0] in d["deviceTypeIdentifier"] for d in iphones_and_ipads):
            raise ValueError(f"Boot the assigned {device} simulator before capture: {udid}")
        root = V2 / "_captures" / device
        index_path = root / "sources.json"
        index = read_json(index_path) if index_path.exists() else {"app": build, "sets": {}}
        languages = args.sets or SETS
        index = prepare_source_index(index, build, args.scenes, languages)
        root.mkdir(parents=True, exist_ok=True)
        checked(["xcrun", "simctl", "install", udid, args.app])
        data = Path(subprocess.check_output(
            ["xcrun", "simctl", "get_app_container", udid, CONFIG["bundleID"], "data"], text=True).strip())
        with tempfile.TemporaryDirectory(dir=root, prefix=".capture-") as tmp:
            for lang in languages:
                profile = SETS[lang]
                entries = index["sets"].setdefault(lang, {})
                for scene in args.scenes or SCENES:
                    name = SCENES[scene]
                    if scene == "quests" and profile["questSource"]:
                        saved = SOURCE / "_captures" / profile["questSource"] / device / "quests.png"
                        inspect_png(saved, device)
                        entries[name] = {"source": str(saved.relative_to(SOURCE)), "sha256": digest(saved),
                                         "origin": "unchanged-v1-quest-screen"}
                        save_json(index_path, index)
                        continue
                    previous = entries.get(name)
                    if previous and "sourceBuild" not in previous and not args.force:
                        saved = SOURCE / previous["source"]
                        if saved.exists() and digest(saved) == previous["sha256"]:
                            continue
                    print(f"{device} {lang} {scene}", flush=True)
                    marker = data / "Documents" / "ScreenshotCapture" / (scene + ".ready")
                    marker.unlink(missing_ok=True)
                    checked(["xcrun", "simctl", "launch", "--terminate-running-process", udid, CONFIG["bundleID"],
                             "-AppleLanguages", f"({lang})", "-AppleLocale", profile["appleLocale"],
                             "--screenshot-scene", scene, "--screenshot-hide-status-bar", "--debug-reduce-motion"])
                    stop = time.monotonic() + 75
                    while not marker.exists() and time.monotonic() < stop:
                        time.sleep(0.15)
                    if not marker.exists():
                        raise RuntimeError(f"The debug capture harness did not confirm {device}/{lang}/{scene}")
                    time.sleep(0.7)
                    raw = Path(tmp) / "current.png"
                    for attempt in range(3):
                        raw.unlink(missing_ok=True)
                        checked(["xcrun", "simctl", "io", udid, "screenshot", raw])
                        try:
                            inspect_png(raw, device)
                            checked(["magick", "-regard-warnings", raw, "null:"])
                            break
                        except (OSError, ValueError, subprocess.CalledProcessError):
                            if attempt == 2:
                                raise
                            time.sleep(0.5)
                    image_hash = digest(raw)
                    saved = root / (image_hash + ".png")
                    if not saved.exists():
                        os.replace(raw, saved)
                    entries[name] = {"source": str(saved.relative_to(SOURCE)), "sha256": image_hash, "origin": "2.0-simulator"}
                    save_json(index_path, index)
        # Only content-addressed PNGs in this tool's own 2.0 capture store can
        # become obsolete. Completed partial batches retain other sets' files.
        used = {entry["source"] for entries in index["sets"].values() for entry in entries.values()}
        if all(len(index["sets"].get(lang, {})) == len(SCENES) for lang in SETS):
            reused_builds = {
                entry["sourceBuild"] for entries in index["sets"].values()
                for entry in entries.values() if "sourceBuild" in entry
            }
            if index.get("sourceBuilds"):
                index["sourceBuilds"] = {
                    key: value for key, value in index["sourceBuilds"].items() if key in reused_builds
                }
                save_json(index_path, index)
            for old in root.glob("*.png"):
                if len(old.stem) == 64 and str(old.relative_to(SOURCE)) not in used:
                    old.unlink()


def ordered_manifests():
    seen_storefronts = set()
    for lang, profile in SETS.items():
        labels = profile["storefronts"]
        if not labels or seen_storefronts.intersection(labels):
            raise ValueError(f"Non-unique storefront mapping at {lang}")
        seen_storefronts.update(labels)
        manifest = read_json(V2 / f"screenshots.{lang}.json")
        if manifest["locale"] != lang or len(manifest["slides"]) != 5:
            raise ValueError(f"Invalid screenshot manifest: {lang}")
        yield lang, manifest


def render(dry_run, slide_id):
    manifests = list(ordered_manifests())
    if dry_run:
        for lang, _ in manifests:
            print(f"{lang} -> {', '.join(SETS[lang]['storefronts'])}")
        return
    capture_indexes = {device: read_json(V2 / "_captures" / device / "sources.json") for device in DEVICES}
    if len({json.dumps(index["app"], sort_keys=True) for index in capture_indexes.values()}) != 1:
        raise ValueError("Capture both devices from the same native build")
    current = V2 / "Generated"
    if slide_id:
        validate(current)
        previous = read_json(current / "assets.json")
    with tempfile.TemporaryDirectory(dir=V2, prefix=".render-") as staging:
        work = Path(staging)
        binary = work / "render"
        checked(["swiftc", "-O", "-module-cache-path", work / "swift-cache", SOURCE / "render_english_screenshots.swift", "-o", binary])
        output = work / "Generated"
        assets = {"app": next(iter(capture_indexes.values()))["app"], "sets": {}}
        assets["captureIndexes"] = {device: f"../_captures/{device}/sources.json" for device in DEVICES}
        seen = {}
        for lang, manifest in manifests:
            raw = work / "resolved" / lang
            for device, data in capture_indexes.items():
                for name in SCENES.values():
                    entry = data["sets"][lang][name]
                    if "sourceBuild" in entry and entry["sourceBuild"] not in data.get("sourceBuilds", {}):
                        raise ValueError(f"Unknown capture build for {lang}/{device}/{name}")
                    src = SOURCE / entry["source"]
                    if digest(src) != entry["sha256"]:
                        raise ValueError(f"Capture checksum changed: {src}")
                    target = raw / device / (name + ".png")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.symlink_to(src)
            dest = work / "rendered" / lang
            contact = output / "Review" / (lang + ".png")
            print(f"Rendering {lang}", flush=True)
            if slide_id:
                for device in DEVICES:
                    folder = dest / device
                    folder.mkdir(parents=True, exist_ok=True)
                    prior_slides = previous["sets"][lang]["devices"][device]
                    for slide, prior in zip(manifest["slides"], prior_slides):
                        if slide["id"] != slide_id:
                            shutil.copyfile(current / prior["file"], folder / slide["filename"])
            checked([binary, "--locale", lang, "--manifest", V2 / f"screenshots.{lang}.json",
                     "--input-root", raw, "--output-root", dest, "--contact-sheet", contact,
                     *(["--slide", slide_id] if slide_id else [])])
            assets["sets"][lang] = {"storefronts": SETS[lang]["storefronts"], "devices": {}}
            for device in DEVICES:
                checked(["asc", "screenshots", "validate", "--path", dest / device, "--device-type", ASC_DEVICE_TYPES[device]])
                slots = []
                for slide in manifest["slides"]:
                    png = dest / device / slide["filename"]
                    key = digest(png)
                    if key not in seen:
                        relative = Path(lang) / device / slide["filename"]
                        (output / relative).parent.mkdir(parents=True, exist_ok=True)
                        png.replace(output / relative)
                        seen[key] = str(relative)
                    slots.append({"id": slide["id"], "file": seen[key], "sha256": key})
                assets["sets"][lang]["devices"][device] = slots
        save_json(output / "assets.json", assets)
        validate(output)
        backup = work / "previous"
        if current.exists():
            current.rename(backup)
        try:
            output.rename(current)
        except BaseException:
            if backup.exists():
                backup.rename(current)
            raise


def validate(output):
    manifest = read_json(output / "assets.json")
    if set(manifest["sets"]) != set(SETS):
        raise ValueError("Missing or unexpected language sets")
    used = {}
    for lang, expected in ordered_manifests():
        group = manifest["sets"][lang]
        if group["storefronts"] != SETS[lang]["storefronts"] or set(group["devices"]) != set(DEVICES):
            raise ValueError(f"Incorrect storefront or device mapping: {lang}")
        for device, slides in group["devices"].items():
            if [v["id"] for v in slides] != [v["id"] for v in expected["slides"]]:
                raise ValueError(f"Incorrect slide order: {lang}/{device}")
            for slide in slides:
                path = output / slide["file"]
                inspect_png(path, device)
                image_hash = digest(path)
                if image_hash != slide["sha256"] or used.setdefault(image_hash, path) != path:
                    raise ValueError(f"Duplicate output or incorrect checksum: {path}")
    files = set(output.glob("*/*/*.png"))
    if files != set(used.values()):
        raise ValueError("Unreferenced screenshot in package")
    print(f"Validated {len(SETS)} language sets and {len(files)} unique full-size PNGs.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    cap = sub.add_parser("capture")
    cap.add_argument("--app-bundle", required=True, type=Path, dest="app")
    cap.add_argument("--iphone-udid")
    cap.add_argument("--ipad-udid")
    cap.add_argument("--profile", action="append", choices=list(SETS), dest="sets")
    cap.add_argument("--scene", action="append", choices=list(SCENES), dest="scenes",
                     help="Refresh the named scene while preserving the existing captures of unchanged scenes.")
    cap.add_argument("--force", action="store_true")
    ren = sub.add_parser("render")
    ren.add_argument("--dry-run", action="store_true")
    ren.add_argument("--slide", dest="slide_id", help="Replace only this slide in the validated five-slide export.")
    sub.add_parser("validate")
    args = parser.parse_args()
    try:
        if args.action == "capture":
            capture(args)
        elif args.action == "render":
            render(args.dry_run, args.slide_id)
        else:
            validate(V2 / "Generated")
    except (OSError, KeyError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
