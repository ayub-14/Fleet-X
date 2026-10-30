#!/bin/bash
# Copyright 2026 FLEET-X Project Contributors
# SPDX-License-Identifier: Apache-2.0
#
# FLEET-X ROS 2 Jazzy environment activation script.
#
# Source this file in a new terminal:
#
#   source ~/fleet_x_ws/scripts/setup_fleet_x.sh
#
# Optional convenience alias:
#
#   alias fleetx='source ~/fleet_x_ws/scripts/setup_fleet_x.sh'

# Resolve the workspace root from this script, so the repository works from any
# clone location rather than only from $HOME/fleet_x_ws.
_FLEET_X_WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source ROS 2 Jazzy. Another sourced ROS distribution is overlaid, not removed.
if [ -f "/opt/ros/jazzy/setup.bash" ]; then
    echo "[FLEET-X] Activating ROS 2 Jazzy..."
    # shellcheck disable=SC1091
    source /opt/ros/jazzy/setup.bash
else
    echo "[FLEET-X] ERROR: ROS 2 Jazzy not found at /opt/ros/jazzy/setup.bash"
    echo "[FLEET-X] Install ROS 2 Jazzy first: https://docs.ros.org/en/jazzy/"
    unset _FLEET_X_WS_DIR
    return 1 2>/dev/null || exit 1
fi

# Source the built FLEET-X workspace.
if [ -f "${_FLEET_X_WS_DIR}/install/setup.bash" ]; then
    echo "[FLEET-X] Activating workspace: ${_FLEET_X_WS_DIR}"
    # shellcheck disable=SC1091
    source "${_FLEET_X_WS_DIR}/install/setup.bash"
else
    echo "[FLEET-X] WARNING: workspace is not built yet."
    echo "[FLEET-X] Run: cd ${_FLEET_X_WS_DIR} && colcon build --symlink-install"
fi

# Gazebo Harmonic system plugins installed by ROS live in /opt/ros/jazzy/lib.
# The launch file also sets this; exporting it here helps plain `gz sim` runs
# and ad-hoc validation commands.
if [ -d "/opt/ros/jazzy/lib" ]; then
    export GZ_SIM_SYSTEM_PLUGIN_PATH="/opt/ros/jazzy/lib${GZ_SIM_SYSTEM_PLUGIN_PATH:+:${GZ_SIM_SYSTEM_PLUGIN_PATH}}"
    export GZ_SIM_RESOURCE_PATH="/opt/ros/jazzy/share${GZ_SIM_RESOURCE_PATH:+:${GZ_SIM_RESOURCE_PATH}}"
    export GZ_SIM_SCENE_PATH="/opt/ros/jazzy/lib${GZ_SIM_SCENE_PATH:+:${GZ_SIM_SCENE_PATH}}"
fi

# Optional: a loopback-only Fast DDS profile for machines with unreliable
# multicast. This is a local reliability aid, not a requirement.
if [ -f "${_FLEET_X_WS_DIR}/config/fastdds_localhost_profile.xml" ]; then
    export FASTDDS_DEFAULT_PROFILES_FILE="${_FLEET_X_WS_DIR}/config/fastdds_localhost_profile.xml"
fi

echo "[FLEET-X] Environment ready. ROS_DISTRO=${ROS_DISTRO:-unknown}"
echo "[FLEET-X] Workspace: ${_FLEET_X_WS_DIR}"

unset _FLEET_X_WS_DIR
