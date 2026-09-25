#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h:h:h}
app_root="$repo_root/MazeArrows/MazeArrows"
tool_root="$repo_root/AppStore/ScreenshotSources/Tools"
source_root="$repo_root/AppStore/ScreenshotSources"
binary_path="${TMPDIR:-/tmp}/maze-arrows-export-parrot-fixture"
verifier_path="${TMPDIR:-/tmp}/maze-arrows-verify-parrot-fixture"
preview_renderer_path="${TMPDIR:-/tmp}/maze-arrows-render-parrot-fixture-preview"
fixture_cache_root="${TMPDIR:-/tmp}/maze-arrows-fixture-module-cache"

mkdir -p "$fixture_cache_root"

if [[ ${1:-} != "--verify-only" ]]; then
    swiftc -O -parse-as-library \
        -module-cache-path "$fixture_cache_root" \
        "$app_root/Models/GridPoint.swift" \
        "$app_root/Models/Direction.swift" \
        "$app_root/Models/Difficulty.swift" \
        "$app_root/Models/PieceGroupPalette.swift" \
        "$app_root/Models/Obstacle.swift" \
        "$app_root/Models/LevelGoal.swift" \
        "$app_root/Models/ArrowPiece.swift" \
        "$app_root/Models/Board.swift" \
        "$app_root/Models/Level.swift" \
        "$app_root/Logic/MoveValidator.swift" \
        "$app_root/Logic/LevelSolver.swift" \
        "$app_root/Logic/SnakeFillGenerator.swift" \
        "$app_root/Logic/ImageBoardBuilder.swift" \
        "$app_root/Data/PhotoMazeBuildUpdate.swift" \
        "$app_root/Logic/PhotoMazeLevelBuilder.swift" \
        "$tool_root/export_parrot_fixture.swift" \
        -o "$binary_path"

    "$binary_path" \
        "$source_root/parrot-photo-maze-compact-v2.png" \
        "$source_root/source-data/parrot-level.json" \
        "$app_root/Debug/ScreenshotParrotFixture.swift"
fi

swiftc -O -D DEBUG -parse-as-library \
    -module-cache-path "$fixture_cache_root" \
    "$app_root/Models/GridPoint.swift" \
    "$app_root/Models/Direction.swift" \
    "$app_root/Models/Difficulty.swift" \
    "$app_root/Models/PieceGroupPalette.swift" \
    "$app_root/Models/Obstacle.swift" \
    "$app_root/Models/LevelGoal.swift" \
    "$app_root/Models/ArrowPiece.swift" \
    "$app_root/Models/Board.swift" \
    "$app_root/Models/Level.swift" \
    "$app_root/Logic/MoveValidator.swift" \
    "$app_root/Logic/LevelSolver.swift" \
    "$app_root/Debug/ScreenshotParrotFixture.swift" \
    "$tool_root/verify_parrot_fixture.swift" \
    -o "$verifier_path"

"$verifier_path"

swiftc -O -parse-as-library \
    -module-cache-path "$fixture_cache_root" \
    "$app_root/Models/GridPoint.swift" \
    "$app_root/Models/Direction.swift" \
    "$app_root/Models/Difficulty.swift" \
    "$app_root/Models/PieceGroupPalette.swift" \
    "$app_root/Models/Obstacle.swift" \
    "$app_root/Models/LevelGoal.swift" \
    "$app_root/Models/ArrowPiece.swift" \
    "$app_root/Models/Board.swift" \
    "$app_root/Models/Level.swift" \
    "$tool_root/render_parrot_fixture_preview.swift" \
    -o "$preview_renderer_path"

"$preview_renderer_path" \
    "$source_root/source-data/parrot-level.json" \
    "$source_root/source-data/parrot-level-preview.png"
