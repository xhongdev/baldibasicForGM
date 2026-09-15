#!/usr/bin/env python3
"""Import baldigd (Godot) into this GameMaker 2026 project as a 3D recreation."""
from __future__ import annotations

import json
import re
import shutil
import struct
import uuid
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(r"D:\Github\baldigd")
TSCN = GODOT / "Scenes" / "School.tscn"
GML_SRC = Path(__file__).resolve().parent / "gml"

MATS = {
    "StandardMaterial3D_m0c5p": ("tile", 0),
    "StandardMaterial3D_d783r": ("ceil", 0),
    "StandardMaterial3D_i36u6": ("brick", 0),
    "StandardMaterial3D_qrtm7": ("brick", 0),
    "StandardMaterial3D_uuoja": ("carpet", 0),
    "StandardMaterial3D_am7bd": ("ceil", 0),
    "StandardMaterial3D_2eucm": ("window", 0),
    "StandardMaterial3D_ksnpj": ("window", 0),
    "StandardMaterial3D_rybsb": ("window", 0),
    "StandardMaterial3D_v8i7x": ("swing0", 0),
    "StandardMaterial3D_guped": ("swing60", 0),
    "StandardMaterial3D_p6d11": ("tile", 1),
    "StandardMaterial3D_hdsv8": ("ceil", 1),
    "StandardMaterial3D_wi5cj": ("brick", 1),
    "StandardMaterial3D_d735p": ("swing0", 0),
    "StandardMaterial3D_nf5uj": ("window", 0),
    "StandardMaterial3D_up7ir": ("brick", 0),
    "StandardMaterial3D_xxy6o": ("brick", 1),
    "StandardMaterial3D_um44o": ("tile", 1),
    "StandardMaterial3D_03f7h": ("ceil", 1),
    "StandardMaterial3D_0yoec": ("brick", 1),
}

KIND = {
    "Floor": "floor",
    "Ceiling": "ceil",
    "Wall1": "n",
    "Wall2": "s",
    "Wall3": "w",
    "Wall4": "e",
}

SKIP_ROOTS = ("Pathway_Preview", "Room_Preview")

