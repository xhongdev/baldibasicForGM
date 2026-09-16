#!/usr/bin/env python3
"""Build walls and doors from their actual Unity mesh planes, not tile yaw guesses."""
from __future__ import annotations

import argparse
from collections import Counter, deque
import html
import json
import math
from pathlib import Path
import re
import shutil
import struct
import zlib

from import_unity_gameplay import DEFAULT_UNITY, ROOT, field, ref
from unity_scene import UnityScene, gm_point

DOOR_SCRIPT = "3e03bb9b92817464d9b3c48091b4270e"
SWING_SCRIPT = "da30cc40ac6707b4596c8a5319ef16e8"
NOTEBOOK_SCRIPT = "61ea5db375303224eada00d83884b71c"
DELTA = {"e": (2, 0), "w": (-2, 0), "n": (0, -2), "s": (0, 2)}


def clean(value):
    # Remove Unity quaternion roundoff, preserving all authored half-unit offsets.
    snapped = round(value * 1000) / 1000
    return snapped if abs(value - snapped) < 0.0001 else round(value, 5)


def plane(scene, tid):
    meshes = scene.components(tid, 33)
    mesh = ref(field(meshes[0][2], "m_Mesh")) if meshes else ""
    assert mesh in ("10209", "10210"), scene.ancestry(tid)
    # Built-in Plane is 10 by 10 in local XZ. These become bottom-left first
    # on the source's upright wall transforms; retain the original UV direction.
    corners = [(-5, 0, 5), (5, 0, 5), (5, 0, -5), (-5, 0, -5)]
    if mesh == "10210":
        corners = [(-0.5, -0.5, 0), (0.5, -0.5, 0), (0.5, 0.5, 0), (-0.5, 0.5, 0)]
    # Unity's built-in Plane runs U from +X to -X. Quad runs it from -X to +X.
    # Winding and UVs are independent: reversing the winding must not mirror text.
    uvs = [[1, 1], [0, 1], [0, 0], [1, 0]] if mesh == "10209" else [[0, 1], [1, 1], [1, 0], [0, 0]]
    vertices = [[clean(v) for v in gm_point(scene.point(tid, p))] + uv for p, uv in zip(corners, uvs)]
    # Unity reverses culling for negative-scale transforms. Bake that into the
    # exported winding, including the handedness change from reflecting world Z.
    m = scene.matrix(tid)
    axis, sign = (1, 1) if mesh == "10209" else (2, -1)
    normal = [m[0][axis]*sign, m[1][axis]*sign, -m[2][axis]*sign]
    a = [vertices[1][i]-vertices[0][i] for i in range(3)]
    b = [vertices[2][i]-vertices[0][i] for i in range(3)]
    cross = [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
    if sum(cross[i]*normal[i] for i in range(3)) < 0:
        vertices.reverse()
    return vertices


def bounds(vertices):
    return [min(p[i] for p in vertices) for i in range(3)] + [max(p[i] for p in vertices) for i in range(3)]


def material_names(unity):
    result = {}
    for path in (unity / "Assets/Material").rglob("*.mat.meta"):
        match = re.search(r"^guid: (\w+)", path.read_text(encoding="utf-8"), re.M)
        if match:
            result[match[1]] = path.name[:-9]
    return result


def material_data(unity):
    textures = {}
    for path in (unity / "Assets/Texture2D").rglob("*.png.meta"):
        match = re.search(r"^guid: (\w+)", path.read_text(encoding="utf-8"), re.M)
        if match: textures[match[1]] = Path(str(path)[:-5])
    result = {}
    for path in (unity / "Assets/Material").rglob("*.mat"):
        text = path.read_text(encoding="utf-8")
        name = field(text, "m_Name")
        tex = re.search(r"- _MainTex:\s*\n\s*m_Texture: (.*?)\n\s*m_Scale: \{x: (.*?), y: (.*?)\}\n\s*m_Offset: \{x: (.*?), y: (.*?)\}", text)
        src = textures.get(guid(tex[1])) if tex else None
        colour = re.search(r"- _Color: \{r: (.*?), g: (.*?), b: (.*?), a: (.*?)\}", text)
        rgb = [round(float(v)*255) for v in colour.groups()[:3]] if colour else [255]*3
        result[name] = {"file": "tex/map/" + (src.name if src else "solid_white.png"),
                        "source": src.relative_to(unity).as_posix() if src else "",
                        "uv": list(map(float, tex.groups()[1:])) if tex else [1, 1, 0, 0],
                        "colour": rgb[0] + rgb[1]*256 + rgb[2]*65536}
    return result


def copy_materials(data, unity):
    dest = ROOT / "datafiles/tex/map"
    dest.mkdir(parents=True, exist_ok=True)
    project = ROOT / "baldibasicForGM.yyp"
    text = project.read_text(encoding="utf-8")
    includes = []
    copied = set()
    for material in data["materials"].values():
        relative = material["file"]
        if relative in copied: continue
        copied.add(relative)
        output = ROOT / "datafiles" / relative
        if material["source"]:
            shutil.copy2(unity / material["source"], output)
        else:
            def chunk(kind, payload):
                return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind+payload))
            output.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B", 1, 1, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\0\xff\xff\xff\xff")) + chunk(b"IEND", b""))
        # Entries from this importer are identified by both name and directory.
        entry = {"$GMIncludedFile": "", "%Name": output.name, "CopyToMask": -1,
                 "filePath": "datafiles/tex/map", "name": output.name, "resourceType": "GMIncludedFile", "resourceVersion": "2.0"}
        includes.append(entry)
    from import_unity_gameplay import load_yy
    existing = {(i["filePath"], i["name"]) for i in load_yy(project)["IncludedFiles"]}
    for entry in includes:
        if (entry["filePath"], entry["name"]) not in existing:
            text = text.replace('"IncludedFiles":[', '"IncludedFiles":[\n    ' + json.dumps(entry) + ",", 1)
    project.write_text(text, encoding="utf-8")


