#!/usr/bin/env bash
# Copyright 2026 FLEET-X Project Contributors
# SPDX-License-Identifier: Apache-2.0
# FLEET-X : stop a running Phase-2A simulation.
#
# The pkill patterns deliberately use the [x] bracket form so that they never
# match the command line of the shell that invokes this script.
set -u

KILL_PATTERNS=(
  '[f]leet_x_amr_sim.launch.py'
  '[r]obot_state_publisher'
  '[g]z sim'
  '[c]ontroller_manager spawner'
  '[s]pawn_fleet_x_amr'
  '[r]viz2'
)

for pattern in "${KILL_PATTERNS[@]}"; do
  pkill -f "$pattern" 2>/dev/null || true
done

sleep 2

# Anything left holding the Gazebo transport port would stop the next launch
# from binding, so report anything that is still alive.
leftover="$(pgrep -af '[f]leet_x_amr_sim.launch.py|[g]z sim|[r]obot_state_pub' || true)"
if [ -n "$leftover" ]; then
  echo "[fleet_x_stop] WARNING - still running:" >&2
  printf '%s\n' "$leftover" >&2
  exit 1
fi

echo "[fleet_x_stop] simulation stopped"
