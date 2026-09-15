#!/usr/bin/env python3
"""Rebuild school_map from Classic 1.4.3 School.unity into GameMaker 3D space.

Unity is a left-handed scene graph (Y up, yaw 0 faces +Z, 10-unit tiles).
This GameMaker port is a 2x2 quad grid: Y up, yaw 0 looks -Z, +X is right,
projection uses -aspect (GM mirrors X). Do not copy Unity transforms.

  gx = (ux - 5) * 0.2
  gz = (uz + 5) * -0.2 + 2
  n = -Z face, s = +Z, e = +X, w = -X
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
REPORT = ROOT / "tools" / "rebuild_geometry_report.txt"


def u_to_p(ux, uz):
    return (ux - 5.0) * 0.2, (uz + 5.0) * -0.2 + 2.0


def snap2(v):
    return round(v / 2.0) * 2.0


def yaw_from_quat(ry, rw):
    return math.degrees(math.atan2(2.0 * rw * ry, 1.0 - 2.0 * ry * ry)) % 360.0


def yaw_to_side(yaw):
    # Unity yaw 0 faces +Z, which is GM -Z (n).
    if yaw < 45 or yaw >= 315:
        return "n"
    if yaw < 135:
        return "e"
    if yaw < 225:
        return "s"
    return "w"


def gm_side_from_unity_delta(dx_u, dz_u):
    """Classify a wall using GM axes after converting the Unity offset."""
    ddx = dx_u * 0.2
    ddz = dz_u * -0.2
    if abs(ddz) >= abs(ddx):
        return "n" if ddz < 0 else "s"
    return "e" if ddx > 0 else "w"


def rotate_xz(x, z, yaw_deg):
    t = math.radians(yaw_deg)
    c, s = math.cos(t), math.sin(t)
    return x * c + z * s, -x * s + z * c


def parse_unity():
    lines = UNITY.read_text(encoding="utf-8", errors="replace").splitlines()
    blocks, cur = [], None
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

    gos, trs = {}, {}
    for b in blocks:
        if b["type"] == "1":
            comps = re.findall(r"fileID: (\d+)", "\n".join(b["lines"]))
            gos[b["id"]] = {
                "name": field(b, "m_Name").strip(),
                "comps": comps,
                "active": field(b, "m_IsActive") != "0",
            }
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

    floors, ceils, walls = set(), set(), set()
    wall_mat = {}
    floor_mats = {}
    door_tiles = []

    def ancestor_blob(tid):
        names = []
        t = tid
        for _ in range(10):
            if t not in trs:
                break
            names.append(gos.get(trs[t]["go"], {}).get("name", ""))
            t = trs[t]["father"]
        return " ".join(names).lower()

    for gid, g in gos.items():
        if not g["active"]:
            continue
        n = g["name"]
        tids = [c for c in g["comps"] if c in trs]
        if not tids:
            continue
        tid = tids[0]
        wx, wy, wz, yaw = world(tid)
        gx, gz = snap2(u_to_p(wx, wz)[0]), snap2(u_to_p(wx, wz)[1])

        if n == "Floor" or n.startswith("Floor "):
            floors.add((gx, gz))
            blob = ancestor_blob(tid)
            mat = "tile"
            if any(k in blob for k in ("faculty", "office", "class", "principal", "math", "spell", "english", "science")):
                mat = "carpet"
            floor_mats[(gx, gz)] = mat
        elif n == "Ceiling" or n.startswith("Ceiling "):
            ceils.add((gx, gz))
        elif n == "Wall" or n.startswith("Wall "):
            fa = trs[tid]["father"]
            if fa not in trs:
                continue
            pname = gos.get(trs[fa]["go"], {}).get("name", "")
            # GM tiles only. Skip NPC/furniture colliders named Wall.
            if not (
                pname.startswith("Hall_")
                or pname.startswith("Room_")
                or pname.startswith("Entrance")
                or pname.startswith("Cafe_")
            ):
                continue
            px, py, pz, _ = world(fa)
            dx, dz = wx - px, wz - pz
            ddx, ddz = dx * 0.2, dz * -0.2
            face = max(abs(ddx), abs(ddz))
            # A face of this 2x2 tile sits ~1 unit from center, not the next tile (~2).
            if face < 0.45 or face > 1.55:
                continue
            gx, gz = snap2(u_to_p(px, pz)[0]), snap2(u_to_p(px, pz)[1])
            side = gm_side_from_unity_delta(dx, dz)
            walls.add((gx, gz, side))
            if wall_mat.get((gx, gz, side)) != "window":
                wall_mat[(gx, gz, side)] = "brick"
        elif n == "Window" or n.startswith("Window "):
            fa = trs[tid]["father"]
            if fa not in trs:
                continue
            pname = gos.get(trs[fa]["go"], {}).get("name", "")
            if not (
                pname.startswith("Hall_")
                or pname.startswith("Room_")
                or pname.startswith("Entrance")
                or pname.startswith("Cafe_")
            ):
                continue
            px, py, pz, _ = world(fa)
            dx, dz = wx - px, wz - pz
            ddx, ddz = dx * 0.2, dz * -0.2
            face = max(abs(ddx), abs(ddz))
            if face < 0.45 or face > 1.55:
                continue
            gx, gz = snap2(u_to_p(px, pz)[0]), snap2(u_to_p(px, pz)[1])
            side = gm_side_from_unity_delta(dx, dz)
            walls.add((gx, gz, side))
            wall_mat[(gx, gz, side)] = "window"

        kind = None
        if n.startswith("Hall_2Wall_Faculty"):
            kind = "faculty"
        elif n.startswith("Hall_2Wall_Door"):
            kind = "class"
        elif n.startswith("Hall_SwingDoor") or n.startswith("Cafe_Door"):
            kind = "swing"
        elif n.startswith("Room_1Wall_Faculty"):
            kind = "faculty"
        elif n.startswith("Room_1Wall_Door"):
            kind = "class"
        if kind:
            sides = []
            for cid in trs[tid]["children"]:
                cname = gos.get(trs[cid]["go"], {}).get("name", "")
                if not cname.startswith("Wall"):
                    continue
                cx, cy, cz, _ = world(cid)
                dx, dz = cx - wx, cz - wz
                sides.append(gm_side_from_unity_delta(dx, dz))
            door_tiles.append(
                {
                    "name": n,
                    "kind": kind,
                    "x": gx,
                    "z": gz,
                    "yaw": yaw,
                    "prefer": yaw_to_side(yaw),
                    "unity_walls": sorted(set(sides)),
                }
            )

    return floors, ceils, walls, door_tiles, floor_mats, wall_mat


def pick_swing_side(d, walls):
    present = set(d.get("unity_walls") or [])
    if not present:
        present = {s for x, z, s in walls if x == d["x"] and z == d["z"]}
    ns = "n" in present and "s" in present
    ew = "e" in present and "w" in present
    if ns:
        return "e" if d["x"] >= 0 else "w"
    if ew:
        return "n" if d["z"] <= 0 else "s"
    return d["prefer"]


def main():
    old = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    old_mat = {}
    for q in old["quads"]:
        if q["k"] == "floor":
            old_mat[(float(q["x"]), float(q["z"]))] = q.get("m", "tile")

    floors, ceils, walls, door_tiles, floor_mats, wall_mat = parse_unity()
    ceils |= floors
    floors |= ceils

    quads = []
    for x, z in sorted(floors):
        mat = old_mat.get((x, z)) or floor_mats.get((x, z), "tile")
        quads.append({"k": "floor", "x": x, "z": z, "m": mat, "d": 0})
    for x, z in sorted(ceils):
        quads.append({"k": "ceil", "x": x, "z": z, "m": "ceil", "d": 0})
    for x, z, s in sorted(walls):
        quads.append({"k": s, "x": x, "z": z, "m": wall_mat.get((x, z, s), "brick"), "d": 0})

    doors = []
    seen = set()
    start_names = {"Hall_SwingDoor (2)", "Hall_SwingDoor (1)", "Hall_SwingDoor"}
    exit_names = {
        "Hall_SwingDoor (5)",
        "Hall_SwingDoor_Side",
        "Hall_SwingDoor_Side (1)",
        "Cafe_Door",
        "Cafe_Door (1)",
    }
    for d in door_tiles:
        if d["name"].startswith("Room_1Wall"):
            continue
        if d["kind"] == "swing":
            side = pick_swing_side(d, walls)
        else:
            side = d["prefer"]
        key = (d["x"], d["z"], side, d["kind"])
        if key in seen:
            continue
        seen.add(key)
        rec = {
            "x": d["x"],
            "z": d["z"],
            "side": side,
            "kind": d["kind"],
            "lock_start": d["name"] in start_names,
        }
        if d["name"] in exit_names:
            rec["exit"] = True
        doors.append(rec)

    # South spawn exit: Unity Entrance, not Hall_SwingDoor.
    south = (0.0, 2.0, "s", "swing")
    if south not in seen and (0.0, 2.0) in floors:
        doors.insert(0, {"x": 0.0, "z": 2.0, "side": "s", "kind": "swing", "lock_start": True, "exit": True})
        seen.add(south)

    doors.sort(key=lambda d: ({"swing": 0, "class": 1, "faculty": 2}.get(d["kind"], 9), d["z"], d["x"], d["side"]))
    # GM grid: a doorway is one plane. Strip brick on both tiles sharing that face.
    opp = {"n": "s", "s": "n", "w": "e", "e": "w"}
    delta = {"n": (0.0, -2.0), "s": (0.0, 2.0), "w": (-2.0, 0.0), "e": (2.0, 0.0)}
    punch = set()
    for door in doors:
        punch.add((door["x"], door["z"], door["side"]))
        dx, dz = delta[door["side"]]
        punch.add((door["x"] + dx, door["z"] + dz, opp[door["side"]]))
    # Room-side Unity door tiles: punch the opening, do not spawn a second door mesh.
    for d in door_tiles:
        if not d["name"].startswith("Room_1Wall"):
            continue
        side = d["prefer"]
        punch.add((d["x"], d["z"], side))
        dx, dz = delta[side]
        punch.add((d["x"] + dx, d["z"] + dz, opp[side]))
    quads = [q for q in quads if (q["k"] not in ("n", "s", "w", "e")) or ((q["x"], q["z"], q["k"]) not in punch)]
    old["quads"] = quads
    old["doors"] = doors

    # Simulate
    nf, nc, nw = set(), set(), set()
    for q in quads:
        if q["k"] == "floor":
            nf.add((q["x"], q["z"]))
        elif q["k"] == "ceil":
            nc.add((q["x"], q["z"]))
        elif q["k"] in "nsew":
            nw.add((q["x"], q["z"], q["k"]))
    lines = [
        f"floors {len(nf)} (unity {len(floors)}) match {len(nf & floors)}",
        f"ceils  {len(nc)} (unity floors {len(floors)})",
        f"walls  {len(nw)} (unity {len(walls)}) match {len(nw & walls)} miss {len(walls - nw)} extra {len(nw - walls)}",
        f"doors  {len(doors)} swing={sum(1 for d in doors if d['kind']=='swing')} class={sum(1 for d in doors if d['kind']=='class')} faculty={sum(1 for d in doors if d['kind']=='faculty')}",
    ]
    for d in doors:
        lines.append(f"  {d['kind']:7} ({d['x']:6.1f},{d['z']:7.1f}) {d['side']} lock={d.get('lock_start')} exit={d.get('exit')}")
    text = "\n".join(lines)
    REPORT.write_text(text, encoding="utf-8")
    print(text)

    if len(nf) < 600 or len(nw) < 500:
        raise SystemExit("geometry too small, not writing")
    MAP_PATH.write_text(json.dumps(old, indent=2), encoding="utf-8")
    print("wrote", MAP_PATH, "quads", len(quads))


if __name__ == "__main__":
    main()
