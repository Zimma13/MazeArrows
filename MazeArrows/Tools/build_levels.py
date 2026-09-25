#!/usr/bin/env python3
"""
Builds levels 26-50 and merges them into levels.json.
Validates each level (adjacency, head segment, no overlap, solvability)
following the Swift LevelValidator + LevelSolver rules.

Design rules to keep levels solvable:
  - Two opposite-facing pieces must NOT share an exit lane
    (i.e. avoid "right" and "left" pieces in the same row whose lanes overlap;
    avoid "up" and "down" in the same column).
  - A vertical piece's body must not sit in another piece's exit lane unless
    that vertical piece can be removed first.
  - Use the y-axis growing DOWN.
"""
import json
import os
import sys

DIRS = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}


def piece(pid, direction, cells, kind=None, color_group=None,
          secondary_direction=None, frozen_unlock_neighbors=None,
          chained_piece_id=None):
    p = {
        "id": pid,
        "direction": direction,
        "cells": [{"x": x, "y": y} for x, y in cells],
    }
    if kind is not None: p["kind"] = kind
    if color_group is not None: p["colorGroup"] = color_group
    if secondary_direction is not None: p["secondaryDirection"] = secondary_direction
    if frozen_unlock_neighbors is not None: p["frozenUnlockNeighbors"] = frozen_unlock_neighbors
    if chained_piece_id is not None: p["chainedPieceId"] = chained_piece_id
    return p


def obstacle(oid, kind, cell, parameter=None, color_group=None):
    o = {"id": oid, "kind": kind, "cell": {"x": cell[0], "y": cell[1]}}
    if parameter is not None: o["parameter"] = parameter
    if color_group is not None: o["colorGroup"] = color_group
    return o


def level(index, name, difficulty, w, h, lives, pieces, obstacles=None,
          goal=None, three_star=0, two_star=1):
    l = {
        "id": f"level_{index:03d}",
        "index": index,
        "name": name,
        "difficulty": difficulty,
        "width": w,
        "height": h,
        "lives": lives,
        "pieces": pieces,
        "threeStarMaxMistakes": three_star,
        "twoStarMaxMistakes": two_star,
    }
    if obstacles: l["obstacles"] = obstacles
    if goal: l["goal"] = goal
    return l


# ----- validation -----

def validate_piece(p, w, h):
    cells = [(c['x'], c['y']) for c in p['cells']]
    if len(cells) < 2:
        return f"piece {p['id']}: too short"
    if len(set(cells)) != len(cells):
        return f"piece {p['id']}: duplicate cell"
    for x, y in cells:
        if not (0 <= x < w and 0 <= y < h):
            return f"piece {p['id']}: out of bounds ({x},{y}) on {w}x{h}"
    for i in range(1, len(cells)):
        ax, ay = cells[i - 1]
        bx, by = cells[i]
        if abs(ax - bx) + abs(ay - by) != 1:
            return f"piece {p['id']}: non-adjacent"
    dx, dy = DIRS[p['direction']]
    ax, ay = cells[-2]
    bx, by = cells[-1]
    if (bx - ax, by - ay) != (dx, dy):
        return (f"piece {p['id']}: head segment mismatch — "
                f"last segment {(bx-ax, by-ay)} but direction {p['direction']} expects {(dx, dy)}")
    head = cells[-1]
    body = set(cells[:-1])
    nx, ny = head[0] + dx, head[1] + dy
    while 0 <= nx < w and 0 <= ny < h:
        if (nx, ny) in body:
            return f"piece {p['id']}: arrow exits through its own body at ({nx},{ny})"
        nx += dx
        ny += dy
    return None


