#!/usr/bin/env python3
"""Confirm each hallway door tile's missing walls and DoubleDoor local offset from Godot School.tscn."""
from __future__ import annotations
import re
from pathlib import Path

TSCN = Path(r"D:\Github\baldigd\Scenes\School.tscn")
IDENT = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
WALL = {"Wall1": "n", "Wall2": "s", "Wall3": "w", "Wall4": "e"}


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
    return [xx, yx, zx, xy, yy, zy, xz, yz, zz, ox + p[9], oy + p[10], oz + p[11]]


def parse():
    node_re = re.compile(r'^\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?\]')
    xf_re = re.compile(r"^transform = Transform3D\((.*)\)$")
    nodes = {}
    order = []
    current = None
    for raw in TSCN.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        m = node_re.match(line)
        if m:
            name, ntype, parent = m.group(1), m.group(2), m.group(3)
            npath = name if parent in (None, ".") else f"{parent}/{name}"
            current = {
                "name": name,
                "type": ntype,
                "parent": None if parent in (None, ".") else parent,
                "path": npath,
                "transform": IDENT[:],
            }
            nodes[npath] = current
            order.append(npath)
            continue
        if current is None:
            continue
        m = xf_re.match(line)
        if m:
            current["transform"] = [float(x.strip()) for x in m.group(1).split(",")]
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


def door_kind(name: str):
    if "DoubleDoor" in name or "CafeDoor" in name:
        return "swing"
    if "FacultyDoor" in name or "PrincipalDoor" in name:
        return "faculty"
    if name.startswith("Hall_2WallDoor") or "SweepDoor" in name:
        return "class"
    return None


def main():
    nodes, order = parse()
    children = {}
    for npath in order:
        p = nodes[npath]["parent"]
        if p:
            children.setdefault(p, []).append(npath)
    print(f"{'name':32} {'tile':16} missing  extra  kind")
    for npath in order:
        n = nodes[npath]
        kind = door_kind(n["name"])
        if kind is None:
            continue
        if n["parent"] and door_kind(nodes[n["parent"]]["name"]):
            continue
        t = world(nodes, npath)
        tx, tz = round(t[9], 2), round(t[11], 2)
        present = set()
        extra = []
        for cpath in children.get(npath, []):
            cn = nodes[cpath]
            if cn["name"] in WALL:
                present.add(WALL[cn["name"]])
            if "Door" in cn["name"] or "Double" in cn["name"]:
                ct = cn["transform"]
                extra.append((cn["name"], round(ct[9], 2), round(ct[11], 2)))
        missing = {"n", "s", "w", "e"} - present
        print(f"{n['name']:32} ({tx:6.1f},{tz:7.1f}) miss={sorted(missing)} extra={extra} {kind}")


if __name__ == "__main__":
    main()
