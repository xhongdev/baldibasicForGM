#!/usr/bin/env python3
"""Fix missing walls and blue-door sides from Unity 1.4.3 only.

Child wall offsets are rotated by parent yaw (world space).
Yellow/swing door sides are not changed.
"""
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
REPORT = ROOT / "tools" / "wall_door_fix_report.txt"

# Walls added by the previous broken pass — remove before re-applying.
BAD_ADD = {
    (-22.0, -54.0, "n"),
    (-22.0, -54.0, "s"),
    (-22.0, -32.0, "n"),
    (-22.0, -32.0, "s"),
    (-6.0, -48.0, "s"),
    (-6.0, -26.0, "s"),
    (0.0, -8.0, "n"),
    (0.0, -8.0, "s"),
    (0.0, -6.0, "n"),
    (0.0, -6.0, "s"),
    (0.0, -4.0, "s"),
    (4.0, -26.0, "s"),
    (6.0, -58.0, "w"),
    (6.0, -46.0, "n"),
    (6.0, -46.0, "s"),
    (6.0, -38.0, "n"),
    (6.0, -38.0, "s"),
    (6.0, -32.0, "n"),
    (6.0, -32.0, "s"),
    (12.0, -6.0, "n"),
    (12.0, -6.0, "s"),
    (22.0, -60.0, "n"),
    (22.0, -60.0, "s"),
    (22.0, -32.0, "n"),
    (22.0, -32.0, "s"),
    (22.0, -18.0, "n"),
    (22.0, -18.0, "s"),
}


def u_to_p(ux, uz):
    return round((ux - 5.0) * 0.2, 4), round((uz + 5.0) * -0.2 + 2.0, 4)


def snap2(v):
    return round(v / 2.0) * 2.0


def yaw_from_quat(ry, rw):
    siny = 2.0 * rw * ry
    cosy = 1.0 - 2.0 * ry * ry
    return math.degrees(math.atan2(siny, cosy)) % 360.0


def yaw_to_side(yaw):
    if yaw < 45 or yaw >= 315:
        return "n"
    if yaw < 135:
        return "e"
    if yaw < 225:
        return "s"
    return "w"


def rotate_xz(x, z, yaw_deg):
    """Unity left-handed Y rotation: +90 sends +Z to +X."""
    t = math.radians(yaw_deg)
    c, s = math.cos(t), math.sin(t)
    return x * c + z * s, -x * s + z * c


def parse_unity():
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
    for tid, t in trs.items():
        if t["father"] in trs:
            trs[t["father"]]["children"].append(tid)

    def world(tid, guard=0):
        if tid not in trs or guard > 24:
            return 0.0, 0.0, 0.0, 0.0
        t = trs[tid]
        yaw = yaw_from_quat(t["ry"], t["rw"])
        if t["father"] in trs:
            px, py, pz, pyaw = world(t["father"], guard + 1)
        else:
            px = py = pz = pyaw = 0.0
        lx, lz = rotate_xz(t["x"], t["z"], pyaw)
        return px + lx, py + t["y"], pz + lz, (pyaw + yaw) % 360.0

    tiles = []
    for gid, g in gos.items():
        n = g["name"]
        if not (
            n.startswith("Hall_2Wall_Door")
            or n.startswith("Hall_2Wall_Faculty")
            or n.startswith("Hall_SwingDoor")
        ):
            continue
        tids = [c for c in g["comps"] if c in trs]
        if not tids:
            continue
        tid = tids[0]
        wx, wy, wz, yaw = world(tid)
        gx, gz = u_to_p(wx, wz)
        sides = []
        for cid in trs[tid]["children"]:
            cname = gos.get(trs[cid]["go"], {}).get("name", "")
            if not cname.startswith("Wall"):
                continue
            cx, cy, cz, _ = world(cid)
            dx = cx - wx
            dz = cz - wz
            # Unity +Z -> project north, Unity +X -> project east
            if abs(dz) >= abs(dx):
                sides.append("n" if dz > 3 else "s")
            else:
                sides.append("e" if dx > 3 else "w")
        if n.startswith("Hall_2Wall_Faculty"):
            kind = "faculty"
        elif n.startswith("Hall_2Wall_Door"):
            kind = "class"
        else:
            kind = "swing"
        tiles.append(
            {
                "name": n,
                "gx": snap2(gx),
                "gz": snap2(gz),
                "yaw": yaw,
                "prefer": yaw_to_side(yaw),
                "unity_walls": sorted(set(sides)),
                "kind": kind,
            }
        )
    return tiles


