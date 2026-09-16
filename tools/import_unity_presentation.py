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
from import_unity_map import build_map, guid, NOTEBOOK_SCRIPT
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
    menu_scene = UnityScene(unity / "Assets/Scene/Scenes/MainMenu.unity")
    secret = UnityScene(unity / "Assets/Scene/Scenes/Secret.unity")
    alarm = UnityScene(unity / "Assets/PrefabInstance/AlarmClockDrop.prefab")
    output = {"textures": {}, "hud": {}, "yctp": {}, "menu": {}, "notebooks": {}, "pickups": {}, "props": {}, "exit_signs": []}

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

    menu_rect = rect_reader(menu_scene, (640, 480))
    menu_assets = {}

    def menu_tid(*path):
        return next(t for t in menu_scene.transforms.values() if menu_scene.ancestry(t) == list(path))

    def sprite_crop(source):
        width, height = png_size(source)
        meta = Path(str(source) + ".meta").read_text(encoding="utf-8")
        match = re.search(r"rect:\s*\n\s*serializedVersion: \d+\s*\n\s*x: ([-\d.]+)\s*\n\s*y: ([-\d.]+)\s*\n\s*width: ([-\d.]+)\s*\n\s*height: ([-\d.]+)", meta)
        if not match: return [0, 0, width, height]
        x, y, w, h = map(float, match.groups())
        return [round(x, 4), round(height-y-h, 4), round(w, 4), round(h, 4)]

    def menu_asset(source, cropped=True):
        cache_key = (source, cropped)
        if cache_key in menu_assets: return menu_assets[cache_key]
        relative = source.relative_to(unity / "Assets").as_posix()
        key = "menu_" + re.sub(r"[^a-z0-9]+", "_", relative.lower()).strip("_")
        if not cropped: key += "_raw"
        texture(key, source)
        size = png_size(source)
        # AssetRipper preserves each UI element's authored transparent canvas.
        # Unity lays that complete canvas into the RectTransform; stretching the
        # tight Sprite rect makes labels huge and changes scale on sprite swap.
        asset = {"texture": key, "crop": [0, 0, size[0], size[1]]}
        if cropped: asset["sprite_rect"] = sprite_crop(source)
        menu_assets[cache_key] = asset
        return asset

    def menu_visible_hit(rect, normal, selected, preserve):
        bounds = []
        for asset in (normal, selected):
            canvas_w, canvas_h = asset["crop"][2:]
            if preserve:
                scale = min(rect[2]/canvas_w, rect[3]/canvas_h)
                x = rect[0] + (rect[2]-canvas_w*scale)*.5
                y = rect[1] + (rect[3]-canvas_h*scale)*.5
                sx = sy = scale
            else:
                x, y = rect[0], rect[1]
                sx, sy = rect[2]/canvas_w, rect[3]/canvas_h
            source = asset["sprite_rect"]
            bounds.append((x+source[0]*sx, y+source[1]*sy,
                           x+(source[0]+source[2])*sx, y+(source[1]+source[3])*sy))
        pad = 4
        x0 = max(rect[0], min(b[0] for b in bounds)-pad)
        y0 = max(rect[1], min(b[1] for b in bounds)-pad)
        x1 = min(rect[0]+rect[2], max(b[2] for b in bounds)+pad)
        y1 = min(rect[1]+rect[3], max(b[3] for b in bounds)+pad)
        return [round(x0, 4), round(y0, 4), round(x1-x0, 4), round(y1-y0, 4)]

    def menu_button(key, image_path, state_path=None, hit_path=None):
        image_tid = menu_tid(*image_path)
        state_tid = menu_tid(*(state_path or image_path))
        hit_tid = menu_tid(*(hit_path or image_path))
        source = renderer_texture(menu_scene, image_tid)
        graphic = next(b for _, _, b in menu_scene.components(image_tid, 114) if field(b, "m_Sprite"))
        state = next((b for _, _, b in menu_scene.components(state_tid, 114) if "m_SpriteState:" in b), "")
        selected_match = re.search(r"m_SelectedSprite: \{fileID: \d+, guid: (\w+)", state)
        selected = textures.get(selected_match[1]) if selected_match else source
        rect = menu_rect(image_tid)
        normal_asset, selected_asset = menu_asset(source), menu_asset(selected)
        preserve = field(graphic, "m_PreserveAspect", "0") == "1"
        output["menu"].setdefault("buttons", {})[key] = {
            "rect": rect,
            "hit": menu_rect(hit_tid) if hit_path else menu_visible_hit(rect, normal_asset, selected_asset, preserve),
            "normal": normal_asset, "selected": selected_asset, "preserve": preserve
        }

    menu_button("start", ("MainMenu", "Start Button"))
    menu_button("main_menu", ("MainMenu", "Menu Button"))
    menu_button("exit", ("MainMenu", "Exit Button"))
    menu_button("story", ("PlayMenu", "StoryButton"))
    menu_button("endless", ("PlayMenu", "EndlessButton"))
    menu_button("play_back", ("PlayMenu", "BackButton"))
    menu_button("how", ("MenuMenu", "HowButton"))
    menu_button("options", ("MenuMenu", "OptionsButton"))
    menu_button("credits", ("MenuMenu", "CreditsButton"))
    menu_button("menu_back", ("MenuMenu", "BackButton"))
    menu_button("controls", ("OptionsMenu", "ControlsButtonPC"))
    menu_button("options_back", ("OptionsMenu", "BackButton"))
    menu_button("story_back", ("Story", "BackButton"))
    menu_button("credits_back", ("Credits", "BackButton"))
    menu_button("controls_back", ("Controls", "BackButton"))
    menu_button("turn", ("OptionsMenu", "TurnSlideImage"), ("OptionsMenu", "TurnSlider"),
                ("OptionsMenu", "TurnSlider"))
    menu_button("rumble", ("OptionsMenu", "RumbleToggle", "Background"), ("OptionsMenu", "RumbleToggle"))
    menu_button("analog", ("OptionsMenu", "AnalogToggle", "Background"), ("OptionsMenu", "AnalogToggle"))

    def menu_raw(path):
        tid = menu_tid(*path)
        return {"rect": menu_rect(tid), "asset": menu_asset(renderer_texture(menu_scene, tid), False)}

    output["menu"]["backgrounds"] = {
        "story": menu_raw(("Story", "RawImage")),
        "credits": menu_raw(("Credits", "RawImage"))
    }
    story_text_tid = menu_tid("PlayMenu", "StoryText")
    endless_text_tid = menu_tid("PlayMenu", "EndlessText")
    controls_text_tid = menu_tid("Controls", "Text (TMP)")
    story_text_scale = abs(vector(menu_scene.blocks[story_text_tid][1], "m_LocalScale", (1, 1, 1))[0])
    endless_text_scale = abs(vector(menu_scene.blocks[endless_text_tid][1], "m_LocalScale", (1, 1, 1))[0])
    controls_text_scale = abs(vector(menu_scene.blocks[controls_text_tid][1], "m_LocalScale", (1, 1, 1))[0])
    output["menu"]["text"] = {
        "story": {"rect": menu_rect(story_text_tid), "font_size": round(32*story_text_scale, 4),
                  "alignment": 514, "spacing": 0, "line_spacing": 0, "colour": [0, 0, 0, 1],
                  "value": "Story Mode:\n\nCollect all 7 notebooks, and then exit the school, to win!"},
        "endless": {"rect": menu_rect(endless_text_tid), "font_size": round(36*endless_text_scale, 4),
                    "alignment": 514, "spacing": 0, "line_spacing": 0, "colour": [0, 0, 0, 1],
                    "value": "Endless Mode:\n\nCollect as many notebooks as you can!"},
        "controls": {"rect": menu_rect(controls_text_tid), "font_size": round(24*controls_text_scale, 4),
                     "alignment": 258, "spacing": 0, "line_spacing": round(16*controls_text_scale, 4), "colour": [0, 0, 0, 1],
                     "value": "Controls:\nWASD - Move\nMouse - Look around\nLeft Click - Pick up objects, open doors, other interactions\nRight Click - Use selected item\nScroll Wheel, 1,2,3 - Change item selection\nShift - Run (Watch your stamina!)\nSpace bar - Look behind you and Jump!"}
    }
    slider = menu_scene.components(menu_tid("OptionsMenu", "TurnSlider"), 114)[0][2]
    handle_tid = menu_tid("OptionsMenu", "TurnSlider", "Handle Slide Area", "Handle")
    track = menu_rect(menu_tid("OptionsMenu", "TurnSlider", "Handle Slide Area"))
    output["menu"]["slider"] = {
        "hit": menu_rect(menu_tid("OptionsMenu", "TurnSlider")),
        "bar": menu_rect(menu_tid("OptionsMenu", "TurnSlider", "Background")),
        "track": [track[0], track[0]+track[2]], "handle_rect": menu_rect(handle_tid),
        "handle": menu_asset(renderer_texture(menu_scene, handle_tid)),
        "min": float(field(slider, "m_MinValue")), "max": float(field(slider, "m_MaxValue"))
    }
    check_source = renderer_texture(menu_scene, menu_tid("OptionsMenu", "RumbleToggle", "Background", "Checkmark"))
    output["menu"]["checks"] = {
        "asset": menu_asset(check_source),
        "rumble": menu_rect(menu_tid("OptionsMenu", "RumbleToggle", "Background", "Checkmark")),
        "analog": menu_rect(menu_tid("OptionsMenu", "AnalogToggle", "Background", "Checkmark"))
    }

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
    texture("gameover_rare", unity / "Assets/Texture2D/Screens/GameOver/99_0.png")
    for i, icon in enumerate(ICONS): texture("item" + str(i+1), base / f"SchoolHouse/PickUps/{icon}.png")
    for key, path in {"check": "YCTPTextures/Check.png", "xmark": "YCTPTextures/X.png",
                      "spray": "SchoolHouse/PickUps/Drops/BSODA_Spray.png",
                      "alarm_drop": "SchoolHouse/PickUps/Drops/AlarmClockDrop.png",
                      "secret_filename2": "Characters/filename2.png",
                      "secret_banana": "SchoolHouse/Billboards/Banana.png",
                      "slots": "HudTextures/ItemSlots.png"}.items(): texture(key, base / path)
    from import_unity_details import build_details
    output['details'] = build_details(unity, school, texture)

    def source_billboard(scene, object_name, texture_key):
        tid = next(t for t in scene.transforms.values() if scene.name(t) == object_name)
        renderer = scene.components(tid, 212)[0][2]
        size = vector(renderer, "m_Size", (1, 1))
        matrix = scene.matrix(tid)
        sx = sum(matrix[i][0]**2 for i in range(3))**0.5
        sy = sum(matrix[i][1]**2 for i in range(3))**0.5
        x, y, z = gm_point(scene.point(tid))
        return {"texture": texture_key, "x": x, "y": y, "z": z,
                "w": round(size[0]*sx*.2, 5), "h": round(size[1]*sy*.2, 5)}

    alarm_tid = next(iter(alarm.transforms.values()))
    alarm_renderer = alarm.components(alarm_tid, 212)[0][2]
    alarm_size = vector(alarm_renderer, "m_Size", (1, 1))
    alarm_matrix = alarm.matrix(alarm_tid)
    alarm_sx = sum(alarm_matrix[i][0]**2 for i in range(3))**0.5
    alarm_sy = sum(alarm_matrix[i][1]**2 for i in range(3))**0.5
    alarm_audio = alarm.components(alarm_tid, 82)[0][2]
    alarm_script = next(b for _, _, b in alarm.components(alarm_tid, 114) if field(b, "ring"))
    output['details']['alarm_drop'] = {
        "texture": "alarm_drop", "y": .8,
        "w": round(alarm_size[0]*alarm_sx*.2, 5), "h": round(alarm_size[1]*alarm_sy*.2, 5),
        "tick_audio": guid(field(alarm_audio, "m_audioClip")),
        "ring_audio": guid(field(alarm_script, "ring"))
    }

    secret_player = next(t for t in secret.transforms.values() if secret.name(t) == "Player")
    filename = next(t for t in secret.transforms.values() if secret.name(t) == "filename2")
    filename_audio = secret.components(filename, 82)[0][2]
    trigger = secret.components(filename, 136)[0][2]
    filename_matrix = secret.matrix(filename)
    trigger_scale = max(sum(filename_matrix[i][axis]**2 for i in range(3))**0.5 for axis in (0, 2))
    px, _, pz = gm_point(secret.point(secret_player))
    output['details']['secret'] = {
        "player": [px, pz],
        "filename2": source_billboard(secret, "filename2", "secret_filename2"),
        "banana": source_billboard(secret, "Banana", "secret_banana"),
        "trigger_radius": round(float(field(trigger, "m_Radius"))*trigger_scale*.2, 5),
        "recording_audio": guid(field(filename_audio, "m_audioClip")),
        "map_file": "secret_map.json",
        "environment_file": "secret_environment.json"
    }
    from import_unity_environment import export_environment
    environment = export_environment(unity, school, texture, textures, output['details'])
    secret_map, _ = build_map(unity, {}, "Secret")
    secret_actor_ids = set(secret.descendants(filename))
    banana = next(t for t in secret.transforms.values() if secret.name(t) == "Banana")
    secret_actor_ids.update(secret.descendants(banana))
    secret_environment = export_environment(unity, secret, texture, textures, output['details'], secret_map,
        secret_actor_ids, {'Environment', 'TemplateRoom', 'Hall_2Wall_Door', 'Desk', 'Chair', 'Baldi'})
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
        assert json.loads((ROOT/'datafiles/secret_map.json').read_text(encoding='utf-8')) == secret_map, 'Secret map differs from Unity'
        assert json.loads((ROOT/'datafiles/secret_environment.json').read_text(encoding='utf-8')) == secret_environment, 'Secret environment differs from Unity'
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
    include(Path('secret_map.json'))
    include(Path('secret_environment.json'))
    for material in secret_map['materials'].values():
        path = Path(material['file'])
        if material['source']:
            destination = ROOT / 'datafiles' / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(unity / material['source'], destination)
        include(path)
    (ROOT/'datafiles/school_environment.json').write_text(json.dumps(environment,separators=(',',':'))+'\n',encoding='utf-8')
    (ROOT/'datafiles/secret_map.json').write_text(json.dumps(secret_map,separators=(',',':'))+'\n',encoding='utf-8')
    (ROOT/'datafiles/secret_environment.json').write_text(json.dumps(secret_environment,separators=(',',':'))+'\n',encoding='utf-8')
    (ROOT / "datafiles/presentation.json").write_text(json.dumps(output, indent=2)+"\n", encoding="utf-8")
    project.write_text(text, encoding="utf-8")
    print(f"Imported {len(output['textures'])} sprite references, {len(output['yctp'])} YCTP rectangles, {len(output['exit_signs'])} exit signs")
    print(f"Environment: {len(environment['meshes'])} meshes, {len(environment['billboards'])} decorations, {len(environment['colliders'])} colliders")
    for kind, npc in environment['npcs'].items(): print('NPC', kind, 'size', npc['w'], npc['h'], 'center_y', npc['y'])
    if environment['missing_meshes']: print('Missing mesh references:', environment['missing_meshes'])


if __name__ == "__main__": main()
