# Pull request

## What changed

<!-- A short description of the change and why it is needed. -->

## Scope

- [ ] Single-robot simulation / control
- [ ] Sensors / SLAM / localization
- [ ] Multi-robot / coordination (planned layer)
- [ ] Documentation
- [ ] Tooling / tests

## Verification

<!-- Exact commands and observed results. Do not claim tests you did not run. -->

```bash
colcon build --symlink-install
colcon test --packages-select fleet_x_amr
colcon test-result --verbose
./tests/smoke_test.sh
```

- [ ] Build passes
- [ ] Lint tests pass
- [ ] Smoke test passes (or is not applicable, with an explanation)
- [ ] Documentation updated if behaviour or status changed

## Honesty checklist

- [ ] Planned features are not described as implemented.
- [ ] No credentials, tokens, private keys or personal data are included.
- [ ] Third-party code/assets are licensed and attributed.
- [ ] Package names, launch paths and install rules remain valid.
