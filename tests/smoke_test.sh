#!/usr/bin/env bash
# Copyright 2026 FLEET-X Project Contributors
# SPDX-License-Identifier: Apache-2.0
#
# FLEET-X runtime smoke test.
#
# Starts the simulation headless, verifies the ros2_control drive chain,
# sensor topics, TF, and a short motion command, then shuts the simulation down.
#
# Usage:
#   ./tests/smoke_test.sh
#
# Exit code 0 means every check passed. The script never needs a GUI.

set -u

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="/tmp/fleet_x_smoke_$(date +%s).log"
FAILURES=0

cleanup() {
  "${WS_DIR}/scripts/fleet_x_stop.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }

field() {
  # field <topic> <field> - echo one field from the next message
  timeout 15 ros2 topic echo "$1" --once --field "$2" 2>/dev/null | head -n 1
}

echo "=== FLEET-X smoke test ==="
echo "Workspace: ${WS_DIR}"

if [ ! -f "${WS_DIR}/install/setup.bash" ]; then
  echo "ERROR: workspace is not built. Run: colcon build --symlink-install" >&2
  exit 2
fi

# shellcheck disable=SC1091
source "${WS_DIR}/scripts/fleet_x_env.sh"

echo "[1] Starting headless simulation"
if ! "${WS_DIR}/scripts/fleet_x_start.sh" --timeout 120 --log "${LOG_FILE}" >/tmp/fleet_x_start.out 2>&1; then
  fail "simulation did not become ready"
  tail -n 30 /tmp/fleet_x_start.out >&2 || true
  exit 1
fi
pass "diff_drive_controller active"

echo "[2] Controllers"
CONTROLLERS="$(timeout 10 ros2 control list_controllers 2>/dev/null || true)"
if printf '%s\n' "${CONTROLLERS}" | grep -Eq '^joint_state_broadcaster .*[[:space:]]active$'; then
  pass "joint_state_broadcaster active"
else
  fail "joint_state_broadcaster not active"
fi
if printf '%s\n' "${CONTROLLERS}" | grep -Eq '^diff_drive_controller .*[[:space:]]active$'; then
  pass "diff_drive_controller active"
else
  fail "diff_drive_controller not active"
fi

echo "[3] Sensor topics"
TOPICS="$(timeout 10 ros2 topic list 2>/dev/null || true)"
printf '%s\n' "${TOPICS}" | grep -qx '/scan' && pass "/scan exists" || fail "/scan missing"
printf '%s\n' "${TOPICS}" | grep -qx '/imu' && pass "/imu exists" || fail "/imu missing"

SCAN_FRAME="$(field /scan header.frame_id)"
[ "${SCAN_FRAME}" = "lidar_link" ] && pass "/scan frame is lidar_link" \
  || fail "/scan frame is '${SCAN_FRAME}', expected lidar_link"

IMU_FRAME="$(field /imu header.frame_id)"
[ "${IMU_FRAME}" = "imu_link" ] && pass "/imu frame is imu_link" \
  || fail "/imu frame is '${IMU_FRAME}', expected imu_link"

echo "[4] TF"
TF_OUTPUT="$(timeout 12 ros2 run tf2_ros tf2_echo world lidar_link 2>/dev/null | head -n 12 || true)"
if printf '%s\n' "${TF_OUTPUT}" | grep -q 'Translation'; then
  pass "world -> lidar_link resolves"
else
  fail "world -> lidar_link did not resolve"
fi

echo "[5] Motion and odometry"
X_BEFORE="$(field /diff_drive_controller/odom pose.pose.position.x)"
if [ -z "${X_BEFORE}" ]; then
  fail "could not read odometry before motion"
else
  timeout 5 ros2 topic pub -r 10 /diff_drive_controller/cmd_vel \
    geometry_msgs/msg/TwistStamped \
    "{header: {frame_id: base_link}, twist: {linear: {x: 0.2}}}" \
    >/dev/null 2>&1 || true
  sleep 2
  X_AFTER="$(field /diff_drive_controller/odom pose.pose.position.x)"
  DELTA="$(python3 -c "print(abs(float('${X_AFTER:-0}') - float('${X_BEFORE:-0}')))" 2>/dev/null || echo 0)"
  if python3 -c "import sys; sys.exit(0 if float('${DELTA}') > 0.05 else 1)"; then
    pass "odometry advanced by ${DELTA} m"
  else
    fail "odometry did not advance (delta ${DELTA} m)"
  fi
fi

echo
if [ "${FAILURES}" -eq 0 ]; then
  echo "=== SMOKE TEST PASSED ==="
  exit 0
fi

echo "=== SMOKE TEST FAILED: ${FAILURES} check(s) ===" >&2
echo "Launch log: ${LOG_FILE}" >&2
exit 1
