#!/usr/bin/env python3
"""
Maze Arrows — Редактор уровней (Tkinter).

Рисуй уровни кликом по клеткам. Живая проверка валидности и решаемости.
Сохранение: черновик (Tools/drafts/) или публикация в levels.json.

Запуск:  python3 Tools/level_editor.py
"""
from __future__ import annotations

import json
import os
import random
import sys
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk
from typing import Any

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_levels as bl  # noqa: E402

LEVELS_JSON = os.path.normpath(os.path.join(HERE, "..", "MazeArrows", "Data", "levels.json"))
DRAFTS_DIR = os.path.join(HERE, "drafts")

DEFAULT_CELL = 32
MIN_CELL = 14
MAX_CELL = 48
GRID_LINE = "#d8dee5"
GRID_BG = "#ffffff"
SELECTED_OUTLINE = "#ff3b30"
IN_PROGRESS_FILL = "#ffd166"
IN_PROGRESS_OUTLINE = "#e0a420"

PIECE_COLORS = [
    "#5b8def", "#ef7b7b", "#52c41a", "#fa8c16",
    "#9254de", "#13c2c2", "#eb2f96", "#fadb14",
    "#2f54eb", "#a0d911", "#fa541c", "#722ed1",
]

OBSTACLE_COLORS = {
    "wall":         "#4a4a4a",
    "gate":         "#1890ff",
    "portal":       "#722ed1",
    "ice":          "#91d5ff",
    "spring":       "#73d13d",
    "destructible": "#bfbfbf",
}

PIECE_KINDS = ["standard", "heavy", "fragile", "frozen", "double",
               "lockedLock", "lockedKey", "bomb", "chain"]
OBSTACLE_KINDS = ["wall", "gate", "portal", "ice", "spring", "destructible"]
DIRECTIONS = ["up", "down", "left", "right"]
DIFFICULTIES = ["easy", "medium", "hard"]
GOAL_KINDS = ["clearAll", "clearWithoutMistakes", "keysBeforeLocks",
              "noHints", "clearColorGroup", "freePiece", "clearInSeconds"]

GOAL_KIND_LABELS = {
    "clearAll":              "Очистить всё",
    "clearWithoutMistakes":  "Без ошибок",
    "keysBeforeLocks":       "Ключи до замков",
    "noHints":               "Без подсказок",
    "clearColorGroup":       "Очистить группу цвета",
    "freePiece":             "Освободить фигуру",
    "clearInSeconds":        "За N секунд",
}
GOAL_LABEL_TO_KIND = {v: k for k, v in GOAL_KIND_LABELS.items()}
GOAL_KIND_DISPLAY = [GOAL_KIND_LABELS[k] for k in GOAL_KINDS]

ARROW_GLYPH = {"up": "▲", "down": "▼", "left": "◀", "right": "▶"}


# ---------------------------------------------------------------------------
# Умный рандомный генератор уровней
# ---------------------------------------------------------------------------


_DIRS = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}


def _srg_exit_clear(head: tuple, dx: int, dy: int,
                    occupied: set, w: int, h: int) -> bool:
    """True если от head в направлении (dx,dy) до края нет занятых клеток."""
    nx, ny = head[0] + dx, head[1] + dy
    while 0 <= nx < w and 0 <= ny < h:
        if (nx, ny) in occupied:
            return False
        nx += dx
        ny += dy
    return True


def _srg_walk(rng: random.Random, min_len: int, max_len: int,
              occupied: set, w: int, h: int,
              straight_w: int = 3,
              require_exit_clear: bool = True,
              prefer_center: bool = False) -> tuple[list, str] | None:
    """
    Строит фигуру блуждающим путём.

    require_exit_clear: True → выход от головы должен быть свободен от occupied.
                        False → допустимо чтобы другие фигуры блокировали выход
                                (фигура разблокируется позже при решении).
    prefer_center: True → старт ближе к центру поля (для сложного центра).
    straight_w: вес «продолжить прямо» (выше → длиннее прямые участки).
    """
    free = [(x, y) for x in range(w) for y in range(h) if (x, y) not in occupied]
    if not free:
        return None

    # Выбор стартовой клетки
    if prefer_center and len(free) > 1:
        cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
        weights = [1.0 / (0.5 + ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5)
                   for x, y in free]
        total_w = sum(weights)
        r = rng.random() * total_w
        acc = 0.0
        start = free[-1]
        for pt, wt in zip(free, weights):
            acc += wt
            if acc >= r:
                start = pt
                break
    else:
        start = rng.choice(rng.sample(free, min(60, len(free))))

    cur_dx, cur_dy = rng.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
    cells = [start]
    cell_set = {start}
    target_len = rng.randint(min_len, max_len)

    for _ in range(target_len - 1):
        cx, cy = cells[-1]
        rev = (-cur_dx, -cur_dy)
        weighted: list = []
        for ddx, ddy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            if (ddx, ddy) == rev:
                continue
            nx, ny = cx + ddx, cy + ddy
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            if (nx, ny) in occupied or (nx, ny) in cell_set:
                continue
            wt = straight_w if (ddx, ddy) == (cur_dx, cur_dy) else 1
            weighted.extend([(ddx, ddy, nx, ny)] * wt)
        if not weighted:
            break
        ndx, ndy, nx, ny = rng.choice(weighted)
        cur_dx, cur_dy = ndx, ndy
        cells.append((nx, ny))
        cell_set.add((nx, ny))

    if len(cells) < 2:
        return None

    # Обрезаем хвост: убираем хвостовые клетки пока не выполнены оба условия:
    # 1) голова не смотрит сквозь своё СОБСТВЕННОЕ тело
    # 2) если require_exit_clear — выход свободен от других фигур
    while len(cells) >= 2:
        ldx = cells[-1][0] - cells[-2][0]
        ldy = cells[-1][1] - cells[-2][1]
        head = cells[-1]

        # Проверка собственного тела в выходном коридоре
        cell_set_now = set(cells)
        nx, ny = head[0] + ldx, head[1] + ldy
        self_blocked = False
        while 0 <= nx < w and 0 <= ny < h:
            if (nx, ny) in cell_set_now:
                self_blocked = True
                break
            nx += ldx
            ny += ldy
        if self_blocked:
            cells.pop()
            continue

        # Проверка выхода от чужих фигур (только если требуется)
        if require_exit_clear and not _srg_exit_clear(head, ldx, ldy, occupied, w, h):
            cells.pop()
            continue

        if len(cells) >= min_len:
            direction = next(d for d, (dx2, dy2) in _DIRS.items()
                             if (dx2, dy2) == (ldx, ldy))
            return cells, direction
        break

    return None


def _srg_direction_from_cells(cells: list[tuple[int, int]]) -> str | None:
    if len(cells) < 2:
        return None
    dx = cells[-1][0] - cells[-2][0]
    dy = cells[-1][1] - cells[-2][1]
    for direction, vec in _DIRS.items():
        if vec == (dx, dy):
            return direction
    return None


def _srg_turn_count(cells: list[tuple[int, int]]) -> int:
    turns = 0
    for i in range(1, len(cells) - 1):
        ax, ay = cells[i - 1]
        bx, by = cells[i]
        cx, cy = cells[i + 1]
        if (bx - ax, by - ay) != (cx - bx, cy - by):
            turns += 1
    return turns


