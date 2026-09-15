#!/usr/bin/env python3
"""Deep walkability / door-hole audit of current school_map.json (GM space)."""
from __future__ import annotations

import json
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
d = json.loads((ROOT / "datafiles" / "school_map.json").read_text(encoding="utf-8"))

floors = set()
walls = defaultdict(set)
for q in d["quads"]:
    x, z = float(q["x"]), float(q["z"])
    if q["k"] == "floor":
        floors.add((x, z))
    elif q["k"] in "nsew":
        walls[(x, z)].add(q["k"])

DELTA = {"n": (0.0, -2.0), "s": (0.0, 2.0), "w": (-2.0, 0.0), "e": (2.0, 0.0)}
OPP = {"n": "s", "s": "n", "w": "e", "e": "w"}


def blocked(a, b):
    x0, z0 = a
    x1, z1 = b
    dx, dz = x1 - x0, z1 - z0
    if dx == 2:
        return "e" in walls[(x0, z0)] or "w" in walls[(x1, z1)]
    if dx == -2:
        return "w" in walls[(x0, z0)] or "e" in walls[(x1, z1)]
    if dz == -2:
        return "n" in walls[(x0, z0)] or "s" in walls[(x1, z1)]
    if dz == 2:
        return "s" in walls[(x0, z0)] or "n" in walls[(x1, z1)]
    return True


def bfs():
    seen = set()
    q = deque([(0.0, 2.0)])
    seen.add((0.0, 2.0))
    while q:
        x, z = q.popleft()
        for dx, dz in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            n = (x + dx, z + dz)
            if n in seen or n not in floors:
                continue
            if blocked((x, z), n):
                continue
            seen.add(n)
            q.append(n)
    return seen


print("=== DOORS: wall on this face vs opposing wall on neighbor ===")
for door in d["doors"]:
    x, z, side = door["x"], door["z"], door["side"]
    dx, dz = DELTA[side]
    nx, nz = x + dx, z + dz
    has = side in walls[(x, z)]
    neigh = (nx, nz) in floors
    opp = (OPP[side] in walls[(nx, nz)]) if neigh else None
    print(
        f"  {door['kind']:7} ({x:6.1f},{z:7.1f}) {side} "
        f"wall_here={has} neighbor={neigh} opp_wall={opp}"
    )

reach = bfs()
print()
print(f"floors={len(floors)} reachable={len(reach)} unreachable={len(floors - reach)}")

print()
print("=== FRONTIER: reachable tile blocked from an adjacent floor ===")
front = []
for x, z in sorted(reach):
    for side, (dx, dz) in DELTA.items():
        nb = (x + dx, z + dz)
        if nb not in floors or nb in reach:
            continue
        front.append((x, z, side, nb, sorted(walls[(x, z)]), sorted(walls[nb])))
print(f"frontier edges={len(front)}")
for row in front[:50]:
    print(f"  {row[0], row[1]} {row[2]} -> {row[3]} here={row[4]} there={row[5]}")

print()
print("=== notebooks on reachable tiles? ===")
for n in d.get("notebooks", []):
    t = (round(n["x"] / 2) * 2, round(n["z"] / 2) * 2)
    print(f"  {n['spr']} at ({n['x']},{n['z']}) tile={t} reachable={t in reach} floor={t in floors}")
