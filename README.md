# DevEnvironment for AI Workspace
This repo contains a Dockerfile and setup script to create a development environment for AI Workspace. The Dockerfile is designed to be flexible and can be built using different base images, as long as they support the necessary package managers and tools.

# Supported base images
    - Debian: all versions (e.g., debian:13-slim, debian:12-slim)
    - Ubuntu: all versions (e.g., ubuntu:24.04, ubuntu:22.04)
    - Amazon Linux: 2023 and later

# Testing command
    docker build --progress=plain -t ai-workspace:latest --build-arg BASE_IMAGE=<BASE_IMAGE> .

# Or run all tests in parallel
    docker compose build --parallel
