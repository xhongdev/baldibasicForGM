#!/usr/bin/env python3
"""Unity 1.4.3 only: which walls each door tile actually has, vs current map."""
from __future__ import annotations

import json
import math
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "datafiles" / "school_map.json"
UNITY = Path(
    r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\Scene\Scenes\School.unity"
)


def u_to_p(ux, uz):
    return round((ux - 5.0) * 0.2, 4), round((uz + 5.0) * -0.2 + 2.0, 4)


def snap2(v):
    return round(v / 2.0) * 2.0


def parse():
    lines = UNITY.read_text(encoding="utf-8", errors="replace").splitlines()
    blocks = []
    cur = None
    for line in lines:
        if line.startswith("--- !u!"):
            if cur:
                blocks.append(cur)
            m = re.match(r"--- !u!(\d+) &(\d+)", line)
            cur = {"type": m.group(1) if m else "", "id": m.group(2) if m else "", "lines": []}
        elif cur is not None:
            cur["lines"].append(line)
    if cur:
        blocks.append(cur)

    def field(b, key):
        for ln in b["lines"]:
            s = ln.strip()
            if s.startswith(key + ":"):
                return s.split(":", 1)[1].strip()
        return ""

    gos = {}
    trs = {}
    for b in blocks:
        if b["type"] == "1":
            comps = re.findall(r"fileID: (\d+)", "\n".join(b["lines"]))
            gos[b["id"]] = {"name": field(b, "m_Name").strip(), "comps": comps}
        elif b["type"] == "4":
            go = field(b, "m_GameObject")
            pos = field(b, "m_LocalPosition")
            rot = field(b, "m_LocalRotation")
            father = field(b, "m_Father")
            gm = re.search(r"fileID: (\d+)", go)
            pm = re.search(r"x: ([-\d.]+), y: ([-\d.]+), z: ([-\d.]+)", pos)
            rm = re.search(r"x: ([-\d.]+), y: ([-\d.]+), z: ([-\d.]+), w: ([-\d.]+)", rot)
            fm = re.search(r"fileID: (\d+)", father)
            if pm:
                trs[b["id"]] = {
                    "go": gm.group(1) if gm else "",
                    "x": float(pm.group(1)),
                    "y": float(pm.group(2)),
                    "z": float(pm.group(3)),
                    "ry": float(rm.group(2)) if rm else 0.0,
                    "rw": float(rm.group(4)) if rm else 1.0,
                    "father": fm.group(1) if fm else "0",
                    "children": [],
                }
    # children lists
    for tid, t in trs.items():
        fa = t["father"]
        if fa in trs:
            trs[fa]["children"].append(tid)

    go_by_tr = {tid: t["go"] for tid, t in trs.items()}

    def world(tid, guard=0):
        if tid not in trs or guard > 20:
            return 0.0, 0.0, 0.0
        t = trs[tid]
        px, py, pz = world(t["father"], guard + 1) if t["father"] in trs else (0.0, 0.0, 0.0)
        return px + t["x"], py + t["y"], pz + t["z"]

    # For each door-like GO, list child wall names and their local offsets
    door_names = []
    for gid, g in gos.items():
        n = g["name"]
        if n.startswith("Hall_2Wall_Door") or n.startswith("Hall_2Wall_Faculty") or n.startswith("Hall_SwingDoor") or n.startswith("Cafe_Door") or n == "Entrance (0)":
            door_names.append((gid, g))

    print("=== UNITY DOOR TILES: child walls vs local offset ===")
    results = []
    for gid, g in door_names:
        tids = [c for c in g["comps"] if c in trs]
        if not tids:
            print("NO TR", g["name"])
            continue
        tid = tids[0]
        wx, wy, wz = world(tid)
        gx, gz = u_to_p(wx, wz)
        kids = []
        for cid in trs[tid]["children"]:
            cgo = gos.get(trs[cid]["go"], {})
            cname = cgo.get("name", "?")
            ct = trs[cid]
            kids.append((cname, ct["x"], ct["y"], ct["z"]))
        # classify wall by local offset (Unity 10-unit tile, walls at +/-5)
        sides = []
        for cname, lx, ly, lz in kids:
            if not cname.startswith("Wall"):
                continue
            if abs(lz) >= abs(lx) and lz < -3:
                sides.append("n")
            elif abs(lz) >= abs(lx) and lz > 3:
                sides.append("s")
            elif abs(lx) >= abs(lz) and lx < -3:
                sides.append("w")
            elif abs(lx) >= abs(lz) and lx > 3:
                sides.append("e")
        missing = {"n", "s", "w", "e"} - set(sides)
        print(f"{g['name']:28} u=({wx:7.1f},{wz:7.1f}) p=({gx:6.1f},{gz:7.1f}) walls={sorted(sides)} hole={sorted(missing)}")
        results.append({"name": g["name"], "gx": gx, "gz": gz, "walls": sorted(sides), "hole": sorted(missing)})
    return results


def main():
    unity = parse()
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    walls = defaultdict(set)
    floors = {}
    for q in data["quads"]:
        x, z = float(q["x"]), float(q["z"])
        if q["k"] == "floor":
            floors[(x, z)] = q.get("m")
        elif q["k"] in "nsew":
            walls[(x, z)].add(q["k"])
    print("\n=== CURRENT MAP vs UNITY HOLE ===")
    for u in unity:
        tile = (snap2(u["gx"]), snap2(u["gz"]))
        have = sorted(walls.get(tile, set()))
        cur = [d for d in data["doors"] if abs(d["x"] - tile[0]) < 0.01 and abs(d["z"] - tile[1]) < 0.01]
        print(
            f"tile {tile} unity_walls={u['walls']} unity_hole={u['hole']} "
            f"map_walls={have} doors={[(d['kind'], d['side']) for d in cur]}"
        )


if __name__ == "__main__":
    main()
