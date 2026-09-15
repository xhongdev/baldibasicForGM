#!/usr/bin/env python3
"""Import source UI rectangles, sprite references and presentation audio."""
from functools import lru_cache
import argparse
import json
from pathlib import Path
import re
import shutil
import hashlib

from import_unity_gameplay import DEFAULT_UNITY, ROOT, field, ref, vector, load_yy, PROPS
from import_unity_map import guid, NOTEBOOK_SCRIPT
from unity_scene import UnityScene, gm_point
from build_from_godot import png_size


def texture_index(unity):
    result = {}
    for path in (unity / "Assets").rglob("*.png.meta"):
        meta = path.read_text(encoding="utf-8")
        match = re.search(r"^guid: (\w+)", meta, re.M)
        if match: result[match[1]] = Path(str(path)[:-5])
    return result


def colour(block, name):
    value = field(block, name)
    return [float(re.search(r"\b" + channel + r": ([\d.-]+)", value)[1]) for channel in "rgba"]


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
    output = {"textures": {}, "hud": {}, "yctp": {}, "notebooks": {}, "pickups": {}, "props": {}, "exit_signs": []}

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
        if name in ("BG", "Image", "TextBG", "YCTP", "Result1", "Result2", "Result3", "BaldiFeed") or name.startswith("Button ("):
            r = math_rect(tid)
            rec = {"rect": r}
            src = renderer_texture(math, tid)
            if src: rec["texture"] = texture("yctp_" + name, src)
            graphic = next((b for _, _, b in math.components(tid, 114) if field(b, "m_Color")), None)
            if graphic: rec["colour"] = colour(graphic, "m_Color")
            output["yctp"][name] = rec
            if args.inspect: print("YCTP", name, r, src.name if src else "")
    # Read the script references rather than guessing names for the answer field.
    script = next(b for kind, b in math.blocks.values() if kind == 114 and "  playerAnswer:" in b)
    for name, source in (("question", "questionText"), ("question2", "questionText2"), ("question3", "questionText3"), ("answer", "playerAnswer")):
        component = math.blocks[ref(field(script, source))][1]
        if name == "answer":
            tid = math.transforms[ref(field(component, "m_GameObject"))]
            output["yctp"]["answerBackground"] = {"rect": math_rect(tid), "colour": [1, 1, 1, 1]}
            component = math.blocks[ref(field(component, "m_TextComponent"))][1]
        tid = math.transforms[ref(field(component, "m_GameObject"))]
        size = float(field(component, "m_fontSize")) * 0.8
        output["yctp"][name] = {"rect": math_rect(tid), "font_size": size,
            "alignment": int(field(component, "m_textAlignment")),
            "spacing": float(field(component, "m_characterSpacing")) * size * 0.01,
            "colour": colour(component, "m_fontColor")}
        if args.inspect: print("YCTP", name, math_rect(tid))

    # Original bitmap font metrics avoid platform-dependent TTF sizes and baselines.
    font = (unity / "Assets/Font/TMP/COMIC_Pro.asset").read_text(encoding="utf-8")
    atlas = texture("yctp_font", guid(field(font, "atlas")))
    atlas_h = output["textures"][atlas]["size"][1]
    glyphs = {}
    table = font.split("  m_GlyphTable:\n", 1)[1].split("  m_CharacterTable:", 1)[0]
    for entry in re.split(r"^  - m_Index: ", table, flags=re.M)[1:]:
        ident, body = entry.split("\n", 1)
        metrics, rect = body.split("    m_GlyphRect:\n", 1)
        number = lambda text, name: float(re.search(r"^\s+" + name + r": ([\d.-]+)", text, re.M)[1])
        w, h = number(rect, "m_Width"), number(rect, "m_Height")
        glyphs[int(ident)] = {"src": [number(rect, "m_X"), atlas_h-number(rect, "m_Y")-h, w, h],
            "bearing": [number(metrics, "m_HorizontalBearingX"), number(metrics, "m_HorizontalBearingY")],
            "advance": number(metrics, "m_HorizontalAdvance")}
    chars = {code: glyphs[int(index)] for code, index in re.findall(r"m_Unicode: (\d+)\n\s+m_GlyphIndex: (\d+)", font)}
    output["yctp_font"] = {"texture": atlas, "size": 24, "ascent": 26, "line_height": 33, "glyphs": chars}

    # Follow the animator's sprite curves and state speeds, including the one-shot frown.
    animator = UnityScene(unity / "Assets/AnimationClip/AnimatorController/BaldiFeed.controller")
    animations = {}
    for kind, state in animator.blocks.values():
        if kind != 1102: continue
        name = field(state, "m_Name")
        anim = (unity / "Assets/AnimationClip" / (name + ".anim")).read_text(encoding="utf-8")
        curve = anim.split("  m_PPtrCurves:", 1)[1].split("    attribute:", 1)[0]
        frames = [{"time": float(t), "texture": texture(name + "_" + str(i), ident)} for i, (t, ident) in
                  enumerate(re.findall(r"- time: ([\d.]+)\n\s+value: \{fileID: \d+, guid: (\w+)", curve))]
        animations[name.removeprefix("Baldi_").lower()] = {"frames": frames, "speed": float(field(state, "m_Speed")),
            "duration": float(re.search(r"m_StopTime: ([\d.]+)", anim)[1]),
            "loop": re.search(r"m_LoopTime: (\d)", anim)[1] == "1"}
    output["yctp_face"] = animations

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
        name = school.name(tid)
        if not school.active(tid) and not name.startswith('Pickup_'): continue
        is_notebook = any(NOTEBOOK_SCRIPT in b for _, _, b in school.components(tid, 114))
        if is_notebook or name.startswith("Pickup_") or name == "ExitSign" or name in PROPS:
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
            pivot_match = re.search(r'spritePivot: \{x: ([\d.]+), y: ([\d.]+)\}', meta)
            pivot_y = float(pivot_match[2]) if pivot_match else .5
            height = size[1]/ppu*sy*.2
            rec = {"texture": key, "w": round(size[0]/ppu*sx*0.2, 5), "h": round(height, 5),
                   "y": round(gm_point(school.point(render_tid))[1] + (.5-pivot_y)*height, 5)}
            if is_notebook:
                pickup = next(b for _, _, b in school.components(tid, 114) if field(b, 'openingDistance'))
                rec['open_distance'] = float(field(pickup, 'openingDistance')) * .2
            elif name.startswith('Pickup_'):
                rec['open_distance'] = 2.0  # PickupScript uses a fixed distance < 10f.
            if is_notebook:
                audio = school.components(tid, 82)
                if audio:
                    rec['respawn_audio'] = guid(field(audio[0][2], 'm_audioClip'))
                output["notebooks"][tid] = rec
            elif name == "ExitSign":
                x, y, z = gm_point(school.point(tid))
                rec.update(x=x, y=y, z=z, source_id=tid)
                entrance = next((p for p in school.ancestry(tid) if p.startswith("Entrance (")), "")
                rec["entrance"] = entrance
                output["exit_signs"].append(rec)
            else:
                go = ref(field(school.blocks[tid][1], "m_GameObject"))
                output["props" if name in PROPS else "pickups"][go] = rec
            if args.inspect: print("WORLD", name, source.name, gm_point(school.point(tid)), rec)
    # Guaranteed source icons, independent of old sprite metadata and world sprites.
    from import_unity_gameplay import ICONS
    base = unity / "Assets/Texture2D"
    for i, filename in enumerate(("0_1.png", "1_1.png", "2_1.png", "3_1.png", "5_1.png")):
        texture("gameover_" + str(i), unity / "Assets/Texture2D/Screens/GameOver" / filename)
    for i, icon in enumerate(ICONS): texture("item" + str(i+1), base / f"SchoolHouse/PickUps/{icon}.png")
    for key, path in {"check": "YCTPTextures/Check.png", "xmark": "YCTPTextures/X.png",
                      "spray": "SchoolHouse/PickUps/Drops/BSODA_Spray.png",
                      "alarm_drop": "SchoolHouse/PickUps/Drops/AlarmClockDrop.png",
                      "slots": "HudTextures/ItemSlots.png"}.items(): texture(key, base / path)
    from import_unity_details import build_details
    output['details'] = build_details(unity, school, texture)
    from import_unity_environment import export_environment
    environment = export_environment(unity, school, texture, textures, output['details'])
    output['environment_file'] = 'school_environment.json'
    if args.inspect:
        print('DETAIL HUD', output['details']['hud'])
        for e in output['details']['entrances']: print('ENTRANCE', e['name'], 'wall', e['wall_bounds'], 'near', e['near'], 'finish', e['finish'])
        print('PROP APPEARANCE', output['props'])
        print('ENVIRONMENT', len(environment['meshes']), 'meshes', len(environment['billboards']), 'billboards', len(environment['colliders']), 'colliders')
        print('MISSING MESHES', environment['missing_meshes'])
        print('NPCS', environment['npcs'])
        return
    if args.check:
        saved = json.loads((ROOT / "datafiles/presentation.json").read_text(encoding="utf-8"))
        assert saved == output, "Presentation data differs from Unity"
        assert json.loads((ROOT/'datafiles/school_environment.json').read_text(encoding='utf-8')) == environment, 'Environment differs from Unity'
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
    include(Path('school_environment.json'))
    (ROOT/'datafiles/school_environment.json').write_text(json.dumps(environment,separators=(',',':'))+'\n',encoding='utf-8')
    (ROOT / "datafiles/presentation.json").write_text(json.dumps(output, indent=2)+"\n", encoding="utf-8")
    project.write_text(text, encoding="utf-8")
    print(f"Imported {len(output['textures'])} sprite references, {len(output['yctp'])} YCTP rectangles, {len(output['exit_signs'])} exit signs")
    print(f"Environment: {len(environment['meshes'])} meshes, {len(environment['billboards'])} decorations, {len(environment['colliders'])} colliders")
    for kind, npc in environment['npcs'].items(): print('NPC', kind, 'size', npc['w'], npc['h'], 'center_y', npc['y'])
    if environment['missing_meshes']: print('Missing mesh references:', environment['missing_meshes'])


if __name__ == "__main__": main()
