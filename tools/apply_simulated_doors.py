#!/usr/bin/env python3
"""Write doors only after Godot missing-wall + Unity spawn simulation."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "datafiles" / "school_map.json"

# Godot School.tscn missing walls = the actual opening(s).
# For 3-open class tiles, pick the room/carpet side from the previous carpet simulation.
DOORS = [
    # start-area swinging doors (lock until 2 notebooks)
    {"x": 8.0, "z": 0.0, "side": "e", "kind": "swing", "lock_start": True},   # miss e/w; east is the start-right corridor
    {"x": -8.0, "z": 0.0, "side": "w", "kind": "swing", "lock_start": True},  # miss e/w; west is the start-left corridor
    {"x": 0.0, "z": -8.0, "side": "n", "kind": "swing", "lock_start": True},  # Hall_SwingDoor in front of player looking at Baldi
    # remaining swinging doors
    {"x": 12.0, "z": -66.0, "side": "e", "kind": "swing", "lock_start": False},
    {"x": -22.0, "z": -58.0, "side": "n", "kind": "swing", "lock_start": False},
    {"x": 6.0, "z": -58.0, "side": "w", "kind": "swing", "lock_start": False},
    {"x": 6.0, "z": -40.0, "side": "n", "kind": "swing", "lock_start": False},
    {"x": -6.0, "z": -38.0, "side": "w", "kind": "swing", "lock_start": False},
    # class / blue
    {"x": 0.0, "z": -4.0, "side": "w", "kind": "class", "lock_start": False},
    {"x": 0.0, "z": -6.0, "side": "e", "kind": "class", "lock_start": False},
    {"x": 22.0, "z": -32.0, "side": "n", "kind": "class", "lock_start": False},
    {"x": 22.0, "z": -60.0, "side": "n", "kind": "class", "lock_start": False},
    {"x": -22.0, "z": -54.0, "side": "n", "kind": "class", "lock_start": False},
    {"x": -6.0, "z": -48.0, "side": "s", "kind": "class", "lock_start": False},
    {"x": 12.0, "z": -6.0, "side": "n", "kind": "class", "lock_start": False},  # sweep closet
    {"x": 4.0, "z": -26.0, "side": "s", "kind": "class", "lock_start": False},
    {"x": 6.0, "z": -32.0, "side": "w", "kind": "class", "lock_start": False},
    # faculty / brown  -- Hall_2WallDoor2 at (22,-18) is FacultyDoor (4) in Unity
    {"x": 22.0, "z": -18.0, "side": "n", "kind": "faculty", "lock_start": False},
    {"x": 6.0, "z": -46.0, "side": "n", "kind": "faculty", "lock_start": False},
    {"x": -22.0, "z": -32.0, "side": "e", "kind": "faculty", "lock_start": False},
    {"x": -6.0, "z": -26.0, "side": "s", "kind": "faculty", "lock_start": False},
    {"x": -14.0, "z": 0.0, "side": "n", "kind": "faculty", "lock_start": False},
]


def main():
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    walls = {}
    floors = {}
    for q in data["quads"]:
        x, z = float(q["x"]), float(q["z"])
        if q["k"] == "floor":
            floors[(x, z)] = q.get("m")
        elif q["k"] in ("n", "s", "w", "e"):
            walls.setdefault((x, z), set()).add(q["k"])

    print("PREFLIGHT")
    ok = True
    for d in DOORS:
        tile = (d["x"], d["z"])
        present = walls.get(tile, set())
        if tile not in floors:
            print(" FAIL no floor", d)
            ok = False
            continue
        if d["kind"] != "swing" and d["side"] in present:
            print(" FAIL class/faculty side blocked by wall", d, "walls", present)
            ok = False
            continue
        sz_w = 2.0 if d["kind"] == "swing" else 1.0
        print(
            f" OK {d['kind']:7} ({d['x']:6.1f},{d['z']:7.1f}) {d['side']} "
            f"lock={d['lock_start']} size={sz_w}x2 walls={sorted(present)} floor={floors[tile]}"
        )
    if not ok:
        raise SystemExit("preflight failed, not writing")

    data["doors"] = DOORS
    # NPC positions from Unity simulation (snapped)
    for npc in data.get("npcs", []):
        if npc["kind"] == "principal":
            npc["x"], npc["z"], npc["h"] = 1.0, -33.0, 1.64
        elif npc["kind"] == "playtime":
            npc["x"], npc["z"], npc["h"] = -22.0, -28.0, 1.64
        elif npc["kind"] == "bully":
            npc["x"], npc["z"], npc["h"] = 0.0, 1.0, 1.64
        elif npc["kind"] == "sweep":
            npc["x"], npc["z"], npc["h"] = 15.0, -6.0, 1.64
        elif npc["kind"] == "crafters":
            npc["x"], npc["z"], npc["h"] = -2.0, -59.0, 1.64
        elif npc["kind"] == "prize":
            npc["x"], npc["z"], npc["h"] = -14.0, -38.0, 1.64
    MAP_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
    kinds = {}
    for d in DOORS:
        kinds[d["kind"]] = kinds.get(d["kind"], 0) + 1
    print("wrote doors", len(DOORS), kinds)


if __name__ == "__main__":
    main()