def can_fly_out(p, board_pieces, obstacles, w, h, removed_count):
    kind = p.get('kind', 'standard')
    if kind == 'frozen':
        thr = p.get('frozenUnlockNeighbors', 1)
        if removed_count < thr:
            return False
    if kind == 'lockedLock':
        group = p.get('colorGroup')
        if group is not None:
            for q in board_pieces:
                if q['id'] != p['id'] and q.get('kind') == 'lockedKey' and q.get('colorGroup') == group:
                    return False

    occ = {}
    for q in board_pieces:
        if q['id'] == p['id']:
            continue
        for c in q['cells']:
            occ[(c['x'], c['y'])] = q['id']
    obs_map = {(o['cell']['x'], o['cell']['y']): o for o in obstacles}

    dx, dy = DIRS[p['direction']]
    cx = p['cells'][-1]['x']
    cy = p['cells'][-1]['y']
    while True:
        nx, ny = cx + dx, cy + dy
        if not (0 <= nx < w and 0 <= ny < h):
            return True
        if (nx, ny) in occ:
            return False
        if (nx, ny) in obs_map:
            ob = obs_map[(nx, ny)]
            ok = False
            if ob['kind'] == 'wall':
                ok = False
            elif ob['kind'] == 'gate':
                gd = ob.get('parameter')
                if gd and gd != p['direction']:
                    ok = False
                elif ob.get('colorGroup') is not None and ob.get('colorGroup') != p.get('colorGroup'):
                    ok = False
                else:
                    ok = True
            elif ob['kind'] in ('portal', 'ice', 'spring'):
                ok = True
            elif ob['kind'] == 'destructible':
                ok = (kind == 'bomb')
            if not ok:
                return False
        cx, cy = nx, ny


def solve(lvl):
    pieces = [dict(p) for p in lvl['pieces']]
    obstacles = list(lvl.get('obstacles', []))
    w, h = lvl['width'], lvl['height']
    initial = len(pieces)
    order = []
    safety = 0
    while pieces:
        safety += 1
        if safety > 1000:
            return None
        moved = False
        for p in list(pieces):
            removed = initial - len(pieces)
            if can_fly_out(p, pieces, obstacles, w, h, removed):
                order.append(p['id'])
                pieces.remove(p)
                kind = p.get('kind', 'standard')
                if kind == 'bomb':
                    body_cells = {(c['x'], c['y']) for c in p['cells']}
                    new_obs = []
                    for o in obstacles:
                        ox, oy = o['cell']['x'], o['cell']['y']
                        adj = any(abs(ox - bx) + abs(oy - by) == 1 for bx, by in body_cells)
                        if o['kind'] == 'destructible' and adj:
                            continue
                        new_obs.append(o)
                    obstacles = new_obs
                if kind == 'chain':
                    cid = p.get('chainedPieceId')
                    if cid:
                        chained = next((q for q in pieces if q['id'] == cid), None)
                        if chained:
                            removed2 = initial - len(pieces)
                            if can_fly_out(chained, pieces, obstacles, w, h, removed2):
                                order.append(chained['id'])
                                pieces.remove(chained)
                moved = True
                break
        if not moved:
            return None
    return order


def validate_level(lvl):
    w, h = lvl['width'], lvl['height']
    occ = {}
    for p in lvl['pieces']:
        err = validate_piece(p, w, h)
        if err: return err
        for c in p['cells']:
            key = (c['x'], c['y'])
            if key in occ:
                return f"overlap: pieces {occ[key]} and {p['id']} at {key}"
            occ[key] = p['id']
    for ob in lvl.get('obstacles', []):
        cx, cy = ob['cell']['x'], ob['cell']['y']
        if not (0 <= cx < w and 0 <= cy < h):
            return f"obstacle {ob['id']} out of bounds"
        if (cx, cy) in occ:
            return f"obstacle {ob['id']} overlaps piece {occ[(cx, cy)]}"
    if solve(lvl) is None:
        return "unsolvable"
    return None


# ----- helpers for building pieces -----

def line(pid, direction, x, y, length):
    """Straight line of `length` cells starting at (x,y), heading in `direction`."""
    dx, dy = DIRS[direction]
    cells = [(x + i * dx, y + i * dy) for i in range(length)]
    return piece(pid, direction, cells)


def L(pid, direction, cells):
    """Hand-built L/U/S shape — last segment must match direction."""
    return piece(pid, direction, cells)


# ============================================================
# LEVELS 26-50
# Difficulty curve:
#   26-30 medium  — denser standard puzzles on 9x12
#   31-35 medium  — introduce single special mechanics
#   36-40 hard    — denser hard 10x14 puzzles
#   41-45 hard    — combine special pieces and obstacles
#   46-50 hard    — alternate goals + finale
# ============================================================

