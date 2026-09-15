#!/usr/bin/env python3
"""Simulate current school_map.json against Classic 1.4.3 School.unity.

Compares floors, ceilings, walls, yellow swinging doors, and blue class doors.
Does not use the Godot port.
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
REPORT = ROOT / "tools" / "simulate_vs_unity_report.txt"

# Project tile = Unity 10 units. Player Unity (5,-5) -> project (0,2).
def u_to_p(ux: float, uz: float) -> tuple[float, float]:
    return round((ux - 5.0) * 0.2, 4), round((uz + 5.0) * -0.2 + 2.0, 4)


def snap2(v: float) -> float:
    return round(v / 2.0) * 2.0


def yaw_from_quat(ry: float, rw: float) -> float:
    siny = 2.0 * rw * ry
    cosy = 1.0 - 2.0 * ry * ry
    return math.degrees(math.atan2(siny, cosy)) % 360.0


def yaw_to_side(yaw: float) -> str:
    if yaw < 45 or yaw >= 315:
        return "n"
    if yaw < 135:
        return "e"
    if yaw < 225:
        return "s"
    return "w"


def rotate_xz(x, z, yaw_deg):
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

    floors = set()
    ceils = set()
    walls = set()
    names_floor = names_ceil = names_wall = 0

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
            names_floor += 1
            floors.add((gx, gz))
        elif n == "Ceiling" or n.startswith("Ceiling "):
            names_ceil += 1
            ceils.add((gx, gz))
        elif n == "Wall" or n.startswith("Wall "):
            names_wall += 1
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
            dx = wx - px
            dz = wz - pz
            ddx, ddz = dx * 0.2, dz * -0.2
            face = max(abs(ddx), abs(ddz))
            if face < 0.45 or face > 1.55:
                continue
            gx, gz = snap2(u_to_p(px, pz)[0]), snap2(u_to_p(px, pz)[1])
            if abs(ddz) >= abs(ddx):
                side = "n" if ddz < 0 else "s"
            else:
                side = "e" if ddx > 0 else "w"
            walls.add((gx, gz, side))

    doors = []
    for gid, g in gos.items():
        n = g["name"]
        tids = [c for c in g["comps"] if c in trs]
        if not tids:
            continue
        tid = tids[0]
        wx, wy, wz, yaw = world(tid)
        gx, gz = snap2(u_to_p(wx, wz)[0]), snap2(u_to_p(wx, wz)[1])
        if n.startswith("Hall_2Wall_Faculty"):
            kind = "faculty"
        elif n.startswith("Hall_2Wall_Door"):
            kind = "class"
        elif n.startswith("Hall_SwingDoor") or n.startswith("Cafe_Door"):
            kind = "swing"
        else:
            continue
        # child walls in world space
        sides = []
        for cid in trs[tid]["children"]:
            cname = gos.get(trs[cid]["go"], {}).get("name", "")
            if not cname.startswith("Wall"):
                continue
            cx, cy, cz, _ = world(cid)
            dx = cx - wx
            dz = cz - wz
            ddx, ddz = dx * 0.2, dz * -0.2
            if abs(ddz) >= abs(ddx):
                sides.append("n" if ddz < 0 else "s")
            else:
                sides.append("e" if ddx > 0 else "w")
        doors.append(
            {
                "name": n,
                "kind": kind,
                "tile": (gx, gz),
                "yaw": yaw,
                "prefer": yaw_to_side(yaw),
                "unity_walls": sorted(set(sides)),
            }
        )

    return {
        "floors": floors,
        "ceils": ceils,
        "walls": walls,
        "doors": doors,
        "counts": (names_floor, names_ceil, names_wall),
    }


def load_map():
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    floors = set()
    ceils = set()
    walls = set()
    for q in data["quads"]:
        x, z = float(q["x"]), float(q["z"])
        k = q["k"]
        if k == "floor":
            floors.add((x, z))
        elif k == "ceil":
            ceils.add((x, z))
        elif k in ("n", "s", "w", "e"):
            walls.add((x, z, k))
    return data, floors, ceils, walls


def fmt_set_diff(label, unity, proj, limit=40):
    miss = sorted(unity - proj)
    extra = sorted(proj - unity)
    lines = [
        f"{label}: unity={len(unity)} project={len(proj)} "
        f"match={len(unity & proj)} missing_in_project={len(miss)} extra_in_project={len(extra)}"
    ]
    if miss:
        lines.append(f"  missing ({min(len(miss), limit)} of {len(miss)}): {miss[:limit]}")
    if extra:
        lines.append(f"  extra   ({min(len(extra), limit)} of {len(extra)}): {extra[:limit]}")
    return lines, miss, extra


def main():
    u = parse_unity()
    data, mf, mc, mw = load_map()
    lines = []
    lines.append("Current project vs Classic 1.4.3 School.unity")
    lines.append("Coord: gx=(ux-5)*0.2  gz=(uz+5)*-0.2+2  snap 2")
    lines.append("Size: Unity tile 10x10x10 -> project 2x2x2")
    lines.append("Yellow door 2x2, blue/faculty door 1x2 in 2-tall wall")
    lines.append("")
    lines.append(
        f"Unity named objects Floor={u['counts'][0]} Ceiling={u['counts'][1]} Wall={u['counts'][2]}"
    )
    lines.append("")

    l, miss_f, extra_f = fmt_set_diff("FLOORS", u["floors"], mf)
    lines.extend(l)
    l, miss_c, extra_c = fmt_set_diff("CEILINGS", u["ceils"], mc)
    lines.extend(l)
    l, miss_w, extra_w = fmt_set_diff("WALLS (tile,side)", u["walls"], mw)
    lines.extend(l)
    lines.append("")

    # Doors
    proj_doors = data["doors"]
    lines.append("YELLOW / SWING DOORS (project left as-is; compare tile presence)")
    swing_u = [d for d in u["doors"] if d["kind"] == "swing"]
    swing_p = [d for d in proj_doors if d["kind"] == "swing"]
    lines.append(f"  unity swing tiles={len(swing_u)} project={len(swing_p)}")
    for d in sorted(swing_u, key=lambda x: (x["tile"][1], x["tile"][0])):
        hits = [
            p
            for p in swing_p
            if abs(p["x"] - d["tile"][0]) < 0.01 and abs(p["z"] - d["tile"][1]) < 0.01
        ]
        if hits:
            p = hits[0]
            ok = "OK  "
            note = f"project side={p['side']} unity_walls={d['unity_walls']} yaw={d['yaw']:.1f}->{d['prefer']}"
        else:
            ok = "MISS"
            note = f"unity_walls={d['unity_walls']} yaw={d['yaw']:.1f}->{d['prefer']}"
        lines.append(f"  {ok} {d['name']:28} tile={d['tile']} {note}")
    extra_s = []
    for p in swing_p:
        if not any(abs(d["tile"][0] - p["x"]) < 0.01 and abs(d["tile"][1] - p["z"]) < 0.01 for d in swing_u):
            extra_s.append(p)
            lines.append(f"  EXTRA swing ({p['x']},{p['z']}) {p['side']} (not a Unity Hall_SwingDoor tile)")
    lines.append("")

    lines.append("BLUE CLASS + BROWN FACULTY DOORS")
    bf_u = [d for d in u["doors"] if d["kind"] in ("class", "faculty")]
    bf_p = [d for d in proj_doors if d["kind"] in ("class", "faculty")]
    side_ok = side_bad = 0
    for d in sorted(bf_u, key=lambda x: (x["kind"], x["tile"][1], x["tile"][0])):
        hits = [
            p
            for p in bf_p
            if abs(p["x"] - d["tile"][0]) < 0.01
            and abs(p["z"] - d["tile"][1]) < 0.01
            and p["kind"] == d["kind"]
        ]
        want = d["prefer"]
        size = "1x2"
        if not hits:
            lines.append(
                f"  MISS {d['kind']:7} {d['name']:28} tile={d['tile']} want_side={want} {size} "
                f"unity_walls={d['unity_walls']}"
            )
            side_bad += 1
            continue
        p = hits[0]
        same = p["side"] == want
        if same:
            side_ok += 1
            tag = "OK  "
        else:
            side_bad += 1
            tag = "SIDE"
        punch = (p["x"], p["z"], p["side"]) in mw or (d["tile"][0], d["tile"][1], want) in u["walls"]
        lines.append(
            f"  {tag} {d['kind']:7} {d['name']:28} tile={d['tile']} "
            f"project={p['side']} unity_yaw={want} {size} unity_walls={d['unity_walls']} "
            f"wall_on_door_side={'yes' if (d['tile'][0], d['tile'][1], p['side']) in mw else 'NO'}"
        )
    lines.append(f"  blue/faculty side match {side_ok}/{side_ok + side_bad}")
    lines.append("")

    # Size contract
    lines.append("SIZE CONTRACT (project emitters)")
    lines.append("  floor/ceil/wall quad: 2 x 2 (full tile)")
    lines.append("  yellow swing door:    2 x 2 (hw=1.0)")
    lines.append("  blue/faculty door:    1 x 2 (hw=0.5) + 0.5 jambs each side")
    lines.append("")

    same_f = len(miss_f) == 0 and len(extra_f) == 0
    same_c = len(miss_c) == 0 and len(extra_c) == 0
    same_w = len(miss_w) == 0 and len(extra_w) == 0
    same_y = extra_s == [] and all(
        any(abs(p["x"] - d["tile"][0]) < 0.01 and abs(p["z"] - d["tile"][1]) < 0.01 for p in swing_p)
        for d in swing_u
        if not d["name"].startswith("Cafe_Door")
    )
    lines.append("VERDICT")
    lines.append(f"  floors    {'MATCH' if same_f else 'NOT the same as Unity'}")
    lines.append(f"  ceilings  {'MATCH' if same_c else 'NOT the same as Unity'}")
    lines.append(f"  walls     {'MATCH' if same_w else 'NOT the same as Unity'}")
    lines.append(f"  yellow    {'tiles present' if same_y else 'tile mismatch'} (sides are corridor openings, not Unity yaw)")
    lines.append(f"  blue      {'sides match Unity yaw' if side_bad == 0 else 'SOME sides differ from Unity yaw'}")
    lines.append("")
    lines.append("Note: Unity combines many meshes; named Floor/Wall/Ceiling objects are the")
    lines.append("tile pieces. CombinedMeshes_* are furniture/lockers and are not in school_map.")

    text = "\n".join(lines)
    REPORT.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
