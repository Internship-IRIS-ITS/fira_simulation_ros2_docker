#!/usr/bin/env bash
# Run the FIRA simulation (Gazebo + ROS 1 Noetic) and the ros1_bridge (ROS 2
# Jazzy) inside a single podman container, sharing the host's network and X11
# display so Gazebo's GUI shows up and ROS/DDS discovery works without extra
# port mapping.
set -euo pipefail

IMAGE="${IMAGE:-fira_simulation_ws_3:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-fira_simulation_ws_3}"

FORCE_BUILD=0
ROS_LOCALHOST_ONLY_VALUE=0
ROS_DOMAIN_ID_VALUE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build|--rebuild)
            FORCE_BUILD=1
            shift
            ;;
        --localhost-only)
            ROS_LOCALHOST_ONLY_VALUE=1
            shift
            ;;
        -d|--domain-id)
            ROS_DOMAIN_ID_VALUE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if [[ "$FORCE_BUILD" -eq 1 ]] || ! podman image exists "$IMAGE"; then
    echo "Building image '$IMAGE'..."
    # --pull=newer refreshes the manoedinata/ubuntu24-ros-jazzy-noetic-docker
    # base image whenever a newer version is available on Docker Hub, so a
    # stale local copy doesn't silently miss packages baked in there.
    podman build --pull=newer -t "$IMAGE" "$(dirname "$0")"
fi

if command -v xhost >/dev/null 2>&1; then
    xhost +local: >/dev/null 2>&1 || true
fi

podman run --rm -it \
    --name "$CONTAINER_NAME" \
    --network host \
    --cap-add NET_RAW \
    --ipc host \
    --security-opt label=disable \
    -e DISPLAY="${DISPLAY:-:0}" \
    -e QT_X11_NO_MITSHM=1 \
    -e ROS_LOCALHOST_ONLY="$ROS_LOCALHOST_ONLY_VALUE" \
    -e ROS_DOMAIN_ID="$ROS_DOMAIN_ID_VALUE" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v "${XAUTHORITY:-$HOME/.Xauthority}:/root/.Xauthority:ro" \
    --device /dev/dri \
    "$IMAGE" "$@"