LEVELS = []

# --- 26 Junction (medium, all standard) ---
LEVELS.append(level(
    26, "Junction", "medium", 9, 12, 5,
    pieces=[
        line("p1", "right", 0, 1, 4),
        line("p2", "right", 0, 3, 5),
        line("p3", "left", 8, 5, 5),
        line("p4", "left", 8, 7, 4),
        line("p5", "down", 2, 9, 3),
        line("p6", "down", 5, 9, 3),
        piece("p7", "up", [(7, 1), (7, 0)]),
        piece("p8", "down", [(0, 9), (0, 10)]),
    ],
))

# --- 27 Standoff (medium) — horizontal-only across rows ---
LEVELS.append(level(
    27, "Standoff", "medium", 9, 12, 5,
    pieces=[
        line("p1", "right", 0, 1, 3),
        line("p2", "left", 8, 2, 3),
        line("p3", "right", 0, 4, 3),
        line("p4", "left", 8, 5, 3),
        line("p5", "right", 0, 7, 3),
        line("p6", "left", 8, 8, 3),
        line("p7", "right", 0, 10, 3),
        line("p8", "left", 8, 11, 3),
        piece("p9", "up", [(4, 1), (4, 0)]),
    ],
))

# --- 28 Lattice (medium) ---
LEVELS.append(level(
    28, "Lattice", "medium", 9, 12, 5,
    pieces=[
        line("p1", "right", 0, 0, 4),
        line("p2", "right", 0, 2, 3),
        line("p3", "right", 0, 4, 4),
        line("p4", "left", 8, 1, 3),
        line("p5", "left", 8, 3, 4),
        line("p6", "left", 8, 5, 3),
        line("p7", "down", 1, 9, 3),
        line("p8", "down", 4, 9, 3),
        line("p9", "down", 7, 9, 3),
        line("p10", "right", 0, 7, 3),
    ],
))

# --- 29 Pinball (medium, with L-shapes) ---
LEVELS.append(level(
    29, "Pinball", "medium", 9, 12, 5,
    pieces=[
        L("p1", "right", [(0, 0), (0, 1), (1, 1), (2, 1), (3, 1)]),
        L("p2", "right", [(0, 3), (1, 3), (1, 4), (2, 4)]),
        L("p3", "left", [(8, 6), (7, 6), (7, 5), (6, 5)]),
        L("p4", "left", [(8, 8), (7, 8), (6, 8), (5, 8), (4, 8)]),
        L("p5", "down", [(3, 9), (3, 10), (3, 11)]),
        L("p6", "down", [(5, 9), (5, 10), (5, 11)]),
        L("p7", "up", [(1, 7), (1, 6), (1, 5)]),
        L("p8", "up", [(8, 1), (8, 0)]),
        line("p9", "right", 0, 10, 3),
        line("p10", "left", 8, 2, 3),
    ],
))

# --- 30 Convoy (medium) — horizontals only, no vertical conflict ---
LEVELS.append(level(
    30, "Convoy", "medium", 9, 12, 5,
    pieces=[
        line("p1", "right", 0, 0, 5),
        line("p2", "right", 0, 1, 5),
        line("p3", "right", 0, 2, 5),
        line("p4", "left", 8, 4, 5),
        line("p5", "left", 8, 5, 5),
        line("p6", "left", 8, 6, 5),
        line("p7", "right", 0, 8, 5),
        line("p8", "right", 0, 9, 5),
        line("p9", "left", 8, 11, 5),
        piece("p10", "right", [(0, 10), (1, 10)]),
        piece("p11", "down", [(3, 10), (3, 11)]),
    ],
))

# --- 31 Walled Garden (medium, walls don't block exits, just constrain) ---
LEVELS.append(level(
    31, "Walled Garden", "medium", 9, 12, 5,
    pieces=[
        line("p1", "right", 0, 1, 3),
        line("p2", "right", 0, 4, 3),
        line("p3", "right", 0, 7, 3),
        line("p4", "left", 8, 2, 3),
        line("p5", "left", 8, 5, 3),
        line("p6", "left", 8, 8, 3),
        line("p7", "right", 0, 10, 3),
    ],
    obstacles=[
        # Walls placed ABOVE/BELOW lanes — visual decoration that doesn't block.
        obstacle("w1", "wall", (4, 0)),
        obstacle("w2", "wall", (4, 3)),
        obstacle("w3", "wall", (4, 6)),
        obstacle("w4", "wall", (4, 9)),
        obstacle("w5", "wall", (4, 11)),
    ],
))

