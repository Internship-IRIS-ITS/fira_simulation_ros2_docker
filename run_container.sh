#!/usr/bin/env bash
# Run the FIRA simulation (Gazebo + ROS 1 Noetic) and the ros1_bridge (ROS 2
# Jazzy) inside a single podman container, sharing the host's network and X11
# display so Gazebo's GUI shows up and ROS/DDS discovery works without extra
# port mapping.
set -euo pipefail

LOCAL_IMAGE="fira_simulation_ros2_docker"
REMOTE_IMAGE="ghcr.io/internship-iris-its/fira_simulation_ros2_docker"
CONTAINER_NAME="${CONTAINER_NAME:-fira_simulation_ros2_docker}"

FORCE_BUILD=0
FORCE_REMOTE=0
ROS_LOCALHOST_ONLY_VALUE=0
ROS_DOMAIN_ID_VALUE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build|--rebuild)
            FORCE_BUILD=1
            shift
            ;;
        -r|--remote)
            FORCE_REMOTE=1
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

if [[ "$FORCE_BUILD" -eq 1 && "$FORCE_REMOTE" -eq 1 ]]; then
    echo "--build and --remote are mutually exclusive" >&2
    exit 1
fi

# Image precedence: $IMAGE env, --remote, --build, local image, GHCR fallback.
if [[ -z "${IMAGE:-}" ]]; then
    if [[ "$FORCE_REMOTE" -eq 1 ]]; then
        IMAGE="$REMOTE_IMAGE"
    elif [[ "$FORCE_BUILD" -eq 1 ]] || podman image exists "$LOCAL_IMAGE"; then
        IMAGE="$LOCAL_IMAGE"
    else
        IMAGE="$REMOTE_IMAGE"
    fi
fi

if [[ "$FORCE_BUILD" -eq 1 ]]; then
    IMAGE="$LOCAL_IMAGE" "$(dirname "$0")/build.sh"
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