SPRITES = [
    ("spr_tex_tile", "Assets/Texture2D/SchoolHouse/FloorTextures/TileFloor.png", True, 0, 0, "World"),
    ("spr_tex_carpet", "Assets/Texture2D/SchoolHouse/FloorTextures/Carpet.png", True, 0, 0, "World"),
    ("spr_tex_ceiling", "Assets/Texture2D/SchoolHouse/Ceiling.png", True, 0, 0, "World"),
    ("spr_tex_brick", "Assets/Texture2D/SchoolHouse/WallTextures/WhiteBrickWall.png", True, 0, 0, "World"),
    ("spr_tex_window", "Assets/Texture2D/SchoolHouse/WallTextures/Window.png", True, 0, 0, "World"),
    ("spr_tex_swing0", "Assets/Texture2D/SchoolHouse/DoorTextures/SwingDoors/SwingDoor0.png", True, 0, 0, "World"),
    ("spr_tex_swing60", "Assets/Texture2D/SchoolHouse/DoorTextures/SwingDoors/SwingDoor60.png", True, 0, 0, "World"),
    ("spr_tex_door", "Assets/Texture2D/SchoolHouse/DoorTextures/Door_0.png", True, 0, 0, "World"),
    ("spr_tex_door_open", "Assets/Texture2D/SchoolHouse/DoorTextures/Door_80.png", True, 0, 0, "World"),
    ("spr_tex_sky0", "Assets/Texture2D/SchoolHouse/OutsideTextures/sky_0.png", True, 0, 0, "World"),
    ("spr_tex_sky90", "Assets/Texture2D/SchoolHouse/OutsideTextures/sky_90.png", True, 0, 0, "World"),
    ("spr_tex_sky180", "Assets/Texture2D/SchoolHouse/OutsideTextures/sky_180.png", True, 0, 0, "World"),
    ("spr_tex_sky270", "Assets/Texture2D/SchoolHouse/OutsideTextures/sky_270.png", True, 0, 0, "World"),
    ("spr_tex_sky_up", "Assets/Texture2D/SchoolHouse/OutsideTextures/sky_UP.png", True, 0, 0, "World"),
    ("spr_tex_sky_down", "Assets/Texture2D/SchoolHouse/OutsideTextures/sky_DOWN.png", True, 0, 0, "World"),
    ("spr_tex_grass", "Assets/Texture2D/SchoolHouse/OutsideTextures/Grass.png", True, 0, 0, "World"),
    ("spr_title", "Assets/Texture2D/MenuTextures/title_final.png", False, 0, 0, "UI"),
    ("spr_item_slots", "Assets/Texture2D/HudTextures/ItemSlots.png", False, 0, 0, "UI"),
    ("spr_yctp", "Assets/Texture2D/YCTPTextures/YCTP2_NoButtons.png", False, 0, 0, "UI"),
    ("spr_check", "Assets/Texture2D/YCTPTextures/Check.png", False, 0, 0, "UI"),
    ("spr_xmark", "Assets/Texture2D/YCTPTextures/X.png", False, 0, 0, "UI"),
    ("spr_gameover", "Assets/Texture2D/Screens/GameOver/0_1.png", False, 0, 0, "UI"),
    ("spr_win", "Assets/Texture2D/Screens/win.png", False, 0, 0, "UI"),
    ("spr_cursor", "Assets/CursorSprite.png", False, 0, 0, "UI"),
    ("spr_baldi_idle", "Assets/Texture2D/Characters/Baldi/Baldi_Wave0099.png", False, 71, 128, "Characters"),
    ("spr_principal", "Assets/Texture2D/Characters/Principal.png", False, 0, 0, "Characters"),
    ("spr_playtime", "Assets/Texture2D/Characters/Playtime/JumpRope_None.png", False, 0, 0, "Characters"),
    ("spr_bully", "Assets/Texture2D/Characters/bully_final.png", False, 0, 0, "Characters"),
    ("spr_sweep", "Assets/Texture2D/Characters/Gotta Sweep Sprite.png", False, 0, 0, "Characters"),
    ("spr_crafters", "Assets/Texture2D/Characters/Arts&Crafters/Crafters_Normal.png", False, 0, 0, "Characters"),
    ("spr_prize", "Assets/Texture2D/Characters/1stPrize/1PR_0.png", False, 0, 0, "Characters"),
    ("spr_notebook", "Assets/Texture2D/SchoolHouse/Billboards/Notebooks.png", False, 32, 38, "UI"),
    ("spr_nb_red", "Assets/Texture2D/SchoolHouse/PickUps/Notebooks/_nbRed.png", False, 0, 0, "UI"),
    ("spr_nb_blue", "Assets/Texture2D/SchoolHouse/PickUps/Notebooks/_nbBlue.png", False, 0, 0, "UI"),
    ("spr_nb_yellow", "Assets/Texture2D/SchoolHouse/PickUps/Notebooks/_nbYellow.png", False, 0, 0, "UI"),
    ("spr_nb_cyan", "Assets/Texture2D/SchoolHouse/PickUps/Notebooks/_nbCyan.png", False, 0, 0, "UI"),
    ("spr_nb_salmon", "Assets/Texture2D/SchoolHouse/PickUps/Notebooks/_nbSalmon.png", False, 0, 0, "UI"),
    ("spr_nb_black", "Assets/Texture2D/SchoolHouse/PickUps/Notebooks/_nbBlack.png", False, 0, 0, "UI"),
    ("spr_bsoda", "Assets/Texture2D/SchoolHouse/PickUps/BSODA.png", False, 0, 0, "UI"),
    ("spr_zesty", "Assets/Texture2D/SchoolHouse/PickUps/EnergyFlavoredZestyBar.png", False, 0, 0, "UI"),
    ("spr_key", "Assets/Texture2D/SchoolHouse/PickUps/Key.png", False, 0, 0, "UI"),
    ("spr_quarter", "Assets/Texture2D/SchoolHouse/PickUps/Quarter.png", False, 0, 0, "UI"),
    ("spr_exit_sign", "Assets/Texture2D/SchoolHouse/Billboards/ExitSign.png", False, 32, 19, "World"),
]

SOUNDS = [
    ("snd_mus_intro", "Assets/AudioClip/Music/mus_Intro.wav"),
    ("snd_mus_school", "Assets/AudioClip/Music/mus_School.wav"),
    ("snd_mus_learn", "Assets/AudioClip/Music/mus_Learn.wav"),
    ("snd_mus_hang", "Assets/AudioClip/Music/mus_hang.wav"),
    ("snd_bal_menu", "Assets/AudioClip/Characters/Baldi/BAL_MainMenu.wav"),
    ("snd_bal_hi", "Assets/AudioClip/Characters/Baldi/BaldiTutor/BAL_Hi.wav"),
    ("snd_bal_slap", "Assets/AudioClip/Characters/Baldi/Sounds/BAL_Slap.wav"),
    ("snd_bal_screech", "Assets/AudioClip/Characters/Baldi/Sounds/BAL_Screech.wav"),
    ("snd_swing", "Assets/AudioClip/Sounds/Doors/swingdoor_open.wav"),
    ("snd_door_open", "Assets/AudioClip/Sounds/Doors/door_open.wav"),
    ("snd_door_close", "Assets/AudioClip/Sounds/Doors/door_close.wav"),
    ("snd_ohno", "Assets/AudioClip/Sounds/ohno.wav"),
    ("snd_bell", "Assets/AudioClip/Sounds/Items/bell.wav"),
    ("snd_praise1", "Assets/AudioClip/Characters/Baldi/MathGame/Praises/BAL_Praise1.wav"),
    ("snd_praise2", "Assets/AudioClip/Characters/Baldi/MathGame/Praises/BAL_Praise2.wav"),
    ("snd_praise3", "Assets/AudioClip/Characters/Baldi/MathGame/Praises/BAL_Praise3.wav"),
    ("snd_praise4", "Assets/AudioClip/Characters/Baldi/MathGame/Praises/BAL_Praise4.wav"),
    ("snd_praise5", "Assets/AudioClip/Characters/Baldi/MathGame/Praises/BAL_Praise5.wav"),
]

