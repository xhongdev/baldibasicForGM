#!/usr/bin/env python3
"""Import source UI rectangles, sprite references and presentation audio."""
from functools import lru_cache
import argparse
import json
from pathlib import Path
import re
import shutil
import hashlib

from import_unity_gameplay import DEFAULT_UNITY, ROOT, field, ref, vector, load_yy
from import_unity_map import guid, NOTEBOOK_SCRIPT
from unity_scene import UnityScene, gm_point
from build_from_godot import png_size, make_sound


def texture_index(unity):
    result = {}
    for path in (unity / "Assets").rglob("*.png.meta"):
        meta = path.read_text(encoding="utf-8")
        match = re.search(r"^guid: (\w+)", meta, re.M)
        if match: result[match[1]] = Path(str(path)[:-5])
    return result


def rect_reader(scene, size):
    @lru_cache(None)
    def rect(tid):
        b = scene.blocks[tid][1]
        parent = ref(field(b, "m_Father"))
        if parent == "0" or scene.components(tid, 223):
            return (0, 0, size[0], size[1], 1, 1)
        px, py, pw, ph, psx, psy = rect(parent)
        amin = vector(b, "m_AnchorMin", (0.5, 0.5))
        amax = vector(b, "m_AnchorMax", (0.5, 0.5))
        pos = vector(b, "m_AnchoredPosition", (0, 0))
        delta = vector(b, "m_SizeDelta", (0, 0))
        pivot = vector(b, "m_Pivot", (0.5, 0.5))
        scale = vector(b, "m_LocalScale", (1, 1, 1))
        sx, sy = psx * scale[0], psy * scale[1]
        w = ((amax[0]-amin[0])*pw + delta[0]*psx) * scale[0]
        h = ((amax[1]-amin[1])*ph + delta[1]*psy) * scale[1]
        x = px + (amin[0]+(amax[0]-amin[0])*pivot[0])*pw + pos[0]*psx - pivot[0]*w
        y = py + (amin[1]+(amax[1]-amin[1])*pivot[1])*ph + pos[1]*psy - pivot[1]*h
        return (x, y, w, h, sx, sy)

    def gui(tid):
        x, y, w, h, _, _ = rect(tid)
        return [round(x * 640/size[0], 4), round((size[1]-y-h)*480/size[1], 4),
                round(w*640/size[0], 4), round(h*480/size[1], 4)]
    return gui


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unity", type=Path, default=DEFAULT_UNITY)
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument("--check", action="store_true", help="Verify imported rectangles and image bytes without writing")
    args = parser.parse_args()
    unity = args.unity
    textures = texture_index(unity)
    school = UnityScene(unity / "Assets/Scene/Scenes/School.unity")
    math = UnityScene(unity / "Assets/PrefabInstance/MathGame.prefab")
    output = {"textures": {}, "hud": {}, "yctp": {}, "notebooks": {}, "pickups": {}, "exit_signs": []}

    def texture(key, src):
        source = textures.get(src) if isinstance(src, str) else src
        if source is None: raise ValueError((key, src))
        name = source.relative_to(unity / "Assets").as_posix().replace("/", "_")
        output["textures"][key] = {"file": "tex/presentation/" + name, "source": source.relative_to(unity).as_posix(), "size": list(png_size(source))}
        return key

    def renderer_texture(scene, tid):
        for _, _, component in scene.components(tid):
            for key in ("m_Sprite", "m_Texture"):
                ident = guid(field(component, key))
                if ident in textures: return textures[ident]
        return None

    math_rect = rect_reader(math, (800, 600))
    for tid in math.transforms.values():
        name = math.name(tid)
        if math.blocks[tid][0] != 224 or not math.active(tid): continue
        if name in ("YCTP", "Result1", "Result2", "Result3", "BaldiFeed", "Text", "InputField", "Answer") or name.startswith("Button ("):
            r = math_rect(tid)
            rec = {"rect": r}
            src = renderer_texture(math, tid)
            if src: rec["texture"] = texture("yctp_" + name, src)
            output["yctp"][name] = rec
            if args.inspect: print("YCTP", name, r, src.name if src else "")
    # Read the script references rather than guessing names for the answer field.
    script = next(b for kind, b in math.blocks.values() if kind == 114 and "  playerAnswer:" in b)
    for name, source in (("question", "questionText"), ("answer", "playerAnswer")):
        component = math.blocks[ref(field(script, source))][1]
        tid = math.transforms[ref(field(component, "m_GameObject"))]
        output["yctp"][name] = {"rect": math_rect(tid)}
        if args.inspect: print("YCTP", name, math_rect(tid))

    # Follow GameController's references so inactive mobile/ending HUDs cannot win.
    controller = next(b for kind, b in school.blocks.values() if kind == 114 and "  itemTextures:" in b)
    hud_ids = {}
    for name in ("itemSelect", "itemText", "notebookCount"):
        ident = ref(field(controller, name))
        comp = school.blocks[ident][1]
        hud_ids[school.transforms[ref(field(comp, "m_GameObject"))]] = name
    slot_list = re.search(r"^  itemSlot:\n((?:  - .*\n)+)", controller, re.M)[1]
    for i, ident in enumerate(re.findall(r"fileID: (\d+)", slot_list)):
        comp = school.blocks[ident][1]
        hud_ids[school.transforms[ref(field(comp, "m_GameObject"))]] = "slot" + str(i)
    for tid in school.transforms.values():
        if school.blocks[tid][0] != 224: continue
        name = school.name(tid)
        if tid not in hud_ids and not (name == "ItemSlots" and school.active(tid)):
            continue
        canvas = tid
        while canvas != "0" and not school.components(canvas, 223):
            canvas = ref(field(school.blocks[canvas][1], "m_Father"))
        resolution = (640, 480)
        if canvas != "0":
            for _, _, comp in school.components(canvas, 114):
                if field(comp, "m_ReferenceResolution"):
                    resolution = vector(comp, "m_ReferenceResolution", resolution)
        rec = {"rect": rect_reader(school, resolution)(tid)}
        src = renderer_texture(school, tid)
        if src: rec["texture"] = texture("hud_" + name, src)
        output["hud"][hud_ids.get(tid, name)] = rec
        if args.inspect: print("HUD", name, resolution, rec)
    for tid in school.transforms.values():
        if not school.active(tid): continue
        name = school.name(tid)
        is_notebook = any(NOTEBOOK_SCRIPT in b for _, _, b in school.components(tid, 114))
        if is_notebook or name.startswith("Pickup_") or name == "ExitSign":
            render_tid = next((t for t in school.descendants(tid) if school.components(t, 212)), None)
            if render_tid is None: continue
            renderer = school.components(render_tid, 212)[0][2]
            source = textures[guid(field(renderer, "m_Sprite"))]
            key = texture("world_" + tid, source)
            size = png_size(source)
            meta = Path(str(source) + ".meta").read_text(encoding="utf-8")
            ppu = float(re.search(r"spritePixelsToUnits: ([\d.]+)", meta)[1])
            mat = school.matrix(render_tid)
            sx = sum(mat[i][0]**2 for i in range(3))**0.5
            sy = sum(mat[i][1]**2 for i in range(3))**0.5
            rec = {"texture": key, "w": round(size[0]/ppu*sx*0.2, 5), "h": round(size[1]/ppu*sy*0.2, 5)}
            if is_notebook: output["notebooks"][tid] = rec
            elif name == "ExitSign":
                x, y, z = gm_point(school.point(tid))
                rec.update(x=x, y=y, z=z, source_id=tid)
                entrance = next((p for p in school.ancestry(tid) if p.startswith("Entrance (")), "")
                rec["entrance"] = entrance
                output["exit_signs"].append(rec)
            else:
                go = ref(field(school.blocks[tid][1], "m_GameObject"))
                output["pickups"][go] = rec
            if args.inspect: print("WORLD", name, source.name, gm_point(school.point(tid)), rec)
    # Guaranteed source icons, independent of old sprite metadata and world sprites.
    from import_unity_gameplay import ICONS
    base = unity / "Assets/Texture2D"
    for i, icon in enumerate(ICONS): texture("item" + str(i+1), base / f"SchoolHouse/PickUps/{icon}.png")
    for key, path in {"check": "YCTPTextures/Check.png", "xmark": "YCTPTextures/X.png",
                      "spray": "SchoolHouse/PickUps/Drops/BSODA_Spray.png",
                      "alarm_drop": "SchoolHouse/PickUps/Drops/AlarmClockDrop.png",
                      "slots": "HudTextures/ItemSlots.png"}.items(): texture(key, base / path)
    if args.inspect: return
    if args.check:
        saved = json.loads((ROOT / "datafiles/presentation.json").read_text(encoding="utf-8"))
        assert saved == output, "Presentation data differs from Unity"
        for asset in output["textures"].values():
            assert hashlib.sha256((unity / asset["source"]).read_bytes()).digest() == hashlib.sha256((ROOT / "datafiles" / asset["file"]).read_bytes()).digest(), asset["file"]
        print("Presentation parity OK: UI rectangles, world sprite references and all imported image bytes")
        return

    dest = ROOT / "datafiles/tex/presentation"
    dest.mkdir(parents=True, exist_ok=True)
    project = ROOT / "baldibasicForGM.yyp"
    text = project.read_text(encoding="utf-8")
    includes = {(r["filePath"], r["name"]) for r in load_yy(project)["IncludedFiles"]}

    def include(path):
        nonlocal text
        directory = "datafiles/" + path.parent.as_posix() if path.parent.as_posix() != "." else "datafiles"
        if (directory, path.name) in includes: return
        entry = {"$GMIncludedFile": "", "%Name": path.name, "CopyToMask": -1, "filePath": directory,
                 "name": path.name, "resourceType": "GMIncludedFile", "resourceVersion": "2.0"}
        text = text.replace('"IncludedFiles":[', '"IncludedFiles":[\n    ' + json.dumps(entry) + ",", 1)
        includes.add((directory, path.name))
    for asset in output["textures"].values():
        path = Path(asset["file"])
        shutil.copy2(unity / asset["source"], ROOT / "datafiles" / path)
        include(path)
    include(Path("presentation.json"))
    (ROOT / "datafiles/presentation.json").write_text(json.dumps(output, indent=2)+"\n", encoding="utf-8")
    # Exact clip references avoid substituting one unrelated error sound everywhere.
    audio_index = {}
    for path in (unity / "Assets/AudioClip").rglob("*.wav.meta"):
        match = re.search(r"^guid: (\w+)", path.read_text(encoding="utf-8"), re.M)
        if match: audio_index[match[1]] = Path(str(path)[:-5])
    sounds = {}
    for name in ("bal_intro", "bal_howto", "bal_plus", "bal_minus", "bal_equals", "bal_screech"):
        sounds[name] = audio_index[guid(field(script, name))]
    for name in ("bal_numbers", "bal_praises", "bal_problems"):
        lines = re.search(r"^  " + name + r":\n((?:  - .*\n)+)", script, re.M)[1]
        for i, ident in enumerate(re.findall(r"guid: (\w+)", lines)):
            sounds[name + str(i)] = audio_index[ident]
    for name in ("aud_buzz", "aud_Hang", "aud_Prize", "aud_AllNotebooks", "aud_Soda", "aud_Spray", "aud_Switch", "aud_MachineQuiet", "aud_MachineStart", "aud_MachineRev", "aud_MachineLoop"):
        sounds[name] = audio_index[guid(field(controller, name))]
    principal = next(b for kind, b in school.blocks.values() if kind == 114 and "  audDetention:" in b)
    for name in ("audNoRunning", "audNoFaculty", "audNoDrinking", "audNoEscaping", "audDetention", "aud_Delay"):
        sounds[name] = audio_index[guid(field(principal, name))]
    for name in ("audTimes", "audScolds"):
        lines = re.search(r"^  " + name + r":\n((?:  - .*\n)+)", principal, re.M)[1]
        for i, ident in enumerate(re.findall(r"guid: (\w+)", lines)):
            sounds[name + str(i)] = audio_index[ident]
    resources = {r["id"]["name"] for r in load_yy(project)["resources"]}
    def register(name, path):
        nonlocal text
        if name not in resources:
            entry = {"id": {"name": name, "path": path}}
            text = text.replace('"resources":[', '"resources":[\n    '+json.dumps(entry)+",", 1)
            resources.add(name)
    gml = []
    for name, source in sounds.items():
        resource = "snd_src_" + name.lower()
        register(resource, make_sound(resource, source))
        gml.append("        " + name + ": " + resource)
    script_name = "scr_bb_audio_assets"
    script_dir = ROOT / "scripts" / script_name
    script_dir.mkdir(parents=True, exist_ok=True)
    (script_dir / (script_name + ".gml")).write_text("// Generated by import_unity_presentation.py; references keep source clips in the build.\nfunction bb_audio_assets() {\n    return {\n"+",\n".join(gml)+"\n    };\n}\n", encoding="utf-8")
    (script_dir / (script_name + ".yy")).write_text(json.dumps({"$GMScript": "v1", "%Name": script_name, "name": script_name,
        "isCompatibility": False, "isDnD": False, "parent": {"name": "Scripts", "path": "folders/Scripts.yy"}, "resourceType": "GMScript", "resourceVersion": "2.0"}, indent=2), encoding="utf-8")
    register(script_name, f"scripts/{script_name}/{script_name}.yy")
    project.write_text(text, encoding="utf-8")
    print(f"Imported {len(output['textures'])} sprite references, {len(output['yctp'])} YCTP rectangles, {len(output['exit_signs'])} exit signs")


if __name__ == "__main__": main()
