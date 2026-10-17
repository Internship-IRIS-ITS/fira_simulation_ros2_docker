#!/usr/bin/env bash
# Build the FIRA simulation image locally as fira_simulation_ros2_docker.
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h|--help]

Build the FIRA simulation image locally with podman.

Environment:
  IMAGE   Tag to build (default: fira_simulation_ros2_docker)
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
esac

IMAGE="${IMAGE:-fira_simulation_ros2_docker}"

# --pull=newer refreshes the base image whenever a newer version is available.
podman build --pull=newer -t "$IMAGE" "$(dirname "$0")/.."