# --- 32 Cold Snap (medium, frozen pieces) ---
LEVELS.append(level(
    32, "Cold Snap", "medium", 9, 12, 5,
    pieces=[
        line("p1", "right", 0, 1, 3),
        line("p2", "right", 0, 3, 3),
        line("p3", "right", 0, 5, 3),
        piece("p4", "right", [(0, 7), (1, 7), (2, 7)],
              kind="frozen", frozen_unlock_neighbors=1),
        piece("p5", "right", [(0, 9), (1, 9), (2, 9)],
              kind="frozen", frozen_unlock_neighbors=2),
        line("p6", "left", 8, 2, 3),
        line("p7", "left", 8, 6, 3),
        piece("p8", "left", [(8, 10), (7, 10), (6, 10)],
              kind="frozen", frozen_unlock_neighbors=3),
    ],
))

# --- 33 Twin Keys (medium, 2 key/lock pairs in non-conflicting rows) ---
LEVELS.append(level(
    33, "Twin Keys", "medium", 9, 12, 5,
    pieces=[
        piece("k1", "right", [(0, 1), (1, 1)], kind="lockedKey", color_group=1),
        piece("k2", "left", [(8, 10), (7, 10)], kind="lockedKey", color_group=2),
        piece("l1", "right", [(0, 4), (1, 4), (2, 4)], kind="lockedLock", color_group=1),
        piece("l2", "left", [(8, 7), (7, 7), (6, 7)], kind="lockedLock", color_group=2),
        line("p1", "right", 0, 8, 3),
        line("p2", "left", 8, 3, 3),
        piece("p3", "down", [(3, 0), (3, 1)]),
        piece("p4", "up", [(5, 11), (5, 10)]),
    ],
))

# --- 34 Demolition (medium, bomb + destructibles) ---
LEVELS.append(level(
    34, "Demolition", "medium", 9, 12, 5,
    pieces=[
        piece("b1", "right", [(0, 4), (1, 4)], kind="bomb"),
        line("p1", "right", 0, 1, 3),
        line("p2", "right", 0, 7, 3),
        line("p3", "left", 8, 2, 3),
        line("p4", "left", 8, 9, 3),
        piece("p5", "down", [(5, 0), (5, 1)]),
        piece("p6", "up", [(3, 11), (3, 10)]),
    ],
    obstacles=[
        # Destructible adjacent to b1 body so bomb clears them on exit.
        obstacle("d1", "destructible", (2, 4)),
        obstacle("d2", "destructible", (1, 5)),
        obstacle("w1", "wall", (4, 6)),
    ],
))

# --- 35 Domino Chain (medium, chain pieces — paired rows for chain links) ---
LEVELS.append(level(
    35, "Domino Chain", "medium", 9, 12, 5,
    pieces=[
        piece("c1", "right", [(0, 2), (1, 2)], kind="chain", chained_piece_id="c2"),
        piece("c2", "right", [(0, 5), (1, 5)], kind="chain", chained_piece_id="c3"),
        piece("c3", "right", [(0, 8), (1, 8)], kind="chain", chained_piece_id="c4"),
        piece("c4", "right", [(0, 10), (1, 10)], kind="standard"),
        line("p1", "left", 8, 1, 3),
        line("p2", "left", 8, 4, 3),
        line("p3", "left", 8, 7, 3),
        line("p4", "left", 8, 11, 3),
        line("p5", "down", 4, 0, 2),
    ],
))

