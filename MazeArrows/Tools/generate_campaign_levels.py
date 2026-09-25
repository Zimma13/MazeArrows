#!/usr/bin/env python3
"""
Generate the 50-level story campaign for Maze Arrows.

The campaign grows from small/tutorial boards to larger dense boards while
keeping every level structurally valid and solvable by the same validator used
by the editor.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass

import build_levels as bl
import level_editor as editor


HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS_JSON = os.path.normpath(os.path.join(HERE, "..", "MazeArrows", "Data", "levels.json"))


@dataclass(frozen=True)
class CampaignSpec:
    index: int
    width: int
    height: int
    difficulty: str
    coverage: float
    bias: float
    style: str
    max_initial: int
    min_pieces: int
    lives: int
    name: str


NAMES = [
    "First Flow", "Small Turns", "Open Lane", "Tiny Hook", "Easy Loop",
    "Corner Run", "Little Spiral", "Side Steps", "Soft Lock", "Narrow Start",
    "Maze Sprout", "Cross Thread", "Pocket Path", "Inner Gate", "Stacked Turns",
    "Balanced Board", "Quiet Center", "Ribbon Walk", "Small Snare", "Roundabout",
    "Middle Knot", "Twin Routes", "Center Pull", "Measured Turns", "Thread Box",
    "Wide Weave", "Long Hook", "Dense Pocket", "Four Sides", "Path Cluster",
    "Tight Streets", "Hidden Outlet", "Spiral Push", "Blocked Core", "Knot Work",
    "Hard Weave", "Deep Center", "Edge Trap", "Crossed Roads", "Maze Lock",
    "Tall Puzzle", "Crowded Flow", "Late Exit", "Heavy Center", "Big Snare",
    "Grand Weave", "Master Path", "Final Threads", "Last Turn", "Maze Crown",
]


def grid_for(index: int) -> tuple[int, int]:
    if index <= 5:
        return 5, 7
    if index <= 10:
        return 6, 8
    if index <= 15:
        return 7, 9
    if index <= 20:
        return 8, 10
    if index <= 25:
        return 8, 11
    if index <= 30:
        return 9, 12
    if index <= 35:
        return 10, 13
    if index <= 40:
        return 10, 14
    if index <= 45:
        return 11, 15
    return 12, 16


def difficulty_for(index: int) -> str:
    if index <= 10:
        return "easy"
    if index <= 30:
        return "medium"
    return "hard"


def spec_for(index: int) -> CampaignSpec:
    width, height = grid_for(index)
    difficulty = difficulty_for(index)
    progress = (index - 1) / 49.0
    coverage = 0.40 + progress * 0.39
    bias = 0.22 + progress * 0.40

    if index <= 5:
        style = ["reference", "dense", "corridor", "spiral", "frame"][index % 5]
        max_initial = 2
        min_pieces = 4
        lives = 5
    elif index <= 10:
        style = ["dense", "corridor", "spiral", "reference", "frame"][index % 5]
        max_initial = 2
        min_pieces = 5
        lives = 5
    elif index <= 20:
        style = ["reference", "corridor", "spiral", "frame", "dense"][index % 5]
        max_initial = 2
        min_pieces = 7 + (index - 11) // 3
        lives = 4
    elif index <= 30:
        style = ["corridor", "spiral", "frame", "dense", "reference"][index % 5]
        max_initial = 2
        min_pieces = 11 + (index - 21) // 3
        lives = 4
    elif index <= 40:
        style = ["spiral", "frame", "corridor", "dense", "reference"][index % 5]
        max_initial = 2
        min_pieces = 14 + (index - 31) // 2
        lives = 3
    else:
        style = ["frame", "spiral", "corridor", "dense", "reference"][index % 5]
        max_initial = 2
        min_pieces = 18 + (index - 41) // 2
        lives = 2

    return CampaignSpec(
        index=index,
        width=width,
        height=height,
        difficulty=difficulty,
        coverage=round(coverage, 3),
        bias=round(bias, 3),
        style=style,
        max_initial=max_initial,
        min_pieces=min_pieces,
        lives=lives,
        name=NAMES[index - 1],
    )


def final_score(metrics: dict, spec: CampaignSpec) -> float:
    score = float(metrics["score"])
    initial = metrics["initialMovable"]
    if initial > spec.max_initial:
        score -= (initial - spec.max_initial) * 95.0
    if initial < 1:
        score -= 500.0
    if metrics["pieces"] < spec.min_pieces:
        score -= (spec.min_pieces - metrics["pieces"]) * 120.0
    else:
        score += min(metrics["pieces"] - spec.min_pieces, 4) * 18.0
    if metrics["density"] < spec.coverage * 0.90:
        score -= (spec.coverage * 0.90 - metrics["density"]) * 450.0
    score -= max(0.0, metrics["edgeRatio"] - 0.48) * 220.0
    score -= max(0.0, 0.22 - metrics["centerDensity"]) * 240.0
    score += metrics["blockedRatio"] * 80.0
    score += metrics["avgTurns"] * 18.0
    return score


def generate_one(spec: CampaignSpec) -> tuple[list[dict], dict]:
    best: tuple[float, list[dict], dict] | None = None
    attempts = 26 if spec.index >= 31 else 18

    for attempt in range(attempts):
        pieces, _, metrics = editor.smart_random_generate(
            spec.width,
            spec.height,
            spec.coverage,
            spec.bias,
            seed=f"campaign-v3:{spec.index}:{attempt}",
            style=spec.style,
            max_initial_movable=spec.max_initial,
            return_metrics=True,
        )
        if not pieces or not metrics["solvable"]:
            continue
        level = {
            "width": spec.width,
            "height": spec.height,
            "pieces": pieces,
            "obstacles": [],
        }
        if bl.validate_level(level) is not None:
            continue
        if metrics["pieces"] < max(3, spec.min_pieces - 3):
            continue
        if metrics["density"] < spec.coverage * 0.78:
            continue

        score = final_score(metrics, spec)
        if best is None or score > best[0]:
            best = (score, pieces, metrics)

    if best is None:
        raise RuntimeError(f"failed to generate level {spec.index}")

    return best[1], best[2]


def make_level(spec: CampaignSpec, pieces: list[dict]) -> dict:
    return {
        "id": f"level_{spec.index:03d}",
        "index": spec.index,
        "name": spec.name,
        "difficulty": spec.difficulty,
        "width": spec.width,
        "height": spec.height,
        "lives": spec.lives,
        "pieces": pieces,
        "threeStarMaxMistakes": 0,
        "twoStarMaxMistakes": max(1, len(pieces) // 6),
    }


def main() -> None:
    levels: list[dict] = []
    report: list[str] = []
    for index in range(1, 51):
        spec = spec_for(index)
        pieces, metrics = generate_one(spec)
        level = make_level(spec, pieces)
        err = bl.validate_level(level)
        if err is not None:
            raise RuntimeError(f"generated invalid level {index}: {err}")
        levels.append(level)
        report.append(
            f"{index:02d} {spec.width}x{spec.height} {spec.difficulty:<6} "
            f"pieces={len(pieces):02d} cells={metrics['cells']:03d} "
            f"start={metrics['initialMovable']:02d} density={metrics['density']:.2f} "
            f"min={spec.min_pieces:02d} "
            f"style={spec.style}"
        )
        print(report[-1], flush=True)

    with open(LEVELS_JSON, "w") as f:
        json.dump(levels, f, indent=2, sort_keys=True)
        f.write("\n")

    print(f"Wrote {len(levels)} levels to {LEVELS_JSON}")


if __name__ == "__main__":
    main()
