#!/bin/zsh
# Bakes the campaign catalog into the app's levels.json.
# Usage: ./bake.sh [output-path]
set -e
cd "$(dirname "$0")"
SRC="../../MazeArrows"
OUT="${1:-$SRC/Data/levels.json}"

swiftc -O -o .levelbaker \
  "$SRC/Models/GridPoint.swift" \
  "$SRC/Models/Direction.swift" \
  "$SRC/Models/ArrowPiece.swift" \
  "$SRC/Models/Board.swift" \
  "$SRC/Models/Obstacle.swift" \
  "$SRC/Models/Level.swift" \
  "$SRC/Models/Difficulty.swift" \
  "$SRC/Models/LevelGoal.swift" \
  "$SRC/Logic/SnakeFillGenerator.swift" \
  "$SRC/Logic/DifficultyConfig.swift" \
  "$SRC/Logic/LevelSolver.swift" \
  "$SRC/Logic/MoveValidator.swift" \
  "$SRC/Logic/LevelValidator.swift" \
  main.swift

./.levelbaker "$OUT"
