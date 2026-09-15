#!/usr/bin/env python3
"""Simulate Classic 1.4.3 door/NPC/HUD/sprite data against the imported school map
BEFORE writing any gameplay files."""
from __future__ import annotations

import json
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "datafiles" / "school_map.json"
UNITY = Path(
    r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\Scene\Scenes\School.unity"
)
DECOMP = Path(r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI")
OUT = ROOT / "tools" / "simulate_classic_report.txt"


def png_size(p: Path):
    with p.open("rb") as f:
        f.read(16)
        w, h = struct.unpack(">II", f.read(8))
        return w, h


def unity_to_godot(ux, uz):
    return round((ux - 5.0) * 0.2, 4), round((uz + 5.0) * -0.2 + 2.0, 4)


def snap2(v):
    return round(v / 2.0) * 2.0


def parse_unity_transforms():
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
                }

    def world(tid, guard=0):
        if tid in ("0", "", None) or tid not in trs or guard > 20:
            return 0.0, 0.0, 0.0
        t = trs[tid]
        px, py, pz = world(t["father"], guard + 1)
        return px + t["x"], py + t["y"], pz + t["z"]

    def yaw_deg(ry, rw):
        siny = 2.0 * (rw * ry)
        cosy = 1.0 - 2.0 * (ry * ry)
        return (math.degrees(math.atan2(siny, cosy))) % 360.0

    named = {}
    for g in gos.values():
        tids = [c for c in g["comps"] if c in trs]
        if not tids:
            continue
        wx, wy, wz = world(tids[0])
        t = trs[tids[0]]
        named[g["name"]] = {
            "ux": wx,
            "uy": wy,
            "uz": wz,
            "gx": unity_to_godot(wx, wz)[0],
            "gz": unity_to_godot(wx, wz)[1],
            "yaw": yaw_deg(t["ry"], t["rw"]),
        }
    return named


def load_map():
    return json.loads(MAP_PATH.read_text(encoding="utf-8"))


def index_map(data):
    floors = {}
    walls = {}
    for q in data["quads"]:
        k = q["k"]
        x, z = float(q["x"]), float(q["z"])
        if k == "floor":
            floors[(x, z)] = q.get("m", "tile")
        elif k in ("n", "s", "w", "e"):
            walls.setdefault((x, z), set()).add(k)
    return floors, walls


OPP = {"n": "s", "s": "n", "w": "e", "e": "w"}
DELTA = {"n": (0.0, -2.0), "s": (0.0, 2.0), "w": (-2.0, 0.0), "e": (2.0, 0.0)}


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


def choose_side(kind, x, z, floors, walls, prefer=None):
    ops = openings(floors, walls, x, z)
    present = walls.get((x, z), set())
    if prefer in ops:
        return prefer, ops, "prefer_open"
    if kind in ("class", "faculty"):
        carpet = []
        for side in ops:
            nx, nz = x + DELTA[side][0], z + DELTA[side][1]
            if floors.get((nx, nz)) == "carpet" or floors.get((x, z)) == "carpet":
                carpet.append(side)
        if carpet:
            return carpet[0], ops, "carpet"
    if ops:
        return ops[0], ops, "opening"
    if prefer in present:
        return prefer, ops, "prefer_wall"
    if present:
        return next(iter(present)), ops, "fallback_wall"
    return "e", ops, "default"


def door_size(kind):
    # Unity tile 10, height 10. Godot tile 2, height 2.
    # Class/faculty Door_0 is 128x256 -> 1 x 2 world units (half-width 0.5).
    # Swing SwingDoor0 is 256x256 -> 2 x 2 (half-width 1.0).
    if kind == "swing":
        return {"w": 2.0, "h": 2.0, "hw": 1.0, "tex": "256x256"}
    return {"w": 1.0, "h": 2.0, "hw": 0.5, "tex": "128x256"}


