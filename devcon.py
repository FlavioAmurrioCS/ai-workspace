#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "rich",
#     "typer-slim",
# ]
# ///

from dataclasses import dataclass
import getpass
import os
import subprocess
import webbrowser

from rich import print_json
import typer


@dataclass
class CLIApp:
    container_cmd: str="container"
    container_name: str="devcon"
    user_name: str= getpass.getuser()
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
        run_cmd = (
            self.container_cmd,
            "run",
            "--name",
            self.container_name,
            "--detach",
            "--rm",
            "-p",
            "1337:1337",
            "-v",
            f"{os.path.expanduser('~')}/dev:/home/{self.user_name}/dev",
            "ai-workspace:latest",
        )
        subprocess.run(run_cmd, check=True)

    def stop(self) -> None:
        cmd=(
            self.container_cmd,
            "stop",
            self.container_name,
        )
        subprocess.run(cmd, check=True)

    def status(self) -> None:
        cmd=(
            self.container_cmd,
            "inspect",
            self.container_name,
        )
        result = subprocess.run(cmd, check=True, capture_output=True)
        print_json(result.stdout.decode())
    def enter(self) -> None:
        cmd=(
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
        app.callback()(self.__init__)

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

# start
# stop
# status
# enter
