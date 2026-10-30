# Maps

This directory holds occupancy maps for the FLEET-X AMR.

The Phase 2C **mapping** workflow is verified: `slam_mapping.launch.py` builds a
map online from `/scan` and publishes it on `/map`. A map has not yet been saved
into this directory as a committed artefact.

## Saving a map

With the simulation and `slam_mapping.launch.py` running, drive the AMR around
the arena to explore it, then save the map:

```bash
ros2 run nav2_map_server map_saver_cli -f "$HOME/fleet_x_ws/src/fleet_x_amr/maps/fleet_x_map"
```

This writes `fleet_x_map.yaml` and `fleet_x_map.pgm` here. `slam_localization.launch.py`
loads `fleet_x_map.yaml` by default; until that file exists, localization cannot
start. See [Phase 2C](../../../docs/development/PHASE_2C_REPORT.md) for the
current status.

Do not commit large or machine-specific map files unless they are useful for
reproducing a documented result.