# --- 36 Bigger Knot (hard) ---
LEVELS.append(level(
    36, "Bigger Knot", "hard", 10, 14, 4,
    pieces=[
        line("p1", "right", 0, 1, 4),
        line("p2", "right", 0, 3, 5),
        line("p3", "right", 0, 5, 4),
        line("p4", "left", 9, 2, 4),
        line("p5", "left", 9, 4, 5),
        line("p6", "left", 9, 6, 4),
        line("p7", "down", 2, 9, 5),
        line("p8", "down", 5, 9, 5),
        line("p9", "down", 8, 9, 5),
        line("p10", "right", 0, 7, 3),
        line("p11", "left", 9, 8, 3),
        piece("p12", "up", [(0, 13), (0, 12)]),
        piece("p13", "up", [(9, 13), (9, 12)]),
    ],
))

# --- 37 Switchback (hard, mostly L-shapes) ---
LEVELS.append(level(
    37, "Switchback", "hard", 10, 14, 4,
    pieces=[
        L("p1", "right", [(0, 0), (0, 1), (1, 1), (2, 1)]),
        L("p2", "right", [(0, 3), (1, 3), (1, 4), (2, 4), (3, 4)]),
        L("p3", "right", [(0, 6), (0, 7), (1, 7), (2, 7), (3, 7)]),
        L("p4", "left", [(9, 2), (8, 2), (8, 3), (7, 3)]),
        L("p5", "left", [(9, 5), (8, 5), (8, 6), (7, 6), (6, 6)]),
        L("p6", "left", [(9, 8), (9, 9), (8, 9), (7, 9)]),
        L("p7", "down", [(5, 9), (5, 10), (5, 11)]),
        L("p8", "down", [(2, 10), (2, 11), (3, 11), (3, 12)]),
        piece("p9", "right", [(0, 12), (1, 12)]),
        line("p10", "left", 9, 11, 3),
        line("p11", "right", 0, 13, 3),
        piece("p12", "up", [(9, 13), (9, 12)]),
    ],
))

# --- 38 Crossfire (hard) ---
LEVELS.append(level(
    38, "Crossfire", "hard", 10, 14, 4,
    pieces=[
        line("p1", "right", 0, 0, 4),
        line("p2", "right", 0, 2, 4),
        line("p3", "right", 0, 4, 4),
        line("p4", "right", 0, 6, 4),
        line("p5", "left", 9, 1, 4),
        line("p6", "left", 9, 3, 4),
        line("p7", "left", 9, 5, 4),
        line("p8", "left", 9, 7, 4),
        line("p9", "down", 4, 9, 5),
        line("p10", "down", 5, 9, 5),
        line("p11", "down", 6, 9, 5),
        line("p12", "down", 7, 9, 5),
        line("p13", "right", 0, 9, 3),
        piece("p14", "up", [(9, 13), (9, 12)]),
    ],
))

# --- 39 Heavy Industry (hard, dense rows) ---
LEVELS.append(level(
    39, "Heavy Industry", "hard", 10, 14, 4,
    pieces=[
        line("p1", "right", 0, 0, 5),
        line("p2", "right", 0, 1, 5),
        line("p3", "right", 0, 3, 5),
        line("p4", "right", 0, 4, 5),
        line("p5", "left", 9, 6, 5),
        line("p6", "left", 9, 7, 5),
        line("p7", "left", 9, 9, 5),
        line("p8", "left", 9, 10, 5),
        line("p9", "down", 2, 12, 2),
        line("p10", "down", 7, 12, 2),
        piece("p11", "up", [(0, 13), (0, 12)]),
        piece("p12", "up", [(9, 13), (9, 12)]),
    ],
))

# --- 40 Gate Maze (hard, gates aligned with piece direction) ---
LEVELS.append(level(
    40, "Gate Maze", "hard", 10, 14, 4,
    pieces=[
        line("p1", "right", 0, 1, 3),
        line("p2", "right", 0, 4, 3),
        line("p3", "right", 0, 7, 3),
        line("p4", "right", 0, 10, 3),
        line("p5", "left", 9, 2, 3),
        line("p6", "left", 9, 5, 3),
        line("p7", "left", 9, 8, 3),
        line("p8", "left", 9, 11, 3),
        line("p9", "right", 0, 13, 3),
    ],
    obstacles=[
        obstacle("g1", "gate", (5, 1), parameter="right"),
        obstacle("g2", "gate", (5, 4), parameter="right"),
        obstacle("g3", "gate", (5, 7), parameter="right"),
        obstacle("g4", "gate", (5, 10), parameter="right"),
        obstacle("g5", "gate", (5, 2), parameter="left"),
        obstacle("g6", "gate", (5, 5), parameter="left"),
        obstacle("g7", "gate", (5, 8), parameter="left"),
        obstacle("g8", "gate", (5, 11), parameter="left"),
    ],
))

