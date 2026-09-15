#!/usr/bin/env python3
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]
yyp_path = root / "baldibasicForGM.yyp"
yyp = yyp_path.read_text(encoding="utf-8")
src_root = Path(r"D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\AudioClip\Characters\Baldi\MathGame")
items = [
    ("snd_bal_math_intro", src_root / "Intro" / "BAL_Math_Intro.wav"),
    ("snd_bal_howto", src_root / "Intro" / "BAL_General_HowTo.wav"),
]
for name, src in items:
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
    if f'"name":"{name}"' not in yyp:
        marker = '{"id":{"name":"snd_bal_hi"'
        entry = f'{{"id":{{"name":"{name}","path":"sounds/{name}/{name}.yy",}},}},\n    '
        yyp = yyp.replace(marker, entry + marker, 1)
yyp_path.write_text(yyp, encoding="utf-8")
print("added", ", ".join(name for name, _ in items))