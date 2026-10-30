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
FLEET-X : online asynchronous SLAM mapping with slam_toolbox.

Run this alongside fleet_x_amr_sim.launch.py. slam_toolbox consumes /scan and
the odom -> base_footprint transform, then publishes /map and map -> odom.
The map is built incrementally while the AMR is driven with teleoperation.

Invoke it with `ros2 launch fleet_x_amr slam_mapping.launch.py`, or add
`rviz:=false` to suppress RViz2 on a headless machine.
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

    default_slam_params = os.path.join(
        pkg_share, 'config', 'mapper_params_online_async.yaml')

    declare_use_sim_time = DeclareLaunchArgument(
        'use_sim_time', default_value='true',
        description='Use simulation time'
    )
    declare_slam_params_file = DeclareLaunchArgument(
        'slam_params_file',
        default_value=default_slam_params,
        description='Full path to the slam_toolbox mapping parameters file'
    )
    declare_rviz = DeclareLaunchArgument(
        'rviz', default_value='true',
        description='Start RViz2 with the FLEET-X view.'
    )

    slam_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(
                slam_toolbox_share, 'launch', 'online_async_launch.py')),
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
        declare_slam_params_file,
        declare_rviz,
        slam_launch,
        rviz,
    ])
