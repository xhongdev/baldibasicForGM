#!/usr/bin/env python3
"""Compile and run opt-in real-GML checks with the installed GameMaker runtime."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--license", type=Path, default=ROOT / ".gmcache/license/licence.plist")
    parser.add_argument("--compile-only", action="store_true")
    args = parser.parse_args()
    runtimes = Path(os.environ.get("PROGRAMDATA", "C:/ProgramData")) / "GameMakerStudio2-LTS2026/Cache/runtimes"
    runtime = args.runtime or sorted(runtimes.glob("runtime-*"))[-1]
    igor = runtime / "bin/igor/windows/x64/Igor.exe"
    cache = ROOT / ".gmcache/build-gms2-windows-VM"
    output = cache / "output/baldibasicForGM.win"
    cache.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [str(igor), f"--project={ROOT / 'baldibasicForGM.yyp'}", f"--rp={runtime}",
               "--runtime=VM", "--config=Default", f"--cache={cache}",
               f"--temp={cache / 'temp'}", f"--lf={args.license}", f"--of={output}", "windows", "Compile"]
    compiled = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, errors="replace", timeout=60)
    log = compiled.stdout + compiled.stderr
    (cache / "compile.log").write_text(log, encoding="utf-8")
    if compiled.returncode or re.search(r"^Error\s*:", log, re.M):
        print(log)
        raise SystemExit("GameMaker compilation failed")
    print("GameMaker VM compilation passed")
    if args.compile_only: return
    debug_log = cache / "selftest.log"
    if debug_log.exists(): debug_log.unlink()
    command = [str(runtime / "windows/x64/Runner.exe"), "-game", str(output),
               "-debugoutput", str(debug_log), "--bb-self-test"]
    proc = subprocess.Popen(command, cwd=output.parent, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        stdout, _ = proc.communicate(timeout=55)
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, _ = proc.communicate()
        print(stdout.decode(errors="replace"))
        if debug_log.exists(): print(debug_log.read_text(encoding="utf-8", errors="replace"))
        raise SystemExit("GameMaker self-test timed out")
    text = stdout.decode(errors="replace")
    if debug_log.exists(): text += "\n" + debug_log.read_text(encoding="utf-8", errors="replace")
    (cache / "selftest_combined.log").write_text(text, encoding="utf-8")
    lines = [line for line in text.splitlines() if "BB_TEST" in line or "ERROR" in line or line.startswith("Error :")]
    print("\n".join(dict.fromkeys(lines)))
    result = re.search(r"BB_TEST_RESULT: (\d+) checks, (\d+) failures", text)
    if proc.returncode or not result or int(result[2]):
        if not result: print(text[-6000:])
        raise SystemExit("GameMaker runtime checks failed; see .gmcache/build-gms2-windows-VM/selftest_combined.log")
    # Runner saves into its sandbox; publish only our explicitly named test captures.
    saves = Path(os.environ["LOCALAPPDATA"]) / "baldibasicForGM"
    for name in ("bb_hud_check.png", "bb_yctp_check.png", "bb_school_window.png", "bb_yctp_window.png", "bb_cheat_menu.png"):
        if (saves / name).exists(): shutil.copy2(saves / name, cache / name)
    print("Presentation captures: .gmcache/build-gms2-windows-VM/bb_*check.png and bb_*window.png")


if __name__ == "__main__":
    main()
