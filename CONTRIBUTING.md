# Contributing to FLEET-X

Thank you for considering a contribution. FLEET-X is a ROS 2 Jazzy / Gazebo
Harmonic project with a deliberately honest development status. Please keep
that honesty intact: do not describe planned features as working features.

## Development setup

```bash
git clone https://github.com/ayub-14/FLEET-X.git
cd FLEET-X
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

## Before opening a pull request

1. Build the workspace without warnings that you introduced.
2. Run the package lint suite:

   ```bash
   colcon test --packages-select fleet_x_amr
   colcon test-result --verbose
   ```

3. Run the runtime smoke test if you changed simulation, control, sensors or
   launch behaviour:

   ```bash
   ./tests/smoke_test.sh
   ```

4. Update the relevant report in `docs/development/` with **what you actually
   verified**, the platform and the date.
5. Keep `README.md` status claims consistent with the code.

## Code and repository rules

- Keep ROS 2 package names, `package.xml`, `CMakeLists.txt`, launch paths and
  `$(find fleet_x_amr)` references valid.
- Do not add generated `build/`, `install/` or `log/` content.
- Do not commit credentials, tokens, private keys, personal data or machine
  specific paths.
- Do not copy third-party code without its licence and attribution.
- Prefer small, focused commits with clear messages, for example:
  - `feat: add lidar range filter`
  - `fix: correct odom frame in rviz config`
  - `docs: record phase 2c mapping result`
- Do not force-push shared branches.

## Reporting issues

Include:

- the exact launch command,
- ROS 2 distribution and Gazebo version,
- relevant log lines,
- what you expected and what happened,
- whether the issue is reproducible headless (`gui:=false rviz:=false`).

## Scope of the current repository

The single-robot substrate is implemented and verified. Multi-robot spawning,
decentralized communication, negotiation, reservation and deadlock recovery are
planned. Contributions toward those phases are welcome, but they must include
tests and must be labelled accurately in documentation.
