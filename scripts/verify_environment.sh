#!/bin/bash
# Copyright 2026 FLEET-X Project Contributors
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================="
echo " FLEET-X Environment Verification"
echo "============================================="

PASS=0
FAIL=0
SKIP=0

check() {
    local desc="$1"
    shift
    echo -n "  [$desc] "
    if output=$("$@" 2>&1); then
        echo "PASS"
        PASS=$((PASS+1))
        return 0
    else
        echo "FAIL"
        FAIL=$((FAIL+1))
        return 1
    fi
}

check_skip() {
    local desc="$1"
    local reason="$2"
    echo "  [$desc] SKIP ($reason)"
    SKIP=$((SKIP+1))
}

# Source environment
echo ""
echo "Activating FLEET-X environment..."
if [ -f "$WS_DIR/scripts/setup_fleet_x.sh" ]; then
    source "$WS_DIR/scripts/setup_fleet_x.sh"
elif [ -f "/opt/ros/jazzy/setup.bash" ]; then
    source /opt/ros/jazzy/setup.bash
else
    echo "ERROR: Cannot find environment to source"
    exit 1
fi

echo ""
echo "--- 1. Ubuntu Version ---"
lsb_release -a 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME

echo ""
echo "--- 2. Architecture ---"
uname -m

echo ""
echo "--- 3. ROS 2 Distro ---"
echo "ROS_DISTRO=$ROS_DISTRO"
echo "ROS_VERSION=$ROS_VERSION"

echo ""
echo "--- 4. ROS 2 CLI ---"
check "ros2 --version" ros2 --version || true
check "ros2 help" ros2 help || true

echo ""
echo "--- 5. ROS 2 Doctor ---"
check "ros2 doctor" ros2 doctor --report || true

echo ""
echo "--- 6. Key ROS 2 Packages ---"
for pkg in ros-jazzy-desktop ros-jazzy-rclcpp ros-jazzy-rclpy \
           ros-jazzy-std-msgs ros-jazzy-geometry-msgs ros-jazzy-sensor-msgs \
           ros-jazzy-nav-msgs ros-jazzy-action-msgs; do
    check "$pkg" dpkg -s "$pkg" >/dev/null 2>&1
done

echo ""
echo "--- 7. Nav2 Packages ---"
for pkg in ros-jazzy-navigation2 ros-jazzy-nav2-bringup ros-jazzy-nav2-bt-navigator \
           ros-jazzy-nav2-costmap-2d ros-jazzy-nav2-controller ros-jazzy-nav2-planner \
           ros-jazzy-nav2-amcl ros-jazzy-nav2-lifecycle-manager; do
    check "$pkg" dpkg -s "$pkg" >/dev/null 2>&1
done

echo ""
echo "--- 8. Gazebo Packages ---"
for pkg in ros-jazzy-ros-gz ros-jazzy-ros-gz-sim ros-jazzy-ros-gz-bridge; do
    check "$pkg" dpkg -s "$pkg" >/dev/null 2>&1
done
check "gz sim --version" gz sim --version || true

echo ""
echo "--- 9. SLAM / Localization ---"
for pkg in ros-jazzy-slam-toolbox ros-jazzy-robot-localization; do
    check "$pkg" dpkg -s "$pkg" >/dev/null 2>&1
done

echo ""
echo "--- 10. TF / Robot State ---"
for pkg in ros-jazzy-tf2-ros ros-jazzy-robot-state-publisher \
           ros-jazzy-joint-state-publisher ros-jazzy-xacro; do
    check "$pkg" dpkg -s "$pkg" >/dev/null 2>&1
done

echo ""
echo "--- 11. Sensor Packages ---"
for pkg in ros-jazzy-pointcloud-to-laserscan ros-jazzy-imu-tools \
           ros-jazzy-depth-image-proc ros-jazzy-image-transport; do
    check "$pkg" dpkg -s "$pkg" >/dev/null 2>&1
done

echo ""
echo "--- 12. RViz2 ---"
check "ros2 pkg executables rviz2" bash -c "ros2 pkg executables rviz2 2>/dev/null | grep -q rviz2" || true

echo ""
echo "--- 13. colcon ---"
check "colcon --version" colcon --version || true

echo ""
echo "--- 14. Python ROS 2 Imports ---"
check "import rclpy" python3 -c "import rclpy" || true
check "import geometry_msgs" python3 -c "import geometry_msgs" || true
check "import sensor_msgs" python3 -c "import sensor_msgs" || true
check "import nav_msgs" python3 -c "import nav_msgs" || true
check "import tf2_ros" python3 -c "import tf2_ros" || true

echo ""
echo "--- 15. Python Libraries ---"
for lib in numpy scipy matplotlib networkx yaml; do
    check "import $lib" python3 -c "import $lib" || true
done

echo ""
echo "--- 16. FLEET-X Workspace ---"
if [ -d "$WS_DIR/src" ]; then
    echo "  [$WS_DIR/src exists] PASS"
    PASS=$((PASS+1))
else
    echo "  [$WS_DIR/src exists] FAIL"
    FAIL=$((FAIL+1))
fi
check "colcon build in workspace" bash -c "cd '$WS_DIR' && colcon build 2>&1" || true

echo ""
echo "--- 17. GUI Verification ---"
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    check "rviz2 --help" bash -c "timeout 5 rviz2 --help 2>&1 | head -1" || true
    check "gz sim --help" bash -c "timeout 5 gz sim --help 2>&1 | head -1" || true
else
    check_skip "rviz2 launch" "No display available (headless)"
    check_skip "gz sim launch" "No display available (headless)"
fi

echo ""
echo "============================================="
echo " VERIFICATION SUMMARY"
echo "============================================="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
echo "============================================="