# --- 41 Frozen Citadel (hard, frozen + decorative walls) ---
LEVELS.append(level(
    41, "Frozen Citadel", "hard", 10, 14, 4,
    pieces=[
        line("p1", "right", 0, 0, 3),
        line("p2", "right", 0, 2, 3),
        piece("f1", "right", [(0, 5), (1, 5), (2, 5)],
              kind="frozen", frozen_unlock_neighbors=2),
        piece("f2", "right", [(0, 8), (1, 8), (2, 8)],
              kind="frozen", frozen_unlock_neighbors=4),
        piece("f3", "right", [(0, 11), (1, 11), (2, 11)],
              kind="frozen", frozen_unlock_neighbors=6),
        line("p3", "left", 9, 1, 3),
        line("p4", "left", 9, 3, 3),
        line("p5", "left", 9, 6, 3),
        line("p6", "left", 9, 9, 3),
        line("p7", "left", 9, 12, 3),
    ],
    obstacles=[
        # Decorative walls outside any exit lane.
        obstacle("w1", "wall", (4, 4)),
        obstacle("w2", "wall", (5, 4)),
        obstacle("w3", "wall", (4, 7)),
        obstacle("w4", "wall", (5, 7)),
        obstacle("w5", "wall", (4, 10)),
        obstacle("w6", "wall", (5, 10)),
    ],
))

# --- 42 Key Master (hard, 3 key/lock pairs, no row-conflicts) ---
LEVELS.append(level(
    42, "Key Master", "hard", 10, 14, 4,
    pieces=[
        piece("k1", "right", [(0, 1), (1, 1)], kind="lockedKey", color_group=1),
        piece("k2", "right", [(0, 4), (1, 4)], kind="lockedKey", color_group=2),
        piece("k3", "right", [(0, 7), (1, 7)], kind="lockedKey", color_group=3),
        piece("l1", "left", [(9, 2), (8, 2), (7, 2)], kind="lockedLock", color_group=1),
        piece("l2", "left", [(9, 5), (8, 5), (7, 5)], kind="lockedLock", color_group=2),
        piece("l3", "left", [(9, 8), (8, 8), (7, 8)], kind="lockedLock", color_group=3),
        line("p1", "right", 0, 10, 3),
        line("p2", "left", 9, 11, 3),
        line("p3", "right", 0, 12, 3),
        line("p4", "left", 9, 13, 3),
    ],
))

# --- 43 Bombing Run (hard, bombs + destructibles adjacent to bomb body) ---
LEVELS.append(level(
    43, "Bombing Run", "hard", 10, 14, 4,
    pieces=[
        piece("b1", "right", [(0, 1), (1, 1)], kind="bomb"),
        piece("b2", "right", [(0, 6), (1, 6)], kind="bomb"),
        piece("b3", "right", [(0, 11), (1, 11)], kind="bomb"),
        line("p1", "right", 0, 3, 3),
        line("p2", "right", 0, 8, 3),
        line("p3", "left", 9, 2, 3),
        line("p4", "left", 9, 7, 3),
        line("p5", "left", 9, 12, 3),
        line("p6", "right", 0, 13, 3),
    ],
    obstacles=[
        # Destructibles adjacent to each bomb body so bombs clear them on exit.
        obstacle("d1", "destructible", (2, 1)),
        obstacle("d2", "destructible", (1, 0)),
        obstacle("d3", "destructible", (2, 6)),
        obstacle("d4", "destructible", (1, 5)),
        obstacle("d5", "destructible", (2, 11)),
        obstacle("d6", "destructible", (1, 10)),
    ],
))

