# Phase 1 Report — FLEET-X

**Status:** completed baseline, later superseded by the Phase 2A `ros2_control`
drive chain.
**Retrospective date:** 2026-10-30.

## 1. Objective

Establish a single custom differential-drive AMR in Gazebo Harmonic with:

- an original URDF/Xacro description,
- a simulation world,
- teleoperation,
- odometry and a usable TF tree.

## 2. What Phase 1 established

- The `fleet_x_amr` ROS 2 package and its custom robot geometry.
- A flat test arena with static racks and pillars
  (`worlds/fleet_x_amr_arena.world`).
- The frame convention `world → odom → base_footprint → base_link` that later
  phases kept.
- A teleoperation path for velocity commands.
- Odometry and TF as the first observable motion feedback.

The original Phase 1 implementation used Gazebo's direct differential-drive
plugin path. That code is **not present in the current package**: Phase 2A
replaced it with `ros2_control` and `gz_ros2_control`, and removed the direct
drive plugin to avoid two components fighting over the same wheel joints.

## 3. Evidence retained in this repository

| Evidence | Location |
|---|---|
| Original chassis, wheel and material definitions | `src/fleet_x_amr/urdf/` |
| Arena world | `src/fleet_x_amr/worlds/fleet_x_amr_arena.world` |
| Frame convention and TF expectations | `docs/architecture/system_architecture.md` |
| Phase 2A report describing the Phase 1 baseline | `docs/development/PHASE_2A_REPORT.md` |

## 4. Reproducibility note

The current repository reproduces the **robot and simulation**, not the exact
Phase 1 plugin configuration. The Phase 1 drive chain was intentionally replaced
in Phase 2A. Any Phase 1-only test logs from the original development session
are not part of this repository, so the Phase 1 motion results are not
independently re-runnable from this commit.

What *is* independently verifiable today is the successor architecture: the
Phase 2A/2B/2C stack documented in the later reports.

## 5. Lessons carried forward

- The wheel axis signs must be mirrored so that positive commands drive both
  sides forward.
- The chassis width must be derived from wheel separation to avoid same-model
  collisions in Gazebo.
- Ground contact height and wheel radius must agree, or the robot appears to
  hover or sink.
- A single source of truth for geometry prevents controller/URDF drift.

These lessons shaped the Phase 2A design and the launch-time geometry check.
