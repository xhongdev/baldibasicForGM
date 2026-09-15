#!/usr/bin/env python3
"""Rebuild school_map doors/openings from Classic 1.4.3 School.unity only.

Does not use the Godot port. Converts Unity 10-unit tiles to this project's
2-unit tiles, then simulates every door against existing floor/wall quads
before writing.
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "datafiles" / "school_map.json"
UNITY = Path(
    r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\Scene\Scenes\School.unity"
)
REPORT = ROOT / "tools" / "map_rebuild_report.txt"

# Unity +Z -> project -Z; Unity origin (5,-5) -> project (0,2); scale 10 -> 2.
def u_to_p(ux: float, uz: float) -> tuple[float, float]:
    return round((ux - 5.0) * 0.2, 4), round((uz + 5.0) * -0.2 + 2.0, 4)


def snap2(v: float) -> float:
    return round(v / 2.0) * 2.0


def yaw_from_quat(ry: float, rw: float) -> float:
    siny = 2.0 * rw * ry
    cosy = 1.0 - 2.0 * ry * ry
    return math.degrees(math.atan2(siny, cosy)) % 360.0


def yaw_to_side(yaw: float) -> str:
    # Unity yaw 0 faces +Z, which is project north (-Z).
    if yaw < 45 or yaw >= 315:
        return "n"
    if yaw < 135:
        return "e"
    if yaw < 225:
        return "s"
    return "w"


DELTA = {"n": (0.0, -2.0), "s": (0.0, 2.0), "w": (-2.0, 0.0), "e": (2.0, 0.0)}
OPP = {"n": "s", "s": "n", "w": "e", "e": "w"}


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

    def field(block, key):
        for ln in block["lines"]:
            s = ln.strip()
            if s.startswith(key + ":"):
                return s.split(":", 1)[1].strip()
        return ""

    gos = {}
    trs = {}
    for b in blocks:
        if b["type"] == "1":
            comps = re.findall(r"fileID: (\d+)", "\n".join(b["lines"]))
            gos[b["id"]] = {"name": field(b, "m_Name").strip(), "comps": comps, "active": field(b, "m_IsActive")}
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
                }

    def world(tid, guard=0):
        if tid in ("0", "", None) or tid not in trs or guard > 24:
            return 0.0, 0.0, 0.0, 0.0, 1.0
        t = trs[tid]
        px, py, pz, pry, prw = world(t["father"], guard + 1)
        # parent yaw * child yaw (y-up only)
        # compose y rotations: q = parent * child
        # (0, pry, 0, prw) * (0, ry, 0, rw)
        ny = prw * t["ry"] + pry * t["rw"]
        nw = prw * t["rw"] - pry * t["ry"]
        return px + t["x"], py + t["y"], pz + t["z"], ny, nw

    named = {}
    for g in gos.values():
        tids = [c for c in g["comps"] if c in trs]
        if not tids:
            continue
        wx, wy, wz, ry, rw = world(tids[0])
        gx, gz = u_to_p(wx, wz)
        named[g["name"]] = {
            "ux": wx,
            "uy": wy,
            "uz": wz,
            "gx": gx,
            "gz": gz,
            "yaw": yaw_from_quat(ry, rw),
            "side": yaw_to_side(yaw_from_quat(ry, rw)),
            "active": g["active"],
        }
    return named


def index_map(data):
    floors = {}
    walls = {}
    for q in data["quads"]:
        x, z = float(q["x"]), float(q["z"])
        k = q["k"]
        if k == "floor":
            floors[(x, z)] = q.get("m", "tile")
        elif k in ("n", "s", "w", "e"):
            walls.setdefault((x, z), set()).add(k)
    return floors, walls


def openings(floors, walls, x, z):
    present = walls.get((x, z), set())
    out = []
    for side, (dx, dz) in DELTA.items():
        nx, nz = x + dx, z + dz
        if (nx, nz) not in floors:
            continue
        if side in present:
            continue
        if OPP[side] in walls.get((nx, nz), set()):
            continue
        out.append(side)
    missing = {"n", "s", "w", "e"} - present
    for side in missing:
        if side not in out:
            nx, nz = x + DELTA[side][0], z + DELTA[side][1]
            if (nx, nz) in floors:
                out.append(side)
    return out


def nearest_floor(floors, gx, gz):
    return min(floors, key=lambda p: (p[0] - gx) ** 2 + (p[1] - gz) ** 2)


def pick_side(kind, x, z, floors, walls, prefer):
    ops = openings(floors, walls, x, z)
    present = walls.get((x, z), set())
    if prefer in ops:
        return prefer, ops, "yaw-open"
    if kind in ("class", "faculty"):
        carpet = []
        for side in ops:
            nx, nz = x + DELTA[side][0], z + DELTA[side][1]
            if floors.get((nx, nz)) == "carpet" or floors.get((x, z)) == "carpet":
                carpet.append(side)
        if carpet:
            return carpet[0], ops, "carpet-open"
        if prefer in present:
            # yaw points at a wall: that is the door hole in the wall
            return prefer, ops, "yaw-wall"
        if ops:
            return ops[0], ops, "open-fallback"
    if kind == "swing":
        # Yellow doors sit in the hallway opening, not on the brick sides.
        ns = "n" in present and "s" in present
        ew = "e" in present and "w" in present
        if ns:
            cand = [s for s in ("e", "w") if s in ops]
            if x >= 0 and "e" in cand:
                return "e", ops, "ew-hall-east"
            if x < 0 and "w" in cand:
                return "w", ops, "ew-hall-west"
            if cand:
                return cand[0], ops, "ew-hall"
        if ew:
            cand = [s for s in ("n", "s") if s in ops]
            if z <= 0 and "n" in cand:
                return "n", ops, "ns-hall-north"
            if z > 0 and "s" in cand:
                return "s", ops, "ns-hall-south"
            if cand:
                return cand[0], ops, "ns-hall"
        if prefer in ops:
            return prefer, ops, "yaw-open"
        if ops:
            return ops[0], ops, "open-fallback"
    if present:
        return next(iter(present)), ops, "any-wall"
    return prefer, ops, "yaw-only"


def door_size(kind):
    if kind == "swing":
        return 2.0, 2.0, 1.0  # w, h, hw  (Unity 10x10)
    return 1.0, 2.0, 0.5     # Unity ~5x10 door in 10-tall wall


UNITY_DOORS = [
    # name, kind, lock_start (NeedMore / start-area), is_exit
    ("Hall_SwingDoor (2)", "swing", True, False),
    ("Hall_SwingDoor (1)", "swing", True, False),
    ("Hall_SwingDoor", "swing", True, False),
    ("Hall_SwingDoor (5)", "swing", False, True),
    ("Hall_SwingDoor_Side (1)", "swing", False, True),
    ("Hall_SwingDoor_Side", "swing", False, True),
    ("Hall_SwingDoor_Pls", "swing", False, False),
    ("Hall_SwingDoor (3)", "swing", False, False),
    ("Hall_2Wall_Door (1)", "class", False, False),
    ("Hall_2Wall_Door", "class", False, False),
    ("Hall_2Wall_Door (5)", "class", False, False),
    ("Hall_2Wall_Door (7)", "class", False, False),
    ("Hall_2Wall_Door (4)", "class", False, False),
    ("Hall_2Wall_Door (6)", "class", False, False),
    ("Hall_2Wall_Door (9)", "class", False, False),
    ("Hall_2Wall_Door (2)", "class", False, False),
    ("Hall_2Wall_Door (3)", "class", False, False),
    ("Hall_2Wall_FacultyDoor (4)", "faculty", False, False),
    ("Hall_2Wall_FacultyDoor", "faculty", False, False),
    ("Hall_2Wall_FacultyDoor (1)", "faculty", False, False),
    ("Hall_2Wall_FacultyDoor (3)", "faculty", False, False),
    ("Hall_2Wall_FacultyDoor (2)", "faculty", False, False),
]


def main():
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    floors, walls = index_map(data)
    named = parse_unity()

    lines = ["Classic 1.4.3 Unity-only map rebuild simulation", ""]
    lines.append("Coord: gx=(ux-5)*0.2  gz=(uz+5)*-0.2+2  snap 2")
    lines.append("Unity yaw 0 (+Z) = project n (-Z). Tile 10 Unity = 2 project.")
    lines.append("Class door 1x2, swing door 2x2, wall height 2.")
    lines.append("")

    player = named.get("Player")
    if player:
        lines.append(
            f"Player unity=({player['ux']:.1f},{player['uz']:.1f}) "
            f"project=({player['gx']:.2f},{player['gz']:.2f}) yaw={player['yaw']:.1f}"
        )
    tutor = named.get("BaldiTutor")
    if tutor:
        lines.append(
            f"Tutor  unity=({tutor['ux']:.1f},{tutor['uz']:.1f}) "
            f"project=({tutor['gx']:.2f},{tutor['gz']:.2f})"
        )
    baldi = named.get("Baldi")
    if baldi:
        lines.append(
            f"Baldi  unity=({baldi['ux']:.1f},{baldi['uz']:.1f}) "
            f"project=({snap2(baldi['gx'])},{snap2(baldi['gz'])})"
        )
    lines.append("")

    out = []
    seen = set()
    fail = 0
    for uname, kind, lock_start, is_exit in UNITY_DOORS:
        u = named.get(uname)
        if not u:
            # Entrance (0) may not have rotation as door; treat as south spawn exit
            lines.append(f"MISS {uname}")
            fail += 1
            continue
        tile = nearest_floor(floors, u["gx"], u["gz"])
        prefer = u["side"]
        side, ops, why = pick_side(kind, tile[0], tile[1], floors, walls, prefer)
        w, h, hw = door_size(kind)
        present = sorted(walls.get(tile, set()))
        key = (tile[0], tile[1], side, kind)
        status = "OK"
        if key in seen:
            status = "DUP"
            fail += 1
        seen.add(key)
        if kind != "swing" and side in present:
            # door punches this wall
            status = "PUNCH"
        dist = math.hypot(tile[0] - u["gx"], tile[1] - u["gz"])
        if dist > 1.5:
            status = "FAR"
            fail += 1
        lines.append(
            f"{status:6} {uname:28} u=({u['ux']:7.1f},{u['uz']:7.1f}) "
            f"raw=({u['gx']:6.2f},{u['gz']:7.2f}) tile={tile} yaw={u['yaw']:6.1f} "
            f"prefer={prefer} side={side} {kind:7} {w}x{h} lock={lock_start} exit={is_exit} "
            f"walls={present} open={ops} why={why} dist={dist:.2f}"
        )
        if status == "DUP":
            continue
        rec = {
            "x": tile[0],
            "z": tile[1],
            "side": side,
            "kind": kind,
            "lock_start": lock_start,
        }
        if is_exit:
            rec["exit"] = True
        out.append(rec)

    # If Entrance (0) missing as named door, add spawn south exit from player tile.
    if player and not any(d.get("exit") and d["z"] > 0 for d in out):
        tile = nearest_floor(floors, 0.0, 2.0)
        rec = {"x": tile[0], "z": tile[1], "side": "s", "kind": "swing", "lock_start": True, "exit": True}
        out.insert(0, rec)
        lines.append(f"ADD    south-exit spawn tile={tile} side=s swing 2x2")

    lines.append("")
    lines.append(f"doors {len(out)} fails {fail}")
    kinds = {}
    for d in out:
        kinds[d["kind"]] = kinds.get(d["kind"], 0) + 1
    lines.append(str(kinds))

    report = "\n".join(lines)
    REPORT.write_text(report, encoding="utf-8")
    print(report)

    if fail and fail > 3:
        raise SystemExit("too many fails, not writing")

    data["doors"] = out
    MAP_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print("wrote", MAP_PATH)


if __name__ == "__main__":
    main()
