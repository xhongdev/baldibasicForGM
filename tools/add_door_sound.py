import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = Path(r"D:\Github\baldigd\Assets\AudioClip\Characters\Baldi\BaldiTutor\BAL_Door.wav")
name = "snd_bal_doors"
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
text = yyp_path.read_text(encoding="utf-8")
needle = '{"id":{"name":"snd_bal_hi"'
insert = '{"id":{"name":"snd_bal_doors","path":"sounds/snd_bal_doors/snd_bal_doors.yy",},},\n    '
if "snd_bal_doors" not in text:
    text = text.replace(needle, insert + needle, 1)
    yyp_path.write_text(text, encoding="utf-8")
    print("yyp patched")
else:
    print("already in yyp")
print("ok", src.stat().st_size)
