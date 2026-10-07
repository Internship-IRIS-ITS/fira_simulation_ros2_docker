FROM manoedinata/ubuntu24-ros-jazzy-noetic-docker

ENV DEBIAN_FRONTEND=noninteractive
# Keep ROS 2 DDS discovery on loopback so it doesn't try to go out over a real NIC.
# ENV ROS_LOCALHOST_ONLY=1

# Base image ships ROS 1 Noetic + ROS 2 Jazzy (desktop-full), rosdep already
# initialized, the workspace dependencies (four_wheel_steering_msgs,
# urdf_geometry_parser, ros_controllers, velodyne, can_msgs) built into
# /opt/ros/noetic, and ros1_bridge built into /opt/ros/jazzy. This Dockerfile
# only builds the FIRA-Autonomous-Cars-Simulator application itself.

# ccache to speed up recompiles across rebuilds.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        ccache

# Put ccache's compiler shims first on PATH so catkin_make below transparently
# caches object files in $CCACHE_DIR (mounted as a build cache) across
# rebuilds, even when the source tree changes and the build layer has to
# rerun from scratch.
ENV PATH=/usr/lib/ccache:${PATH}
ENV CCACHE_DIR=/root/.ccache

WORKDIR /root/fira_simulation_ws_3
COPY src/FIRA-Autonomous-Cars-Simulator ./src/FIRA-Autonomous-Cars-Simulator
COPY bridge_config.yaml /root/bridge_config.yaml

# catkin_make's generated top-level Makefile doesn't always encode
# cross-package message-header dependencies correctly under high parallelism,
# so a from-scratch build can race and miss a freshly generated header
# (e.g. can_msgs/Frame.h) on the first pass; retrying once picks it up.
# build/ and ccache are cache mounts: this RUN always reruns after a source
# change (its output, devel/, must land in the image), but object files for
# unchanged translation units are pulled from cache instead of recompiled.
RUN --mount=type=cache,target=/root/.ccache \
    --mount=type=cache,target=/root/fira_simulation_ws_3/build,sharing=locked \
    /bin/bash -c "source /opt/ros/noetic/setup.bash && (catkin_make || catkin_make)"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]
CMD ["all"]
