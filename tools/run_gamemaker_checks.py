#!/usr/bin/env python3
"""Use gm-cli compile/run to execute the opt-in checks in the real GML Runner."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".gmcache/build-gms2-windows-VM"


def execute(command, log_name, timeout, env=None):
    proc = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    timed_out = False
    try:
        output, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        # gm-cli owns an Igor/Runner process tree; do not leave the game behind.
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        output, _ = proc.communicate()
    text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", output.decode("utf-8", errors="replace"))
    (CACHE / log_name).write_text(text, encoding="utf-8")
    if timed_out:
        raise SystemExit(f"gm-cli timed out; see {CACHE / log_name}")
    return proc.returncode, text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gm-cli", default=shutil.which("gm-cli.cmd") or shutil.which("gm-cli"))
    parser.add_argument("--toolchain", default="GMS2@2026.0.0.23")
    parser.add_argument("--license", type=Path, default=ROOT / ".gmcache/license/licence.plist")
    parser.add_argument("--compile-only", action="store_true")
    parser.add_argument("--timeout", type=int, default=180, help="Runner check deadline in seconds")
    args = parser.parse_args()
    if not args.gm_cli:
        raise SystemExit("gm-cli is not on PATH; use --gm-cli to provide its executable")
    CACHE.mkdir(parents=True, exist_ok=True)
    flags = [str(ROOT / "baldibasicForGM.yyp"), "--target", "windows", "--runtime", "vm",
             "--toolchain", args.toolchain, "--license", str(args.license)]
    env = dict(os.environ)
    code, text = execute([args.gm_cli, "compile", *flags], "compile.log", 120, env)
    if code or re.search(r"\bError\s*:", text):
        print(text)
        raise SystemExit("gm-cli compilation failed")
    print("gm-cli VM compilation passed", flush=True)
    if args.compile_only:
        return
    env["BB_SELF_TEST"] = "1"
    code, text = execute([args.gm_cli, "run", *flags], "selftest_combined.log", args.timeout, env)
    lines = [line for line in text.splitlines() if "BB_TEST" in line or "BB_PROFILE" in line
             or "ERROR" in line or "Error :" in line]
    print("\n".join(dict.fromkeys(lines)))
    result = re.search(r"BB_TEST_RESULT: (\d+) checks, (\d+) failures", text)
    if code or not result or int(result[2]):
        if not result:
            print(text[-6000:])
        raise SystemExit("gm-cli Runner checks failed; see .gmcache/build-gms2-windows-VM/selftest_combined.log")
    saves = Path(os.environ["LOCALAPPDATA"]) / "baldibasicForGM"
    for name in ("bb_hud_check.png", "bb_yctp_check.png", "bb_yctp_corrupt_check.png", "bb_school_window.png",
                  "bb_yctp_window.png", "bb_cheat_menu.png", "bb_boots_check.png", "bb_rope_check.png",
                  "bb_detention_check.png", "bb_exit_map_check.png", "bb_vending_check.png", "bb_menu_title.png",
                   "bb_menu_modes.png", "bb_menu_menu.png", "bb_menu_options.png", "bb_menu_story_info.png",
                   "bb_menu_credits.png", "bb_menu_controls.png", "bb_secret_front_check.png",
                  "bb_secret_back_check.png", "bb_secret_door_check.png", "bb_door_out_check.png",
                  "bb_door_in_check.png"):
        if (saves / name).exists():
            shutil.copy2(saves / name, CACHE / name)
    print("Presentation captures: .gmcache/build-gms2-windows-VM/bb_*check.png and bb_*window.png")


if __name__ == "__main__":
    main()