def guid(value):
    match = re.search(r"guid: (\w+)", value)
    return match.group(1) if match else ""


def build_map(unity, previous, scene_name="School"):
    scene = UnityScene(unity / f"Assets/Scene/Scenes/{scene_name}.unity")
    mats = material_names(unity)
    materials = material_data(unity)
    used_materials = {}
    quads, doors, notebooks, exits = [], [], [], []
    seen = set()
    source_counts = Counter()
    for tid in scene.transforms.values():
        if not scene.active(tid):
            continue
        name = scene.name(tid)
        path = scene.ancestry(tid)
        if scene_name == "School" and path[0] != "Environment":
            continue
        parent = ref(field(scene.blocks[tid][1], "m_Father"))
        px, py, pz = [clean(v) for v in gm_point(scene.point(tid))]
        if name.split(" (")[0] in ("Floor", "Ceiling", "Wall", "Window") and scene.name(parent).startswith(("Hall_", "Room_", "Cafe_", "Entrance")):
            renderers = scene.components(tid, 23)
            if not renderers or field(renderers[0][2], "m_Enabled") == "0":
                continue
            verts = plane(scene, tid)
            box = bounds(verts)
            kind = "floor" if name.startswith("Floor") else "ceil" if name.startswith("Ceiling") else "wall"
            material = re.search(r"m_Materials:\s*\n\s*- (.*)", renderers[0][2])
            mat = mats.get(guid(material[1]), "") if material else ""
            source_counts["material:" + mat] += 1
            gm_mat = "carpet" if "Carpet" in mat else "tile" if kind == "floor" else "ceil" if kind == "ceil" else "window" if "Window" in mat else "brick"
            used_materials[mat] = materials[mat]
            source_counts[kind] += 1
            key = (kind, tuple(tuple(v) for v in verts), mat)
            if key in seen:
                continue
            seen.add(key)
            quads.append({"k": kind, "x": px, "z": pz, "m": gm_mat, "d": int("Dark" in mat),
                          "v": verts, "bounds": box, "source_id": tid, "material": mat})
        if name == "ExitTrigger":
            exits.append({"x": px, "z": pz, "name": path[-2], "source_id": tid})
        for ident, _, script in scene.components(tid, 114):
            script_guid = guid(field(script, "m_Script"))
            if script_guid == NOTEBOOK_SCRIPT:
                notebooks.append({"x": px, "y": py, "z": pz, "source_id": tid, "spr": "spr_nb_green"})
            if script_guid not in (DOOR_SCRIPT, SWING_SCRIPT):
                continue
            # Read the barrier component reference, then its GameObject transform.
            barrier = scene.blocks[ref(field(script, "barrier"))][1]
            bt = scene.transforms[ref(field(barrier, "m_GameObject"))]
            verts = plane(scene, bt)
            box = bounds(verts)
            cx, cy, cz = [(box[i]+box[i+3])*0.5 for i in range(3)]
            tile_x, _, tile_z = [clean(v) for v in gm_point(scene.point(parent))]
            side = ("e" if cx > tile_x else "w") if box[3]-box[0] < 0.001 else ("s" if cz > tile_z else "n")
            mat = mats.get(guid(field(script, "closed")), "")
            open_mat = mats.get(guid(field(script, "open")), "")
            kind = "swing" if script_guid == SWING_SCRIPT else "faculty" if "Faculty" in mat else "class"
            # Use outside renderer geometry for UV orientation, barrier for collision.
            in_block = scene.blocks[ref(field(script, "inside"))][1]
            in_tid = scene.transforms[ref(field(in_block, "m_GameObject"))]
            out_block = scene.blocks[ref(field(script, "outside"))][1]
            out_tid = scene.transforms[ref(field(out_block, "m_GameObject"))]
            doors.append({"x": tile_x, "z": tile_z, "cx": cx, "cz": cz, "side": side,
                          "w": max(box[3]-box[0], box[5]-box[2]), "h": box[4]-box[1],
                          "kind": kind, "lock_start": kind == "swing", "v": plane(scene, out_tid),
                          "v_inside": plane(scene, in_tid),
                          "bounds": box, "source_id": ident, "source_name": scene.name(parent)})
            doors[-1].update(material=mat, open_material=open_mat)
            used_materials[mat] = materials[mat]
            used_materials[open_mat] = materials[open_mat]
    quads.sort(key=lambda q: (q["k"], q["z"], q["x"], q["bounds"][1], q["source_id"]))
    doors.sort(key=lambda d: (d["kind"], d["z"], d["x"]))
    notebooks.sort(key=lambda n: (n["z"], n["x"]), reverse=True)
    colours = ["green", "red", "blue", "yellow", "cyan", "salmon", "black"]
    for i, notebook in enumerate(notebooks):
        notebook["spr"] = "spr_nb_" + colours[i % 7]
    result = dict(previous)
    if "player" not in result:
        player = next(t for t in scene.transforms.values() if scene.name(t) == "Player")
        result["player"] = list(gm_point(scene.point(player)))
    if scene_name == "Secret":
        player = next(t for t in scene.transforms.values() if scene.name(t) == "Player")
        camera = next(t for t in scene.transforms.values() if scene.name(t) == "Main Camera")
        origin = gm_point(scene.point(player))
        forward = gm_point(scene.point(player, (0, 0, 1)))
        result["camera"] = list(gm_point(scene.point(camera)))
        result["player_yaw"] = round(math.atan2(origin[0]-forward[0], origin[2]-forward[2]), 6)
    result.update(schema=2, scene=scene_name,
                  source=f"Unity Classic 1.4.3 {scene_name}.unity mesh planes (parent TRS)",
                  quads=quads, doors=doors, notebooks=notebooks, exits=exits, materials=used_materials)
    result["nav_edges"] = build_nav_edges(result)
    return result, source_counts


