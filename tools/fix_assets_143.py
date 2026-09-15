#!/usr/bin/env python3
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]

mp = root / "datafiles" / "school_map.json"
data = json.loads(mp.read_text(encoding="utf-8"))
data["doors"] = [
    {"x": 8.0, "z": 0.0, "side": "n", "kind": "swing", "lock_start": True},
    {"x": -8.0, "z": 0.0, "side": "s", "kind": "swing", "lock_start": True},
    {"x": 0.0, "z": -8.0, "side": "w", "kind": "swing", "lock_start": True},
    {"x": 12.0, "z": -66.0, "side": "n", "kind": "swing", "lock_start": False},
    {"x": 6.0, "z": -58.0, "side": "s", "kind": "swing", "lock_start": False},
    {"x": -22.0, "z": -58.0, "side": "n", "kind": "swing", "lock_start": False},
    {"x": 6.0, "z": -38.0, "side": "w", "kind": "swing", "lock_start": False},
    {"x": -6.0, "z": -38.0, "side": "n", "kind": "swing", "lock_start": False},
    {"x": 0.0, "z": -4.0, "side": "e", "kind": "class", "lock_start": False},
    {"x": 0.0, "z": -6.0, "side": "w", "kind": "class", "lock_start": False},
    {"x": 22.0, "z": -32.0, "side": "e", "kind": "class", "lock_start": False},
    {"x": 22.0, "z": -60.0, "side": "e", "kind": "class", "lock_start": False},
    {"x": -22.0, "z": -54.0, "side": "e", "kind": "class", "lock_start": False},
    {"x": -6.0, "z": -48.0, "side": "n", "kind": "class", "lock_start": False},
    {"x": 12.0, "z": -6.0, "side": "w", "kind": "class", "lock_start": False},
    {"x": 4.0, "z": -26.0, "side": "n", "kind": "class", "lock_start": False},
    {"x": 6.0, "z": -32.0, "side": "e", "kind": "class", "lock_start": False},
    {"x": 22.0, "z": -18.0, "side": "e", "kind": "faculty", "lock_start": False},
    {"x": 6.0, "z": -46.0, "side": "w", "kind": "faculty", "lock_start": False},
    {"x": -22.0, "z": -32.0, "side": "w", "kind": "faculty", "lock_start": False},
    {"x": -6.0, "z": -26.0, "side": "n", "kind": "faculty", "lock_start": False},
    {"x": -16.0, "z": 0.0, "side": "s", "kind": "faculty", "lock_start": False},
]
mp.write_text(json.dumps(data, indent=2), encoding="utf-8")
print("doors", len(data["doors"]))

src = Path(r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\AudioClip\Characters\Baldi\BaldiTutor\BAL_GetPrize.wav")
if not src.exists():
    src = Path(r"D:\Github\baldigd\Assets\AudioClip\Characters\Baldi\BaldiTutor\BAL_GetPrize.wav")
name = "snd_bal_prize"
dest = root / "sounds" / name
dest.mkdir(parents=True, exist_ok=True)
shutil.copy2(src, dest / f"{name}.wav")
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
    "soundFile": f"{name}.wav",
    "type": 0,
    "volume": 1.0,
}
(dest / f"{name}.yy").write_text(json.dumps(yy, indent=2), encoding="utf-8")

yyp_path = root / "baldibasicForGM.yyp"
yyp = yyp_path.read_text(encoding="utf-8")
if "snd_bal_prize" not in yyp:
    needle = '{"id":{"name":"snd_bal_hi"'
    insert = '{"id":{"name":"snd_bal_prize","path":"sounds/snd_bal_prize/snd_bal_prize.yy",},},\n    '
    yyp = yyp.replace(needle, insert + needle, 1)
    print("yyp prize")

npc_dir = root / "datafiles" / "tex" / "npc"
npc_dir.mkdir(parents=True, exist_ok=True)
godot = Path(r"D:\Github\baldigd\Assets\Texture2D\Characters")
copies = [
    (godot / "Playtime" / "JumpRope_0.png", "playtime.png"),
    (godot / "bully_final.png", "bully.png"),
    (godot / "Gotta Sweep Sprite.png", "sweep.png"),
    (godot / "Arts&Crafters" / "Crafters_Normal.png", "crafters.png"),
    (godot / "1stPrize" / "1PR_0.png", "prize.png"),
    (godot / "Principal.png", "principal.png"),
]
inc_blob = yyp.split('"IncludedFiles":[')[1].split("],")[0]
for srcp, nm in copies:
    shutil.copy2(srcp, npc_dir / nm)
    if nm not in inc_blob:
        entry = (
            '{"$GMIncludedFile":"","%Name":"'
            + nm
            + '","CopyToMask":-1,"filePath":"datafiles/tex/npc","name":"'
            + nm
            + '","resourceType":"GMIncludedFile","resourceVersion":"2.0",},'
        )
        yyp = yyp.replace(
            '{"$GMIncludedFile":"","%Name":"swing_locked.png"',
            entry + "\n    " + '{"$GMIncludedFile":"","%Name":"swing_locked.png"',
            1,
        )
        print("include", nm)
print("npc copied")
yyp_path.write_text(yyp, encoding="utf-8")
print("ok")
