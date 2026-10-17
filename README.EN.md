# FIRA Simulation ROS 2 Bridge

English | [Bahasa Indonesia](README.md)

Runs the [FIRA Autonomous Cars Simulator](src/FIRA-Autonomous-Cars-Simulator)
(Gazebo + ROS 1 Noetic) together with a `ros1_bridge` (ROS 2 Jazzy) in a single
podman container. The topics listed in `bridge_config.yaml` are bridged so you
can drive and observe the simulation from ROS 2.

## Requirements

- [podman](https://podman.io/)
- An X11 session (the Gazebo GUI is shown on the host display)
- `/dev/dri` for GPU rendering
- `xhost` (optional, used to allow the container to open windows)

## Quick start

```bash
./scripts/run_container.sh
```

This starts both the simulation and the bridge. If no local image exists, the
prebuilt image is pulled from
`ghcr.io/internship-iris-its/fira_simulation_ros2_docker`.

Then, from a ROS 2 Jazzy shell on the same machine (same `ROS_DOMAIN_ID`):

```bash
source /opt/ros/jazzy/setup.bash
ros2 topic list
```

## Scripts

Every script accepts `-h`/`--help`.

| Script             | Purpose                                                    |
| ------------------ | ---------------------------------------------------------- |
| `run_container.sh` | Run the simulation and bridge in a container               |
| `build.sh`         | Build the image locally as `fira_simulation_ros2_docker`   |
| `pull.sh`          | Pull the latest prebuilt image from GHCR                   |
| `entrypoint.sh`    | Container entrypoint (not run directly on the host)        |

### `run_container.sh`

```
./scripts/run_container.sh [options] [command...]
```

| Option                   | Description                                         |
| ------------------------ | --------------------------------------------------- |
| `-b`, `--build`          | Build the image locally first (runs `build.sh`)     |
| `-r`, `--remote`         | Force the GHCR image, even if a local one exists    |
| `-d`, `--domain-id N`    | Set `ROS_DOMAIN_ID` (default `0`)                   |
| `--localhost-only`       | Set `ROS_LOCALHOST_ONLY=1` (default `0`)            |
| `-h`, `--help`           | Show help                                           |

The optional `command` is passed to the container entrypoint:

| Command   | Effect                                         |
| --------- | ---------------------------------------------- |
| `all`     | Simulation and bridge (default)                |
| `sim`     | Gazebo simulation only                         |
| `bridge`  | `ros1_bridge` parameter bridge only            |
| other     | Executed as-is, e.g. `bash` for a shell        |

Examples:

```bash
./scripts/run_container.sh -d 42            # use ROS_DOMAIN_ID=42
./scripts/run_container.sh sim              # simulation only
./scripts/run_container.sh bash             # shell inside the container
```

### Which image is used

First match wins:

1. The `IMAGE` environment variable
2. `--remote`: the GHCR image
3. `--build`: the local image, rebuilt first
4. A local `fira_simulation_ros2_docker` image, if one exists
5. The GHCR image

## Using the prebuilt image

Podman only pulls the remote image the first time. To update it:

```bash
./scripts/pull.sh
```

If you have a local `fira_simulation_ros2_docker` image, it takes priority.
Either run with `--remote`, or remove the local one:

```bash
./scripts/run_container.sh --remote
# or
podman rmi fira_simulation_ros2_docker
```

If the GHCR package is private, log in first with `podman login ghcr.io`.

## Building locally

```bash
./scripts/build.sh                # builds fira_simulation_ros2_docker
./scripts/run_container.sh        # now uses the local image
```

Or build and run in one step with `./scripts/run_container.sh --build`.

## Environment variables

| Variable         | Used by                      | Description                                  |
| ---------------- | ---------------------------- | -------------------------------------------- |
| `IMAGE`          | `run_container.sh`, `build.sh`, `pull.sh` | Override the image name/tag     |
| `CONTAINER_NAME` | `run_container.sh`           | Container name (default `fira_simulation_ros2_docker`) |

## Bridged topics

Edit `bridge_config.yaml` to change which topics are bridged, then rebuild the
image (`./scripts/build.sh`).
