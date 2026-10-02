"""Compile/run the real Swift rules and engine on macOS. Never a Python substitute."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
compiler = shutil.which("swiftc")
if not compiler or sys.platform != "darwin":
    print("BLOCKED: macOS Swift/Combine toolchain required; no native verification claimed.")
    raise SystemExit(2)
output = root / ".ai/tmp/magic-pour/native"
output.mkdir(parents=True, exist_ok=True)
game = root / "ios/App/App/Game"
binary = output / "magic-pour-tests"
subprocess.run([compiler, "-O", "-o", str(binary),
                *[str(game / name) for name in ("Models.swift", "LevelGenerator.swift", "GameEngine.swift")],
                str(root / "scripts/magic-pour-tests.swift")], check=True, cwd=root)
subprocess.run([str(binary)], check=True, cwd=root, timeout=60)