IDENT = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]


def uid() -> str:
    return str(uuid.uuid4())


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Not a PNG: {path}")
        f.read(4)
        t = f.read(4)
        if t != b"IHDR":
            raise ValueError(f"No IHDR: {path}")
        w, h = struct.unpack(">II", f.read(8))
        return int(w), int(h)


def clean(v: float) -> float:
    if abs(v) < 1e-4:
        return 0.0
    return round(v, 4)


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
    return [
        xx, yx, zx,
        xy, yy, zy,
        xz, yz, zz,
        ox + p[9], oy + p[10], oz + p[11],
    ]


def parse_tscn(path: Path):
    node_re = re.compile(r'^\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?\]')
    xf_re = re.compile(r"^transform = Transform3D\((.*)\)$")
    vis_re = re.compile(r"^visible = (true|false)$")
    mat_re = re.compile(r'^surface_material_override/0 = SubResource\("([^"]+)"\)$')

    nodes = {}
    order = []
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        m = node_re.match(line)
        if m:
            name, ntype, parent = m.group(1), m.group(2), m.group(3)
            if parent in (None, "."):
                npath = name
                parent_path = None
            else:
                npath = f"{parent}/{name}"
                parent_path = parent
            current = {
                "name": name,
                "type": ntype,
                "parent": parent_path,
                "path": npath,
                "transform": IDENT[:],
                "visible": True,
                "material": None,
            }
            nodes[npath] = current
            order.append(npath)
            continue
        if current is None:
            continue
        m = xf_re.match(line)
        if m:
            nums = [float(x.strip()) for x in m.group(1).split(",")]
            current["transform"] = nums
            continue
        m = vis_re.match(line)
        if m:
            current["visible"] = m.group(1) == "true"
            continue
        m = mat_re.match(line)
        if m and current["parent"] and current["parent"] in nodes:
            nodes[current["parent"]]["material"] = m.group(1)

    def hidden(npath: str) -> bool:
        p = npath
        while p:
            n = nodes[p]
            if not n["visible"] or n["name"] in SKIP_ROOTS:
                return True
            p = n["parent"]
        return False

    def world(npath: str):
        chain = []
        p = npath
        while p:
            chain.append(nodes[p])
            p = nodes[p]["parent"]
        t = IDENT[:]
        for n in reversed(chain):
            t = compose(t, n["transform"])
        return t

    quads = []
    doors = []
    rooms = defaultdict(list)
    player = [0.0, 1.02, 2.0]
    tutor = [-0.3, 0.787, -1.0]

    for npath in order:
        n = nodes[npath]
        if hidden(npath):
            continue
        if n["name"] == "Player" and n["type"] == "CharacterBody3D":
            t = world(npath)
            player = [clean(t[9]), clean(t[10]), clean(t[11])]
            continue
        if n["name"] == "BaldiTutor":
            t = world(npath)
            tutor = [clean(t[9]), clean(t[10]), clean(t[11])]
            continue
        if n["name"] == "AnimatedSprite3D" and n["parent"] and nodes[n["parent"]]["name"] == "BaldiTutor":
            t = world(npath)
            tutor = [clean(t[9]), clean(t[10]), clean(t[11])]
            continue
        if n["name"] == "DoubleDoorClosed":
            t = world(npath)
            parent = n["parent"]
            tile = nodes[parent]["parent"] if parent else None
            tile_t = world(tile) if tile else t
            lx = t[9] - tile_t[9]
            lz = t[11] - tile_t[11]
            if abs(lx) >= abs(lz):
                side = "e" if lx >= 0 else "w"
            else:
                side = "s" if lz >= 0 else "n"
            doors.append({
                "x": clean(tile_t[9]),
                "z": clean(tile_t[11]),
                "side": side,
                "kind": "swing",
            })
            continue
        if n["name"] in KIND and n["type"] == "StaticBody3D":
            if n["name"] in ("DoubleDoorClosed", "DoubleDoorOpen"):
                continue
            t = world(npath)
            # piece local offsets: floor at tile origin, walls offset
            parent = n["parent"]
            tile_t = world(parent) if parent else t
            tx, tz = clean(tile_t[9]), clean(tile_t[11])
            k = KIND[n["name"]]
            mat_id = n["material"]
            mat, dark = MATS.get(mat_id, (None, 0))
            if mat is None:
                if k == "floor":
                    mat = "carpet" if "Room" in (parent or "") else "tile"
                elif k == "ceil":
                    mat = "ceil"
                else:
                    mat = "brick"
            if mat in ("swing0", "swing60") and k in ("n", "s", "w", "e"):
                side = {"n": "n", "s": "s", "w": "w", "e": "e"}[k]
                doors.append({
                    "x": tx,
                    "z": tz,
                    "side": side,
                    "kind": "swing",
                })
                continue
            quads.append({"k": k, "x": tx, "z": tz, "m": mat, "d": int(dark)})
            if k == "floor" and parent:
                group = "Halls"
                for part in parent.split("/"):
                    if part in (
                        "MathRoom", "SpellingRoom", "ScienceRoom", "EnglishRoom",
                        "PrincipalsOffice", "FacultyRoom1-1", "FacultyRoom1-2",
                        "FacultyRoom2", "Entrances", "Halls",
                    ):
                        group = part
                rooms[group].append([tx, tz])

    uniq = []
    seen = set()
    for d in doors:
        key = (d["x"], d["z"], d["side"])
        if key in seen:
            continue
        seen.add(key)
        uniq.append(d)
    return {
        "player": player,
        "tutor": tutor,
        "quads": quads,
        "doors": uniq,
        "rooms": {k: v for k, v in rooms.items()},
    }


