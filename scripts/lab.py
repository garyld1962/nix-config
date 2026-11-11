#!/usr/bin/env python3
"""Run the configuration only in the disposable WSL lab, from the source Ubuntu."""
import argparse
import io
from pathlib import Path
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
DISTRO = "Ubuntu-Nix-Test"
DEST = "/home/gary/nix-config"
SYSTEM32 = "/mnt/c/Windows/System32"


def windows_exe(name, fallback):
    """SSH sessions into WSL do not get the Windows PATH appended."""
    return shutil.which(name) or fallback


WSL_EXE = windows_exe("wsl.exe", f"{SYSTEM32}/wsl.exe")
POWERSHELL_EXE = windows_exe("powershell.exe", f"{SYSTEM32}/WindowsPowerShell/v1.0/powershell.exe")


def wsl(*args, data=None, capture=False):
    return subprocess.run(
        [WSL_EXE, "-d", DISTRO, "-u", "gary", "--cd", "/home/gary", "--exec", *args],
        input=data, stdout=subprocess.PIPE if capture else None, check=True,
    ).stdout


def guard():
    wsl("grep", "-Fxq", "Ubuntu-Nix-Test blank baseline v2", "/etc/nix-lab-baseline")


def sync():
    guard()
    files = [ROOT / "flake.nix", ROOT / "bootstrap.sh"]
    if (ROOT / "flake.lock").exists():
        files.append(ROOT / "flake.lock")
    files += sorted((ROOT / "home").rglob("*"))
    files += sorted(path for path in (ROOT / "packages").rglob("*")
                    if "node_modules" not in path.parts)
    files += sorted((ROOT / "scripts").glob("*.sh"))
    files += sorted((ROOT / "scripts").glob("*.zsh"))
    files += sorted((ROOT / "scripts").glob("*.py"))
    archive = io.BytesIO()
    with tarfile.open(fileobj=archive, mode="w") as tar:
        for path in files:
            if path.is_file():
                tar.add(path, arcname=str(path.relative_to(ROOT)))
    wsl("mkdir", "-p", DEST)
    wsl("tar", "-xf", "-", "-C", DEST, data=archive.getvalue())


def script(name):
    guard()
    wsl("bash", f"{DEST}/scripts/{name}.sh")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["sync", "bootstrap", "install", "lock", "apply", "test", "rebuild"])
    args = parser.parse_args()
    if args.action == "rebuild":
        if not (ROOT / "flake.lock").is_file():
            parser.error("A saved flake.lock is required before a reset/rebuild.")
        windows_script = subprocess.check_output(
            ["wslpath", "-w", str(ROOT / "scripts/wsl-lab.ps1")], text=True
        ).strip()
        subprocess.run([POWERSHELL_EXE, "-NoProfile", "-ExecutionPolicy", "Bypass",
                        "-File", windows_script, "-Action", "Reset"], check=True)
    sync()
    if args.action == "bootstrap":
        script("bootstrap")
    if args.action in ("install", "rebuild"):
        guard()
        wsl("bash", f"{DEST}/bootstrap.sh")
    if args.action == "lock":
        script("lock")
        (ROOT / "flake.lock").write_bytes(wsl("cat", f"{DEST}/flake.lock", capture=True))
    if args.action == "apply":
        script("apply")
    if args.action in ("test", "rebuild"):
        script("smoke-test")


if __name__ == "__main__":
    main()
