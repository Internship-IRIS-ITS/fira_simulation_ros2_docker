#!/bin/bash
set -e

#source /opt/ros/noetic/setup.bash
source /root/fira_simulation_ws_3/devel/setup.bash

run_sim() {
    export QT_QPA_PLATFORM=xcb
    roslaunch avisengine_environment track_race_simple.launch
}

run_bridge() {
    source /opt/ros/jazzy/setup.bash
    rosparam load /root/bridge_config.yaml
    ros2 run ros1_bridge parameter_bridge
}

case "${1:-all}" in
    -h|--help|help)
        echo "Usage: entrypoint.sh [sim|bridge|all|command...]"
        echo "  sim      Launch the Gazebo simulation only"
        echo "  bridge   Run the ros1_bridge parameter_bridge only"
        echo "  all      Run both (default)"
        echo "  other    Exec the given command"
        ;;
    sim)
        run_sim
        ;;
    bridge)
        run_bridge
        ;;
    all)
        run_sim &
        SIM_PID=$!

        echo "Waiting for roscore..."
        until rostopic list >/dev/null 2>&1; do
            sleep 1
        done

        run_bridge &
        BRIDGE_PID=$!

        wait -n "$SIM_PID" "$BRIDGE_PID"
        ;;
    *)
        exec "$@"
        ;;
esac