def centroid(cells):
    if not cells:
        return [0.0, 0.0]
    sx = sum(c[0] for c in cells) / len(cells)
    sz = sum(c[1] for c in cells) / len(cells)
    return [clean(sx), clean(sz)]


def enrich(data):
    rooms = data["rooms"]
    nb_spr = [
        "spr_notebook", "spr_nb_red", "spr_nb_blue", "spr_nb_yellow",
        "spr_nb_cyan", "spr_nb_salmon", "spr_nb_black",
    ]
    room_order = ["MathRoom", "SpellingRoom", "ScienceRoom", "EnglishRoom", "FacultyRoom1-1", "FacultyRoom1-2", "FacultyRoom2"]
    notebooks = []
    for i, name in enumerate(room_order):
        if name in rooms and rooms[name]:
            c = centroid(rooms[name])
            notebooks.append({"x": c[0], "z": c[1], "spr": nb_spr[i % len(nb_spr)]})
    if len(notebooks) < 7 and "Halls" in rooms:
        halls = rooms["Halls"]
        picks = halls[len(halls) // 4 : len(halls) // 4 + (7 - len(notebooks)) * 8 : 8]
        for i, cell in enumerate(picks):
            notebooks.append({"x": cell[0], "z": cell[1], "spr": nb_spr[(len(notebooks)) % len(nb_spr)]})
    notebooks = notebooks[:7]

    items = []
    for name, kind, spr in (
        ("FacultyRoom1-1", 1, "spr_zesty"),
        ("FacultyRoom1-2", 2, "spr_bsoda"),
        ("FacultyRoom2", 1, "spr_zesty"),
        ("PrincipalsOffice", 2, "spr_bsoda"),
    ):
        if name in rooms and rooms[name]:
            c = centroid(rooms[name])
            items.append({"x": c[0] + 0.4, "z": c[1] - 0.4, "kind": kind, "spr": spr})

    def npc(kind, spr, room, w, h, y=0.9):
        cells = rooms.get(room) or rooms.get("Halls") or [[0, -8]]
        c = centroid(cells)
        return {"kind": kind, "spr": spr, "x": c[0], "y": y, "z": c[1], "w": w, "h": h}

    npcs = [
        npc("principal", "spr_principal", "PrincipalsOffice", 0.85, 1.7),
        npc("playtime", "spr_playtime", "Halls", 0.8, 1.55),
        npc("bully", "spr_bully", "ScienceRoom", 0.9, 1.6),
        npc("sweep", "spr_sweep", "EnglishRoom", 1.4, 2.2, 1.1),
        npc("crafters", "spr_crafters", "SpellingRoom", 0.85, 1.7),
    ]
    data["notebooks"] = notebooks
    data["items"] = items
    data["npcs"] = npcs
    data["centroids"] = {k: centroid(v) for k, v in rooms.items()}
    del data["rooms"]
    return data


def write_json(obj, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2), encoding="utf-8")


def write_folder(folder_path: str, name: str):
    p = ROOT / folder_path
    p.parent.mkdir(parents=True, exist_ok=True)
    write_json(
        {
            "$GMFolder": "",
            "%Name": name,
            "folderPath": folder_path.replace("\\", "/"),
            "name": name,
            "resourceType": "GMFolder",
            "resourceVersion": "2.0",
        },
        p,
    )


