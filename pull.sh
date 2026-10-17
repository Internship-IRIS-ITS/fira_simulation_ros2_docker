#!/usr/bin/env bash
# Pull the latest prebuilt FIRA simulation image from GHCR.
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h|--help]

Pull the latest prebuilt FIRA simulation image from GHCR.

Environment:
  IMAGE   Image to pull
          (default: ghcr.io/internship-iris-its/fira_simulation_ros2_docker:latest)
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

IMAGE="${IMAGE:-ghcr.io/internship-iris-its/fira_simulation_ros2_docker:latest}"

podman pull "$IMAGE"
