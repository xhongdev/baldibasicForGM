#!/usr/bin/env python3
"""Describe the Classic 1.4.3 start route from School.unity (GM axes annotated)."""
from __future__ import annotations

import math
import re
from pathlib import Path

UNITY = Path(
    r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\Scene\Scenes\School.unity"
)


def u_to_p(ux, uz):
    return (ux - 5.0) * 0.2, (uz + 5.0) * -0.2 + 2.0


def snap2(v):
    return round(v / 2.0) * 2.0


def yaw_from_quat(ry, rw):
    return math.degrees(math.atan2(2.0 * rw * ry, 1.0 - 2.0 * ry * ry)) % 360.0


def rotate_xz(x, z, yaw_deg):
    t = math.radians(yaw_deg)
    c, s = math.cos(t), math.sin(t)
    return x * c + z * s, -x * s + z * c


def parse():
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
            gos[b["id"]] = {"name": field(b, "m_Name").strip(), "comps": comps, "active": field(b, "m_IsActive") != "0"}
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

    named = {}
    for gid, g in gos.items():
        tids = [c for c in g["comps"] if c in trs]
        if not tids:
            continue
        wx, wy, wz, yaw = world(tids[0])
        gx, gz = u_to_p(wx, wz)
        named[g["name"]] = {
            "unity": (wx, wy, wz),
            "gm": (gx, gz),
            "tile": (snap2(gx), snap2(gz)),
            "yaw": yaw,
            "name": g["name"],
        }
    return named


def main():
    n = parse()
    keys = [
        "Player",
        "Main Camera",
        "BaldiTutor",
        "TutorBaldi",
        "Entrance (0)",
        "ExitTrigger",
        "Hall_1Wall",
        "Hall_SwingDoor",
        "Hall_SwingDoor (1)",
        "Hall_SwingDoor (2)",
        "Hall_2Wall_Door",
        "Hall_2Wall_Door (1)",
        "MathRoom",
        "SpellingRoom",
    ]
    print("=== Unity start pieces ===")
    for k in keys:
        if k in n:
            o = n[k]
            print(
                f"{k:22} Unity xz=({o['unity'][0]:7.1f},{o['unity'][2]:7.1f}) "
                f"yaw={o['yaw']:6.1f}  GM=({o['gm'][0]:6.2f},{o['gm'][1]:7.2f}) tile={o['tile']}"
            )
        else:
            print(f"{k:22} MISSING")
    print()
    print("All notebooks / swing / class doors near start (Unity z < 80, |x|<80):")
    for name, o in sorted(n.items(), key=lambda kv: (kv[1]["unity"][2], kv[1]["unity"][0])):
        nm = name
        if not any(
            s in nm
            for s in (
                "Notebook",
                "Hall_SwingDoor",
                "Hall_2Wall_Door",
                "Entrance",
                "Exit",
                "Math",
                "Spell",
                "Player",
                "BaldiTutor",
                "Tutor",
            )
        ):
            continue
        ux, uz = o["unity"][0], o["unity"][2]
        if abs(ux) > 80 or uz > 80 or uz < -40:
            continue
        print(
            f"  {nm:28} U=({ux:7.1f},{uz:7.1f}) yaw={o['yaw']:6.1f} GM={o['tile']}"
        )


if __name__ == "__main__":
    main()
