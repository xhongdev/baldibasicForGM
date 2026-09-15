#!/usr/bin/env python3
from pathlib import Path
import re

UNITY = Path(r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\Scene\Scenes\School.unity")
lines = UNITY.read_text(encoding="utf-8", errors="replace").splitlines()

blocks = []
cur = None
for i, line in enumerate(lines):
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
        if ln.strip().startswith(key + ":") or ln.strip().startswith(key + " "):
            return ln.split(":", 1)[-1].strip()
    return ""

gos = {}
trs = {}
for b in blocks:
    if b["type"] == "1":
        name = field(b, "m_Name").strip()
        comps = []
        grab = False
        for ln in b["lines"]:
            if ln.strip().startswith("m_Component:"):
                grab = True
                continue
            if grab:
                m = re.search(r"fileID: (\d+)", ln)
                if m:
                    comps.append(m.group(1))
                elif ln.startswith("  m_"):
                    grab = False
        gos[b["id"]] = {"name": name, "comps": comps}
    elif b["type"] == "4":
        go = field(b, "m_GameObject")
        m = re.search(r"fileID: (\d+)", go)
        pos = field(b, "m_LocalPosition")
        rot = field(b, "m_LocalRotation")
        father = field(b, "m_Father")
        pm = re.search(r"x: ([-\d.]+), y: ([-\d.]+), z: ([-\d.]+)", pos)
        rm = re.search(r"x: ([-\d.]+), y: ([-\d.]+), z: ([-\d.]+), w: ([-\d.]+)", rot)
        fm = re.search(r"fileID: (\d+)", father)
        if pm:
            trs[b["id"]] = {
                "go": m.group(1) if m else "",
                "x": float(pm.group(1)),
                "y": float(pm.group(2)),
                "z": float(pm.group(3)),
                "ry": float(rm.group(2)) if rm else 0,
                "rw": float(rm.group(4)) if rm else 1,
                "father": fm.group(1) if fm else "0",
            }

go_by_tr = {tid: t["go"] for tid, t in trs.items()}

def world(tid, guard=0):
    if tid in ("0", "", None) or tid not in trs or guard > 16:
        return 0.0, 0.0, 0.0
    t = trs[tid]
    px, py, pz = world(t["father"], guard + 1)
    return px + t["x"], py + t["y"], pz + t["z"]

def to_godot(ux, uz):
    return round((ux - 5.0) * 0.2, 3), round((uz + 5.0) * -0.2 + 2.0, 3)

def yaw_side(ry, rw):
    # quaternion y,w -> yaw. identity rw=1 door facing +Z = our south? Unity +Z is our -Z (north).
    # 90 deg y=0.71 w=0.71 typically faces +X or -X
    import math
    # y-up quat yaw
    siny = 2 * (rw * ry)
    cosy = 1 - 2 * (ry * ry)
    yaw = math.atan2(siny, cosy)  # radians, 0 = +Z unity = our north (-Z godot)
    deg = (yaw * 180 / math.pi) % 360
    if deg < 45 or deg >= 315:
        return "n"  # facing unity +Z = godot -Z = north wall of tile? door on north face
    if 45 <= deg < 135:
        return "e"
    if 135 <= deg < 225:
        return "s"
    return "w"

print("=== SWING ===")
for gid, g in gos.items():
    n = g["name"]
    if "SwingDoor" not in n and "Cafe_Door" not in n:
        continue
    tid = g["comps"][0] if g["comps"] else ""
    if tid not in trs:
        print("MISS", n, tid)
        continue
    wx, wy, wz = world(tid)
    gx, gz = to_godot(wx, wz)
    t = trs[tid]
    print(f"{n:28} u=({wx:7.1f},{wz:7.1f}) g=({gx:7.2f},{gz:7.2f}) side~{yaw_side(t['ry'], t['rw'])} ry={t['ry']:.2f} rw={t['rw']:.2f}")

print("\n=== HALL CLASS DOORS ===")
for gid, g in gos.items():
    n = g["name"]
    if not n.startswith("Hall_2Wall_Door"):
        continue
    tid = g["comps"][0] if g["comps"] else ""
    if tid not in trs:
        print("MISS", n, tid)
        continue
    wx, wy, wz = world(tid)
    gx, gz = to_godot(wx, wz)
    t = trs[tid]
    print(f"{n:28} u=({wx:7.1f},{wz:7.1f}) g=({gx:7.2f},{gz:7.2f}) side~{yaw_side(t['ry'], t['rw'])} ry={t['ry']:.2f} rw={t['rw']:.2f}")

print("\n=== FACULTY HALL DOORS ===")
for gid, g in gos.items():
    n = g["name"]
    if "FacultyDoor" not in n:
        continue
    tid = g["comps"][0] if g["comps"] else ""
    if tid not in trs:
        print("MISS", n, tid)
        continue
    wx, wy, wz = world(tid)
    gx, gz = to_godot(wx, wz)
    t = trs[tid]
    print(f"{n:28} u=({wx:7.1f},{wz:7.1f}) g=({gx:7.2f},{gz:7.2f}) side~{yaw_side(t['ry'], t['rw'])} ry={t['ry']:.2f} rw={t['rw']:.2f}")
