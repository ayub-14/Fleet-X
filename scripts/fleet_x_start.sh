#!/usr/bin/env bash
# Copyright 2026 FLEET-X Project Contributors
# SPDX-License-Identifier: Apache-2.0
# FLEET-X : start the Phase-2A simulation in the background and wait until the
# ros2_control drive chain is actually usable.
#
# Prints "READY" on stdout once /controller_manager is responsive AND
# diff_drive_controller reports itself active. Prints the launch log path.
#
# Usage:
#   fleet_x_start.sh [--gui] [--rviz] [--log FILE] [--timeout SECONDS]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/fleet_x_env.sh"

GUI="false"
RVIZ="false"
LOG="${SCRIPT_DIR}/../log/fleet_x_amr_sim.log"
TIMEOUT=90

while [ $# -gt 0 ]; do
  case "$1" in
    --gui)    GUI="true"; shift ;;
    --rviz)   RVIZ="true"; shift ;;
    --log)    LOG="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$LOG")"
LOG="$(readlink -f "$LOG")"

if pgrep -f '[f]leet_x_amr_sim.launch.py' >/dev/null 2>&1; then
  echo "[fleet_x_start] a simulation is already running; stopping it first" >&2
  "${SCRIPT_DIR}/fleet_x_stop.sh" >/dev/null 2>&1 || true
fi

echo "[fleet_x_start] launching (gui=${GUI} rviz=${RVIZ}) -> ${LOG}"

setsid bash -c "source '${SCRIPT_DIR}/fleet_x_env.sh' && \
  exec ros2 launch fleet_x_amr fleet_x_amr_sim.launch.py \
  gui:=${GUI} rviz:=${RVIZ}" \
  > "${LOG}" 2>&1 < /dev/null &

# ---- wait for the controller manager to come up -------------------------
echo -n "[fleet_x_start] waiting for diff_drive_controller to become active "
deadline=$(( $(date +%s) + TIMEOUT ))
ready=0
while [ "$(date +%s)" -lt "${deadline}" ]; do
  if ! pgrep -f '[f]leet_x_amr_sim.launch.py' >/dev/null 2>&1; then
    echo
    echo "[fleet_x_start] ERROR: the launch process exited. Last log lines:" >&2
    tail -n 25 "${LOG}" >&2
    exit 1
  fi

  controllers="$(timeout 10 ros2 control list_controllers 2>/dev/null || true)"
  # Anchor on the trailing state column so that "inactive" cannot be mistaken
  # for "active".
  if printf '%s\n' "${controllers}" | grep -Eq '^diff_drive_controller .*[[:space:]]active$'; then
    ready=1
    break
  fi
  echo -n '.'
  sleep 3
done
echo

if [ "${ready}" -ne 1 ]; then
  echo "[fleet_x_start] ERROR: diff_drive_controller did not become active within ${TIMEOUT}s." >&2
  echo "[fleet_x_start] controller state was:" >&2
  timeout 10 ros2 control list_controllers >&2 2>&1 || true
  echo "[fleet_x_start] --- launch log ---" >&2
  grep -iE 'error|failed|exception|Traceback' "${LOG}" | tail -n 25 >&2 || true
  exit 1
fi

echo "READY"
echo "${LOG}"
