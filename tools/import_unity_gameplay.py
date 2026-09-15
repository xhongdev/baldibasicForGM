#!/usr/bin/env python3
"""Import Classic 1.4.3 pickups/props without rebuilding the school geometry or GML.

The checked-in output runs without Unity. Re-running preserves existing resource IDs.
"""
from __future__ import annotations

import argparse
from functools import lru_cache
import json
from pathlib import Path
import re
import shutil

from build_from_godot import make_sound, make_sprite

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_UNITY = Path(r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI")
PICKUPS = ["EnergyFlavoredZestyBar", "YellowDoorLock", "Key", "BSODA", "Quarter",
           "Tape", "AlarmClock", "WD-3D", "SafetyScissors", "BigBoots"]
ICONS = ["EnergyFlavoredZestyBar", "YellowDoorLock", "Key", "BSODA", "Quarter",
         "Tape", "AlarmClockItem", "wd_nosquee", "SafetyScissors", "BootsIcon"]
SPRITES = ["spr_zesty", "spr_door_lock", "spr_key", "spr_bsoda", "spr_quarter",
           "spr_tape", "spr_alarm", "spr_nosquee", "spr_scissors", "spr_boots"]
PROPS = {"BSODAMachine": ("soda", "VendingMachines/BSODAMachine", 1.0, 2.0),
         "ZestyMachine": ("zesty", "VendingMachines/ZestyMachine", 1.0, 2.0),
         "PayPhone": ("phone", "TapePlayers/Phone", 0.6, 0.9),
         "TapePlayer": ("tape", "TapePlayers/TapePlayerOpen", 0.6, 0.3)}


def load_yy(path):
    return json.loads(re.sub(r",\s*([}\]])", r"\1", path.read_text(encoding="utf-8-sig")))


def field(block, name, default=""):
    match = re.search(r"^  " + re.escape(name) + r": (.*)$", block, re.M)
    return match.group(1) if match else default


def vector(block, name, default):
    values = re.findall(r"[xyzw]: ([-+\deE.]+)", field(block, name))
    return tuple(map(float, values)) if values else default


def ref(value):
    match = re.search(r"fileID: (-?\d+)", value)
    return match.group(1) if match else "0"


def scene_objects(path):
    """Keep duplicate names and compose complete parent TRS (including scale)."""
    text = path.read_text(encoding="utf-8-sig")
    blocks = {m[2]: (int(m[1]), m[3]) for m in re.finditer(
        r"^--- !u!(\d+) &(-?\d+)[^\n]*\n(.*?)(?=^--- !u!|\Z)", text, re.M | re.S)}
    transforms = {ref(field(b, "m_GameObject")): ident for ident, (kind, b) in blocks.items() if kind == 4}

    @lru_cache(None)
    def matrix(ident):
        if ident == "0":
            return ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1))
        b = blocks[ident][1]
        x, y, z, w = vector(b, "m_LocalRotation", (0, 0, 0, 1))
        s = vector(b, "m_LocalScale", (1, 1, 1))
        p = vector(b, "m_LocalPosition", (0, 0, 0))
        rot = ((1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)),
               (2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)),
               (2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)))
        local = tuple(tuple(rot[i][j]*s[j] for j in range(3)) + (p[i],) for i in range(3)) + ((0, 0, 0, 1),)
        parent = matrix(ref(field(b, "m_Father")))
        return tuple(tuple(sum(parent[i][k]*local[k][j] for k in range(4)) for j in range(4)) for i in range(4))

    @lru_cache(None)
    def active(ident):
        if ident == "0":
            return True
        b = blocks[ident][1]
        go = blocks[ref(field(b, "m_GameObject"))][1]
        return field(go, "m_IsActive", "1") != "0" and active(ref(field(b, "m_Father")))

    result = []
    for ident, (kind, b) in blocks.items():
        if kind != 1 or ident not in transforms:
            continue
        tid = transforms[ident]
        mat = matrix(tid)
        ux, uy, uz = (mat[i][3] for i in range(3))
        result.append({"source_id": ident, "name": field(b, "m_Name"),
                       "x": round((ux-5)*0.2, 5), "y": round(uy*0.2, 5),
                       "z": round(1-uz*0.2, 5), "active": active(tid)})
    return result