def make_sprite(name: str, src: Path, for3d: bool, ox: int, oy: int, folder: str):
    w, h = png_size(src)
    frame = uid()
    layer = uid()
    kf = uid()
    dest_dir = ROOT / "sprites" / name
    layer_dir = dest_dir / "layers" / frame
    layer_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, layer_dir / f"{layer}.png")
    shutil.copy2(src, dest_dir / f"{frame}.png")
    parent = {"name": folder, "path": f"folders/Sprites/{folder}.yy"} if folder != "Sprites" else {
        "name": "Sprites",
        "path": "folders/Sprites.yy",
    }
    yy = {
        "$GMSprite": "v2",
        "%Name": name,
        "bboxMode": 0,
        "bbox_bottom": h - 1,
        "bbox_left": 0,
        "bbox_right": w - 1,
        "bbox_top": 0,
        "collisionKind": 1,
        "collisionTolerance": 0,
        "DynamicTexturePage": False,
        "edgeFiltering": False,
        "For3D": for3d,
        "frames": [
            {"$GMSpriteFrame": "v1", "%Name": frame, "name": frame, "resourceType": "GMSpriteFrame", "resourceVersion": "2.0"},
        ],
        "gridX": 0,
        "gridY": 0,
        "height": h,
        "HTile": for3d,
        "layers": [
            {
                "$GMImageLayer": "",
                "%Name": layer,
                "blendMode": 0,
                "displayName": "default",
                "isLocked": False,
                "name": layer,
                "opacity": 100.0,
                "resourceType": "GMImageLayer",
                "resourceVersion": "2.0",
                "visible": True,
            }
        ],
        "name": name,
        "nineSlice": None,
        "origin": 9 if (ox or oy) else 0,
        "parent": parent,
        "preMultiplyAlpha": False,
        "resourceType": "GMSprite",
        "resourceVersion": "2.0",
        "sequence": {
            "$GMSequence": "v1",
            "%Name": name,
            "autoRecord": True,
            "backdropHeight": 768,
            "backdropImageOpacity": 0.5,
            "backdropImagePath": "",
            "backdropWidth": 1366,
            "backdropXOffset": 0.0,
            "backdropYOffset": 0.0,
            "events": {
                "$KeyframeStore<MessageEventKeyframe>": "",
                "Keyframes": [],
                "resourceType": "KeyframeStore<MessageEventKeyframe>",
                "resourceVersion": "2.0",
            },
            "eventStubScript": None,
            "eventToFunction": {},
            "length": 1.0,
            "lockOrigin": False,
            "moments": {
                "$KeyframeStore<MomentsEventKeyframe>": "",
                "Keyframes": [],
                "resourceType": "KeyframeStore<MomentsEventKeyframe>",
                "resourceVersion": "2.0",
            },
            "name": name,
            "playback": 1,
            "playbackSpeed": 30.0,
            "playbackSpeedType": 0,
            "resourceType": "GMSequence",
            "resourceVersion": "2.0",
            "showBackdrop": True,
            "showBackdropImage": False,
            "timeUnits": 1,
            "tracks": [
                {
                    "$GMSpriteFramesTrack": "",
                    "builtinName": 0,
                    "events": [],
                    "inheritsTrackColour": True,
                    "interpolation": 1,
                    "isCreationTrack": False,
                    "keyframes": {
                        "$KeyframeStore<SpriteFrameKeyframe>": "",
                        "Keyframes": [
                            {
                                "$Keyframe<SpriteFrameKeyframe>": "",
                                "Channels": {
                                    "0": {
                                        "$SpriteFrameKeyframe": "",
                                        "Id": {"name": frame, "path": f"sprites/{name}/{name}.yy"},
                                        "resourceType": "SpriteFrameKeyframe",
                                        "resourceVersion": "2.0",
                                    }
                                },
                                "Disabled": False,
                                "id": kf,
                                "IsCreationKey": False,
                                "Key": 0.0,
                                "Length": 1.0,
                                "resourceType": "Keyframe<SpriteFrameKeyframe>",
                                "resourceVersion": "2.0",
                                "Stretch": False,
                            }
                        ],
                        "resourceType": "KeyframeStore<SpriteFrameKeyframe>",
                        "resourceVersion": "2.0",
                    },
                    "modifiers": [],
                    "name": "frames",
                    "resourceType": "GMSpriteFramesTrack",
                    "resourceVersion": "2.0",
                    "spriteId": None,
                    "trackColour": 0,
                    "tracks": [],
                    "traits": 0,
                }
            ],
            "visibleRange": None,
            "volume": 1.0,
            "xorigin": ox,
            "yorigin": oy,
        },
        "swatchColours": None,
        "swfPrecision": 0.5,
        "textureGroupId": {"name": "Default", "path": "texturegroups/Default"},
        "type": 0,
        "VTile": for3d,
        "width": w,
    }
    write_json(yy, dest_dir / f"{name}.yy")
    return f"sprites/{name}/{name}.yy"


def make_sound(name: str, src: Path):
    dest_dir = ROOT / "sounds" / name
    dest_dir.mkdir(parents=True, exist_ok=True)
    wav_name = f"{name}.wav"
    shutil.copy2(src, dest_dir / wav_name)
    yy = {
        "$GMSound": "",
        "%Name": name,
        "audioGroupId": {"name": "audiogroup_default", "path": "audiogroups/audiogroup_default"},
        "bitDepth": 1,
        "bitRate": 128,
        "compression": 0,
        "conversionMode": 0,
        "duration": 0.0,
        "name": name,
        "parent": {"name": "Sounds", "path": "folders/Sounds.yy"},
        "preload": False,
        "resourceType": "GMSound",
        "resourceVersion": "2.0",
        "sampleRate": 44100,
        "soundFile": wav_name,
        "type": 0,
        "volume": 1.0,
    }
    write_json(yy, dest_dir / f"{name}.yy")
    return f"sounds/{name}/{name}.yy"