def wall_boxes(data):
    return [q["bounds"] for q in data["quads"] if q["k"] == "wall" and q["bounds"][1] < 1 < q["bounds"][4]]


def hits_wall(x, z, boxes, radius=0.29):
    for x0, _, z0, x1, _, z1 in boxes:
        # Match GameMaker's wall thickness of .08.
        if x1-x0 < 0.001: x0, x1 = x0-0.08, x1+0.08
        if z1-z0 < 0.001: z0, z1 = z0-0.08, z1+0.08
        dx, dz = x-max(x0, min(x, x1)), z-max(z0, min(z, z1))
        if dx*dx+dz*dz < radius*radius:
            return True
    return False


def build_nav_edges(data):
    floors = {(q["x"], q["z"]) for q in data["quads"] if q["k"] == "floor" and q["bounds"][1] == 0}
    walls = wall_boxes(data)
    portals = {}
    for d in data["doors"]:
        dx, dz = DELTA[d["side"]]
        a, b = (d["x"], d["z"]), (d["x"]+dx, d["z"]+dz)
        portals[frozenset((a, b))] = [d["cx"], d["cz"]]
    edges = []
    for x, z in sorted(floors):
        for dx, dz in ((2, 0), (0, 2)):
            a, b = (x, z), (x+dx, z+dz)
            if b not in floors:
                continue
            p = portals.get(frozenset((a, b)), [x+dx/2, z+dz/2])
            if not hits_wall(*p, walls):
                edges.append({"a": list(a), "b": list(b), "p": p})
    return edges