def simulate_doors(data, named):
    floors, walls = index_map(data)
    unity_doors = [
        ("Hall_SwingDoor (2)", "swing", True),
        ("Hall_SwingDoor (1)", "swing", True),
        ("Hall_SwingDoor", "swing", True),
        ("Hall_SwingDoor (5)", "swing", False),
        ("Hall_SwingDoor_Side (1)", "swing", False),
        ("Hall_SwingDoor_Pls", "swing", False),
        ("Hall_SwingDoor (3)", "swing", False),
        ("Hall_SwingDoor_Side", "swing", False),
        ("Hall_2Wall_Door (1)", "class", False),
        ("Hall_2Wall_Door", "class", False),
        ("Hall_2Wall_Door (5)", "class", False),
        ("Hall_2Wall_Door (7)", "class", False),
        ("Hall_2Wall_Door (4)", "class", False),
        ("Hall_2Wall_Door (6)", "class", False),
        ("Hall_2Wall_Door (9)", "class", False),
        ("Hall_2Wall_Door (2)", "class", False),
        ("Hall_2Wall_Door (3)", "class", False),
        ("Hall_2Wall_FacultyDoor (4)", "faculty", False),
        ("Hall_2Wall_FacultyDoor", "faculty", False),
        ("Hall_2Wall_FacultyDoor (1)", "faculty", False),
        ("Hall_2Wall_FacultyDoor (3)", "faculty", False),
        ("Hall_2Wall_FacultyDoor (2)", "faculty", False),
    ]
    rows = []
    for uname, kind, lock in unity_doors:
        u = named.get(uname)
        if not u:
            rows.append({"name": uname, "ok": False, "reason": "missing unity node"})
            continue
        x, z = snap2(u["gx"]), snap2(u["gz"])
        if (x, z) not in floors:
            best = min(floors, key=lambda p: (p[0] - u["gx"]) ** 2 + (p[1] - u["gz"]) ** 2)
            x, z = best
        yaw = u["yaw"]
        if yaw < 45 or yaw >= 315:
            prefer = "n"
        elif yaw < 135:
            prefer = "e"
        elif yaw < 225:
            prefer = "s"
        else:
            prefer = "w"
        side, ops, why = choose_side(kind, x, z, floors, walls, prefer)
        sz = door_size(kind)
        present = sorted(walls.get((x, z), set()))
        gap = 0.0 if kind == "swing" else (2.0 - sz["w"])
        rows.append(
            {
                "name": uname,
                "ok": True,
                "kind": kind,
                "lock_start": lock,
                "unity": (round(u["ux"], 1), round(u["uz"], 1)),
                "godot_raw": (round(u["gx"], 2), round(u["gz"], 2)),
                "tile": (x, z),
                "yaw": round(yaw, 1),
                "prefer": prefer,
                "side": side,
                "openings": ops,
                "walls": present,
                "why": why,
                "w": sz["w"],
                "h": sz["h"],
                "hw": sz["hw"],
                "gap": gap,
                "floor": floors.get((x, z)),
            }
        )
    return rows


def simulate_characters(named):
    chars = {
        "Player": named.get("Player"),
        "BaldiTutor": named.get("BaldiTutor"),
        "Baldi": named.get("Baldi"),
        "Principal of the Thing": named.get("Principal of the Thing") or named.get("Principal"),
        "Playtime": named.get("Playtime"),
        "Its a Bully": named.get("Its a Bully"),
        "Gotta Sweep": named.get("Gotta Sweep"),
        "Arts and Crafters": named.get("Arts and Crafters"),
        "1st Prize": named.get("1st Prize"),
    }
    sprites = {
        "slap": DECOMP / "Assets/Texture2D/Characters/Baldi/Angry/Baldi_Slap0000.png",
        "wave": DECOMP / "Assets/Texture2D/Characters/Baldi/Baldi_Wave0000.png",
        "play": DECOMP / "Assets/Texture2D/Characters/Playtime/JumpRope_0.png",
        "bully": DECOMP / "Assets/Texture2D/Characters/bully_final.png",
        "sweep": DECOMP / "Assets/Texture2D/Characters/Gotta Sweep Sprite.png",
        "craft": DECOMP / "Assets/Texture2D/Characters/Arts&Crafters/Crafters_Normal.png",
        "prize": DECOMP / "Assets/Texture2D/Characters/1stPrize/1PR_0.png",
        "prin": DECOMP / "Assets/Texture2D/Characters/Principal.png",
        "nb": DECOMP / "Assets/Texture2D/SchoolHouse/PickUps/Notebooks/_nbGreen.png",
        "slots": DECOMP / "Assets/Texture2D/HudTextures/ItemSlots.png",
        "door": DECOMP / "Assets/Texture2D/SchoolHouse/DoorTextures/Door_0.png",
        "swing": DECOMP / "Assets/Texture2D/SchoolHouse/DoorTextures/SwingDoors/SwingDoor0.png",
        "quarter": DECOMP / "Assets/Texture2D/SchoolHouse/PickUps/Quarter.png",
    }
    sizes = {}
    for k, p in sprites.items():
        sizes[k] = png_size(p) if p.exists() else None
    # Billboard world size: Classic sprites sit ~8 Unity units tall (~1.6 Godot).
    # width = height * (texW/texH)
    char_h = 1.64
    bill = {}
    for k, sz in sizes.items():
        if not sz:
            continue
        w, h = sz
        bill[k] = (round(char_h * (w / h), 3), char_h)
    # notebooks / items bob: sin(frameCount * deg2rad) / 2 + 1  -> amplitude 0.5 Unity = 0.1 Godot
    bob = {"unity_amp": 0.5, "godot_amp": 0.1, "formula": "sin(frame*0.017453292)/2+1"}
    # HUD Classic 480x360 letterboxed in 640x480? Original is 480x360.
    # Keep internal 640x480 4:3. ItemSlots 256x114; Classic uses 3 of 4 diamonds.
    # itemSelectOffset = [-80,-40,0] in 480-wide canvas? Unity canvas often 640.
    hud = {
        "internal": (640, 480),
        "classic": (480, 360),
        "slots_tex": sizes.get("slots"),
        "slots_draw": (192, 85.5),  # first 3 diamonds of 256x114 at scale 0.75? 256*(3/4)=192
        "slot_centers": [32, 96, 160],  # in 192-wide crop
        "select_red": True,
        "stamina": (150, 12),
        "notebooks": "n/7 Notebooks",
    }
    slap_w = bill.get("slap", (0.68, 1.64))
    return chars, sizes, bill, bob, hud, slap_w


