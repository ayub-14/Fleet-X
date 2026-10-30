# Phase 2C Report — SLAM Mapping and Localization

**Date:** 2026-10-30
**Platform:** Ubuntu 24.04.5 LTS, ROS 2 Jazzy, Gazebo Harmonic 8.15.0,
`ros-jazzy-slam-toolbox` 2.8.5.
**Overall status:** online mapping **verified**; saved-map localization
**in progress**.

## 1. Objective

Use the Phase 2B LiDAR and odometry to build a map of the simulated arena, and
evaluate whether the robot can localize against it.

## 2. Prerequisite verification

The Phase 2A/2B stack was brought up headless before mapping:

```bash
cd ~/fleet_x_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
ros2 launch fleet_x_amr fleet_x_amr_sim.launch.py gui:=false rviz:=false
```

Verified:

```text
joint_state_broadcaster  active
diff_drive_controller    active
/scan   sensor_msgs/msg/LaserScan  frame lidar_link
/imu    sensor_msgs/msg/Imu        frame imu_link
```

## 3. Mapping launch

`slam_mapping.launch.py` includes `slam_toolbox`'s
`online_async_launch.py` with:

- `use_sim_time:=true`
- `config/mapper_params_online_async.yaml`
- optional RViz2 (`rviz:=true` by default)

Command:

```bash
ros2 launch fleet_x_amr slam_mapping.launch.py rviz:=false
```

The launch starts the SLAM node, configures it, activates it, and registers the
LiDAR as a sensor.

## 4. Observed result

Within the first map update interval:

```text
$ ros2 topic info /map
Type: nav_msgs/msg/OccupancyGrid
Publisher count: 1

$ ros2 topic echo /map --once
header:
  frame_id: map
info:
  resolution: 0.05
  width: 85
  height: 229
```

The `map → odom` transform resolved:

```text
$ ros2 run tf2_ros tf2_echo map odom
Translation: [-0.000, -0.000, 0.000]
Rotation:    [0.000, 0.000, 0.000, 1.000]
```

The map dimensions differ between runs because the map is built incrementally
from the explored area and the robot's starting pose. That is expected for
online SLAM, not a fixed map.

**Conclusion:** the mapping path is working end to end on live simulated data.
It is not a synthetic or pre-recorded map.

## 5. Localization status

`src/fleet_x_amr/launch/slam_localization.launch.py` exists and is wired to:

- `nav2_map_server` with `maps/fleet_x_map.yaml`,
- `nav2_lifecycle_manager` for the map server,
- `slam_toolbox` in `localization` mode with
  `config/mapper_params_localization.yaml`.

However:

- no `fleet_x_map.yaml` / image is committed,
- the full localization launch has **not** been verified end to end,
- no AMCL configuration or Nav2 integration exists for `fleet_x_amr`.

It is therefore reported as **in progress**, not complete.

## 6. Saving a map

With mapping running and the robot driven around the arena:

```bash
ros2 run nav2_map_server map_saver_cli -f \
  "$HOME/fleet_x_ws/src/fleet_x_amr/maps/fleet_x_map"
```

This writes `fleet_x_map.yaml` and `fleet_x_map.pgm`. A verified map should be
committed only after checking that localization against it reproduces.

## 7. Problems encountered

| Problem | Observation | Resolution / status |
|---|---|---|
| RViz always started in the original mapping launch | Unhelpful on headless machines | Added `rviz` launch argument |
| TF message filter warnings at startup | Early scans arrive before the transform cache is warm | Non-fatal; SLAM registers the sensor and publishes the map |
| Map extents vary per run | Online mapping only covers explored space | Expected; not treated as a failure |
| Localization map missing | `maps/fleet_x_map.yaml` does not exist | Documented as in progress |

## 8. What this proves — and what it does not

**Proves:** the robot produces usable scan + odometry data, and `slam_toolbox`
can build and publish a map and the `map → odom` transform in this simulation.

**Does not prove:** localization accuracy, loop-closure quality, long-run map
stability, Nav2 navigation, or anything about multi-robot coordination.

## 9. Next steps

1. Drive a deliberate exploration route that covers the arena.
2. Save the map and commit it with a short provenance note.
3. Validate `slam_localization.launch.py` with that map.
4. Add a repeatable mapping/localization regression test.
5. Proceed to Nav2 bring-up for the single AMR.
