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
FLEET-X : localization against a saved map with slam_toolbox.

This launch is the Phase 2C localization scaffold. It loads a map through
nav2_map_server and starts slam_toolbox in localization mode. A map generated
by slam_mapping.launch.py must first be saved as
src/fleet_x_amr/maps/fleet_x_map.yaml (plus its image), or supplied through the
map:= launch argument. Without that asset the launch will not complete.

The mapping path is the verified Phase 2C workflow; localization is still
work in progress. See docs/development/PHASE_2C_REPORT.md.

Invoke it with `ros2 launch fleet_x_amr slam_localization.launch.py`, optionally
passing `map:=/path/to/map.yaml` or `rviz:=false`.
"""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    pkg_share = get_package_share_directory('fleet_x_amr')
    slam_toolbox_share = get_package_share_directory('slam_toolbox')

    default_map = os.path.join(pkg_share, 'maps', 'fleet_x_map.yaml')
    default_slam_params = os.path.join(
        pkg_share, 'config', 'mapper_params_localization.yaml')

    declare_use_sim_time = DeclareLaunchArgument(
        'use_sim_time', default_value='true',
        description='Use simulation time'
    )
    declare_map = DeclareLaunchArgument(
        'map', default_value=default_map,
        description='Full path to the map yaml file to load'
    )
    declare_slam_params_file = DeclareLaunchArgument(
        'slam_params_file',
        default_value=default_slam_params,
        description='Full path to the slam_toolbox localization parameters file'
    )
    declare_rviz = DeclareLaunchArgument(
        'rviz', default_value='true',
        description='Start RViz2 with the FLEET-X view.'
    )

    map_server = Node(
        package='nav2_map_server',
        executable='map_server',
        name='map_server',
        output='screen',
        parameters=[
            {'yaml_filename': LaunchConfiguration('map')},
            {'use_sim_time': LaunchConfiguration('use_sim_time')},
        ],
    )

    lifecycle_manager = Node(
        package='nav2_lifecycle_manager',
        executable='lifecycle_manager',
        name='lifecycle_manager_localization',
        output='screen',
        parameters=[
            {'use_sim_time': LaunchConfiguration('use_sim_time')},
            {'autostart': True},
            {'node_names': ['map_server']},
        ],
    )

    slam_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(
                slam_toolbox_share, 'launch', 'localization_launch.py')),
        launch_arguments={
            'use_sim_time': LaunchConfiguration('use_sim_time'),
            'slam_params_file': LaunchConfiguration('slam_params_file'),
        }.items()
    )

    rviz = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        output='screen',
        parameters=[{'use_sim_time': LaunchConfiguration('use_sim_time')}],
        arguments=[
            '-d', os.path.join(pkg_share, 'rviz', 'fleet_x_amr.rviz')],
        condition=IfCondition(LaunchConfiguration('rviz')),
    )

    return LaunchDescription([
        declare_use_sim_time,
        declare_map,
        declare_slam_params_file,
        declare_rviz,
        map_server,
        lifecycle_manager,
        slam_launch,
        rviz,
    ])
