#!/usr/bin/env python3
# Copyright 2026 FLEET-X Project Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""
FLEET-X : single command simulation launch for Phase 2A (ros2_control).

Launches, in one process group:

    Gazebo Harmonic server (+ GUI unless gui:=false)
        |
        v
    fleet_x_amr URDF spawned from the robot_description topic
        |
        v
    gz_ros2_control system plugin  ->  creates controller_manager
        |
        +-- joint_state_broadcaster  (active)
        +-- diff_drive_controller    (active)   <-- /cmd_vel in, /odom out

    robot_state_publisher          ->  /tf from /joint_states
    static_transform_publisher     ->  world -> odom

Usage:

    ros2 launch fleet_x_amr fleet_x_amr_sim.launch.py
    ros2 launch fleet_x_amr fleet_x_amr_sim.launch.py gui:=false rviz:=false

No Nav2 and no multi-robot logic: this file wires up the drive chain and the
sensor bridges that Phase 2A and Phase 2B are responsible for.
"""

import os
import re

from ament_index_python.packages import (
    get_package_prefix,
    get_package_share_directory,
)
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument,
    ExecuteProcess,
    SetEnvironmentVariable,
    Shutdown,
    TimerAction,
)
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
import xacro
import yaml


# Name declared by worlds/fleet_x_amr_arena.world. The world control service used
# to unpause the simulation is addressed by world name, so it must match.
WORLD_NAME = 'fleet_x_amr_arena'


def read_xacro_properties(xacro_path):
    """
    Extract literal <xacro:property name=".." value=".."/> declarations.

    Only literal values are collected; derived properties whose value is an
    xacro expression are not needed for the cross-check below.
    """
    props = {}
    pattern = re.compile(r'<xacro:property\s+name="([^"]+)"\s+value="([^"]+)"')
    with open(xacro_path, 'r', encoding='utf-8') as handle:
        for line in handle:
            match = pattern.search(line)
            if match:
                props[match.group(1)] = match.group(2)
    return props


def verify_geometry_matches_controllers(package_share, controllers_yaml_path):
    """
    Fail fast if the URDF geometry and the controller YAML disagree.

    diff_drive_controller converts wheel angular velocity into linear velocity
    with its OWN copy of wheel_radius and wheel_separation. If those numbers
    ever drift from the URDF, the AMR still drives correctly but the odometry is
    scaled wrongly - a subtle physics bug that is very hard to notice. Checking
    here turns it into an immediate, obvious startup failure.
    """
    dims_path = os.path.join(
        package_share, 'urdf', 'fleet_x_amr_dimensions.xacro')
    props = read_xacro_properties(dims_path)

    with open(controllers_yaml_path, 'r', encoding='utf-8') as handle:
        params = yaml.safe_load(handle)

    diff_drive = params['diff_drive_controller']['ros__parameters']

    checks = (
        ('WHEEL_RADIUS', 'wheel_radius'),
        ('WHEEL_SEPARATION', 'wheel_separation'),
    )

    for xacro_key, yaml_key in checks:
        urdf_value = float(props[xacro_key])
        yaml_value = float(diff_drive[yaml_key])
        if abs(urdf_value - yaml_value) > 1e-9:
            raise RuntimeError(
                'FLEET-X geometry mismatch: URDF {0} = {1} m but '
                'diff_drive_controller {2} = {3} m. Reconcile them before '
                'launching.'.format(
                    xacro_key, urdf_value, yaml_key, yaml_value))

    print('[fleet_x_amr] geometry cross-check OK: wheel_radius={0} m, '
          'wheel_separation={1} m'.format(
              props['WHEEL_RADIUS'], props['WHEEL_SEPARATION']))


def generate_launch_description():
    package_share = get_package_share_directory('fleet_x_amr')

    urdf_path = os.path.join(
        package_share, 'urdf', 'fleet_x_amr.urdf.xacro')
    controllers_yaml = os.path.join(
        package_share, 'config', 'fleet_x_amr_controllers.yaml')
    world_file = os.path.join(
        package_share, 'worlds', 'fleet_x_amr_arena.world')
    rviz_config = os.path.join(
        package_share, 'rviz', 'fleet_x_amr.rviz')

    # Eager consistency check, so a geometry/config mismatch fails before
    # Gazebo is started at all.
    verify_geometry_matches_controllers(package_share, controllers_yaml)

    # ---------------- launch arguments ----------------
    gui_arg = DeclareLaunchArgument(
        'gui', default_value='true',
        description='Start the Gazebo graphical client.')
    rviz_arg = DeclareLaunchArgument(
        'rviz', default_value='true',
        description='Start RViz2 with the FLEET-X view.')
    world_arg = DeclareLaunchArgument(
        'world', default_value=world_file,
        description='Absolute path to the Gazebo world file.')
    spawn_x_arg = DeclareLaunchArgument('spawn_x', default_value='0.0')
    spawn_y_arg = DeclareLaunchArgument('spawn_y', default_value='0.0')
    spawn_yaw_arg = DeclareLaunchArgument('spawn_yaw', default_value='0.0')

    # ---------------- Gazebo plugin discovery ----------------
    # gz-sim discovers system plugins through GZ_SIM_SYSTEM_PLUGIN_PATH. The
    # gz_ros2_control Gazebo system plugin lives in that package's lib/
    # directory; prepend it here so no external environment tweaking is needed.
    # The prefix, not the share directory: on Linux an ament package installs
    # its libraries in <prefix>/lib, whereas <share>/<pkg>/../lib would resolve
    # to <share>/lib, which does not exist.
    gz_control_lib = os.path.join(get_package_prefix('gz_ros2_control'), 'lib')

    set_gz_plugin_path = SetEnvironmentVariable(
        'GZ_SIM_SYSTEM_PLUGIN_PATH', gz_control_lib)

    # ---------------- Gazebo ----------------
    # -s runs the physics server only (headless); -r adds the GUI.
    #
    # Gazebo is started directly instead of through ros_gz_sim/gz_sim.launch.py
    # because that include collapses the whole argument vector into a single
    # 'gz_args' string, which gz then parses as one argument. The custom world
    # path is silently dropped and Gazebo falls back to its built-in default
    # world, so neither /world/fleet_x_amr_arena/clock nor the arena's
    # /world/fleet_x_amr_arena/control service ever exists.
    def gazebo_process(gui_mode):
        return ExecuteProcess(
            cmd=[
                'gz', 'sim',
                '-r' if gui_mode else '-s',
                '-v', '4',
                LaunchConfiguration('world'),
            ],
            output='screen',
            # Passed explicitly: an ExecuteProcess does not reliably inherit
            # the SetEnvironmentVariable above, and without the path gz-sim
            # reports "Failed to load system plugin
            # [libgz_ros2_control-system.so] : Could not find shared library".
            additional_env={
                'GZ_SIM_SYSTEM_PLUGIN_PATH': gz_control_lib,
            },
            on_exit=Shutdown(),
            condition=IfCondition(LaunchConfiguration('gui'))
            if gui_mode else UnlessCondition(LaunchConfiguration('gui')),
        )

    # ---------------- robot_state_publisher ----------------
    # The absolute path of the controllers YAML is baked into the URDF by xacro
    # itself ($(find fleet_x_amr) resolves to the install share directory), so
    # the Gazebo system plugin can read it from inside the spawned SDF model.
    # Depending on its version, xacro returns either the rendered XML string or
    # the parsed DOM document, so normalise to a string here.
    rendered = xacro.process_file(urdf_path)
    robot_description = (
        rendered if isinstance(rendered, str)
        else rendered.toprettyxml(indent='  '))

    robot_state_publisher = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        name='robot_state_publisher',
        output='screen',
        parameters=[{
            'robot_description': robot_description,
            'use_sim_time': True,
        }],
    )

    # ---------------- simulation clock ----------------
    # Gazebo publishes /clock on its own transport. It has to be bridged into
    # the ROS graph, because every ROS node here runs with use_sim_time:=true
    # and because controller_manager drives its read/update cycle from the ROS
    # clock. Without this bridge the controller lifecycle transitions block
    # waiting for a clock that never ticks, and activation times out.
    clock_bridge = Node(
        package='ros_gz_bridge',
        executable='parameter_bridge',
        name='clock_bridge',
        output='screen',
        arguments=[
            '/clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock',
        ],
    )

    # ---------------- sensor bridges (LiDAR and IMU) ----------------
    sensor_bridge = Node(
        package='ros_gz_bridge',
        executable='parameter_bridge',
        name='sensor_bridge',
        output='screen',
        arguments=[
            '/scan@sensor_msgs/msg/LaserScan[gz.msgs.LaserScan',
            '/imu@sensor_msgs/msg/Imu[gz.msgs.IMU',
        ],
    )

    # ---------------- unpause the simulation ----------------
    # On this machine gz-sim brings the world up in the paused state (the user
    # GUI configuration at ~/.gz/sim/8/gui.config carries
    # <start_paused>true</start_paused>). While the world is paused,
    # controller_manager::read() blocks waiting for simulated time to advance,
    # so every controller activation fails after 5 s with
    # "Switch controller timed out after 5 seconds" - while hardware
    # initialisation and controller loading appear to succeed, which makes the
    # real cause easy to miss.
    #
    # Unpausing is therefore done explicitly here, with retries, because the
    # world control service is only reachable once the server has finished
    # loading the world. This keeps the launch independent of any personal GUI
    # setting, which is what a scripted/headless simulation needs.
    unpause_simulation = ExecuteProcess(
        cmd=[
            'bash', '-c',
            'for attempt in $(seq 1 20); do '
            '  resp=$(gz service -s /world/{world}/control '
            '       --reqtype gz.msgs.WorldControl '
            '       --reptype gz.msgs.Boolean '
            '       --timeout 3000 '
            '       --req "pause: false" 2>&1 | tr -d "\\n"); '
            '  echo "[fleet_x_amr] unpause attempt $attempt -> $resp"; '
            '  if echo "$resp" | grep -q "data: true"; then '
            '    echo "[fleet_x_amr] simulation unpaused after $attempt attempt(s)"; exit 0; fi; '
            '  sleep 2; '
            'done; '
            'echo "[fleet_x_amr] ERROR: could not unpause the simulation"; '
            'exit 1'.format(world=WORLD_NAME),
        ],
        output='screen',
    )

    # ---------------- world -> odom ----------------
    # diff_drive_controller owns the odom -> base_footprint edge. The link from
    # the simulator's world frame down to odom is fixed, so a static publisher
    # is the correct source for it.
    world_to_odom = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        name='world_to_odom',
        output='screen',
        arguments=[
            '--x', '0.0', '--y', '0.0', '--z', '0.0',
            '--roll', '0.0', '--pitch', '0.0', '--yaw', '0.0',
            '--frame-id', 'world', '--child-frame-id', 'odom',
        ],
        parameters=[{'use_sim_time': True}],
    )

    # ---------------- spawn the AMR ----------------
    spawn_amr = Node(
        package='ros_gz_sim',
        executable='create',
        name='spawn_fleet_x_amr',
        output='screen',
        arguments=[
            '-topic', 'robot_description',
            '-name', 'fleet_x_amr',
            '-x', LaunchConfiguration('spawn_x'),
            '-y', LaunchConfiguration('spawn_y'),
            '-z', '0.0',
            '-Y', LaunchConfiguration('spawn_yaw'),
        ],
    )

    # ---------------- controller spawning ----------------
    # The Gazebo system plugin creates the controller_manager and loads the
    # manager-level settings from the controllers YAML, but it does not load
    # individual controllers. They are therefore spawned here, once the model
    # (and with it the hardware component and the manager) exists.
    #
    # Each spawner is given the same YAML with -p so the controller node
    # receives its own parameter block - notably diff_drive_controller's
    # wheel_radius / wheel_separation - before it is configured.
    def spawn_controller(controller_name):
        return Node(
            package='controller_manager',
            executable='spawner',
            name='spawn_' + controller_name,
            output='screen',
            arguments=[
                controller_name,
                '-c', '/controller_manager',
                '-p', controllers_yaml,
            ],
        )

    joint_state_broadcaster_spawner = spawn_controller('joint_state_broadcaster')
    diff_drive_spawner = spawn_controller('diff_drive_controller')

    # ---------------- RViz ----------------
    rviz = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        output='screen',
        arguments=['-d', rviz_config],
        parameters=[{'use_sim_time': True}],
        condition=IfCondition(LaunchConfiguration('rviz')),
    )

    return LaunchDescription([
        gui_arg,
        rviz_arg,
        world_arg,
        spawn_x_arg,
        spawn_y_arg,
        spawn_yaw_arg,

        set_gz_plugin_path,

        clock_bridge,
        sensor_bridge,
        robot_state_publisher,
        world_to_odom,

        # Gazebo first; spawn only once the server accepts service calls.
        gazebo_process(gui_mode=True),
        gazebo_process(gui_mode=False),

        # Let the server finish loading, unpause it, then spawn the AMR.
        TimerAction(period=3.0, actions=[unpause_simulation]),
        TimerAction(period=8.0, actions=[spawn_amr]),

        # Controllers once the model and its hardware component exist.
        TimerAction(period=10.0, actions=[
            joint_state_broadcaster_spawner,
            diff_drive_spawner,
        ]),

        rviz,
    ])
