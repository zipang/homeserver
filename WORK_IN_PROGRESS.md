# WORK IN PROGRESS: zrok Deployment & Self-Healing Fixes

We encountered significant issues with systemd deadlocks and authentication failures during the initial `zrok` deployment. The current goal is to implement a **Decoupled, Self-Healing** architecture.

## Current Issues & Failures
1.  **Systemd Deadlock**: `zrok-init` and `zrok-network` were blocking `nixos-rebuild` when they called `podman` while the podman daemon was being managed by the same rebuild process.
2.  **Authentication Race Condition**: `ziti-controller` was not consistently using the password provided in secrets during quickstart initialization.
3.  **Dependency Loops**: Rigid `requires` and `after` chains caused the entire system manager to hang when a single component failed.

## The New Strategy: Decoupled Startup
We are moving away from rigid systemd dependencies to a "convergent" model where each component tries to reach its target state independently.

- [ ] **Remove Hard Dependencies**: Replace `requires` with `wants` and remove `before` triggers that block the system switch.
- [ ] **Deterministic Password Sync**: The `zrok-bootstrap` service will forcefully sync the Ziti admin password instead of relying on the initial setup.
- [ ] **Lightweight Init**: Ensure `zrok-init` only performs file operations and never calls `podman`.
- [ ] **Background Retries**: All services will use `Restart=on-failure` with backoffs, allowing them to eventually connect without blocking other services.

## Status: Temporarily Disabled
The `zrok.nix` module is currently commented out in `hosts/SKYLAB/configuration.nix` to allow for safe server maintenance and reboots.

## Pending Tasks
1.  Refactor `modules/services/zrok.nix` to implement the decoupled strategy.
2.  Test the `reset-zrok.sh` script with the new architecture.
3.  Re-enable the module in `configuration.nix`.