# --- 44 Chain Reaction II (hard, chain pieces) ---
LEVELS.append(level(
    44, "Chain Reaction II", "hard", 10, 14, 4,
    pieces=[
        piece("c1", "right", [(0, 1), (1, 1)], kind="chain", chained_piece_id="c2"),
        piece("c2", "right", [(0, 4), (1, 4)], kind="chain", chained_piece_id="c3"),
        piece("c3", "right", [(0, 7), (1, 7)], kind="chain", chained_piece_id="c4"),
        piece("c4", "right", [(0, 10), (1, 10)], kind="chain", chained_piece_id="c5"),
        piece("c5", "right", [(0, 12), (1, 12)], kind="standard"),
        line("p1", "left", 9, 0, 4),
        line("p2", "left", 9, 3, 4),
        line("p3", "left", 9, 6, 4),
        line("p4", "left", 9, 9, 4),
        line("p5", "left", 9, 13, 4),
        line("p6", "right", 0, 2, 3),
    ],
))

# --- 45 Time Pressure (hard, clearInSeconds goal) ---
LEVELS.append(level(
    45, "Time Pressure", "hard", 10, 14, 4,
    pieces=[
        line("p1", "right", 0, 0, 4),
        line("p2", "right", 0, 2, 4),
        line("p3", "right", 0, 4, 4),
        line("p4", "right", 0, 6, 4),
        line("p5", "right", 0, 8, 4),
        line("p6", "right", 0, 10, 4),
        line("p7", "right", 0, 12, 4),
        line("p8", "left", 9, 1, 4),
        line("p9", "left", 9, 3, 4),
        line("p10", "left", 9, 5, 4),
        line("p11", "left", 9, 7, 4),
        line("p12", "left", 9, 9, 4),
        line("p13", "left", 9, 11, 4),
        line("p14", "left", 9, 13, 4),
    ],
    goal={"kind": "clearInSeconds", "value": 90},
))

# --- 46 Color Hunt (hard, clearColorGroup=1 — clear targets, distractors stay) ---
LEVELS.append(level(
    46, "Color Hunt", "hard", 10, 14, 4,
    pieces=[
        # Group 1 (target) — must clear all of these
        piece("g1a", "right", [(0, 1), (1, 1), (2, 1)], color_group=1),
        piece("g1b", "right", [(0, 5), (1, 5), (2, 5)], color_group=1),
        piece("g1c", "left", [(9, 8), (8, 8), (7, 8)], color_group=1),
        piece("g1d", "left", [(9, 12), (8, 12), (7, 12)], color_group=1),
        # Distractors (group 2)
        piece("g2a", "right", [(0, 3), (1, 3), (2, 3)], color_group=2),
        piece("g2b", "right", [(0, 7), (1, 7), (2, 7)], color_group=2),
        piece("g2c", "left", [(9, 2), (8, 2), (7, 2)], color_group=2),
        piece("g2d", "left", [(9, 6), (8, 6), (7, 6)], color_group=2),
        piece("g2e", "left", [(9, 10), (8, 10), (7, 10)], color_group=2),
        piece("g2f", "right", [(0, 9), (1, 9), (2, 9)], color_group=2),
        piece("g2g", "left", [(9, 13), (8, 13), (7, 13)], color_group=2),
    ],
    goal={"kind": "clearColorGroup", "value": 1},
))

# --- 47 Free the Gem (hard, freePiece goal) ---
LEVELS.append(level(
    47, "Free the Gem", "hard", 10, 14, 4,
    pieces=[
        # The "gem" — boxed in. Player must clear blockers so it can fly out.
        piece("gem", "right", [(0, 6), (1, 6), (2, 6), (3, 6)], color_group=3),
        # Direct blockers in front of gem
        piece("p1", "down", [(5, 4), (5, 5), (5, 6), (5, 7)]),
        piece("p2", "down", [(7, 4), (7, 5), (7, 6), (7, 7)]),
        # Other clutter
        line("p3", "right", 0, 1, 3),
        line("p4", "right", 0, 11, 3),
        line("p5", "left", 9, 2, 3),
        line("p6", "left", 9, 9, 3),
        line("p7", "left", 9, 12, 3),
        line("p8", "right", 0, 13, 3),
    ],
    goal={"kind": "freePiece", "value": "gem"},
))

