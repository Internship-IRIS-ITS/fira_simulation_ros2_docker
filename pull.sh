#!/usr/bin/env bash
# Pull the latest prebuilt FIRA simulation image from GHCR.
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/internship-iris-its/fira_simulation_ros2_docker:latest}"

podman pull "$IMAGE"
