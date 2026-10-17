#!/usr/bin/env bash
# Build the FIRA simulation image locally as fira_simulation_ros2_docker.
set -euo pipefail

IMAGE="${IMAGE:-fira_simulation_ros2_docker}"

# --pull=newer refreshes the base image whenever a newer version is available.
podman build --pull=newer -t "$IMAGE" "$(dirname "$0")"
