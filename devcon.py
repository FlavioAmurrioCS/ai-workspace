#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich",
#     "typer-slim",
# ]
# ///
# flake8: noqa: S603,S606
import getpass
import os
import subprocess
import webbrowser
from dataclasses import dataclass

import typer
from rich import print_json


@dataclass
class CLIApp:
    container_cmd: str = "container"
    # container_cmd: str="docker"
    container_name: str = "devcon"
    user_name: str = getpass.getuser()
    user_id: int = os.getuid()
    group_id: int = os.getgid()

    def start(self) -> None:
        build_cmd = (
            self.container_cmd,
            "build",
            "--tag=ai-workspace:latest",
            f"--build-arg=DEVENV_GROUP_ID={self.group_id}",
            f"--build-arg=DEVENV_USER_ID={self.user_id}",
            f"--build-arg=DEVENV_USERNAME={self.user_name}",
            "--build-arg=BASE_IMAGE=debian:13-slim",
            os.path.dirname(__file__),
        )

        subprocess.run(build_cmd, check=True)
        container_home = f"/home/{self.user_name}"
        host_home = os.path.expanduser("~")
        run_cmd = (
            self.container_cmd,
            "run",
            f"--name={self.container_name}",
            "--detach",
            "--rm",
            "--publish=127.0.0.1:1337:1337",
            "--publish=127.0.0.1:8082:8082",
            f"--volume={host_home}/dev:{container_home}/dev",
            f"--volume={host_home}/opt/mounts/devcon-mise:{container_home}/.local/share/mise",
            f"--volume={host_home}/opt/mounts/devcon-claude:{container_home}/.claude",
            "ai-workspace:latest",
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
