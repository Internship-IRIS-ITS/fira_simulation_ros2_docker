#!/usr/bin/env bash
# Run the FIRA simulation (Gazebo + ROS 1 Noetic) and the ros1_bridge (ROS 2
# Jazzy) inside a single podman container, sharing the host's network and X11
# display so Gazebo's GUI shows up and ROS/DDS discovery works without extra
# port mapping.
set -euo pipefail

LOCAL_IMAGE="fira_simulation_ros2_docker"
REMOTE_IMAGE="ghcr.io/internship-iris-its/fira_simulation_ros2_docker"
CONTAINER_NAME="${CONTAINER_NAME:-fira_simulation_ros2_docker}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [command...]

Run the FIRA simulation and ROS 1 <-> ROS 2 bridge in a podman container.
With no command, the container starts both the simulation and the bridge.
Commands: sim, bridge, all, or any other command to exec inside the container.

Options:
  -b, --build, --rebuild   Build the image locally first (runs build.sh)
  -r, --remote             Force the GHCR image, even if a local one exists
  -d, --domain-id N        ROS_DOMAIN_ID (default: 0)
      --localhost-only     Set ROS_LOCALHOST_ONLY=1 (default: 0)
  -h, --help               Show this help

Image selection (first match wins):
  \$IMAGE env var, --remote, --build, local $LOCAL_IMAGE, $REMOTE_IMAGE

Environment:
  IMAGE            Use this image, overriding the selection above
  CONTAINER_NAME   Container name (default: fira_simulation_ros2_docker)
EOF
}

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
        -h|--help)
            usage
            exit 0
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

# Without a GPU (/dev/dri missing, e.g. VMs or GPU-less machines) skip the
# device passthrough and fall back to Mesa software rendering (llvmpipe), which
# is slower but lets Gazebo's GUI start. Likewise only mount the Xauthority
# file when it exists, since podman refuses to start on a missing bind source.
EXTRA_ARGS=()
if [[ -d /dev/dri ]]; then
    EXTRA_ARGS+=(--device /dev/dri)
else
    echo "No /dev/dri found; using software rendering." >&2
    EXTRA_ARGS+=(-e LIBGL_ALWAYS_SOFTWARE=1)
fi
XAUTH_FILE="${XAUTHORITY:-$HOME/.Xauthority}"
if [[ -f "$XAUTH_FILE" ]]; then
    EXTRA_ARGS+=(-v "$XAUTH_FILE:/root/.Xauthority:ro")
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
    ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} \
    "$IMAGE" "$@"
