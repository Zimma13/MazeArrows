#!/usr/bin/env python3
"""Compile fixed authored layouts for chapter 241–260; never modify legacy levels.

Default: validate the source, dependency semantics, every reachable state and the
committed output. --write updates only levels-v2.json and content-manifest.json.
--contact-sheet PATH additionally creates a designer PNG (Pillow is optional).
No random generator or old level baker is used by this tool.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
SOURCE = HERE / "authored-layouts.json"
OUTPUT = PROJECT / "MazeArrows/Data/levels-v2.json"
LEGACY = PROJECT / "MazeArrows/Data/levels.json"
MANIFEST = HERE / "content-manifest.json"
LEGACY_SHA256 = "f781f36eb3a64e8e2e84c5fb3e693e83e0f1425cc37a801d63acd7a06fb223c9"
DIRECTIONS = {"right": (1, 0), "left": (-1, 0), "down": (0, 1), "up": (0, -1)}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def forward_ray(piece, width, height):
    dx, dy = DIRECTIONS[piece["direction"]]
    x, y = piece["cells"][-1]
    cells = []
    x, y = x + dx, y + dy
    while 0 <= x < width and 0 <= y < height:
        cells.append((x, y))
        x, y = x + dx, y + dy
    return set(cells)


def topological_order(dependencies, subset=None):
    pending = set(dependencies) if subset is None else set(subset)
    removed = set()
    order = []
    while pending:
        choices = sorted(n for n in pending if dependencies[n] <= removed)
        require(choices, f"Cyclic dependency or incomplete predecessor set: {sorted(pending)}")
        node = choices[0]
        removed.add(node)
        pending.remove(node)
        order.append(node)
    return order


def reachable_states(dependencies):
    """Exhaust every reachable removed-set, not just one favourable solution."""
    names = sorted(dependencies)
    bits = {n: 1 << i for i, n in enumerate(names)}
    required = {n: sum(bits[p] for p in dependencies[n]) for n in names}
    full = (1 << len(names)) - 1
    visited = {0}
    todo = deque([0])
    transitions = 0
    while todo:
        removed = todo.popleft()
        available = [n for n in names if not removed & bits[n] and removed & required[n] == required[n]]
        require(removed == full or available, "Reachable dead end")
        for n in available:
            after = removed | bits[n]
            # Every previously available surviving arrow stays available.
            require(all(after & required[q] == required[q] for q in available if q != n), "Non-monotone move")
            transitions += 1
            if after not in visited:
                visited.add(after)
                todo.append(after)
    require(full in visited, "No full-clear state")
    return len(visited), transitions


def validate_layout(layout):
    index = layout["index"]
    nodes = layout["nodes"]
    gates = layout["gates"]
    width, height = layout["width"], layout["height"]
    require(layout["count"] == len(nodes), f"{index}: stale arrow count")
    require(set(nodes) == set(layout["deps"]), f"{index}: undeclared graph node")
    require(1 <= len(gates) <= 4, f"{index}: gate count")
    keys = {n for n in nodes if n in ("KA", "KB")}
    require(keys and len(keys) <= 2, f"{index}: key count")
    occupied = {}
    rays = {}
    for name, piece in nodes.items():
        cells = list(map(tuple, piece["cells"]))
        require(len(cells) >= 2, f"{index}/{name}: short piece")
        require(len(set(cells)) == len(cells), f"{index}/{name}: self intersection")
        for cell in cells:
            x, y = cell
            require(0 <= x < width and 0 <= y < height, f"{index}/{name}: out of bounds")
            require(cell not in occupied, f"{index}/{name}: overlaps {occupied.get(cell)}")
            occupied[cell] = name
        require(all(abs(a[0]-b[0]) + abs(a[1]-b[1]) == 1 for a,b in zip(cells,cells[1:])), f"{index}/{name}: disconnected body")
        require((cells[-1][0]-cells[-2][0], cells[-1][1]-cells[-2][1]) == DIRECTIONS[piece["direction"]], f"{index}/{name}: head mismatch")
        rays[name] = forward_ray(piece, width, height)
        require(not rays[name].intersection(cells), f"{index}/{name}: self-blocked head ray")
    gate_cells = set()
    for name, (key, x, y) in gates.items():
        require(key in keys, f"{index}/{name}: invalid key reference")
        require(0 <= x < width and 0 <= y < height, f"{index}/{name}: out of bounds")
        require((x,y) not in occupied and (x,y) not in gate_cells, f"{index}/{name}: overlapping gate")
        gate_cells.add((x,y))
    require({g[0] for g in gates.values()} == keys, f"{index}: unused key")
    physical = {}
    gate_paths = {}
    dependencies = {}
    for name, lane in rays.items():
        physical[name] = {occupied[c] for c in lane if c in occupied}
        gate_paths[name] = {g for g, (_,x,y) in gates.items() if (x,y) in lane}
        require(physical[name] == set(layout["deps"][name]), f"{index}/{name}: unexpected physical edges: {physical[name]} vs {layout['deps'][name]}")
        require(gate_paths[name] == set(layout["gatepaths"].get(name, [])), f"{index}/{name}: unexpected gates on full ray")
        dependencies[name] = physical[name] | {gates[g][0] for g in gate_paths[name]}
    solution = topological_order(dependencies)
    witnesses = []
    for gate, (key, _, _) in gates.items():
        found = False
        for target, path in gate_paths.items():
            if gate not in path:
                continue
            without = physical[target] | {gates[g][0] for g in path - {gate}}
            ancestors = set(without)
            while True:
                expanded = ancestors | {p for n in ancestors for p in dependencies[n]}
                if expanded == ancestors:
                    break
                ancestors = expanded
            if key in ancestors or target in ancestors:
                continue
            prefix = topological_order(dependencies, ancestors)
            require(not dependencies[target] <= ancestors and without <= ancestors, f"{index}/{gate}: invalid witness")
            witnesses.append({"gate": gate, "target": target, "legalPrefix": prefix, "closedKey": key})
            found = True
            break
        require(found, f"{index}/{gate}: decorative/redundant gate has no reachable witness")
    if index == 241:
        require({n for n, deps in dependencies.items() if not deps} == {"KA"}, "241: tutorial key must be sole legal first move")
    for first, second in (("X","Y"),) if index == 251 else (("U","V"),) if index == 258 else ():
        require(gate_paths[first] == gate_paths[second] == {"ga1"}, f"{index}: missing shared gate")
        a,b = DIRECTIONS[nodes[first]["direction"]], DIRECTIONS[nodes[second]["direction"]]
        require(a[0]*b[0] + a[1]*b[1] == 0, f"{index}: shared rays must be perpendicular")
    states, transitions = reachable_states(dependencies)
    return {"index": index, "id": f"story_{index}", "titleRU": layout["titleRU"], "titleEN": layout["titleEN"], "width": width, "height": height, "arrowCount": len(nodes), "gateCount": len(gates), "keyCount": len(keys), "physicalPredecessors": {n:sorted(physical[n]) for n in nodes}, "gatesOnFullRay": {n:sorted(gate_paths[n]) for n in nodes if gate_paths[n]}, "allPredecessors": {n:sorted(dependencies[n]) for n in nodes}, "solution": solution, "gateWitnesses": witnesses, "reachableStatesChecked": states, "legalTransitionsChecked": transitions}


def compile_level(layout):
    index = layout["index"]
    identity = lambda name: f"s{index}_{name}"
    pieces = []
    for name, node in layout["nodes"].items():
        piece = {"id": identity(name), "cells": [{"x":x,"y":y} for x,y in node["cells"]], "direction": node["direction"], "kind": "lockedKey" if name in ("KA","KB") else "standard", "crackLevel": 0}
        if name in ("KA","KB"):
            piece["colorGroup"] = 1 if name == "KA" else 2
        pieces.append(piece)
    obstacles = [{"id": identity(name), "kind": "keyGate", "cell": {"x":x,"y":y}, "parameter": identity(key), "colorGroup": 1 if key == "KA" else 2} for name,(key,x,y) in layout["gates"].items()]
    return {"id":f"story_{index}", "index":index, "rulesVersion":2, "name":layout["titleEN"], "difficulty":layout["difficulty"], "width":layout["width"], "height":layout["height"], "lives":4, "goal":{"kind":"clearAll"}, "threeStarMaxMistakes":0, "twoStarMaxMistakes":1, "pieces":pieces, "obstacles":obstacles}


def contact_sheet(layouts, destination):
    from PIL import Image, ImageDraw, ImageFont
    scale = 21
    tile_w, tile_h = 410, 470
    sheet = Image.new("RGB", (tile_w*4, tile_h*5), "#ffffff")
    draw = ImageDraw.Draw(sheet)
    for i, layout in enumerate(layouts):
        ox, oy = (i%4)*tile_w, (i//4)*tile_h
        draw.text((ox+15,oy+10), f"{layout['index']}: {layout['titleEN']}", fill="#202f40")
        draw.text((ox+15,oy+27), f"{len(layout['nodes'])} arrows / {len(layout['gates'])} gate cells", fill="#66717d")
        bx = ox + (tile_w-layout['width']*scale)//2
        by = oy + 63
        def point(cell):
            return bx+cell[0]*scale, by+cell[1]*scale
        for x in range(layout['width']):
            for y in range(layout['height']):
                px,py = point((x,y)); draw.ellipse((px-1,py-1,px+1,py+1), fill="#d9dde0")
        for name, piece in layout['nodes'].items():
            points = [point(c) for c in piece['cells']]
            color = "#ae6a08" if name == "KA" else "#7055b5" if name == "KB" else "#344c63"
            draw.line(points, fill=color, width=4, joint='curve')
            x,y = points[-1]; dx,dy = DIRECTIONS[piece['direction']]
            draw.polygon([(x+dx*6,y+dy*6),(x-dx*5-dy*5,y-dy*5+dx*5),(x-dx*5+dy*5,y-dy*5-dx*5)], fill=color)
            x,y = points[len(points)//2]; draw.text((x+4,y+2), name, fill=color)
        for name,(key,x,y) in layout['gates'].items():
            x,y=point((x,y)); color="#ae6a08" if key=="KA" else "#7055b5"
            draw.rounded_rectangle((x-8,y-8,x+8,y+8),radius=3,fill=color)
            draw.text((x-3,y-6),"A" if key=="KA" else "B",fill="white")
        draw.line((ox+4,oy+tile_h-3,ox+tile_w-4,oy+tile_h-3), fill="#e2e6ea")
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Write only the separate V2 package and its manifest")
    parser.add_argument("--contact-sheet", type=Path)
    args = parser.parse_args()
    legacy_hash = hashlib.sha256(LEGACY.read_bytes()).hexdigest()
    require(legacy_hash == LEGACY_SHA256, "Legacy levels.json changed: restore/inspect it before building V2")
    layouts = json.loads(SOURCE.read_text())
    require([s['index'] for s in layouts] == list(range(241,261)), "Expected exactly 241–260 in order")
    reports = [validate_layout(s) for s in layouts]
    levels = [compile_level(s) for s in layouts]
    manifest = {"chapter":8, "rulesVersion":2, "legacySHA256":LEGACY_SHA256, "source":"authored-layouts.json", "method":"Fixed authored coordinates; exact full-ray graph verification; exhaustive reachable-state checks; one counterfactual witness per gate cell.", "levels":reports}
    for path, value in ((OUTPUT,levels),(MANIFEST,manifest)):
        content = json.dumps(value,ensure_ascii=False,indent=2)+"\n"
        if args.write:
            path.write_text(content)
        else:
            require(path.exists() and path.read_text()==content, f"{path.name} differs from authored source; run --write after reviewing the layout")
    if args.contact_sheet:
        contact_sheet(layouts,args.contact_sheet)
    print(f"Validated {len(levels)} fixed levels; {sum(len(l['pieces']) for l in levels)} arrows; {sum(len(l['obstacles']) for l in levels)} gate cells.")
    print(f"Exhaustive graph check: {sum(r['reachableStatesChecked'] for r in reports):,} reachable states / {sum(r['legalTransitionsChecked'] for r in reports):,} legal transitions. Every gate has a reachable counterfactual witness.")
    print(f"Legacy SHA-256 unchanged: {legacy_hash}")
    print(" ".join(f"{r['index']}:{r['arrowCount']}" for r in reports))


if __name__ == '__main__':
    main()
