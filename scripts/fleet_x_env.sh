#!/usr/bin/env bash
# Copyright 2026 FLEET-X Project Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Source the ROS 2 Jazzy and FLEET-X workspace environments.
#
#   source scripts/fleet_x_env.sh
#
# The workspace root is resolved from this file, so the repository can live in
# any directory, not only ~/fleet_x_ws.

set +u

_FLEET_X_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_FLEET_X_WS_DIR="$(dirname "${_FLEET_X_SCRIPT_DIR}")"

# Drop unrelated colcon overlays so FLEET-X behaviour is not influenced by an
# unrelated workspace that happens to be sourced in the caller's shell.
if [ -n "${AMENT_PREFIX_PATH:-}" ]; then
  _fleet_x_keep=""
  IFS=':' read -r -a _fleet_x_entries <<< "${AMENT_PREFIX_PATH}"
  for _fleet_x_entry in "${_fleet_x_entries[@]}"; do
    case "${_fleet_x_entry}" in
      /opt/ros/jazzy|"${_FLEET_X_WS_DIR}"/install) ;;
      *) continue ;;
    esac
    _fleet_x_keep="${_fleet_x_keep:+${_fleet_x_keep}:}${_fleet_x_entry}"
  done
  export AMENT_PREFIX_PATH="${_fleet_x_keep}"
  unset _fleet_x_keep _fleet_x_entry _fleet_x_entries
fi

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
# shellcheck disable=SC1091
source "${_FLEET_X_WS_DIR}/install/setup.bash"

# gz-sim discovers system plugins through GZ_SIM_SYSTEM_PLUGIN_PATH. The
# gz_ros2_control plugin is installed under the ROS prefix, not this workspace.
if [ -d /opt/ros/jazzy/lib ]; then
  export GZ_SIM_SYSTEM_PLUGIN_PATH="/opt/ros/jazzy/lib${GZ_SIM_SYSTEM_PLUGIN_PATH:+:${GZ_SIM_SYSTEM_PLUGIN_PATH}}"
fi

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"

unset _FLEET_X_SCRIPT_DIR _FLEET_X_WS_DIR