def make_script(name: str, src: Path):
    dest = ROOT / "scripts" / name
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest / f"{name}.gml")
    yy = {
        "$GMScript": "v1",
        "%Name": name,
        "isCompatibility": False,
        "isDnD": False,
        "name": name,
        "parent": {"name": "Scripts", "path": "folders/Scripts.yy"},
        "resourceType": "GMScript",
        "resourceVersion": "2.0",
    }
    write_json(yy, dest / f"{name}.yy")
    return f"scripts/{name}/{name}.yy"


def make_object(name: str, events: list[tuple[str, int, int]]):
    dest = ROOT / "objects" / name
    dest.mkdir(parents=True, exist_ok=True)
    event_list = []
    for fname, etype, enum in events:
        src = GML_SRC / f"{name}_{fname}"
        shutil.copy2(src, dest / fname)
        event_list.append({
            "$GMEvent": "v1",
            "%Name": "",
            "collisionObjectId": None,
            "eventNum": enum,
            "eventType": etype,
            "isDnD": False,
            "name": "",
            "resourceType": "GMEvent",
            "resourceVersion": "2.0",
        })
    yy = {
        "$GMObject": "",
        "%Name": name,
        "eventList": event_list,
        "managed": True,
        "name": name,
        "overriddenProperties": [],
        "parent": {"name": "Objects", "path": "folders/Objects.yy"},
        "parentObjectId": None,
        "persistent": name == "obj_boot",
        "physicsAngularDamping": 0.1,
        "physicsDensity": 0.5,
        "physicsFriction": 0.2,
        "physicsGroup": 1,
        "physicsKinematic": False,
        "physicsLinearDamping": 0.1,
        "physicsObject": False,
        "physicsRestitution": 0.1,
        "physicsSensor": False,
        "physicsShape": 1,
        "physicsShapePoints": [],
        "physicsStartAwake": True,
        "properties": [],
        "resourceType": "GMObject",
        "resourceVersion": "2.0",
        "solid": False,
        "spriteId": None,
        "spriteMaskId": None,
        "visible": True,
    }
    write_json(yy, dest / f"{name}.yy")
    return f"objects/{name}/{name}.yy"


def make_room(name: str, obj_name: str, width=640, height=480):
    dest = ROOT / "rooms" / name
    dest.mkdir(parents=True, exist_ok=True)
    inst = "inst_" + uid().replace("-", "")[:8]
    views = []
    for i in range(8):
        views.append({
            "hborder": 32,
            "hport": height,
            "hspeed": -1,
            "hview": height,
            "inherit": False,
            "objectId": None,
            "vborder": 32,
            "visible": i == 0,
            "vspeed": -1,
            "wport": width,
            "wview": width,
            "xport": 0,
            "xview": 0,
            "yport": 0,
            "yview": 0,
        })
    yy = {
        "$GMRoom": "v1",
        "%Name": name,
        "creationCodeFile": "",
        "inheritCode": False,
        "inheritCreationOrder": False,
        "inheritLayers": False,
        "instanceCreationOrder": [{"name": inst, "path": f"rooms/{name}/{name}.yy"}],
        "isDnd": False,
        "layers": [
            {
                "$GMRInstanceLayer": "",
                "%Name": "Instances",
                "depth": 0,
                "effectEnabled": True,
                "effectType": None,
                "gridX": 32,
                "gridY": 32,
                "hierarchyFrozen": False,
                "inheritLayerDepth": False,
                "inheritLayerSettings": False,
                "inheritSubLayers": True,
                "inheritVisibility": True,
                "instances": [
                    {
                        "$GMRInstance": "v1",
                        "%Name": inst,
                        "colour": 4294967295,
                        "frozen": False,
                        "hasCreationCode": False,
                        "ignore": False,
                        "imageIndex": 0,
                        "imageSpeed": 1.0,
                        "inheritCode": False,
                        "inheritedItemId": None,
                        "inheritItemSettings": False,
                        "isDnd": False,
                        "name": inst,
                        "objectId": {"name": obj_name, "path": f"objects/{obj_name}/{obj_name}.yy"},
                        "properties": [],
                        "resourceType": "GMRInstance",
                        "resourceVersion": "2.0",
                        "rotation": 0.0,
                        "scaleX": 1.0,
                        "scaleY": 1.0,
                        "x": 0.0,
                        "y": 0.0,
                    }
                ],
                "layers": [],
                "name": "Instances",
                "properties": [],
                "resourceType": "GMRInstanceLayer",
                "resourceVersion": "2.0",
                "userdefinedDepth": False,
                "visible": True,
            },
            {
                "$GMRBackgroundLayer": "",
                "%Name": "Background",
                "animationFPS": 15.0,
                "animationSpeedType": 0,
                "colour": 4294967295 if name == "rm_title" else 4278190080,
                "depth": 100,
                "effectEnabled": True,
                "effectType": None,
                "gridX": 32,
                "gridY": 32,
                "hierarchyFrozen": False,
                "hspeed": 0.0,
                "htiled": False,
                "inheritLayerDepth": False,
                "inheritLayerSettings": False,
                "inheritSubLayers": True,
                "inheritVisibility": True,
                "layers": [],
                "name": "Background",
                "properties": [],
                "resourceType": "GMRBackgroundLayer",
                "resourceVersion": "2.0",
                "spriteId": None,
                "stretch": False,
                "userdefinedAnimFPS": False,
                "userdefinedDepth": False,
                "visible": True,
                "vspeed": 0.0,
                "vtiled": False,
                "x": 0,
                "y": 0,
            },
        ],
        "name": name,
        "parent": {"name": "Rooms", "path": "folders/Rooms.yy"},
        "parentRoom": None,
        "physicsSettings": {
            "inheritPhysicsSettings": False,
            "PhysicsWorld": False,
            "PhysicsWorldGravityX": 0.0,
            "PhysicsWorldGravityY": 10.0,
            "PhysicsWorldPixToMetres": 0.1,
        },
        "resourceType": "GMRoom",
        "resourceVersion": "2.0",
        "roomSettings": {"Height": height, "inheritRoomSettings": False, "persistent": False, "Width": width},
        "sequenceId": None,
        "views": views,
        "viewSettings": {
            "clearDisplayBuffer": True,
            "clearViewBackground": False,
            "enableViews": True,
            "inheritViewSettings": False,
        },
        "volume": 1.0,
    }
    write_json(yy, dest / f"{name}.yy")
    return f"rooms/{name}/{name}.yy"