def _srg_normalize(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    min_x = min(x for x, _ in cells)
    min_y = min(y for _, y in cells)
    return [(x - min_x, y - min_y) for x, y in cells]


def _srg_rotate(cells: list[tuple[int, int]], steps: int) -> list[tuple[int, int]]:
    out = cells
    for _ in range(steps % 4):
        out = [(-y, x) for x, y in out]
    return _srg_normalize(out)


def _srg_mirror(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    return _srg_normalize([(-x, y) for x, y in cells])


def _srg_template_variants(cells: list[tuple[int, int]]) -> list[list[tuple[int, int]]]:
    variants: list[list[tuple[int, int]]] = []
    seen: set[str] = set()
    for steps in range(4):
        rotated = _srg_rotate(cells, steps)
        for candidate in (rotated, _srg_mirror(rotated)):
            direction = _srg_direction_from_cells(candidate)
            if direction is None:
                continue
            if _srg_exit_hits_own_body(candidate, direction):
                continue
            key = "|".join(f"{x},{y}" for x, y in candidate) + "/" + direction
            if key not in seen:
                seen.add(key)
                variants.append(candidate)
    return variants


def _srg_exit_hits_own_body(cells: list[tuple[int, int]], direction: str | None = None) -> bool:
    if len(cells) < 2:
        return True
    direction = direction or _srg_direction_from_cells(cells)
    if direction is None:
        return True
    dx, dy = _DIRS[direction]
    hx, hy = cells[-1]
    body = set(cells[:-1])
    return any(
        (dy == 0 and y == hy and (x - hx) * dx > 0) or
        (dx == 0 and x == hx and (y - hy) * dy > 0)
        for x, y in body
    )


def _srg_piece(pid: str, cells: list[tuple[int, int]]) -> dict | None:
    direction = _srg_direction_from_cells(cells)
    if direction is None:
        return None
    if _srg_exit_hits_own_body(cells, direction):
        return None
    return {
        "id": pid,
        "direction": direction,
        "cells": [{"x": x, "y": y} for x, y in cells],
    }


def _srg_piece_cells(piece: dict) -> list[tuple[int, int]]:
    return [(c["x"], c["y"]) for c in piece["cells"]]


def _srg_spiral(cols: int, rows: int) -> list[tuple[int, int]]:
    left, top = 0, 0
    right, bottom = cols - 1, rows - 1
    path: list[tuple[int, int]] = []
    while left <= right and top <= bottom:
        for x in range(left, right + 1):
            path.append((x, top))
        top += 1
        for y in range(top, bottom + 1):
            path.append((right, y))
        right -= 1
        if top <= bottom:
            for x in range(right, left - 1, -1):
                path.append((x, bottom))
            bottom -= 1
        if left <= right:
            for y in range(bottom, top - 1, -1):
                path.append((left, y))
            left += 1
    return path


def _srg_template_library(w: int, h: int, long_bias: float,
                          style: str) -> list[tuple[list[tuple[int, int]], float]]:
    max_len = max(4, int((w + h) * (0.25 + long_bias * 0.45)))
    length_cap = 8 + int(long_bias * 8)
    length_cap = max(6, min(length_cap, max(6, int(min(w, h) * 0.85))))
    max_len = min(max_len, length_cap, max(4, w * h - 1))

    bases: list[tuple[list[tuple[int, int]], float, set[str]]] = []

    def add(cells: list[tuple[int, int]], weight: float, *tags: str) -> None:
        if len(cells) < 2 or len(cells) > max_len:
            return
        if len(set(cells)) != len(cells):
            return
        if _srg_direction_from_cells(cells) is None:
            return
        bases.append((cells, weight, set(tags)))

    # Straight corridors.
    for length in range(2, min(max_len, max(w, h)) + 1):
        weight = 1.0 + long_bias * length / 3.0
        add([(x, 0) for x in range(length)], weight, "line", "corridor")

    # L hooks and long hooks.
    for a in range(2, min(max_len, max(w, h)) + 1):
        for b in range(2, min(max_len - a + 2, max(w, h)) + 1):
            cells = [(0, y) for y in range(a)] + [(x, a - 1) for x in range(1, b)]
            add(cells, 2.5 + long_bias, "hook")

    # U / frame fragments.
    for cols in range(3, min(w, 7) + 1):
        for rows in range(3, min(h, 7) + 1):
            cells = ([(0, y) for y in range(rows)] +
                     [(x, rows - 1) for x in range(1, cols)] +
                     [(cols - 1, y) for y in range(rows - 2, -1, -1)])
            add(cells, 4.5, "frame", "u")

            open_box = ([(x, 0) for x in range(cols)] +
                        [(cols - 1, y) for y in range(1, rows)] +
                        [(x, rows - 1) for x in range(cols - 2, -1, -1)])
            add(open_box, 4.0, "frame")

    # S shapes and stairs.
    for cols in range(3, min(w, 8) + 1):
        cells = ([(x, 0) for x in range(cols)] +
                 [(cols - 1, 1)] +
                 [(x, 1) for x in range(cols - 2, -1, -1)] +
                 [(0, 2)] +
                 [(x, 2) for x in range(1, cols)])
        add(cells, 4.2, "snake", "corridor")

    for steps in range(3, min(8, max_len) + 1):
        cells = [(0, 0)]
        x, y = 0, 0
        for i in range(steps):
            x += 1
            cells.append((x, y))
            y += 1
            cells.append((x, y))
        add(cells, 2.8, "stair")

    # Compact spirals.
    for cols in range(3, min(w, 6) + 1):
        for rows in range(3, min(h, 6) + 1):
            add(_srg_spiral(cols, rows), 5.0, "spiral", "frame")

    style_weights = {
        "reference": {"line": 1.15, "corridor": 1.2, "hook": 1.25, "frame": 1.35,
                      "u": 1.2, "snake": 1.15, "spiral": 1.1, "stair": 0.9},
        "dense": {"line": 0.9, "corridor": 0.85, "hook": 1.25, "frame": 1.0,
                  "u": 1.0, "snake": 1.15, "spiral": 1.1, "stair": 1.25},
        "corridor": {"line": 1.7, "corridor": 1.8, "hook": 1.2, "frame": 0.95,
                     "u": 0.9, "snake": 1.35, "spiral": 0.55, "stair": 0.65},
        "spiral": {"line": 0.7, "corridor": 0.7, "hook": 1.0, "frame": 1.25,
                   "u": 1.15, "snake": 1.1, "spiral": 2.3, "stair": 0.8},
        "frame": {"line": 1.0, "corridor": 1.05, "hook": 1.1, "frame": 2.0,
                  "u": 1.8, "snake": 0.9, "spiral": 1.25, "stair": 0.6},
    }.get(style, {})

    weighted: list[tuple[list[tuple[int, int]], float]] = []
    seen: set[str] = set()
    for cells, weight, tags in bases:
        style_weight = 1.0
        for tag in tags:
            style_weight *= style_weights.get(tag, 1.0)
        for variant in _srg_template_variants(cells):
            key = "|".join(f"{x},{y}" for x, y in variant)
            if key in seen:
                continue
            seen.add(key)
            weighted.append((variant, max(0.1, weight * style_weight)))

    return weighted


def _srg_weighted_template(rng: random.Random,
                           templates: list[tuple[list[tuple[int, int]], float]]
                           ) -> list[tuple[int, int]]:
    total = sum(weight for _, weight in templates)
    pick = rng.random() * total
    acc = 0.0
    for cells, weight in templates:
        acc += weight
        if acc >= pick:
            return cells
    return templates[-1][0]


def _srg_exit_lane_cells(piece: dict, w: int, h: int) -> set[tuple[int, int]]:
    dx, dy = _DIRS[piece["direction"]]
    head = piece["cells"][-1]
    nx, ny = head["x"] + dx, head["y"] + dy
    lane: set[tuple[int, int]] = set()
    while 0 <= nx < w and 0 <= ny < h:
        lane.add((nx, ny))
        nx += dx
        ny += dy
    return lane


def _srg_block_count(cells: list[tuple[int, int]],
                     pieces: list[dict], w: int, h: int) -> int:
    cell_set = set(cells)
    return sum(1 for p in pieces if cell_set & _srg_exit_lane_cells(p, w, h))


def _srg_style_position_score(cells: list[tuple[int, int]], w: int, h: int,
                              style: str, phase: float) -> float:
    cx = sum(x for x, _ in cells) / len(cells)
    cy = sum(y for _, y in cells) / len(cells)
    board_cx = (w - 1) / 2.0
    board_cy = (h - 1) / 2.0
    center_dist = ((cx - board_cx) ** 2 + (cy - board_cy) ** 2) ** 0.5
    max_dist = max(1.0, ((board_cx) ** 2 + (board_cy) ** 2) ** 0.5)
    edge_dist = min(cx, cy, w - 1 - cx, h - 1 - cy)
    edge_cells = sum(1 for x, y in cells if x == 0 or y == 0 or x == w - 1 or y == h - 1)
    center_bonus = max(0.0, 10.0 * (1.0 - center_dist / max_dist))
    edge_penalty = edge_cells * 3.5

    if style == "frame":
        return max(0.0, 6.0 - edge_dist * 2.0) + center_bonus * 0.45 - edge_penalty * 0.45
    if style == "dense":
        return center_bonus * 1.25 - edge_penalty
    if style == "corridor":
        span_x = max(x for x, _ in cells) - min(x for x, _ in cells)
        span_y = max(y for _, y in cells) - min(y for _, y in cells)
        return max(span_x, span_y) * 1.2 + center_bonus * 0.7 - edge_penalty
    if style == "spiral":
        return center_bonus * 1.15 - edge_penalty * 0.8

    # Reference style: keep most structure in the middle third, with some openers outside.
    if phase < 0.70:
        return center_bonus * 1.15 - edge_penalty
    return center_bonus * 0.65 + max(0.0, 2.5 - edge_dist) - edge_penalty * 0.7


def _srg_distribution_metrics(pieces: list[dict], w: int, h: int) -> dict:
    occupied = {cell for p in pieces for cell in _srg_piece_cells(p)}
    if not occupied:
        return {"centerDensity": 0.0, "edgeRatio": 0.0, "bboxFill": 0.0}

    margin_x = max(1, w // 5)
    margin_y = max(1, h // 5)
    center_cells = {
        (x, y)
        for x in range(margin_x, max(margin_x + 1, w - margin_x))
        for y in range(margin_y, max(margin_y + 1, h - margin_y))
    }
    center_area = max(1, len(center_cells))
    center_density = len(occupied & center_cells) / center_area

    edge_count = sum(
        1 for x, y in occupied
        if x <= 1 or y <= 1 or x >= w - 2 or y >= h - 2
    )
    edge_ratio = edge_count / max(1, len(occupied))

    min_x = min(x for x, _ in occupied)
    max_x = max(x for x, _ in occupied)
    min_y = min(y for _, y in occupied)
    max_y = max(y for _, y in occupied)
    bbox_area = max(1, (max_x - min_x + 1) * (max_y - min_y + 1))
    bbox_fill = len(occupied) / bbox_area
    return {
        "centerDensity": round(center_density, 3),
        "edgeRatio": round(edge_ratio, 3),
        "bboxFill": round(bbox_fill, 3),
    }


def _srg_count_available(pieces: list[dict], w: int, h: int,
                         obstacles: list[dict] | None = None) -> int:
    obstacles = obstacles or []
    return sum(1 for p in pieces if bl.can_fly_out(p, pieces, obstacles, w, h, 0))


def _srg_analyze_pieces(pieces: list[dict], w: int, h: int,
                        target_coverage: float,
                        max_initial_movable: int | None = None,
                        obstacles: list[dict] | None = None) -> dict:
    obstacles = obstacles or []
    cells_count = sum(len(p["cells"]) for p in pieces)
    density = cells_count / max(1, w * h)
    initial_movable = _srg_count_available(pieces, w, h, obstacles)
    lvl = {"width": w, "height": h, "pieces": pieces, "obstacles": obstacles}
    order = bl.solve(lvl)
    is_solvable = bool(pieces) and order is not None

    lengths = [len(p["cells"]) for p in pieces]
    avg_len = sum(lengths) / max(1, len(lengths))
    short_count = sum(1 for v in lengths if v <= 2)
    long_count = sum(1 for v in lengths if v >= 6)
    turn_counts = [_srg_turn_count(_srg_piece_cells(p)) for p in pieces]
    avg_turns = sum(turn_counts) / max(1, len(turn_counts))
    distribution = _srg_distribution_metrics(pieces, w, h)

    dir_counts = {d: 0 for d in DIRECTIONS}
    for p in pieces:
        dir_counts[p["direction"]] = dir_counts.get(p["direction"], 0) + 1
    max_dir_ratio = max(dir_counts.values()) / max(1, len(pieces))

    branch_counts: list[int] = []
    if order:
        remaining = [dict(p) for p in pieces]
        for pid in order:
            branch_counts.append(_srg_count_available(remaining, w, h, obstacles))
            remaining = [p for p in remaining if p["id"] != pid]

    blocked_ratio = 0.0
    if pieces:
        blocked_ratio = (len(pieces) - initial_movable) / len(pieces)

    score = -1_000_000.0
    if order is not None and pieces:
        score = 0.0
        density_window = 0.18
        score += max(0.0, 1.0 - abs(density - target_coverage) / density_window) * 140.0

        desired_initial = max_initial_movable
        if desired_initial is None:
            desired_initial = 3 if w * h >= 120 else 4
        if 1 <= initial_movable <= desired_initial:
            score += 135.0 - initial_movable * 6.0
        else:
            score -= abs(initial_movable - desired_initial) * 28.0

        score += blocked_ratio * 120.0
        score += len(order) * 3.0
        score += min(avg_len, 8.0) * 7.0
        score += min(avg_turns, 2.2) * 26.0
        score += long_count * 4.0
        score += (1.0 - max_dir_ratio) * 55.0
        score += sum(1 for n in branch_counts if n <= desired_initial) * 3.0
        score += distribution["centerDensity"] * 130.0
        score += distribution["bboxFill"] * 55.0
        score -= max(0.0, distribution["edgeRatio"] - 0.32) * 180.0

        short_limit = max(2, len(pieces) // 5)
        if short_count > short_limit:
            score -= (short_count - short_limit) * 9.0
        if density < target_coverage * 0.72:
            score -= (target_coverage * 0.72 - density) * 220.0

    return {
        "score": round(score, 2),
        "solvable": is_solvable,
        "pieces": len(pieces),
        "cells": cells_count,
        "density": round(density, 3),
        "initialMovable": initial_movable,
        "blockedRatio": round(blocked_ratio, 3),
        "solutionLength": len(order) if order else 0,
        "avgLength": round(avg_len, 2),
        "avgTurns": round(avg_turns, 2),
        "shortPieces": short_count,
        "longPieces": long_count,
        "directions": dir_counts,
        "centerDensity": distribution["centerDensity"],
        "edgeRatio": distribution["edgeRatio"],
        "bboxFill": distribution["bboxFill"],
    }


def _srg_reverse_template_generate(w: int, h: int, coverage: float,
                                   long_bias: float, rng: random.Random,
                                   style: str,
                                   max_initial_movable: int | None,
                                   obstacles: list[dict] | None = None) -> list[dict]:
    templates = _srg_template_library(w, h, long_bias, style)
    if not templates:
        return []

    total = w * h
    target = max(4, int(total * coverage))
    obstacles = obstacles or []
    occupied: set[tuple[int, int]] = {
        (o["cell"]["x"], o["cell"]["y"]) for o in obstacles
    }
    pieces: list[dict] = []
    placed = 0
    pid_n = 1
    miss_budget = 900
    misses = 0

    while placed < target and misses < miss_budget:
        phase = min(1.0, placed / max(1, target))
        best_piece: dict | None = None
        best_score = -1_000_000.0

        for _ in range(48):
            base = _srg_weighted_template(rng, templates)
            max_x = max(x for x, _ in base)
            max_y = max(y for _, y in base)
            avail_x = w - max_x
            avail_y = h - max_y
            if avail_x <= 0 or avail_y <= 0:
                continue

            ox = rng.randrange(avail_x)
            oy = rng.randrange(avail_y)
            cells = [(x + ox, y + oy) for x, y in base]
            if any(c in occupied for c in cells):
                continue

            piece = _srg_piece(f"p{pid_n}", cells)
            if piece is None:
                continue
            if bl.validate_piece(piece, w, h) is not None:
                continue

            trial = pieces + [piece]
            if not bl.can_fly_out(piece, trial, obstacles, w, h, 0):
                continue

            blocks = _srg_block_count(cells, pieces, w, h)
            lane_len = len(_srg_exit_lane_cells(piece, w, h))
            available = _srg_count_available(trial, w, h, obstacles)
            turns = _srg_turn_count(cells)
            style_score = _srg_style_position_score(cells, w, h, style, phase)
            desired_initial = max_initial_movable or (3 if total >= 120 else 4)
            edge_cells = sum(
                1 for x, y in cells
                if x == 0 or y == 0 or x == w - 1 or y == h - 1
            )

            score = (
                blocks * 34.0
                + len(cells) * (2.0 + long_bias * 1.5)
                + min(turns, 4) * 7.0
                + style_score
                - max(0, available - desired_initial) * 4.0
                - edge_cells * 5.0
                + rng.random() * 2.0
            )
            if phase < 0.72:
                score += min(lane_len, 6) * 9.0
                if lane_len == 0:
                    score -= 140.0
                elif lane_len == 1:
                    score -= 45.0
            elif lane_len == 0:
                score += 8.0
            if placed > target * 0.25 and blocks == 0:
                score -= 12.0
            if score > best_score:
                best_score = score
                best_piece = piece

        if best_piece is None:
            misses += 1
            continue

        best_piece["id"] = f"p{pid_n}"
        pid_n += 1
        pieces.append(best_piece)
        for cell in _srg_piece_cells(best_piece):
            occupied.add(cell)
        placed += len(best_piece["cells"])
        misses = 0

    _srg_reduce_initial_moves(
        pieces=pieces,
        occupied=occupied,
        templates=templates,
        w=w,
        h=h,
        coverage=coverage,
        long_bias=long_bias,
        rng=rng,
        style=style,
        max_initial_movable=max_initial_movable,
        obstacles=obstacles,
        next_pid_n=pid_n,
    )

    # Keep ids stable and compact.
    for i, p in enumerate(pieces, 1):
        p["id"] = f"p{i}"
    return pieces


def _srg_reduce_initial_moves(pieces: list[dict],
                              occupied: set[tuple[int, int]],
                              templates: list[tuple[list[tuple[int, int]], float]],
                              w: int,
                              h: int,
                              coverage: float,
                              long_bias: float,
                              rng: random.Random,
                              style: str,
                              max_initial_movable: int | None,
                              obstacles: list[dict],
                              next_pid_n: int) -> None:
    desired = max_initial_movable or (3 if w * h >= 120 else 4)
    if desired < 1:
        desired = 1

    total_cells = w * h - len(obstacles)
    current_cells = sum(len(p["cells"]) for p in pieces)
    max_cells = min(total_cells, int((w * h) * min(0.78, coverage + 0.08)))
    if current_cells >= max_cells:
        return

    blocker_templates = [
        (cells, weight) for cells, weight in templates
        if len(cells) <= max(7, int((w + h) * (0.18 + long_bias * 0.20)))
    ] or templates

    pid_n = next_pid_n
    attempts_without_progress = 0
    while (_srg_count_available(pieces, w, h, obstacles) > desired
           and current_cells < max_cells
           and attempts_without_progress < 18):
        movable = [
            p for p in pieces
            if bl.can_fly_out(p, pieces, obstacles, w, h, 0)
        ]
        if len(movable) <= desired:
            break

        # Prefer blocking longer exposed lanes; those are visually obvious free moves.
        target_piece = max(
            movable,
            key=lambda p: (len(_srg_exit_lane_cells(p, w, h)), len(p["cells"]))
        )
        target_lane = _srg_exit_lane_cells(target_piece, w, h)
        if not target_lane:
            attempts_without_progress += 1
            continue

        best_piece: dict | None = None
        best_score = -1_000_000.0
        lane_cells = list(target_lane)
        for _ in range(80):
            base = _srg_weighted_template(rng, blocker_templates)
            max_x = max(x for x, _ in base)
            max_y = max(y for _, y in base)

            anchor = rng.choice(base)
            lane_anchor = rng.choice(lane_cells)
            ox = lane_anchor[0] - anchor[0]
            oy = lane_anchor[1] - anchor[1]
            if ox < 0 or oy < 0 or ox + max_x >= w or oy + max_y >= h:
                continue
            cells = [(x + ox, y + oy) for x, y in base]
            if any(c in occupied for c in cells):
                continue
            if not (set(cells) & target_lane):
                continue
            if current_cells + len(cells) > max_cells:
                continue

            piece = _srg_piece(f"p{pid_n}", cells)
            if piece is None or bl.validate_piece(piece, w, h) is not None:
                continue

            trial = pieces + [piece]
            if not bl.can_fly_out(piece, trial, obstacles, w, h, 0):
                continue

            blocks = _srg_block_count(cells, pieces, w, h)
            lane_len = len(_srg_exit_lane_cells(piece, w, h))
            if lane_len == 0 and blocks < 2:
                continue
            available_after = _srg_count_available(trial, w, h, obstacles)
            edge_cells = sum(
                1 for x, y in cells
                if x == 0 or y == 0 or x == w - 1 or y == h - 1
            )
            score = (
                130.0
                + blocks * 42.0
                + min(_srg_turn_count(cells), 3) * 8.0
                + len(cells) * (1.5 + long_bias)
                + min(lane_len, 5) * 8.0
                + _srg_style_position_score(cells, w, h, style, 1.0)
                - max(0, available_after - desired) * 16.0
                - edge_cells * 5.0
                + rng.random()
            )
            if available_after < _srg_count_available(pieces, w, h, obstacles):
                score += 70.0
            if score > best_score:
                best_score = score
                best_piece = piece

        if best_piece is None:
            attempts_without_progress += 1
            continue

        before = _srg_count_available(pieces, w, h, obstacles)
        best_piece["id"] = f"p{pid_n}"
        pid_n += 1
        pieces.append(best_piece)
        for cell in _srg_piece_cells(best_piece):
            occupied.add(cell)
        current_cells += len(best_piece["cells"])
        after = _srg_count_available(pieces, w, h, obstacles)
        attempts_without_progress = 0 if after < before else attempts_without_progress + 1


def _srg_walk_generate(w: int, h: int, coverage: float,
                       long_bias: float, rng: random.Random,
                       obstacles: list[dict] | None = None) -> list[dict]:
    total = w * h
    target = max(4, int(total * coverage))

    min_len = 2
    base = (w + h) // 2
    max_len = max(3, int(base * (0.25 + long_bias * 0.75)))
    max_len = min(max_len, total - 1)

    straight_w = max(1, int(1 + long_bias * 5))

    obstacles = obstacles or []
    occupied: set = {(o["cell"]["x"], o["cell"]["y"]) for o in obstacles}
    pieces: list = []
    placed = 0
    pid_n = 1
    MAX_FAILS = 500

    center_target = int(target * 0.60)
    fails = 0
    while placed < center_target and fails < MAX_FAILS:
        result = _srg_walk(rng, min_len, max_len, occupied, w, h,
                           straight_w=straight_w,
                           require_exit_clear=False,
                           prefer_center=True)
        if result is None:
            fails += 1
            continue
        cells, direction = result
        pid = f"p{pid_n}"; pid_n += 1
        pieces.append({"id": pid, "direction": direction,
                       "cells": [{"x": x, "y": y} for x, y in cells]})
        for c in cells:
            occupied.add(c)
        placed += len(cells)
        fails = 0

    fails = 0
    while placed < target and fails < MAX_FAILS:
        result = _srg_walk(rng, min_len, max_len, occupied, w, h,
                           straight_w=straight_w,
                           require_exit_clear=True,
                           prefer_center=False)
        if result is None:
            fails += 1
            continue
        cells, direction = result
        pid = f"p{pid_n}"; pid_n += 1
        pieces.append({"id": pid, "direction": direction,
                       "cells": [{"x": x, "y": y} for x, y in cells]})
        for c in cells:
            occupied.add(c)
        placed += len(cells)
        fails = 0

    lvl: dict = {"width": w, "height": h, "pieces": pieces, "obstacles": obstacles}
    max_cleanup = max(0, len(pieces) // 3)

    for _ in range(max_cleanup):
        if bl.solve(lvl) is not None:
            break
        remaining = lvl["pieces"]
        stuck = [p for p in remaining
                 if not bl.can_fly_out(p, remaining, [], w, h, 0)]
        if not stuck:
            stuck = remaining
        to_remove = min(stuck, key=lambda p: len(p["cells"]))
        lvl["pieces"].remove(to_remove)

    pieces = lvl["pieces"]
    if bl.solve({"width": w, "height": h, "pieces": pieces, "obstacles": obstacles}) is None:
        return []

    for i, p in enumerate(pieces, 1):
        p["id"] = f"p{i}"
    return pieces


def smart_random_generate(w: int, h: int, coverage: float,
                          long_bias: float, seed=None,
                          style: str = "reference",
                          max_initial_movable: int | None = None,
                          return_metrics: bool = False,
                          obstacles: list[dict] | None = None) -> tuple:
    """
    Генерирует уровень для редактора.

    По умолчанию используется reverse-build: каждая новая фигура обязана
    вылетать после уже добавленных, поэтому итоговый уровень имеет
    гарантированный порядок решения. Старое блуждание оставлено как стиль
    "walk" для сравнения.
    """
    rng = random.Random(seed)
    style = style or "reference"
    obstacles = obstacles or []
    if style == "walk":
        pieces = _srg_walk_generate(w, h, coverage, long_bias, rng, obstacles)
    else:
        pieces = _srg_reverse_template_generate(
            w, h, coverage, long_bias, rng, style, max_initial_movable, obstacles
        )

    metrics = _srg_analyze_pieces(pieces, w, h, coverage, max_initial_movable, obstacles)
    if not metrics["solvable"]:
        pieces = []
        metrics = _srg_analyze_pieces(pieces, w, h, coverage, max_initial_movable, obstacles)

    if return_metrics:
        return pieces, len(pieces) + 1, metrics
    return pieces, len(pieces) + 1


# ---------------------------------------------------------------------------
# Состояние редактора
# ---------------------------------------------------------------------------

class State:
    def __init__(self) -> None:
        self.width = 10
        self.height = 14
        self.lives = 5
        self.pieces: list[dict] = []
        self.obstacles: list[dict] = []
        self.goal: dict | None = None
        self.name: str = ""
        self.difficulty: str = "medium"
        self.index: int = 51
        self.three_star: int = 0
        self.two_star: int = 1
        self.next_pid_n = 1
        self.next_oid_n = 1

    def as_level_dict(self) -> dict:
        out: dict[str, Any] = {
            "id": f"level_{self.index:03d}",
            "index": self.index,
            "difficulty": self.difficulty,
            "width": self.width,
            "height": self.height,
            "lives": self.lives,
            "pieces": [dict(p) for p in self.pieces],
            "threeStarMaxMistakes": self.three_star,
            "twoStarMaxMistakes": self.two_star,
        }
        if self.name:
            out["name"] = self.name
        if self.obstacles:
            out["obstacles"] = [dict(o) for o in self.obstacles]
        if self.goal:
            out["goal"] = dict(self.goal)
        return out

    @classmethod
    def from_level_dict(cls, lvl: dict) -> "State":
        s = cls()
        s.width = lvl["width"]
        s.height = lvl["height"]
        s.lives = lvl.get("lives", 5)
        s.name = lvl.get("name", "")
        s.difficulty = lvl.get("difficulty", "medium")
        s.index = lvl.get("index", 51)
        s.three_star = lvl.get("threeStarMaxMistakes", 0)
        s.two_star = lvl.get("twoStarMaxMistakes", 1)
        s.pieces = [dict(p) for p in lvl.get("pieces", [])]
        s.obstacles = [dict(o) for o in lvl.get("obstacles", [])]
        s.goal = dict(lvl["goal"]) if "goal" in lvl else None
        for p in s.pieces:
            pid = p["id"]
            if pid.startswith("p") and pid[1:].isdigit():
                s.next_pid_n = max(s.next_pid_n, int(pid[1:]) + 1)
        for o in s.obstacles:
            oid = o["id"]
            if oid.startswith("o") and oid[1:].isdigit():
                s.next_oid_n = max(s.next_oid_n, int(oid[1:]) + 1)
        return s


# ---------------------------------------------------------------------------
# Приложение
# ---------------------------------------------------------------------------

class EditorApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Maze Arrows — Редактор уровней")

        self.state = State()
        self.cell = DEFAULT_CELL

        self.mode: str = "piece"
        self.selected_id: str | None = None
        self.selected_kind: str | None = None  # 'piece' | 'obstacle'
        self.current_piece: dict | None = None

        self._validate_token = 0
        self._solve_thread: threading.Thread | None = None
        self._solve_lock = threading.Lock()
        self._after_id: str | None = None

        self._build_ui()
        self._redraw()
        self._schedule_validate()

    # ------------------------------------------------------------------ UI

    def _build_ui(self) -> None:
        root = self.root
        root.geometry("1280x900")
        root.minsize(900, 600)

        # Меню
        menubar = tk.Menu(root)
        filem = tk.Menu(menubar, tearoff=0)
        filem.add_command(label="Новый уровень", command=self._cmd_new, accelerator="⌘N")
        filem.add_command(label="Открыть черновик…", command=self._cmd_open_draft, accelerator="⌘O")
        filem.add_command(label="Открыть из levels.json…", command=self._cmd_open_from_main)
        filem.add_separator()
        filem.add_command(label="Сохранить черновик", command=self._cmd_save_draft, accelerator="⌘S")
        filem.add_command(label="Сохранить черновик как…", command=lambda: self._cmd_save_draft(ask=True))
        filem.add_command(label="Опубликовать в levels.json", command=self._cmd_publish)
        menubar.add_cascade(label="Файл", menu=filem)
        root.config(menu=menubar)
        root.bind("<Command-n>", lambda e: self._cmd_new())
        root.bind("<Command-o>", lambda e: self._cmd_open_draft())
        root.bind("<Command-s>", lambda e: self._cmd_save_draft())

        bar = ttk.Frame(root, padding=(8, 6))
        bar.pack(side=tk.TOP, fill=tk.X)
        self._build_toolbar(bar)

        main = ttk.PanedWindow(root, orient=tk.HORIZONTAL)
        main.pack(side=tk.TOP, fill=tk.BOTH, expand=True, padx=8, pady=(0, 4))

        canvas_wrap = ttk.Frame(main)
        main.add(canvas_wrap, weight=4)

        side = ttk.Frame(main, padding=8)
        main.add(side, weight=1)

        self._build_canvas(canvas_wrap)
        self._build_sidebar(side)

        # Статус-бар
        status = ttk.Frame(root, padding=(8, 4))
        status.pack(side=tk.BOTTOM, fill=tk.X)
        self.status_dot = tk.Canvas(status, width=14, height=14, highlightthickness=0)
        self.status_dot.pack(side=tk.LEFT, padx=(0, 6))
        self.status_dot.create_oval(2, 2, 12, 12, fill="#888", outline="", tags="dot")
        self.status_label = ttk.Label(status, text="Ожидание")
        self.status_label.pack(side=tk.LEFT)
        self.stats_label = ttk.Label(status, text="")
        self.stats_label.pack(side=tk.RIGHT)
        self.coord_label = ttk.Label(status, text="", foreground="#888", width=10)
        self.coord_label.pack(side=tk.RIGHT, padx=(0, 16))

        # Клавиатура
        root.bind("<Escape>", lambda e: self._cancel_current_piece())
        root.bind("<Return>", lambda e: self._finish_current_piece())
        root.bind("<KP_Enter>", lambda e: self._finish_current_piece())
        root.bind("<BackSpace>", lambda e: self._delete_selected())
        root.bind("<Delete>", lambda e: self._delete_selected())

    def _build_toolbar(self, parent: ttk.Frame) -> None:
        row = ttk.Frame(parent)
        row.pack(side=tk.TOP, fill=tk.X)

        ttk.Label(row, text="Ш:").pack(side=tk.LEFT)
        self.var_w = tk.IntVar(value=self.state.width)
        ttk.Spinbox(row, from_=4, to=60, width=4, textvariable=self.var_w,
                    command=self._on_size_changed).pack(side=tk.LEFT, padx=(2, 8))

        ttk.Label(row, text="В:").pack(side=tk.LEFT)
        self.var_h = tk.IntVar(value=self.state.height)
        ttk.Spinbox(row, from_=4, to=60, width=4, textvariable=self.var_h,
                    command=self._on_size_changed).pack(side=tk.LEFT, padx=(2, 8))

        ttk.Label(row, text="Ячейка:").pack(side=tk.LEFT)
        self.var_cell = tk.IntVar(value=self.cell)
        ttk.Spinbox(row, from_=MIN_CELL, to=MAX_CELL, increment=2, width=4,
                    textvariable=self.var_cell, command=self._on_cell_changed).pack(side=tk.LEFT, padx=(2, 2))
        ttk.Button(row, text="−", width=2, command=self._zoom_out).pack(side=tk.LEFT, padx=1)
        ttk.Button(row, text="+", width=2, command=self._zoom_in).pack(side=tk.LEFT, padx=1)
        ttk.Button(row, text="⊡ Вписать", command=self._zoom_fit).pack(side=tk.LEFT, padx=(4, 16))

        ttk.Label(row, text="Жизни:").pack(side=tk.LEFT)
        self.var_lives = tk.IntVar(value=self.state.lives)
        ttk.Spinbox(row, from_=1, to=99, width=4, textvariable=self.var_lives,
                    command=self._on_lives_changed).pack(side=tk.LEFT, padx=(2, 16))

        ttk.Label(row, text="Индекс:").pack(side=tk.LEFT)
        self.var_index = tk.IntVar(value=self.state.index)
        ttk.Spinbox(row, from_=1, to=999, width=5, textvariable=self.var_index,
                    command=self._on_index_changed).pack(side=tk.LEFT, padx=(2, 16))

        ttk.Label(row, text="Название:").pack(side=tk.LEFT)
        self.var_name = tk.StringVar(value=self.state.name)
        ent = ttk.Entry(row, textvariable=self.var_name, width=18)
        ent.pack(side=tk.LEFT, padx=(2, 16))
        ent.bind("<KeyRelease>", lambda e: self._on_name_changed())

        ttk.Label(row, text="Сложность:").pack(side=tk.LEFT)
        self.var_diff = tk.StringVar(value=self.state.difficulty)
        cb = ttk.Combobox(row, textvariable=self.var_diff, values=DIFFICULTIES,
                          width=8, state="readonly")
        cb.pack(side=tk.LEFT, padx=(2, 8))
        cb.bind("<<ComboboxSelected>>", lambda e: self._on_diff_changed())

        # Режимы
        row2 = ttk.Frame(parent)
        row2.pack(side=tk.TOP, fill=tk.X, pady=(6, 0))

        ttk.Label(row2, text="Режим:").pack(side=tk.LEFT)
        self.mode_var = tk.StringVar(value="piece")
        modes = [
            ("Фигура", "piece"),
            ("Стена", "wall"),
            ("Ворота", "gate"),
            ("Портал", "portal"),
            ("Лёд", "ice"),
            ("Пружина", "spring"),
            ("Разрушаемое", "destructible"),
            ("Ластик", "eraser"),
        ]
        for label, val in modes:
            rb = ttk.Radiobutton(row2, text=label, value=val,
                                 variable=self.mode_var, command=self._on_mode_changed)
            rb.pack(side=tk.LEFT, padx=2)

        ttk.Separator(row2, orient=tk.VERTICAL).pack(side=tk.LEFT, fill=tk.Y, padx=8)

        ttk.Button(row2, text="Зафиксировать (↵)",
                   command=self._finish_current_piece).pack(side=tk.LEFT, padx=2)
        ttk.Button(row2, text="Отмена (Esc)",
                   command=self._cancel_current_piece).pack(side=tk.LEFT, padx=2)
        ttk.Button(row2, text="Удалить (⌫)",
                   command=self._delete_selected).pack(side=tk.LEFT, padx=2)

        ttk.Separator(row2, orient=tk.VERTICAL).pack(side=tk.LEFT, fill=tk.Y, padx=8)
        ttk.Button(row2, text="🎲 Умный рандом",
                   command=self._cmd_smart_random).pack(side=tk.LEFT, padx=2)
        ttk.Button(row2, text="🗑 Очистить поле",
                   command=self._cmd_clear_board).pack(side=tk.LEFT, padx=2)

    def _build_canvas(self, parent: ttk.Frame) -> None:
        self.cframe = ttk.Frame(parent)
        self.cframe.pack(fill=tk.BOTH, expand=True)

        self.canvas = tk.Canvas(self.cframe, bg=GRID_BG, highlightthickness=0)
        hbar = ttk.Scrollbar(self.cframe, orient=tk.HORIZONTAL, command=self.canvas.xview)
        vbar = ttk.Scrollbar(self.cframe, orient=tk.VERTICAL, command=self.canvas.yview)
        self.canvas.configure(xscrollcommand=hbar.set, yscrollcommand=vbar.set)

        self.canvas.grid(row=0, column=0, sticky="nsew")
        vbar.grid(row=0, column=1, sticky="ns")
        hbar.grid(row=1, column=0, sticky="ew")
        self.cframe.rowconfigure(0, weight=1)
        self.cframe.columnconfigure(0, weight=1)

        self.canvas.bind("<Button-1>", self._on_click)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.canvas.bind("<Motion>", self._on_mouse_move)
        self.canvas.bind("<Command-MouseWheel>", self._on_zoom)
        self.canvas.bind("<Control-MouseWheel>", self._on_zoom)
        self._drag_active = False
        self._drag_cell: tuple[int, int] | None = None

    def _build_sidebar(self, parent: ttk.Frame) -> None:
        # === Цель ===
        ttk.Label(parent, text="Цель", font=("", 12, "bold")).pack(anchor="w")
        gframe = ttk.Frame(parent)
        gframe.pack(fill=tk.X, pady=(2, 12))

        _init_goal = self.state.goal["kind"] if self.state.goal else "clearAll"
        self.var_goal_kind = tk.StringVar(value=GOAL_KIND_LABELS.get(_init_goal, _init_goal))
        cb = ttk.Combobox(gframe, textvariable=self.var_goal_kind, values=GOAL_KIND_DISPLAY,
                          state="readonly", width=22)
        cb.pack(side=tk.TOP, fill=tk.X)
        cb.bind("<<ComboboxSelected>>", lambda e: self._on_goal_changed())

        self.var_goal_value = tk.StringVar(value=str(self.state.goal.get("value", "")) if self.state.goal else "")
        self.goal_value_entry = ttk.Entry(gframe, textvariable=self.var_goal_value)
        self.goal_value_entry.pack(side=tk.TOP, fill=tk.X, pady=(4, 0))
        self.goal_value_entry.bind("<KeyRelease>", lambda e: self._on_goal_changed())

        # === Звёзды ===
        ttk.Label(parent, text="Пороги звёзд", font=("", 12, "bold")).pack(anchor="w")
        sframe = ttk.Frame(parent)
        sframe.pack(fill=tk.X, pady=(2, 12))
        ttk.Label(sframe, text="3★ макс. ошибок:").grid(row=0, column=0, sticky="w")
        self.var_3star = tk.IntVar(value=self.state.three_star)
        ttk.Spinbox(sframe, from_=0, to=20, width=4, textvariable=self.var_3star,
                    command=self._on_stars_changed).grid(row=0, column=1, sticky="e")
        ttk.Label(sframe, text="2★ макс. ошибок:").grid(row=1, column=0, sticky="w")
        self.var_2star = tk.IntVar(value=self.state.two_star)
        ttk.Spinbox(sframe, from_=0, to=20, width=4, textvariable=self.var_2star,
                    command=self._on_stars_changed).grid(row=1, column=1, sticky="e")
        sframe.columnconfigure(0, weight=1)

        ttk.Separator(parent, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=4)

        # === Свойства выбранного ===
        ttk.Label(parent, text="Выбрано", font=("", 12, "bold")).pack(anchor="w")
        self.props_frame = ttk.Frame(parent)
        self.props_frame.pack(fill=tk.X, pady=(2, 12))
        self._build_props_panel(empty=True)

        ttk.Separator(parent, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=4)

        # === Подсказки ===
        ttk.Label(parent, text="Подсказки", font=("", 12, "bold")).pack(anchor="w")
        legend = (
            "• Режим «Фигура»: клик + тащи по клеткам.\n"
            "• Направление = последний сегмент тела.\n"
            "• Клик на пустую клетку — новая фигура.\n"
            "• ↵ или кнопка «Зафиксировать» — готово.\n"
            "• Esc — отмена текущей фигуры.\n"
            "• Клик на фигуру/препятствие — выделить.\n"
            "• Режимы препятствий: клик ставит объект.\n"
            "• Ластик: клик удаляет что угодно.\n"
            "• ⌘+прокрутка — зум сетки."
        )
        ttk.Label(parent, text=legend, justify="left", foreground="#666").pack(anchor="w")

    def _build_props_panel(self, empty: bool = False) -> None:
        for w in self.props_frame.winfo_children():
            w.destroy()

        if empty or self.selected_id is None:
            ttk.Label(self.props_frame, text="— ничего не выбрано —",
                      foreground="#888").pack(anchor="w")
            return

        if self.selected_kind == "obstacle":
            ob = next((o for o in self.state.obstacles if o["id"] == self.selected_id), None)
            if ob is None:
                return
            ttk.Label(self.props_frame, text=f"Препятствие: {ob['id']}", font=("", 11, "bold")).pack(anchor="w")
            ttk.Label(self.props_frame, text=f"Тип: {ob['kind']}").pack(anchor="w")
            ttk.Label(self.props_frame, text=f"Клетка: ({ob['cell']['x']}, {ob['cell']['y']})").pack(anchor="w")
            if ob["kind"] == "gate":
                gv = tk.StringVar(value=ob.get("parameter", "right"))
                ttk.Label(self.props_frame, text="Направление ворот:").pack(anchor="w")
                cb = ttk.Combobox(self.props_frame, textvariable=gv,
                                  values=DIRECTIONS, state="readonly", width=10)
                cb.pack(anchor="w")
                cb.bind("<<ComboboxSelected>>", lambda e: self._update_obstacle_field("parameter", gv.get()))
                ttk.Label(self.props_frame, text="Группа цветов (опц.):").pack(anchor="w")
                cv = tk.StringVar(value=str(ob.get("colorGroup", "")))
                ent = ttk.Entry(self.props_frame, textvariable=cv, width=6)
                ent.pack(anchor="w")
                ent.bind("<KeyRelease>",
                         lambda e: self._update_obstacle_field("colorGroup", _try_int(cv.get())))
            elif ob["kind"] == "portal":
                ttk.Label(self.props_frame, text="ID пары порталов:").pack(anchor="w")
                pv = tk.StringVar(value=str(ob.get("parameter", "")))
                ent = ttk.Entry(self.props_frame, textvariable=pv, width=10)
                ent.pack(anchor="w")
                ent.bind("<KeyRelease>",
                         lambda e: self._update_obstacle_field("parameter", pv.get() or None))
            return

        # фигура
        p = next((q for q in self.state.pieces if q["id"] == self.selected_id), None)
        if p is None:
            return
        ttk.Label(self.props_frame, text=f"Фигура: {p['id']}", font=("", 11, "bold")).pack(anchor="w")
        ttk.Label(self.props_frame, text=f"Клеток: {len(p['cells'])}, напр.: {p['direction']}").pack(anchor="w")

        ttk.Label(self.props_frame, text="Тип:").pack(anchor="w", pady=(6, 0))
        kv = tk.StringVar(value=p.get("kind", "standard"))
        cb = ttk.Combobox(self.props_frame, textvariable=kv,
                          values=PIECE_KINDS, state="readonly", width=14)
        cb.pack(anchor="w")
        cb.bind("<<ComboboxSelected>>", lambda e: self._update_piece_kind(kv.get()))

        ttk.Label(self.props_frame, text="Группа цветов (опц.):").pack(anchor="w", pady=(6, 0))
        cgv = tk.StringVar(value=str(p.get("colorGroup", "")))
        ent = ttk.Entry(self.props_frame, textvariable=cgv, width=6)
        ent.pack(anchor="w")
        ent.bind("<KeyRelease>",
                 lambda e: self._update_piece_field("colorGroup", _try_int(cgv.get())))

        kind = p.get("kind", "standard")
        if kind == "double":
            ttk.Label(self.props_frame, text="Доп. направление:").pack(anchor="w", pady=(6, 0))
            sv = tk.StringVar(value=p.get("secondaryDirection", "up"))
            cb2 = ttk.Combobox(self.props_frame, textvariable=sv,
                               values=DIRECTIONS, state="readonly", width=10)
            cb2.pack(anchor="w")
            cb2.bind("<<ComboboxSelected>>",
                     lambda e: self._update_piece_field("secondaryDirection", sv.get()))

        if kind == "frozen":
            ttk.Label(self.props_frame, text="Разблокировать после N удалений:").pack(anchor="w", pady=(6, 0))
            fv = tk.StringVar(value=str(p.get("frozenUnlockNeighbors", 1)))
            ent2 = ttk.Entry(self.props_frame, textvariable=fv, width=6)
            ent2.pack(anchor="w")
            ent2.bind("<KeyRelease>",
                      lambda e: self._update_piece_field("frozenUnlockNeighbors", _try_int(fv.get()) or 1))

        if kind == "chain":
            ttk.Label(self.props_frame, text="ID связанной фигуры:").pack(anchor="w", pady=(6, 0))
            cv = tk.StringVar(value=p.get("chainedPieceId", ""))
            ent3 = ttk.Entry(self.props_frame, textvariable=cv, width=10)
            ent3.pack(anchor="w")
            ent3.bind("<KeyRelease>",
                      lambda e: self._update_piece_field("chainedPieceId", cv.get() or None))

    # ------------------------------------------------------------------ отрисовка

    def _redraw(self) -> None:
        c = self.canvas
        c.delete("all")
        w_px = self.state.width * self.cell
        h_px = self.state.height * self.cell
        c.configure(scrollregion=(0, 0, w_px + 2, h_px + 2))

        c.create_rectangle(0, 0, w_px, h_px, fill=GRID_BG, outline="")
        for x in range(self.state.width + 1):
            c.create_line(x * self.cell, 0, x * self.cell, h_px, fill=GRID_LINE)
        for y in range(self.state.height + 1):
            c.create_line(0, y * self.cell, w_px, y * self.cell, fill=GRID_LINE)

        for ob in self.state.obstacles:
            self._draw_obstacle(ob)

        for p in self.state.pieces:
            self._draw_piece(p, selected=(self.selected_kind == "piece" and self.selected_id == p["id"]))

        if self.current_piece is not None:
            self._draw_piece(self.current_piece, in_progress=True)

        ps = len(self.state.pieces)
        os_ = len(self.state.obstacles)
        self.stats_label.config(
            text=f"{ps} фигур · {os_} препятствий · {self.state.width}×{self.state.height}"
        )

    def _cell_rect(self, gx: int, gy: int) -> tuple[float, float, float, float]:
        return (gx * self.cell + 1, gy * self.cell + 1,
                (gx + 1) * self.cell - 1, (gy + 1) * self.cell - 1)

    def _piece_color(self, p: dict) -> str:
        try:
            idx = next(i for i, q in enumerate(self.state.pieces) if q["id"] == p["id"])
        except StopIteration:
            idx = 0
        return PIECE_COLORS[idx % len(PIECE_COLORS)]

    def _draw_piece(self, p: dict, selected: bool = False, in_progress: bool = False) -> None:
        cells = p["cells"]
        if not cells:
            return
        fill = IN_PROGRESS_FILL if in_progress else self._piece_color(p)
        outline = IN_PROGRESS_OUTLINE if in_progress else "#333"
        out_w = 2 if not selected else 3
        if selected:
            outline = SELECTED_OUTLINE
            out_w = 3

        for c in cells:
            x0, y0, x1, y1 = self._cell_rect(c["x"], c["y"])
            self.canvas.create_rectangle(x0, y0, x1, y1, fill=fill, outline=outline,
                                         width=out_w, tags=f"piece:{p['id']}")

        for a, b in zip(cells, cells[1:]):
            ax, ay, bx, by = a["x"], a["y"], b["x"], b["y"]
            cx0 = min(ax, bx) * self.cell + self.cell // 4
            cy0 = min(ay, by) * self.cell + self.cell // 4
            cx1 = (max(ax, bx) + 1) * self.cell - self.cell // 4
            cy1 = (max(ay, by) + 1) * self.cell - self.cell // 4
            self.canvas.create_rectangle(cx0, cy0, cx1, cy1, fill=fill, outline="",
                                         tags=f"piece:{p['id']}")

        if len(cells) >= 2 and not in_progress:
            head = cells[-1]
            hx, hy = head["x"], head["y"]
            cx = hx * self.cell + self.cell / 2
            cy = hy * self.cell + self.cell / 2
            direction = p.get("direction", "right")
            self.canvas.create_text(cx, cy, text=ARROW_GLYPH.get(direction, "?"),
                                    fill="white", font=("Helvetica", int(self.cell * 0.55), "bold"),
                                    tags=f"piece:{p['id']}")

        kind = p.get("kind", "standard")
        if kind != "standard" and cells:
            head = cells[0]
            hx, hy = head["x"], head["y"]
            badge = {"heavy": "H", "fragile": "F", "frozen": "❄",
                     "double": "D", "lockedLock": "🔒", "lockedKey": "🔑",
                     "bomb": "💣", "chain": "⛓"}.get(kind, "?")
            self.canvas.create_text(hx * self.cell + 8, hy * self.cell + 10, text=badge,
                                    fill="white", font=("Helvetica", int(self.cell * 0.35), "bold"),
                                    tags=f"piece:{p['id']}")

    def _draw_obstacle(self, ob: dict) -> None:
        x = ob["cell"]["x"]
        y = ob["cell"]["y"]
        x0, y0, x1, y1 = self._cell_rect(x, y)
        color = OBSTACLE_COLORS.get(ob["kind"], "#999")
        selected = self.selected_kind == "obstacle" and self.selected_id == ob["id"]
        outline = SELECTED_OUTLINE if selected else "#555"
        w = 3 if selected else 1
        self.canvas.create_rectangle(x0, y0, x1, y1, fill=color, outline=outline,
                                     width=w, tags=f"obstacle:{ob['id']}")
        glyph = {"wall": "█", "gate": "║", "portal": "○", "ice": "❄",
                 "spring": "↯", "destructible": "▤"}.get(ob["kind"], "?")
        cx = x * self.cell + self.cell / 2
        cy = y * self.cell + self.cell / 2
        self.canvas.create_text(cx, cy, text=glyph, fill="white",
                                font=("Helvetica", int(self.cell * 0.5), "bold"),
                                tags=f"obstacle:{ob['id']}")

    # ------------------------------------------------------------------ события мыши

    def _canvas_to_cell(self, event) -> tuple[int, int] | None:
        cx = self.canvas.canvasx(event.x)
        cy = self.canvas.canvasy(event.y)
        gx = int(cx // self.cell)
        gy = int(cy // self.cell)
        if 0 <= gx < self.state.width and 0 <= gy < self.state.height:
            return gx, gy
        return None

    def _on_click(self, event) -> None:
        cell = self._canvas_to_cell(event)
        if cell is None:
            return
        gx, gy = cell

        if self.mode == "eraser":
            self._erase_at(gx, gy)
            return

        if self.mode in OBSTACLE_KINDS:
            self._add_obstacle(self.mode, gx, gy)
            return

        # Режим фигуры
        if self.current_piece is None:
            p = self._piece_at(gx, gy)
            if p is not None:
                self._select_piece(p["id"])
                return
            ob = self._obstacle_at(gx, gy)
            if ob is not None:
                self._select_obstacle(ob["id"])
                return
            # Клик на пустую клетку — снять выделение
            if self.selected_id is not None:
                self.selected_id = None
                self.selected_kind = None
                self._build_props_panel(empty=True)
                self._redraw()
                return

        # Начать или продолжить рисование фигуры
        self._drag_active = True
        self._drag_cell = (gx, gy)

        if self.current_piece is None:
            if self._piece_at(gx, gy) is not None:
                return
            if self._obstacle_at(gx, gy) is not None:
                return
            self._start_piece(gx, gy)
        else:
            self._extend_piece(gx, gy)

    def _on_drag(self, event) -> None:
        if not self._drag_active or self.current_piece is None:
            return
        cell = self._canvas_to_cell(event)
        if cell is None or cell == self._drag_cell:
            return
        gx, gy = cell
        last = self.current_piece["cells"][-1]
        if abs(gx - last["x"]) + abs(gy - last["y"]) == 1:
            self._extend_piece(gx, gy)
            self._drag_cell = (gx, gy)

    def _on_release(self, event) -> None:
        self._drag_active = False
        self._drag_cell = None

    def _on_mouse_move(self, event) -> None:
        cell = self._canvas_to_cell(event)
        if cell is None:
            self.coord_label.config(text="")
        else:
            self.coord_label.config(text=f"x{cell[0]} y{cell[1]}")

    def _on_zoom(self, event) -> None:
        delta = getattr(event, "delta", 0)
        if delta > 0:
            new_cell = min(MAX_CELL, self.cell + 2)
        else:
            new_cell = max(MIN_CELL, self.cell - 2)
        if new_cell != self.cell:
            self.cell = new_cell
            self.var_cell.set(self.cell)
            self._redraw()

    def _zoom_in(self) -> None:
        new_cell = min(MAX_CELL, self.cell + 2)
        if new_cell != self.cell:
            self.cell = new_cell
            self.var_cell.set(self.cell)
            self._redraw()

    def _zoom_out(self) -> None:
        new_cell = max(MIN_CELL, self.cell - 2)
        if new_cell != self.cell:
            self.cell = new_cell
            self.var_cell.set(self.cell)
            self._redraw()

    def _zoom_fit(self) -> None:
        self.cframe.update_idletasks()
        w_avail = self.cframe.winfo_width() - 24
        h_avail = self.cframe.winfo_height() - 24
        if w_avail <= 0 or h_avail <= 0 or self.state.width == 0 or self.state.height == 0:
            return
        cell_w = w_avail // self.state.width
        cell_h = h_avail // self.state.height
        new_cell = max(MIN_CELL, min(MAX_CELL, min(cell_w, cell_h)))
        if new_cell != self.cell:
            self.cell = new_cell
            self.var_cell.set(self.cell)
            self._redraw()

    # ------------------------------------------------------------------ фигуры

    def _start_piece(self, gx: int, gy: int) -> None:
        pid = f"p{self.state.next_pid_n}"
        self.state.next_pid_n += 1
        self.current_piece = {
            "id": pid,
            "direction": "right",
            "cells": [{"x": gx, "y": gy}],
        }
        self._redraw()
        self._schedule_validate()

    def _extend_piece(self, gx: int, gy: int) -> None:
        if self.current_piece is None:
            return
        cells = self.current_piece["cells"]
        if any(c["x"] == gx and c["y"] == gy for c in cells):
            return
        last = cells[-1]
        dx = gx - last["x"]
        dy = gy - last["y"]
        if abs(dx) + abs(dy) != 1:
            return
        if self._piece_at(gx, gy) is not None:
            return
        if self._obstacle_at(gx, gy) is not None:
            return
        cells.append({"x": gx, "y": gy})
        for name, (ddx, ddy) in bl.DIRS.items():
            if (ddx, ddy) == (dx, dy):
                self.current_piece["direction"] = name
                break
        self._redraw()
        self._schedule_validate()

    def _finish_current_piece(self) -> None:
        if self.current_piece is None:
            return
        if len(self.current_piece["cells"]) < 2:
            messagebox.showwarning("Фигура слишком короткая",
                                   "Фигура должна содержать минимум 2 клетки.")
            return
        self.state.pieces.append(self.current_piece)
        self.current_piece = None
        self._redraw()
        self._schedule_validate()

    def _cancel_current_piece(self) -> None:
        if self.current_piece is None:
            return
        self.current_piece = None
        self._redraw()
        self._schedule_validate()

    def _select_piece(self, pid: str) -> None:
        if self.current_piece is not None:
            if len(self.current_piece["cells"]) >= 2:
                self.state.pieces.append(self.current_piece)
            self.current_piece = None
        self.selected_id = pid
        self.selected_kind = "piece"
        self._build_props_panel()
        self._redraw()

    def _select_obstacle(self, oid: str) -> None:
        if self.current_piece is not None:
            if len(self.current_piece["cells"]) >= 2:
                self.state.pieces.append(self.current_piece)
            self.current_piece = None
        self.selected_id = oid
        self.selected_kind = "obstacle"
        self._build_props_panel()
        self._redraw()

    def _delete_selected(self) -> None:
        if self.current_piece is not None:
            self._cancel_current_piece()
            return
        if self.selected_id is None:
            return
        if self.selected_kind == "piece":
            self.state.pieces = [p for p in self.state.pieces if p["id"] != self.selected_id]
        else:
            self.state.obstacles = [o for o in self.state.obstacles if o["id"] != self.selected_id]
        self.selected_id = None
        self.selected_kind = None
        self._build_props_panel(empty=True)
        self._redraw()
        self._schedule_validate()

    def _piece_at(self, gx: int, gy: int) -> dict | None:
        for p in self.state.pieces:
            for c in p["cells"]:
                if c["x"] == gx and c["y"] == gy:
                    return p
        return None

    def _obstacle_at(self, gx: int, gy: int) -> dict | None:
        for o in self.state.obstacles:
            if o["cell"]["x"] == gx and o["cell"]["y"] == gy:
                return o
        return None

    # ------------------------------------------------------------------ препятствия

    def _add_obstacle(self, kind: str, gx: int, gy: int) -> None:
        if self._piece_at(gx, gy) is not None or self._obstacle_at(gx, gy) is not None:
            return
        oid = f"o{self.state.next_oid_n}"
        self.state.next_oid_n += 1
        ob: dict[str, Any] = {"id": oid, "kind": kind, "cell": {"x": gx, "y": gy}}
        if kind == "gate":
            ob["parameter"] = "right"
        self.state.obstacles.append(ob)
        self._redraw()
        self._schedule_validate()

    def _erase_at(self, gx: int, gy: int) -> None:
        p = self._piece_at(gx, gy)
        if p is not None:
            self.state.pieces = [q for q in self.state.pieces if q["id"] != p["id"]]
            if self.selected_kind == "piece" and self.selected_id == p["id"]:
                self.selected_id = None
                self.selected_kind = None
                self._build_props_panel(empty=True)
            self._redraw()
            self._schedule_validate()
            return
        ob = self._obstacle_at(gx, gy)
        if ob is not None:
            self.state.obstacles = [q for q in self.state.obstacles if q["id"] != ob["id"]]
            if self.selected_kind == "obstacle" and self.selected_id == ob["id"]:
                self.selected_id = None
                self.selected_kind = None
                self._build_props_panel(empty=True)
            self._redraw()
            self._schedule_validate()

    # ------------------------------------------------------------------ обработчики тулбара

    def _on_size_changed(self) -> None:
        try:
            new_w = int(self.var_w.get())
            new_h = int(self.var_h.get())
        except (tk.TclError, ValueError):
            return
        self.state.width = max(2, new_w)
        self.state.height = max(2, new_h)
        self.state.pieces = [p for p in self.state.pieces
                             if all(0 <= c["x"] < self.state.width and 0 <= c["y"] < self.state.height
                                    for c in p["cells"])]
        self.state.obstacles = [o for o in self.state.obstacles
                                if 0 <= o["cell"]["x"] < self.state.width and 0 <= o["cell"]["y"] < self.state.height]
        self._redraw()
        self._schedule_validate()

    def _on_cell_changed(self) -> None:
        try:
            self.cell = max(MIN_CELL, min(MAX_CELL, int(self.var_cell.get())))
        except (tk.TclError, ValueError):
            return
        self._redraw()

    def _on_lives_changed(self) -> None:
        try:
            self.state.lives = max(1, int(self.var_lives.get()))
        except (tk.TclError, ValueError):
            pass

    def _on_index_changed(self) -> None:
        try:
            self.state.index = max(1, int(self.var_index.get()))
        except (tk.TclError, ValueError):
            pass

    def _on_name_changed(self) -> None:
        self.state.name = self.var_name.get().strip()

    def _on_diff_changed(self) -> None:
        self.state.difficulty = self.var_diff.get()

    def _on_mode_changed(self) -> None:
        self.mode = self.mode_var.get()
        if self.mode != "piece" and self.current_piece is not None:
            if len(self.current_piece["cells"]) >= 2:
                self.state.pieces.append(self.current_piece)
            self.current_piece = None
            self._redraw()
            self._schedule_validate()

    def _on_goal_changed(self) -> None:
        kind = GOAL_LABEL_TO_KIND.get(self.var_goal_kind.get(), self.var_goal_kind.get())
        if kind == "clearAll":
            self.state.goal = None
            self.var_goal_value.set("")
            self.goal_value_entry.configure(state="disabled")
        else:
            val_raw = self.var_goal_value.get().strip()
            goal: dict[str, Any] = {"kind": kind}
            if kind in ("clearColorGroup", "clearInSeconds"):
                self.goal_value_entry.configure(state="normal")
                try:
                    goal["value"] = int(val_raw) if val_raw else 0
                except ValueError:
                    goal["value"] = 0
            elif kind == "freePiece":
                self.goal_value_entry.configure(state="normal")
                if val_raw:
                    goal["value"] = val_raw
            else:
                self.goal_value_entry.configure(state="disabled")
                self.var_goal_value.set("")
            self.state.goal = goal
        self._schedule_validate()

    def _on_stars_changed(self) -> None:
        try:
            self.state.three_star = int(self.var_3star.get())
            self.state.two_star = int(self.var_2star.get())
        except (tk.TclError, ValueError):
            pass

    def _update_piece_kind(self, kind: str) -> None:
        p = next((q for q in self.state.pieces if q["id"] == self.selected_id), None)
        if p is None:
            return
        p["kind"] = kind
        if kind == "frozen" and "frozenUnlockNeighbors" not in p:
            p["frozenUnlockNeighbors"] = 1
        self._build_props_panel()
        self._redraw()
        self._schedule_validate()

    def _update_piece_field(self, key: str, value: Any) -> None:
        p = next((q for q in self.state.pieces if q["id"] == self.selected_id), None)
        if p is None:
            return
        if value is None or value == "":
            p.pop(key, None)
        else:
            p[key] = value
        self._redraw()
        self._schedule_validate()

    def _update_obstacle_field(self, key: str, value: Any) -> None:
        ob = next((o for o in self.state.obstacles if o["id"] == self.selected_id), None)
        if ob is None:
            return
        if value is None or value == "":
            ob.pop(key, None)
        else:
            ob[key] = value
        self._redraw()
        self._schedule_validate()

    # ------------------------------------------------------------------ валидация

    def _schedule_validate(self) -> None:
        if self._after_id is not None:
            try:
                self.root.after_cancel(self._after_id)
            except tk.TclError:
                pass
        self._after_id = self.root.after(250, self._do_validate)

    def _do_validate(self) -> None:
        lvl = self.state.as_level_dict()
        err = _cheap_validate(lvl)
        if err is not None:
            self._set_status("invalid", err)
            return
        self._set_status("checking", "Проверяю решаемость…")
        self._validate_token += 1
        token = self._validate_token

        def worker() -> None:
            t0 = time.time()
            try:
                if any(p.get("kind") == "double" for p in lvl["pieces"]):
                    self.root.after(0, lambda: self._on_validate_done(token, "skipped",
                                                                      "Есть double-фигуры — солвер пропущен"))
                    return
                order = bl.solve(lvl)
                dt = time.time() - t0
                if order is None:
                    self.root.after(0, lambda: self._on_validate_done(token, "unsolvable",
                                                                      f"Нерешаемо ({dt:.2f}с)"))
                else:
                    self.root.after(0, lambda: self._on_validate_done(token, "solvable",
                                                                      f"Решаемо за {len(order)} ходов ({dt:.2f}с)"))
            except Exception as ex:
                self.root.after(0, lambda: self._on_validate_done(token, "invalid",
                                                                  f"Ошибка солвера: {ex}"))

        threading.Thread(target=worker, daemon=True).start()

    def _on_validate_done(self, token: int, state: str, text: str) -> None:
        if token != self._validate_token:
            return
        self._set_status(state, text)

    def _set_status(self, state: str, text: str) -> None:
        color = {"solvable": "#3fb680", "checking": "#fadb14",
                 "invalid": "#ef4458", "unsolvable": "#ef4458",
                 "skipped": "#8a8a8a"}.get(state, "#888")
        self.status_dot.itemconfigure("dot", fill=color)
        self.status_label.config(text=text)

    # ------------------------------------------------------------------ файловые операции

    def _cmd_smart_random(self) -> None:
        if (self.state.pieces or self.state.obstacles) and not self._confirm_lose_changes():
            return

        area = self.state.width * self.state.height
        # Умолчание заполненности зависит от размера поля
        if area < 40:
            default_cov = 55
        elif area < 80:
            default_cov = 62
        elif area < 160:
            default_cov = 67
        else:
            default_cov = 70

        dlg = tk.Toplevel(self.root)
        dlg.title("🎲 Умный рандом")
        dlg.resizable(False, False)
        dlg.grab_set()
        dlg.transient(self.root)

        pad = {"padx": 12, "pady": 6}

        # --- Заполненность ---
        ttk.Label(dlg, text=f"Поле {self.state.width}×{self.state.height} "
                  f"= {area} кл.", font=("", 10, "bold")).grid(
            row=0, column=0, columnspan=3, sticky="w", padx=12, pady=(12, 2))

        ttk.Label(dlg, text="Заполненность:").grid(row=1, column=0, sticky="w", **pad)
        var_cov = tk.IntVar(value=default_cov)
        cov_lbl = ttk.Label(dlg, text=f"{default_cov}%", width=5)

        def _update_cov_lbl(*_):
            v = var_cov.get()
            cells_est = int(area * v / 100)
            cov_lbl.config(text=f"{v}%  (~{cells_est} кл.)")

        scale_cov = ttk.Scale(dlg, from_=25, to=85, variable=var_cov,
                              orient=tk.HORIZONTAL, length=220,
                              command=_update_cov_lbl)
        scale_cov.grid(row=1, column=1, **pad)
        cov_lbl.grid(row=1, column=2, sticky="w", padx=(0, 12))
        _update_cov_lbl()

        # --- Длина стрелок ---
        ttk.Label(dlg, text="Длина стрелок:").grid(row=2, column=0, sticky="w", **pad)
        var_bias = tk.StringVar(value="mixed")
        bf = ttk.Frame(dlg)
        bf.grid(row=2, column=1, columnspan=2, sticky="w", **pad)
        for txt, val, hint in [
            ("Короткие (2–3)", "short",  "плотные, много фигур"),
            ("Смешанные",     "mixed",   "разнообразие длин"),
            ("Длинные (5–10)", "long",   "мало фигур, сложнее"),
        ]:
            rb = ttk.Radiobutton(bf, text=txt, value=val, variable=var_bias)
            rb.pack(side=tk.LEFT, padx=4)
            rb.config()

        # --- Стиль композиции ---
        style_items = [
            ("Как в референсах", "reference"),
            ("Плотный центр", "dense"),
            ("Длинные коридоры", "corridor"),
            ("Спирали", "spiral"),
            ("Рамки", "frame"),
            ("Старое блуждание", "walk"),
        ]
        style_label_to_value = {label: value for label, value in style_items}
        ttk.Label(dlg, text="Стиль:").grid(row=3, column=0, sticky="w", **pad)
        var_style = tk.StringVar(value=style_items[0][0])
        style_combo = ttk.Combobox(dlg, textvariable=var_style,
                                   values=[label for label, _ in style_items],
                                   width=20, state="readonly")
        style_combo.grid(row=3, column=1, columnspan=2, sticky="w", **pad)

        # --- Стартовая сложность ---
        default_initial = 3 if area >= 120 else 4
        if self.state.difficulty == "easy":
            default_initial = 5
        elif self.state.difficulty == "hard":
            default_initial = 3
        ttk.Label(dlg, text="Макс. ходов на старте:").grid(row=4, column=0, sticky="w", **pad)
        var_initial = tk.IntVar(value=default_initial)
        ttk.Spinbox(dlg, from_=1, to=12, width=4,
                    textvariable=var_initial).grid(row=4, column=1, sticky="w", **pad)
        ttk.Label(dlg, text="меньше = сложнее",
                  foreground="#777").grid(row=4, column=2, sticky="w", padx=(0, 12))

        # --- Seed и препятствия ---
        ttk.Label(dlg, text="Seed:").grid(row=5, column=0, sticky="w", **pad)
        var_seed = tk.StringVar(value="")
        ttk.Entry(dlg, textvariable=var_seed, width=18).grid(row=5, column=1, sticky="w", **pad)
        ttk.Label(dlg, text="пусто = случайно",
                  foreground="#777").grid(row=5, column=2, sticky="w", padx=(0, 12))

        var_keep_obstacles = tk.BooleanVar(value=False)
        keep_obstacles = ttk.Checkbutton(
            dlg,
            text="Сохранить препятствия",
            variable=var_keep_obstacles,
        )
        keep_obstacles.grid(row=6, column=1, columnspan=2, sticky="w", **pad)
        if not self.state.obstacles:
            keep_obstacles.configure(state="disabled")

        var_show_metrics = tk.BooleanVar(value=True)
        ttk.Checkbutton(dlg, text="Показать метрики после генерации",
                        variable=var_show_metrics).grid(
            row=7, column=1, columnspan=2, sticky="w", **pad)

        # --- Описание ---
        info_var = tk.StringVar(value="")
        info_lbl = ttk.Label(dlg, textvariable=info_var, foreground="#555",
                             font=("", 9), wraplength=380, justify="left")
        info_lbl.grid(row=8, column=0, columnspan=3, sticky="w", padx=12, pady=(0, 4))

        def _update_info(*_):
            bias = var_bias.get()
            cov = var_cov.get()
            bias_map = {"short": 0.1, "mixed": 0.5, "long": 0.9}
            b = bias_map[bias]
            max_len = max(4, int((self.state.width + self.state.height) * (0.25 + b * 0.45)))
            max_len = min(max_len, area - 1)
            avg_len = 2 + b * (max_len - 2) * 0.55
            est_pieces = max(1, int(area * cov / 100 / avg_len))
            style = var_style.get()
            info_var.set(
                f"Ожидается ≈{est_pieces} фигур · макс. длина ~{max_len} кл. · {style}"
            )

        var_cov.trace_add("write", _update_info)
        var_bias.trace_add("write", _update_info)
        var_style.trace_add("write", _update_info)
        _update_info()

        # --- Количество попыток ---
        ttk.Label(dlg, text="Попыток генерации:").grid(row=9, column=0, sticky="w", **pad)
        var_tries = tk.IntVar(value=8)
        ttk.Spinbox(dlg, from_=1, to=20, width=4,
                    textvariable=var_tries).grid(row=9, column=1, sticky="w", **pad)
        ttk.Label(dlg, text="(берётся лучший результат)",
                  foreground="#777").grid(row=9, column=2, sticky="w", padx=(0, 12))

        # --- Кнопки ---
        result: dict = {}

        def on_ok():
            result["ok"] = True
            result["cov"] = var_cov.get()
            result["bias"] = var_bias.get()
            result["tries"] = var_tries.get()
            result["style"] = style_label_to_value.get(var_style.get(), "reference")
            result["max_initial"] = var_initial.get()
            result["seed"] = var_seed.get().strip()
            result["keep_obstacles"] = var_keep_obstacles.get()
            result["show_metrics"] = var_show_metrics.get()
            dlg.destroy()

        def on_cancel():
            dlg.destroy()

        btn_row = ttk.Frame(dlg)
        btn_row.grid(row=10, column=0, columnspan=3, pady=12)
        ttk.Button(btn_row, text="Сгенерировать", command=on_ok).pack(side=tk.LEFT, padx=8)
        ttk.Button(btn_row, text="Отмена", command=on_cancel).pack(side=tk.LEFT, padx=8)

        dlg.wait_window()
        if not result.get("ok"):
            return

        bias_map = {"short": 0.1, "mixed": 0.5, "long": 0.9}
        long_bias = bias_map[result["bias"]]
        coverage = result["cov"] / 100.0
        tries = max(1, int(result["tries"]))
        style = result["style"]
        max_initial = max(1, int(result["max_initial"]))
        seed_base = result["seed"] or None
        kept_obstacles = list(self.state.obstacles) if result["keep_obstacles"] else []

        # Запускаем несколько попыток, берём лучшую по метрикам качества.
        best_pieces: list = []
        best_metrics: dict | None = None
        best_score = -1_000_000.0
        for attempt in range(tries):
            attempt_seed = None
            if seed_base is not None:
                attempt_seed = f"{seed_base}:{attempt}"
            ps, _, metrics = smart_random_generate(
                self.state.width,
                self.state.height,
                coverage,
                long_bias,
                seed=attempt_seed,
                style=style,
                max_initial_movable=max_initial,
                return_metrics=True,
                obstacles=kept_obstacles,
            )
            if ps and metrics["score"] > best_score:
                best_score = metrics["score"]
                best_pieces = ps
                best_metrics = metrics

        if not best_pieces:
            messagebox.showwarning("Рандом",
                                   "Не удалось разместить ни одной фигуры.\n"
                                   "Попробуйте увеличить сетку или уменьшить заполненность.")
            return

        # Перенумеруем pid-ы последовательно
        for i, p in enumerate(best_pieces, start=1):
            p["id"] = f"p{i}"

        self.state.pieces = best_pieces
        self.state.obstacles = kept_obstacles
        self.state.next_pid_n = len(best_pieces) + 1
        self.state.next_oid_n = max(
            [1] + [
                int(o["id"][1:]) + 1
                for o in self.state.obstacles
                if o.get("id", "").startswith("o") and o["id"][1:].isdigit()
            ]
        )
        self.selected_id = None
        self.selected_kind = None
        self.current_piece = None
        self._build_props_panel(empty=True)
        self._redraw()
        self._schedule_validate()

        if best_metrics is not None:
            summary = (
                f"Score: {best_metrics['score']}\n"
                f"Фигур: {best_metrics['pieces']} · клеток: {best_metrics['cells']} "
                f"({int(best_metrics['density'] * 100)}%)\n"
                f"Стартовых ходов: {best_metrics['initialMovable']} · "
                f"заблокировано: {int(best_metrics['blockedRatio'] * 100)}%\n"
                f"Решение: {best_metrics['solutionLength']} ходов · "
                f"ср. длина: {best_metrics['avgLength']} · "
                f"ср. поворотов: {best_metrics['avgTurns']}\n"
                f"Центр: {int(best_metrics['centerDensity'] * 100)}% · "
                f"края: {int(best_metrics['edgeRatio'] * 100)}%"
            )
            self.status_label.config(text=summary.replace("\n", " | "))
            if result["show_metrics"]:
                messagebox.showinfo("Метрики уровня", summary)

    def _cmd_clear_board(self) -> None:
        if not self.state.pieces and not self.state.obstacles and self.current_piece is None:
            return
        if not messagebox.askyesno("Очистить поле", "Удалить все фигуры и препятствия?"):
            return
        self.state.pieces = []
        self.state.obstacles = []
        self.state.next_pid_n = 1
        self.state.next_oid_n = 1
        self.current_piece = None
        self.selected_id = None
        self.selected_kind = None
        self._build_props_panel(empty=True)
        self._redraw()
        self._schedule_validate()

    def _cmd_new(self) -> None:
        if not self._confirm_lose_changes():
            return
        self.state = State()
        self._refresh_meta_widgets()
        self.selected_id = None
        self.selected_kind = None
        self.current_piece = None
        self._build_props_panel(empty=True)
        self._redraw()
        self._schedule_validate()

    def _cmd_open_draft(self) -> None:
        if not self._confirm_lose_changes():
            return
        os.makedirs(DRAFTS_DIR, exist_ok=True)
        path = filedialog.askopenfilename(initialdir=DRAFTS_DIR,
                                          title="Открыть черновик",
                                          filetypes=[("JSON", "*.json")])
        if not path:
            return
        with open(path) as f:
            data = json.load(f)
        self.state = State.from_level_dict(data)
        self._refresh_meta_widgets()
        self.selected_id = None
        self.selected_kind = None
        self.current_piece = None
        self._build_props_panel(empty=True)
        self._redraw()
        self._schedule_validate()

    def _cmd_open_from_main(self) -> None:
        if not self._confirm_lose_changes():
            return
        if not os.path.exists(LEVELS_JSON):
            messagebox.showerror("Файл не найден", f"{LEVELS_JSON} не найден.")
            return
        with open(LEVELS_JSON) as f:
            levels = json.load(f)
        indices = sorted([str(l["index"]) for l in levels])
        if not indices:
            messagebox.showinfo("Пусто", "В levels.json нет уровней.")
            return
        picked = simpledialog.askstring("Открыть уровень",
                                        f"Введите индекс уровня ({indices[0]}–{indices[-1]}):",
                                        parent=self.root)
        if not picked:
            return
        try:
            idx = int(picked)
        except ValueError:
            messagebox.showerror("Неверный ввод", "Индекс должен быть числом.")
            return
        lvl = next((l for l in levels if l["index"] == idx), None)
        if lvl is None:
            messagebox.showerror("Не найдено", f"Уровня с индексом {idx} не существует.")
            return
        self.state = State.from_level_dict(lvl)
        self._refresh_meta_widgets()
        self.selected_id = None
        self.selected_kind = None
        self.current_piece = None
        self._build_props_panel(empty=True)
        self._redraw()
        self._schedule_validate()

    def _cmd_save_draft(self, ask: bool = False) -> None:
        os.makedirs(DRAFTS_DIR, exist_ok=True)
        suggested = f"level_{self.state.index:03d}"
        if self.state.name:
            safe = "".join(c if c.isalnum() or c in "-_ " else "_" for c in self.state.name).strip().replace(" ", "_")
            if safe:
                suggested = f"level_{self.state.index:03d}_{safe}"
        if ask or not hasattr(self, "_last_draft_path") or not self._last_draft_path:
            path = filedialog.asksaveasfilename(initialdir=DRAFTS_DIR,
                                                initialfile=f"{suggested}.json",
                                                title="Сохранить черновик",
                                                defaultextension=".json",
                                                filetypes=[("JSON", "*.json")])
            if not path:
                return
            self._last_draft_path = path
        else:
            path = self._last_draft_path
        lvl = self.state.as_level_dict()
        with open(path, "w") as f:
            json.dump(lvl, f, indent=2, sort_keys=True)
        self.status_label.config(text=f"Черновик сохранён → {os.path.basename(path)}")

    def _cmd_publish(self) -> None:
        lvl = self.state.as_level_dict()
        err = _cheap_validate(lvl)
        if err is not None:
            if not messagebox.askyesno("Ошибка валидации",
                                       f"Уровень невалиден:\n\n{err}\n\nОпубликовать всё равно?"):
                return
        else:
            self.status_label.config(text="Запускаю солвер перед публикацией…")
            self.root.update_idletasks()
            order = None
            try:
                order = bl.solve(lvl)
            except Exception as ex:
                if not messagebox.askyesno("Ошибка солвера",
                                           f"Солвер завершился с ошибкой: {ex}.\n\nОпубликовать всё равно?"):
                    return
            if order is None:
                if not messagebox.askyesno("Нерешаемо",
                                           "Солвер считает уровень нерешаемым.\n\nОпубликовать всё равно?"):
                    return

        if not os.path.exists(LEVELS_JSON):
            messagebox.showerror("Файл не найден", f"{LEVELS_JSON} не найден.")
            return
        with open(LEVELS_JSON) as f:
            existing = json.load(f)

        existing = [l for l in existing if l["index"] != lvl["index"]]
        merged = sorted(existing + [lvl], key=lambda l: l["index"])
        with open(LEVELS_JSON, "w") as f:
            json.dump(merged, f, indent=2, sort_keys=True)
        messagebox.showinfo("Опубликовано",
                            f"Уровень {lvl['index']} записан в levels.json\n"
                            f"(всего уровней: {len(merged)})")

    def _confirm_lose_changes(self) -> bool:
        if not self.state.pieces and not self.state.obstacles:
            return True
        return messagebox.askyesno("Отменить изменения?",
                                   "Текущий уровень имеет несохранённые изменения. Продолжить?")

    def _refresh_meta_widgets(self) -> None:
        self.var_w.set(self.state.width)
        self.var_h.set(self.state.height)
        self.var_lives.set(self.state.lives)
        self.var_index.set(self.state.index)
        self.var_name.set(self.state.name)
        self.var_diff.set(self.state.difficulty)
        self.var_3star.set(self.state.three_star)
        self.var_2star.set(self.state.two_star)
        if self.state.goal is None:
            self.var_goal_kind.set(GOAL_KIND_LABELS["clearAll"])
            self.var_goal_value.set("")
            self.goal_value_entry.configure(state="disabled")
        else:
            kind_key = self.state.goal["kind"]
            self.var_goal_kind.set(GOAL_KIND_LABELS.get(kind_key, kind_key))
            self.var_goal_value.set(str(self.state.goal.get("value", "")))


# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------

def _try_int(s: str) -> int | None:
    s = s.strip()
    if not s:
        return None
    try:
        return int(s)
    except ValueError:
        return None


def _cheap_validate(lvl: dict) -> str | None:
    w, h = lvl["width"], lvl["height"]
    if not lvl["pieces"]:
        return "нет фигур"
    occ: dict[tuple[int, int], str] = {}
    for p in lvl["pieces"]:
        err = bl.validate_piece(p, w, h)
        if err:
            return err
        for c in p["cells"]:
            k = (c["x"], c["y"])
            if k in occ:
                return f"перекрытие: фигуры {occ[k]} и {p['id']} в {k}"
            occ[k] = p["id"]
    for ob in lvl.get("obstacles", []):
        cx, cy = ob["cell"]["x"], ob["cell"]["y"]
        if not (0 <= cx < w and 0 <= cy < h):
            return f"препятствие {ob['id']} за пределами сетки"
        if (cx, cy) in occ:
            return f"препятствие {ob['id']} перекрывает фигуру {occ[(cx, cy)]}"
    return None


# ---------------------------------------------------------------------------

def main() -> None:
    root = tk.Tk()
    EditorApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