def export_gameplay(unity):
    items, props = [], []
    for obj in scene_objects(unity / "Assets/Scene/Scenes/School.unity"):
        name = obj["name"]
        if name.startswith("Pickup_") and name[7:] in PICKUPS:
            kind = PICKUPS.index(name[7:]) + 1
            items.append({**obj, "kind": kind, "spr": SPRITES[kind-1],
                          "reward": kind == 5 and not obj["active"]})
        elif name in PROPS:
            kind, _, w, h = PROPS[name]
            props.append({**obj, "kind": kind, "spr": "spr_prop_" + kind, "w": w, "h": h})
    assert {i["kind"] for i in items} == set(range(1, 11)), "Missing Unity pickup kinds"
    assert sum(i["reward"] for i in items) == 1, "Expected one first-notebook reward"
    assert len(props) == 5, "Expected two soda machines, zesty machine, phone, tape player"
    return {"schema": 1, "source": "Unity Classic 1.4.3 School.unity", "items": items, "props": props}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unity", type=Path, default=DEFAULT_UNITY)
    parser.add_argument("--check", action="store_true", help="Compare scene data with checked-in output; do not write")
    args = parser.parse_args()
    data = export_gameplay(args.unity)
    output = ROOT / "datafiles/school_gameplay.json"
    if args.check:
        assert json.loads(output.read_text(encoding="utf-8")) == data, "Gameplay data differs from Unity"
        print(f"Unity parity OK: {len(data['items'])} pickups, {len(data['props'])} props, all 10 item IDs")
        return

    project_path = ROOT / "baldibasicForGM.yyp"
    project_text = project_path.read_text(encoding="utf-8")
    project = load_yy(project_path)
    resources = {r["id"]["name"] for r in project["resources"]}

    def register(name, path):
        nonlocal project_text
        if name not in resources:
            entry = json.dumps({"id": {"name": name, "path": path}}, separators=(",", ":"))
            project_text = project_text.replace('"resources":[', '"resources":[\n    ' + entry + ",", 1)
            resources.add(name)

    texture_dir = args.unity / "Assets/Texture2D/SchoolHouse/PickUps"
    textures = [(SPRITES[i], texture_dir / (icon + ".png")) for i, icon in enumerate(ICONS)]
    textures += [("spr_prop_" + kind, texture_dir / (rel + ".png")) for kind, rel, _, _ in PROPS.values()]
    textures += [("spr_prop_tape_closed", texture_dir / "TapePlayers/TapePlayerClosed.png")]
    for name, src in textures:
        yy_path = ROOT / f"sprites/{name}/{name}.yy"
        if not yy_path.exists():
            path = make_sprite(name, src, True, 0, 0, "World" if "prop_" in name else "UI")
        else:
            # Refresh pixels without changing frame/layer IDs from the IDE.
            yy = load_yy(yy_path)
            frame, layer = yy["frames"][0]["name"], yy["layers"][0]["name"]
            shutil.copy2(src, yy_path.parent / f"{frame}.png")
            shutil.copy2(src, yy_path.parent / f"layers/{frame}/{layer}.png")
            path = yy_path.relative_to(ROOT).as_posix()
        register(name, path)
    for name, source in {"snd_soda": "soda_spray", "snd_nosquee": "can_spray",
                         "snd_antihearing": "AntiHearing", "snd_alarm": "bell"}.items():
        register(name, make_sound(name, args.unity / f"Assets/AudioClip/Sounds/Items/{source}.wav"))
    if not any(f["name"] == output.name for f in project["IncludedFiles"]):
        entry = {"$GMIncludedFile": "", "%Name": output.name, "CopyToMask": -1,
                 "filePath": "datafiles", "name": output.name,
                 "resourceType": "GMIncludedFile", "resourceVersion": "2.0"}
        project_text = project_text.replace('"IncludedFiles":[', '"IncludedFiles":[\n    ' + json.dumps(entry) + ",", 1)
    output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    project_path.write_text(project_text, encoding="utf-8")
    print(f"Imported {len(data['items'])} pickups, {len(data['props'])} props and Unity item assets")


if __name__ == "__main__":
    main()