def copy_included():
    files = []
    wave_src = GODOT / "Assets/Texture2D/Characters/Baldi"
    wave_dst = ROOT / "datafiles/tex/baldi_wave"
    wave_dst.mkdir(parents=True, exist_ok=True)
    for i in range(100):
        src = wave_src / f"Baldi_Wave{i:04d}.png"
        dst = wave_dst / f"{i:02d}.png"
        shutil.copy2(src, dst)
        files.append(("tex/baldi_wave", f"{i:02d}.png"))

    slap_dst = ROOT / "datafiles/tex/baldi_slap"
    slap_dst.mkdir(parents=True, exist_ok=True)
    slap_src = GODOT / "Assets/Texture2D/Characters/Baldi/Angry"
    for name in ("0000", "0006", "0012", "0018", "0024"):
        src = slap_src / f"Baldi_Slap{name}.png"
        shutil.copy2(src, slap_dst / f"{name}.png")
        files.append(("tex/baldi_slap", f"{name}.png"))

    font_dst = ROOT / "datafiles/fonts"
    font_dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(GODOT / "Assets/Font/COMIC.ttf", font_dst / "COMIC.ttf")
    files.append(("fonts", "COMIC.ttf"))
    files.append(("", "school_map.json"))
    return files


def patch_windows_options():
    p = ROOT / "options/windows/options_windows.yy"
    text = p.read_text(encoding="utf-8")
    text = text.replace('"option_windows_display_name":"baldibasicForGM"', '"option_windows_display_name":"Baldi\'s Basics In Education And Learning"')
    text = text.replace('"option_windows_interpolate_pixels":true', '"option_windows_interpolate_pixels":false')
    text = text.replace('"option_windows_executable_name":"new_blank.exe"', '"option_windows_executable_name":"BaldisBasics.exe"')
    text = text.replace('"option_windows_use_raw_mouse":false', '"option_windows_use_raw_mouse":true')
    p.write_text(text, encoding="utf-8")


