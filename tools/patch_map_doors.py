#!/usr/bin/env python3
"""Place Classic doors/exits from Godot School.tscn door tiles, not hallway openings."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TSCN = Path(r"D:\Github\baldigd\Scenes\School.tscn")
MAP_PATH = ROOT / "datafiles" / "school_map.json"

IDENT = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
WALL_KIND = {"Wall1": "n", "Wall2": "s", "Wall3": "w", "Wall4": "e"}
SWING_MATS = {"StandardMaterial3D_v8i7x", "StandardMaterial3D_guped", "StandardMaterial3D_d735p"}


def clean(v: float) -> float:
    if abs(v) < 1e-4:
        return 0.0
    return round(v, 4)


def apply_basis(m, vx, vy, vz):
    return (
        m[0] * vx + m[1] * vy + m[2] * vz,
        m[3] * vx + m[4] * vy + m[5] * vz,
        m[6] * vx + m[7] * vy + m[8] * vz,
    )


def compose(p, c):
    xx, xy, xz = apply_basis(p, c[0], c[3], c[6])
    yx, yy, yz = apply_basis(p, c[1], c[4], c[7])
    zx, zy, zz = apply_basis(p, c[2], c[5], c[8])
    ox, oy, oz = apply_basis(p, c[9], c[10], c[11])
    return [
        xx, yx, zx,
        xy, yy, zy,
        xz, yz, zz,
        ox + p[9], oy + p[10], oz + p[11],
    ]


def parse_tscn(path: Path):
    node_re = re.compile(r'^\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?\]')
    xf_re = re.compile(r"^transform = Transform3D\((.*)\)$")
    mat_re = re.compile(r'^surface_material_override/0 = SubResource\("([^"]+)"\)$')
    nodes = {}
    order = []
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        m = node_re.match(line)
        if m:
            name, ntype, parent = m.group(1), m.group(2), m.group(3)
            if parent in (None, "."):
                npath = name
                parent_path = None
            else:
                npath = f"{parent}/{name}"
                parent_path = parent
            current = {
                "name": name,
                "type": ntype,
                "parent": parent_path,
                "path": npath,
                "transform": IDENT[:],
                "material": None,
            }
            nodes[npath] = current
            order.append(npath)
            continue
        if current is None:
            continue
        m = xf_re.match(line)
        if m:
            current["transform"] = [float(x.strip()) for x in m.group(1).split(",")]
            continue
        m = mat_re.match(line)
        if m:
            current["material"] = m.group(1)
            if current["parent"] and current["parent"] in nodes and nodes[current["parent"]]["material"] is None:
                nodes[current["parent"]]["material"] = m.group(1)
    return nodes, order


def world(nodes, npath):
    chain = []
    p = npath
    while p:
        chain.append(nodes[p])
        p = nodes[p]["parent"]
    t = IDENT[:]
    for n in reversed(chain):
        t = compose(t, n["transform"])
    return t


def door_kind(name: str) -> str | None:
    if "DoubleDoor" in name or "CafeDoor" in name:
        return "swing"
    if "FacultyDoor" in name or "PrincipalDoor" in name:
        return "faculty"
    if name.startswith("Hall_2WallDoor") or "SweepDoor" in name:
        return "class"
    return None


def main():
    nodes, order = parse_tscn(TSCN)
    children = {}
    for npath in order:
        p = nodes[npath]["parent"]
        if p:
            children.setdefault(p, []).append(npath)

    floors = {}
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    for q in data["quads"]:
        if q["k"] == "floor":
            floors[(clean(q["x"]), clean(q["z"]))] = q.get("m", "tile")

    doors = []
    seen = set()

    def add_door(x, z, side, kind, lock_start=False):
        x, z = clean(x), clean(z)
        key = (x, z, side, kind)
        if key in seen:
            return
        seen.add(key)
        doors.append(
            {
                "x": x,
                "z": z,
                "side": side,
                "kind": kind,
                "lock_start": bool(lock_start),
            }
        )

    for npath in order:
        n = nodes[npath]
        kind = door_kind(n["name"])
        if kind is None:
            continue
        if n["parent"] and door_kind(nodes[n["parent"]]["name"]):
            continue
        t = world(nodes, npath)
        tx, tz = clean(t[9]), clean(t[11])
        present = set()
        swing_sides = set()
        for cpath in children.get(npath, []):
            cn = nodes[cpath]
            if cn["name"] in WALL_KIND:
                side = WALL_KIND[cn["name"]]
                present.add(side)
                mat = cn["material"]
                if not mat:
                    for gc in children.get(cpath, []):
                        if nodes[gc]["material"]:
                            mat = nodes[gc]["material"]
                            break
                if mat in SWING_MATS:
                    swing_sides.add(side)
        missing = {"n", "s", "w", "e"} - present
        neigh = {"n": (0.0, -2.0), "s": (0.0, 2.0), "w": (-2.0, 0.0), "e": (2.0, 0.0)}
        carpet_sides = []
        open_sides = []
        for side in (swing_sides | missing):
            dx, dz = neigh[side]
            np = (clean(tx + dx), clean(tz + dz))
            if np not in floors:
                continue
            open_sides.append(side)
            if floors[np] == "carpet" or floors.get((tx, tz)) == "carpet":
                carpet_sides.append(side)
        chosen = []
        if kind in ("class", "faculty"):
            chosen = carpet_sides or open_sides[:1]
        else:
            if swing_sides:
                chosen = [s for s in swing_sides if s in open_sides] or list(swing_sides)[:1]
            elif open_sides:
                # One swinging door across the corridor, facing outward from origin.
                if "e" in open_sides and tx >= 0:
                    chosen = ["e"]
                elif "w" in open_sides and tx < 0:
                    chosen = ["w"]
                elif "s" in open_sides and tz >= -20:
                    chosen = ["s"]
                elif "n" in open_sides:
                    chosen = ["n"]
                else:
                    chosen = open_sides[:1]
        if len(chosen) > 2:
            continue
        for side in chosen:
            add_door(tx, tz, side, kind, False)

    # South entrance swinging door (Wall2 / south uses swing material).
    add_door(0.0, 2.0, "s", "swing", True)

    # Classic start-area trio: one ahead/behind and one to each side.
    start_want = {(8.0, 0.0), (-8.0, 0.0), (0.0, 2.0)}
    for d in doors:
        d["lock_start"] = d["kind"] == "swing" and (d["x"], d["z"]) in start_want

    exits = [
        {"x": 0.0, "z": 4.0, "name": "south"},
        {"x": -22.0, "z": -58.0, "name": "west"},
        {"x": 6.0, "z": -58.0, "name": "cafe"},
        {"x": 12.0, "z": -66.0, "name": "east"},
    ]

    data["doors"] = doors
    data["exits"] = exits
    if data.get("notebooks"):
        data["notebooks"][0]["spr"] = "spr_nb_green"

    # Classic spawn tweaks
    npcs = data.get("npcs", [])
    for npc in npcs:
        if npc["kind"] == "bully":
            npc["x"], npc["z"] = 0.0, 0.0
        elif npc["kind"] == "crafters":
            npc["x"], npc["z"] = -8.0, -58.0
        elif npc["kind"] == "sweep":
            npc["x"], npc["z"] = 14.0, -6.0
        elif npc["kind"] == "playtime":
            npc["x"], npc["z"] = 8.0, -20.0
    if not any(n["kind"] == "prize" for n in npcs):
        npcs.append(
            {
                "kind": "prize",
                "spr": "spr_prize",
                "x": 22.0,
                "y": 0.9,
                "z": -8.0,
                "w": 0.9,
                "h": 1.7,
            }
        )
    data["npcs"] = npcs

    MAP_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
    kinds = {}
    for d in doors:
        kinds[d["kind"]] = kinds.get(d["kind"], 0) + 1
    print("doors", len(doors), kinds)
    print("start locks:")
    for d in doors:
        if d["lock_start"]:
            print(" ", d)
    print("all doors:")
    for d in doors:
        print(" ", d)


if __name__ == "__main__":
    main()
