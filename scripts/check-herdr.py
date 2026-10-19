#!/usr/bin/env python3
"""Test Herdr in an isolated named session inside the disposable WSL instance."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid


def main():
    if not os.environ.get("WSL_DISTRO_NAME"):
        raise SystemExit("This check only operates inside WSL.")
    session = "nix-smoke-" + uuid.uuid4().hex[:8]
    env = {key: value for key, value in os.environ.items() if not key.startswith("HERDR_")}
    with tempfile.TemporaryDirectory(prefix="hdr-") as temporary:
        root = Path(temporary)
        config = root / "config.toml"
        config.write_text(
            Path.home().joinpath(".config/herdr/config.toml").read_text()
            + "\n[update]\nversion_check = false\nmanifest_check = false\n"
        )
        env.update(HERDR_CONFIG_PATH=str(config), XDG_CONFIG_HOME=temporary,
                   HERDR_SESSION=session, TERM="xterm-256color")

        def call(*args, parse=True):
            result = subprocess.run(["herdr", *args, "--session", session], env=env,
                                    text=True, capture_output=True, timeout=15, check=True)
            return json.loads(result.stdout) if parse else result.stdout

        existing = call("session", "list", "--json")
        assert not any(item["name"] == session for item in existing["sessions"])
        with (root / "server.log").open("w") as log:
            server = subprocess.Popen(["herdr", "server", "--session", session], env=env,
                                      cwd=temporary, stdin=subprocess.DEVNULL,
                                      stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 20
                while time.monotonic() < deadline:
                    if server.poll() is not None:
                        raise RuntimeError((root / "server.log").read_text())
                    try:
                        status = call("status", "--json")
                        if status.get("server", {}).get("running"):
                            break
                    except subprocess.CalledProcessError:
                        pass
                    time.sleep(0.2)
                else:
                    raise RuntimeError("Herdr did not become ready in 20 seconds.")

                sessions = call("session", "list", "--json")["sessions"]
                owned = next(item for item in sessions if item["name"] == session)
                assert owned["default"] is False
                assert Path(owned["socket_path"]).is_relative_to(root), owned
                workspace = call("workspace", "create", "--cwd", temporary,
                                 "--label", "Nix smoke test")
                workspace_id = workspace["result"]["workspace"]["workspace_id"]
                panes = call("pane", "list", "--workspace", str(workspace_id))["result"]["panes"]
                pane_id = str(panes[0]["pane_id"])
                command = "[[ -n $ZSH_VERSION && $(node --version) == v22.* ]] && printf '%s%s\\n' NIX_HERDR_ READY"
                call("pane", "run", pane_id, command, parse=False)
                call("pane", "wait-output", pane_id, "--match", "NIX_HERDR_READY", "--timeout", "10000", parse=False)
                print("PASS: Herdr starts an isolated server and runs Zsh with Nix-managed Node in a real pane")
                call("session", "stop", session, "--json")
                server.wait(timeout=10)
            finally:
                # Only terminate the process this test created, never an ambient Herdr server.
                if server.poll() is None:
                    server.terminate()
                    try:
                        server.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        server.kill()
                        server.wait(timeout=5)


if __name__ == "__main__":
    main()