def validate(data, school=True):
    floors = {(q["x"], q["z"]) for q in data["quads"] if q["k"] == "floor"}
    walls = wall_boxes(data)
    assert floors, "Scene has no walkable floor geometry"
    if school:
        assert len(floors) > 600
        assert len(data["doors"]) == 23, f"Unexpected scripted door count: {len(data['doors'])}"
        assert len(data["notebooks"]) == 7
        assert len(data["exits"]) == 4
    for d in data["doors"]:
        dx, dz = DELTA[d["side"]]
        assert (d["x"], d["z"]) in floors and (d["x"]+dx, d["z"]+dz) in floors, ("door faces missing floor", d)
        assert not hits_wall(d["cx"], d["cz"], walls), ("door blocked by wall", d)
        assert abs(d["w"]-(2 if d["kind"] == "swing" else 1)) < 0.001, d
        assert bounds(d["v"]) == bounds(d["v_inside"]), ("door faces do not coincide", d)
    graph = {p: [] for p in floors}
    for e in data["nav_edges"]:
        graph[tuple(e["a"])].append(tuple(e["b"]))
        graph[tuple(e["b"])].append(tuple(e["a"]))
    start = (round(data["player"][0]/2)*2, round(data["player"][2]/2)*2)
    seen, queue = {start}, deque([start])
    while queue:
        for nb in graph[queue.popleft()]:
            if nb not in seen: seen.add(nb); queue.append(nb)
    for n in data["notebooks"]:
        assert (round(n["x"]/2)*2, round(n["z"]/2)*2) in seen, ("unreachable notebook", n)
    if not school:
        assert start in seen, ("unreachable player spawn", data["player"])
    return {"floors": len(floors), "reachable_floors": len(seen), "wall_surfaces": sum(q["k"] == "wall" for q in data["quads"]),
            "collision_walls": len(walls), "doors": len(data["doors"]), "notebooks": len(data["notebooks"]), "nav_edges": len(data["nav_edges"])}


