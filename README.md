# DevEnvironment for AI Workspace

This repo contains a Dockerfile and setup script to create a development
environment for AI Workspace. The Dockerfile is designed to be flexible and can
be built using different base images, as long as they support the necessary
package managers and tools.

**Wolfi dev container** (long-running, mise + pitchfork services): see
[`images/wolfi/README.md`](images/wolfi/README.md).

## Supported base images

- Debian: all versions, such as debian:13-slim and debian:12-slim
- Ubuntu: all versions, such as ubuntu:24.04 and ubuntu:22.04
- Amazon Linux: 2023 and later

## Testing command

```sh
docker build --progress=plain -t ai-workspace:latest \
    --build-arg BASE_IMAGE=<BASE_IMAGE> .
```

## Or run all tests in parallel

```sh
docker compose build --parallel
```