def main():
    data = load_map()
    named = parse_unity_transforms()
    doors = simulate_doors(data, named)
    chars, sizes, bill, bob, hud, slap_w = simulate_characters(named)

    lines = []
    lines.append("=== DOOR SIMULATION ===")
    fail = 0
    out_doors = []
    seen = set()
    for r in doors:
        if not r.get("ok"):
            fail += 1
            lines.append(f"FAIL {r['name']}: {r.get('reason')}")
            continue
        key = (r["tile"][0], r["tile"][1], r["side"], r["kind"])
        dup = key in seen
        seen.add(key)
        status = "OK"
        if r["side"] not in r["openings"] and r["kind"] != "swing":
            status = "WARN-side"
        if r["kind"] == "swing" and r["side"] not in r["openings"] and r["side"] not in r["walls"]:
            status = "WARN-swing"
        if dup:
            status = "DUP"
            fail += 1
        lines.append(
            f"{status:10} {r['name']:28} tile={r['tile']} side={r['side']} kind={r['kind']} "
            f"lock={r['lock_start']} w={r['w']} h={r['h']} gap={r['gap']} "
            f"open={r['openings']} walls={r['walls']} why={r['why']} yaw={r['yaw']} prefer={r['prefer']}"
        )
        if not dup:
            out_doors.append(
                {
                    "x": r["tile"][0],
                    "z": r["tile"][1],
                    "side": r["side"],
                    "kind": r["kind"],
                    "lock_start": r["lock_start"],
                }
            )

    lines.append("")
    lines.append("=== CHARACTER / SPRITE SIZE SIMULATION ===")
    for n, c in chars.items():
        if c:
            lines.append(
                f"{n:24} unity=({c['ux']:.1f},{c['uz']:.1f}) godot=({c['gx']:.2f},{c['gz']:.2f}) yaw={c['yaw']:.1f}"
            )
        else:
            lines.append(f"{n:24} MISSING")
    lines.append("textures: " + ", ".join(f"{k}={v}" for k, v in sizes.items()))
    lines.append("billboard at h=1.64: " + ", ".join(f"{k}={v}" for k, v in bill.items()))
    lines.append(f"slap world size {slap_w} (must NOT use wave 142x256 aspect)")
    lines.append(f"bob {bob}")
    lines.append(f"hud {hud}")
    lines.append("")
    player = chars.get("Player")
    tutor = chars.get("BaldiTutor")
    baldi = chars.get("Baldi")
    if player and tutor:
        look_dx = tutor["gx"] - player["gx"]
        look_dz = tutor["gz"] - player["gz"]
        lines.append(f"player look toward tutor dz={look_dz:.2f} (negative Z = facing Baldi if yaw=0)")
    if baldi:
        lines.append(f"angry Baldi spawn godot=({snap2(baldi['gx'])},{snap2(baldi['gz'])})")
    if tutor:
        lines.append(f"quarter beside tutor at ({tutor['gx']+0.85:.2f},{tutor['gz']:.2f}) bob amp 0.1")

    # start yellow door in front of player looking at Baldi
    start_front = [d for d in out_doors if d["kind"] == "swing" and d["lock_start"] and d["z"] < 1]
    lines.append(f"start-lock swing doors: {start_front}")

    report = "\n".join(lines)
    OUT.write_text(report, encoding="utf-8")
    print(report)
    print("\nVALIDATED_DOORS", len(out_doors), "FAILS", fail)
    (ROOT / "tools" / "simulated_doors.json").write_text(json.dumps(out_doors, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