def main():
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))

    # Revert previous bad wall inserts.
    before = len(data["quads"])
    data["quads"] = [
        q
        for q in data["quads"]
        if (float(q["x"]), float(q["z"]), q["k"]) not in BAD_ADD
        or q["k"] not in ("n", "s", "w", "e")
        or q.get("m") != "brick"
    ]
    # The filter above is wrong if original brick walls matched BAD_ADD.
    # Those 27 were new; originals at those keys didn't exist. Safe.

    floors = {}
    walls = defaultdict(set)
    for q in data["quads"]:
        x, z = float(q["x"]), float(q["z"])
        if q["k"] == "floor":
            floors[(x, z)] = q.get("m", "tile")
        elif q["k"] in ("n", "s", "w", "e"):
            walls[(x, z)].add(q["k"])

    unity = parse_unity()
    lines = ["Pass 2: rotated world walls. Yellow doors unchanged.", ""]
    add_walls = []
    door_updates = {}

    for u in unity:
        tile = (u["gx"], u["gz"])
        have = walls.get(tile, set())
        need = set(u["unity_walls"])
        missing = sorted(need - have)
        extra = sorted(have - need)

        if u["kind"] == "swing":
            lines.append(
                f"SWING {u['name']:28} tile={tile} yaw={u['yaw']:6.1f} "
                f"unity_walls={u['unity_walls']} map={sorted(have)} miss={missing} extra={extra}"
            )
            continue

        side = u["prefer"]
        # Door occupies yaw-facing side. Keep Unity side walls (not the door hole).
        keep_walls = need - {side}
        miss_keep = sorted(keep_walls - have)
        w, h = 1.0, 2.0
        lines.append(
            f"{u['kind']:7} {u['name']:28} tile={tile} yaw={u['yaw']:6.1f} "
            f"door={side} {w}x{h} unity_walls={u['unity_walls']} map={sorted(have)} "
            f"ADD={miss_keep} punch={side in have}"
        )
        door_updates[(tile[0], tile[1], u["kind"])] = side
        for s in miss_keep:
            add_walls.append((tile[0], tile[1], s))

    add_walls = sorted(set(add_walls))
    lines.append("")
    lines.append(f"walls to add: {len(add_walls)}")
    for w in add_walls:
        lines.append(f"  + brick {w}")

    # Preflight: never add a wall on a yellow-door opening
    swing_holes = {
        (float(d["x"]), float(d["z"]), d["side"])
        for d in data["doors"]
        if d["kind"] == "swing"
    }
    blocked = [w for w in add_walls if w in swing_holes]
    if blocked:
        lines.append("PREFLIGHT FAIL swing blocked: " + str(blocked))
        REPORT.write_text("\n".join(lines), encoding="utf-8")
        print("\n".join(lines))
        raise SystemExit("would brick a yellow door opening")

    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))

    existing = {(float(q["x"]), float(q["z"]), q["k"]) for q in data["quads"]}
    added = 0
    for x, z, side in add_walls:
        if (x, z, side) in existing:
            continue
        if (x, z) not in floors:
            continue
        data["quads"].append({"k": side, "x": x, "z": z, "m": "brick", "d": 0})
        existing.add((x, z, side))
        added += 1

    for d in data["doors"]:
        if d["kind"] not in ("class", "faculty"):
            continue
        key = (float(d["x"]), float(d["z"]), d["kind"])
        if key in door_updates:
            d["side"] = door_updates[key]

    MAP_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"\nreverted bad walls, added {added} correct walls, {len(door_updates)} blue/faculty sides")
    print("quads", before, "->", len(data["quads"]))


if __name__ == "__main__":
    main()
