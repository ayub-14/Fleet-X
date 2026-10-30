# FLEET-X Robot Architecture

The robot is a custom differential-drive AMR. All geometry is declared in one
Xacro file, `src/fleet_x_amr/urdf/fleet_x_amr_dimensions.xacro`, and consumed by
the chassis, wheel, sensor and controller definitions.

## 1. Physical layout

```text
                 +X (forward)
                    ▲
        lidar_link  │  (0.12, 0, 0.18)
                    │
        ┌───────────┴───────────┐
        │       base_link       │  0.40 m × 0.30 m × 0.10 m
        │       mass 5.0 kg     │
        └───┬───────────────┬───┘
     left   │               │   right
   wheel    │               │   wheel
  (+Y)      │               │   (−Y)
            └───────────────┘
       wheel radius 0.05 m, separation 0.30 m
```

`base_footprint` is the ground projection and the odometry reference.
`base_link` is 0.10 m above it.

## 2. Dimensions

| Property | Value | Meaning |
|---|---:|---|
| `WHEEL_RADIUS` | 0.05 m | Contact radius; odometry scale |
| `WHEEL_WIDTH` | 0.04 m | Wheel thickness |
| `WHEEL_SEPARATION` | 0.30 m | Track width used by `diff_drive_controller` |
| `BASE_LENGTH` | 0.40 m | Chassis length |
| `BASE_HEIGHT` | 0.10 m | Chassis height |
| `BASE_MASS` | 5.0 kg | Chassis mass |
| `WHEEL_MASS` | 0.5 kg | Each wheel |
| `BASE_LINK_HEIGHT` | 0.10 m | `base_footprint → base_link` offset |
| `BASE_WIDTH` | derived | `(WHEEL_SEPARATION − WHEEL_WIDTH) / 2 − WHEEL_CLEARANCE`, doubled |
| `WHEEL_CLEARANCE` | 0.01 m | Gap between chassis side and wheel inner face |

The chassis width is deliberately **derived** so that the chassis box can never
overlap the wheel cylinders. Overlap creates same-model contacts in Gazebo,
which silently jams the wheels and corrupts motion while odometry still appears
to advance.

## 3. Links and joints

| Joint | Type | Parent → Child | Origin |
|---|---|---|---|
| `base_footprint_to_base_link` | fixed | `base_footprint → base_link` | `0 0 0.10` |
| `left_wheel_joint` | continuous | `base_link → left_wheel` | `0 +0.15 −0.05`, axis `0 1 0` |
| `right_wheel_joint` | continuous | `base_link → right_wheel` | `0 −0.15 −0.05`, axis `0 −1 0` |
| `lidar_joint` | fixed | `base_link → lidar_link` | `0.12 0 0.18` |
| `imu_joint` | fixed | `base_link → imu_link` | `0 0 0.12` |
| `base_link_to_sensor_mount` | fixed | `base_link → sensor_mount` | front-top mounting stub |

The wheel axes are mirrored. A positive velocity command on both joints drives
the robot forward, which is the sign convention expected by
`diff_drive_controller`.

## 4. Inertia

- Chassis: analytic box inertia from `BASE_MASS`, `BASE_LENGTH`, `BASE_WIDTH`,
  `BASE_HEIGHT`.
- Wheels: solid-cylinder inertia about the spin axis
  (`I = ½ m r²`) and the perpendicular axes.
- Sensor links: small representative masses and inertias.

The values are physically plausible but are not identified from a real robot.
They are suitable for simulation, not for hardware controller tuning.

## 5. Sensors

### 2D LiDAR

| Parameter | Value |
|---|---|
| Gazebo type | `gpu_lidar` |
| Frame | `lidar_link` |
| Topic | `/scan` (`sensor_msgs/msg/LaserScan`) |
| Update rate | 10 Hz |
| Samples | 360 |
| Angular range | −π to +π |
| Range | 0.08 m to 12.0 m |
| Range resolution | 0.01 m |
| Noise | Gaussian, σ = 0.01 m |

### IMU

| Parameter | Value |
|---|---|
| Gazebo type | `imu` |
| Frame | `imu_link` |
| Topic | `/imu` (`sensor_msgs/msg/Imu`) |
| Update rate | 100 Hz |
| Angular velocity noise | Gaussian, σ = 2 × 10⁻⁴ rad/s per axis |
| Linear acceleration noise | Gaussian, σ = 1.7 × 10⁻² m/s² per axis |

The IMU orientation covariance is currently zero-filled by the bridge. It is
not a calibrated covariance and must not be used as one.

## 6. Control chain

```text
TwistStamped command
        │
        ▼
diff_drive_controller
        │  velocity command interfaces
        ▼
gz_ros2_control/GazeboSimSystem
        │
        ▼
Gazebo DART physics
        │  joint position + velocity state
        ▼
joint_state_broadcaster  ──>  /joint_states
        │
        └──> diff_drive_controller odometry  ──>  /diff_drive_controller/odom
```

There is no synthetic encoder timer. Wheel state comes from the simulated
physics, and `open_loop` is `false`.

## 7. Geometry invariant

The launch file checks:

```text
WHEEL_RADIUS      (Xacro) == wheel_radius      (controller YAML)
WHEEL_SEPARATION  (Xacro) == wheel_separation  (controller YAML)
```

If either differs, the launch aborts before Gazebo starts. This prevents a
silent odometry scale error.

## 8. Source files

| File | Responsibility |
|---|---|
| `urdf/fleet_x_amr.urdf.xacro` | Top-level assembly |
| `urdf/fleet_x_amr_dimensions.xacro` | Single source of geometric truth |
| `urdf/fleet_x_amr_materials.xacro` | Colour palette |
| `urdf/fleet_x_amr_chassis.xacro` | Chassis, footprint, sensor mount |
| `urdf/fleet_x_amr_wheels.xacro` | Wheel macro and both wheels |
| `urdf/fleet_x_amr_sensors.xacro` | LiDAR and IMU links, joints, Gazebo sensors |
| `urdf/fleet_x_amr_ros2_control.xacro` | Hardware interfaces and Gazebo control plugin |
| `config/fleet_x_amr_controllers.yaml` | Controller manager and controller parameters |
| `worlds/fleet_x_amr_arena.world` | Flat arena, racks, pillars, required Gazebo systems |

## 9. Non-goals in the current model

- No suspension, caster wheel or payload model.
- No camera or depth sensor.
- No realistic battery, motor dynamics or wheel slip model.
- No hardware description for a physical robot.

These are roadmap items, not hidden assumptions in the current verification.