def main():
    import sys
    if "--legacy-rebuild" not in sys.argv:
        raise SystemExit("Historical Godot generator overwrites runtime code and the Unity map. Use tools/import_unity_map.py --write for map work; pass --legacy-rebuild only to recreate the old prototype.")
    print("Parsing", TSCN)
    data = enrich(parse_tscn(TSCN))
    print(
        f"quads={len(data['quads'])} doors={len(data['doors'])} "
        f"notebooks={len(data['notebooks'])} items={len(data['items'])} "
        f"player={data['player']} tutor={data['tutor']}"
    )
    write_json(data, ROOT / "datafiles/school_map.json")

    folders = [
        ("folders/Sprites.yy", "Sprites"),
        ("folders/Sprites/World.yy", "World"),
        ("folders/Sprites/UI.yy", "UI"),
        ("folders/Sprites/Characters.yy", "Characters"),
        ("folders/Objects.yy", "Objects"),
        ("folders/Scripts.yy", "Scripts"),
        ("folders/Sounds.yy", "Sounds"),
        ("folders/Rooms.yy", "Rooms"),
    ]
    for fp, name in folders:
        write_folder(fp, name)

    resources = []
    for name, rel, for3d, ox, oy, folder in SPRITES:
        src = GODOT / rel
        if not src.exists():
            print("MISSING sprite", src)
            continue
        path = make_sprite(name, src, for3d, ox, oy, folder)
        resources.append({"id": {"name": name, "path": path}})

    for name, rel in SOUNDS:
        src = GODOT / rel
        if not src.exists():
            print("MISSING sound", src)
            continue
        path = make_sound(name, src)
        resources.append({"id": {"name": name, "path": path}})

    for sname in ("scr_bb3d", "scr_bb_util", "scr_bb_game"):
        path = make_script(sname, GML_SRC / f"{sname}.gml")
        resources.append({"id": {"name": sname, "path": path}})

    resources.append({"id": {"name": "obj_boot", "path": make_object("obj_boot", [("Create_0.gml", 0, 0)])}})
    resources.append({"id": {"name": "obj_title", "path": make_object("obj_title", [
        ("Create_0.gml", 0, 0), ("Step_0.gml", 3, 0), ("Draw_0.gml", 8, 0)
    ])}})
    resources.append({"id": {"name": "obj_school", "path": make_object("obj_school", [
        ("Create_0.gml", 0, 0), ("Step_0.gml", 3, 0), ("Draw_0.gml", 8, 0),
        ("Draw_64.gml", 8, 64), ("CleanUp_0.gml", 12, 0)
    ])}})

    resources.append({"id": {"name": "rm_boot", "path": make_room("rm_boot", "obj_boot")}})
    resources.append({"id": {"name": "rm_title", "path": make_room("rm_title", "obj_title")}})
    resources.append({"id": {"name": "rm_school", "path": make_room("rm_school", "obj_school")}})

    included = copy_included()
    included_res = []
    for folder, fname in included:
        file_path = f"datafiles/{folder}" if folder else "datafiles"
        included_res.append({
            "$GMIncludedFile": "",
            "%Name": fname,
            "CopyToMask": -1,
            "filePath": file_path.replace("\\", "/"),
            "name": fname,
            "resourceType": "GMIncludedFile",
            "resourceVersion": "2.0",
        })

    yyp = {
        "$GMProject": "v1",
        "%Name": "baldibasicForGM",
        "AudioGroups": [
            {
                "$GMAudioGroup": "v1",
                "%Name": "audiogroup_default",
                "exportDir": "",
                "name": "audiogroup_default",
                "resourceType": "GMAudioGroup",
                "resourceVersion": "2.0",
                "targets": -1,
            }
        ],
        "configs": {"children": [], "name": "Default"},
        "defaultScriptType": 0,
        "Folders": [
            {
                "$GMFolder": "",
                "%Name": name,
                "folderPath": fp,
                "name": name,
                "resourceType": "GMFolder",
                "resourceVersion": "2.0",
            }
            for fp, name in folders
        ],
        "ForcedPrefabProjectReferences": [],
        "IncludedFiles": included_res,
        "isEcma": False,
        "LibraryEmitters": [],
        "MetaData": {"IDEVersion": "2026.0.0.16"},
        "name": "baldibasicForGM",
        "resources": resources,
        "resourceType": "GMProject",
        "resourceVersion": "2.0",
        "RoomOrderNodes": [
            {"roomId": {"name": "rm_boot", "path": "rooms/rm_boot/rm_boot.yy"}},
            {"roomId": {"name": "rm_title", "path": "rooms/rm_title/rm_title.yy"}},
            {"roomId": {"name": "rm_school", "path": "rooms/rm_school/rm_school.yy"}},
        ],
        "templateType": "game",
        "TextureGroups": [
            {
                "$GMTextureGroup": "",
                "%Name": "Default",
                "autocrop": True,
                "border": 2,
                "compressFormat": "bz2",
                "customOptions": "",
                "directory": "",
                "groupParent": None,
                "isScaled": True,
                "loadType": "default",
                "mipsToGenerate": 0,
                "name": "Default",
                "resourceType": "GMTextureGroup",
                "resourceVersion": "2.0",
                "targets": -1,
            }
        ],
    }
    write_json(yyp, ROOT / "baldibasicForGM.yyp")
    write_json({"FolderOrderSettings": [], "ResourceOrderSettings": []}, ROOT / "baldibasicForGM.resource_order")

    old = ROOT / "rooms" / "Room1"
    if old.exists():
        shutil.rmtree(old)

    patch_windows_options()
    (ROOT / "README.md").write_text(
        """# baldibasicForGM

Baldi's Basics (from the Godot port `baldigd`) recreated in GameMaker LTS 2026.

GameMaker has no native 3D object/scene system. This project still implements a real first-person 3D schoolhouse using vertex buffers, a perspective camera, depth testing, textured world quads, and Y-axis billboards for characters — the same 3D presentation as the Godot source.

## Run

Open `baldibasicForGM.yyp` in GameMaker 2026 LTS and run.

## Controls

- WASD / arrows: walk
- Shift: run (stamina)
- Mouse: look
- 1/2/3 or mouse wheel: item slot
- Right click or Q: use item (Zesty bar restores stamina, BSODA pushes Baldi)
- Esc: pause
- Collect 7 notebooks, finish the You Can Think Pad, then return to the start/exit

## Rebuild from Godot assets

```
python tools/build_from_godot.py
```
""",
        encoding="utf-8",
    )
    print("Done.")


if __name__ == "__main__":
    main()
