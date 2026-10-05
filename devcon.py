#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich",
#     "typer-slim",
# ]
# ///
# flake8: noqa: S603,S606
import json
import os
import subprocess
import webbrowser
from dataclasses import dataclass
from enum import StrEnum
from typing import Literal
from typing import TypedDict

import typer
from rich import print_json

PROJECT_ROOT = os.path.dirname(__file__)
WOLFI_DIR = os.path.join(PROJECT_ROOT, "images", "wolfi")
USER_HOME = os.path.expanduser("~")


class MountVolume(TypedDict):
    type: Literal["volume"]
    src: str
    dst: str


class Service(StrEnum):
    vscode = "vscode"
    zellij = "zellij"


@dataclass
class CLIApp:
    container_cmd: str = "container"
    # container_cmd: str="docker"
    container_name: str = "devcon"
    # user_name: str = getpass.getuser()
    # user_id: int = os.getuid()
    # group_id: int = os.getgid()

    def _container_status(self) -> str | None:
        """Return the container's status (such as "running"), or None if it doesn't exist."""
        # `container inspect` exits 0 and prints `[]` for an unknown name.
        cmd = (self.container_cmd, "inspect", self.container_name)
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        containers = json.loads(result.stdout or "[]")
        return containers[0].get("status") if containers else None

    def start(self, service: list[Service] | None = None) -> None:
        # Fail before the build and the volume `chown` if the name is taken.
        status = self._container_status()
        if status is not None:
            print(f"{self.container_name} already exists ({status}). Use `stop` first, or `enter`.")
            raise typer.Exit(1)

        image_name = "devcon:latest"
        build_cmd = (
            self.container_cmd,
            "build",
            f"--tag={image_name}",
            ".",
        )

        devcon_services = " ".join(service or [])

        subprocess.run(build_cmd, check=True, cwd=WOLFI_DIR)
        # container_home = f"/home/{self.user_name}"
        # host_home = os.path.expanduser("~")

        mounts: tuple[MountVolume, ...] = (
            {"type": "volume", "src": "devcon-vscode", "dst": "/home/devuser/.vscode"},
            {"type": "volume", "src": "devcon-vscode-server", "dst": "/home/devuser/.vscode-server"},
            {"type": "volume", "src": "devcon-zellij", "dst": "/home/devuser/.local/share/zellij"},
            {"type": "volume", "src": "devcon-zellij-config", "dst": "/home/devuser/.config/zellij"},
            {"type": "volume", "src": "devcon-mise", "dst": "/home/devuser/.local/share/mise"},
            {"type": "volume", "src": "devcon-mise-state", "dst": "/home/devuser/.local/state/mise"},
            {"type": "volume", "src": "devcon-mise-config", "dst": "/home/devuser/.config/mise"},
            {"type": "volume", "src": "devcon-dev", "dst": "/home/devuser/dev"},
            {"type": "volume", "src": "devcon-claude", "dst": "/home/devuser/.claude"},
            {"type": "volume", "src": "devcon-opencode", "dst": "/home/devuser/.local/share/opencode"},
            {"type": "volume", "src": "devcon-opencode-config", "dst": "/home/devuser/.config/opencode"},
        )
        check_cmd = (
            self.container_cmd,
            "run",
            "--remove",
            "--user=0",
            "--entrypoint=chown",
            *(f"--mount=type={x['type']},src={x['src']},dst={x['dst']}" for x in mounts),
            image_name,
            "1000:1000",
            *(x["dst"] for x in mounts),
        )
        subprocess.run(check_cmd, check=True)
        auto_expose_ports = ("3000", "8000")
        run_cmd = (
            self.container_cmd,
            "run",
            "--detach",
            "--remove",
            f"--name={self.container_name}",
            # "--restart=unless-stopped",
            "--publish=127.0.0.1:1337:1337",
            "--publish=127.0.0.1:8082:8082",
            *(f"--publish=127.0.0.1:{x}:{x}" for x in auto_expose_ports),
            *(f"--mount=type={x['type']},src={x['src']},dst={x['dst']}" for x in mounts),
            f"--mount=type=bind,src={USER_HOME}/.config/mise/conf.d,dst=/home/devuser/.config/mise/conf.d,readonly",
            *(() if not devcon_services else (f"--env=DEVCON_SERVICES={devcon_services}",)),
            "--memory=4G",
            image_name,
        )
        os.execlp(run_cmd[0], *run_cmd)

    def stop(self) -> None:
        cmd = (
            self.container_cmd,
            "stop",
            self.container_name,
        )
        subprocess.run(cmd, check=True)

    def status(self) -> None:
        cmd = (
            self.container_cmd,
            "inspect",
            self.container_name,
        )
        result = subprocess.run(cmd, check=True, capture_output=True)
        print_json(result.stdout.decode())

    def enter(self) -> None:
        cmd = (
            self.container_cmd,
            "exec",
            "-it",
            self.container_name,
            "/bin/bash",
        )
        os.execvp(cmd[0], cmd)
        # subprocess.run(cmd, check=True)

    def open_web(self) -> None:
        webbrowser.open("http://localhost:1337")

    def get_app(self) -> typer.Typer:
        app = typer.Typer()
        app.callback()(self.__init__)  # ty: ignore[invalid-argument-type]

        app.command()(self.start)
        app.command()(self.stop)
        app.command()(self.status)
        app.command()(self.enter)
        app.command()(self.open_web)
        return app


if __name__ == "__main__":
    cli_app = CLIApp()
    app = cli_app.get_app()
    app()