def write_preview(data, old, path):
    # Standalone zoomable SVG. Native browser zoom keeps world coordinates legible.
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="-37 -75 70 86" width="980" height="1204">',
             '<rect x="-37" y="-75" width="70" height="86" fill="#18202c"/>',
             '<g stroke-width=".10">']
    for q in data["quads"]:
        if q["k"] == "floor":
            parts.append(f'<rect x="{q["x"]-1}" y="{q["z"]-1}" width="2" height="2" fill="{"#566271" if q["m"] == "carpet" else "#b8c2cd"}" stroke="#8b98a6"/>')
    for box in wall_boxes(data):
        parts.append(f'<path d="M{box[0]},{box[2]} L{box[3]},{box[5]}" stroke="#202630" stroke-width=".17"/>')
    for d in old["doors"]:
        dx, dz = DELTA[d["side"]]
        cx, cz = d["x"]+dx/2, d["z"]+dz/2
        hw = 1 if d["kind"] == "swing" else .5
        parts.append(f'<path d="M{cx-(hw if dz else 0)},{cz-(hw if dx else 0)} L{cx+(hw if dz else 0)},{cz+(hw if dx else 0)}" stroke="#ff5275" stroke-width=".13" stroke-dasharray=".25 .15"/>')
    for d in data["doors"]:
        b = d["bounds"]
        label = html.escape(f'{d["source_name"]}: ({d["cx"]}, {d["cz"]}) {d["w"]}x{d["h"]}')
        parts.append(f'<path d="M{b[0]},{b[2]} L{b[3]},{b[5]}" stroke="{"#ffdb4d" if d["kind"] == "swing" else "#22c8f0"}" stroke-width=".22"><title>{label}</title></path>')
    for n in data["notebooks"]:
        parts.append(f'<circle cx="{n["x"]}" cy="{n["z"]}" r=".4" fill="#48ef87" stroke="#10291b"/>')
    parts += ['</g><g fill="white" font-family="sans-serif" font-size="1">',
              '<text x="-35" y="7">Unity walls / doors: cyan + yellow; old doors: red dashed</text>',
              '<text x="-35" y="9">Green: notebooks. Hover a door for source name and coordinates.</text>', '</g></svg>']
    path.write_text("\n".join(parts), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unity", type=Path, default=DEFAULT_UNITY)
    parser.add_argument("--write", action="store_true", help="Write only after all geometry checks pass")
    parser.add_argument("--check", action="store_true", help="Assert the checked-in map matches Unity")
    parser.add_argument("--verbose", action="store_true", help="Print all door coordinates and source material counts")
    parser.add_argument("--scene", choices=("School", "Secret"), default="School")
    args = parser.parse_args()
    target = ROOT / ("datafiles/school_map.json" if args.scene == "School" else "datafiles/secret_map.json")
    old = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
    data, counts = build_map(args.unity, old, args.scene)
    if args.verbose:
        for d in data["doors"]:
            print(f'{d["kind"]:7} {d["source_name"]:30} tile=({d["x"]:5},{d["z"]:6}) face={d["side"]} center=({d["cx"]:5},{d["cz"]:6}) width={d["w"]}')
        print("Source:", dict(counts))
    stats = validate(data, args.scene == "School")
    print("Validated:", json.dumps(stats))
    if args.check:
        assert old == data, "Map differs from source; run --write to regenerate"
        print("Unity map parity OK")
    if args.write:
        copy_materials(data, args.unity)
        preview = ROOT / "tools/unity_map_comparison.svg"
        if args.scene == "School" and (old.get("schema") != 2 or not preview.exists()):
            write_preview(data, old, preview)
        target.write_text(json.dumps(data, separators=(",", ":")) + "\n", encoding="utf-8")
        report = "unity_map_report.json" if args.scene == "School" else "unity_secret_map_report.json"
        (ROOT / "tools" / report).write_text(json.dumps(stats, indent=2) + "\n", encoding="utf-8")
        print("Wrote source-derived map and comparison SVG")


if __name__ == "__main__":
    main()