# --- 48 No Mistakes (hard, clearWithoutMistakes goal) ---
LEVELS.append(level(
    48, "No Mistakes", "hard", 10, 14, 5,
    pieces=[
        line("p1", "right", 0, 1, 4),
        line("p2", "right", 0, 3, 4),
        line("p3", "right", 0, 5, 4),
        line("p4", "right", 0, 7, 4),
        line("p5", "right", 0, 9, 4),
        line("p6", "right", 0, 11, 4),
        line("p7", "left", 9, 2, 4),
        line("p8", "left", 9, 4, 4),
        line("p9", "left", 9, 6, 4),
        line("p10", "left", 9, 8, 4),
        line("p11", "left", 9, 10, 4),
        line("p12", "left", 9, 12, 4),
        line("p13", "right", 0, 0, 4),
        line("p14", "left", 9, 13, 4),
    ],
    goal={"kind": "clearWithoutMistakes"},
))

# --- 49 Master's Test (hard, mixed mechanics, no row-conflicts) ---
LEVELS.append(level(
    49, "Master's Test", "hard", 10, 14, 4,
    pieces=[
        piece("k1", "right", [(0, 0), (1, 0)], kind="lockedKey", color_group=1),
        piece("l1", "left", [(9, 1), (8, 1), (7, 1)], kind="lockedLock", color_group=1),
        piece("b1", "right", [(0, 5), (1, 5)], kind="bomb"),
        piece("c1", "right", [(0, 8), (1, 8)], kind="chain", chained_piece_id="c2"),
        piece("c2", "right", [(0, 10), (1, 10)], kind="standard"),
        piece("f1", "right", [(0, 12), (1, 12), (2, 12)],
              kind="frozen", frozen_unlock_neighbors=3),
        line("p1", "right", 0, 2, 3),
        line("p2", "right", 0, 7, 3),
        line("p3", "left", 9, 3, 3),
        line("p4", "left", 9, 6, 3),
        line("p5", "left", 9, 9, 3),
        line("p6", "left", 9, 13, 3),
    ],
    obstacles=[
        obstacle("d1", "destructible", (2, 5)),
        obstacle("d2", "destructible", (1, 4)),
        obstacle("w1", "wall", (4, 11)),
    ],
))

# --- 50 Final Maze (hard finale) ---
LEVELS.append(level(
    50, "Final Maze", "hard", 10, 14, 3,
    pieces=[
        line("p1", "right", 0, 0, 4),
        line("p2", "right", 0, 2, 4),
        line("p3", "right", 0, 4, 4),
        line("p4", "right", 0, 6, 4),
        line("p5", "right", 0, 8, 4),
        line("p6", "right", 0, 10, 4),
        line("p7", "right", 0, 12, 4),
        line("p8", "left", 9, 1, 4),
        line("p9", "left", 9, 3, 4),
        line("p10", "left", 9, 5, 4),
        line("p11", "left", 9, 7, 4),
        line("p12", "left", 9, 9, 4),
        line("p13", "left", 9, 11, 4),
        line("p14", "left", 9, 13, 4),
        piece("p15", "up", [(5, 1), (5, 0)]),
    ],
    three_star=1, two_star=2,
))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.normpath(os.path.join(here, "..", "MazeArrows", "Data", "levels.json"))
    with open(json_path) as f:
        existing = json.load(f)

    # Drop any old level with index >= 26 so re-running is safe.
    existing = [l for l in existing if l['index'] < 26]

    failed = 0
    for lvl in LEVELS:
        err = validate_level(lvl)
        if err:
            print(f"❌ Level {lvl['index']} {lvl['name']}: {err}", file=sys.stderr)
            failed += 1
        else:
            print(f"✓ Level {lvl['index']:2d} {lvl['name']:<22} ({len(lvl['pieces'])} pieces, {len(lvl.get('obstacles', []))} obs)")

    if failed:
        print(f"\n{failed} level(s) failed validation. Aborting.", file=sys.stderr)
        sys.exit(1)

    merged = sorted(existing + LEVELS, key=lambda l: l['index'])
    with open(json_path, 'w') as f:
        json.dump(merged, f, indent=2, sort_keys=True)
    print(f"\nWrote {len(merged)} levels to {json_path}")


if __name__ == "__main__":
    main()
