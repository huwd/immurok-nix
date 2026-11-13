# 0001. Package as a standalone flake, with a module that installs infrastructure and leaves authentication policy to the user

- **Status:** Accepted
- **Decided by:** @huwd
- **Decided:** 2026-11-13
- **Recorded:** 2026-11-13
- **Discussion:** none

## Summary

The immurok Linux client doesn't install on NixOS as released.
This repository packages it as a flake that exposes a package, an overlay and a NixOS module.
The module sets up the daemon and its plumbing, and leaves the PAM hooks that change how logins work as separate options that default to off.
A broken authentication stack can lock a user out of `sudo`, so enabling the device is never the same step as trusting it.

## Context

Upstream ships `.deb`, `.rpm` and Arch packages, and a `make install` flow.
They assume a conventional layout and mutate the system at install time:

- binaries and units go to `/usr` and `/etc`, and the units hardcode `/usr/bin` paths
- the install flow creates a system user and edits `/etc/pam.d`
- NixOS generates `/etc/pam.d` from configuration and keeps the store read-only

The client has several parts: a daemon that runs as a dedicated system user, a user-session agent, a CLI, a GTK4 settings app, and a C PAM module.
Pairing and enrolling a finger need only the daemon.
Authentication hooks are optional and each one changes how a login path behaves.

## Options considered

### Standalone flake with an infrastructure-only module (chosen)

A flake outputs `packages`, `overlays.default` and `nixosModules.default`.
The module runs the daemon, creates its user, wires the D-Bus policy and enables Bluetooth.
PAM hooks, lock-screen unlock and SSH integration are separate options, each off by default.

- It can be consumed from a configuration repository as a flake input.
- It can move to nixpkgs later without rewriting: the package takes only `pkgs`, and the module doesn't refer to anyone's own configuration.
- A consumer can pair and enrol a device before changing any authentication behaviour.
- It is one more repository to maintain and keep updated against upstream releases.

### Package only, in the consumer's own configuration repository

Simplest to start, but every consumer would copy the derivation, and the module work would be tangled with one person's choices.

### Straight to nixpkgs

Reviewers would expect a stable upstream, and the upstream is pre-1.0.
It also slows iteration while the packaging is still being worked out.

### Wrap the upstream `.deb` or `.rpm`

It would unpack the release binaries and patch their paths.
That skips building from source, and it ties the package to upstream's build environment and glibc version, so it can't be reproduced or audited.

## Decision

The repository is a flake that exposes `packages.<system>.immurok`, `overlays.default` and `nixosModules.default`.
The package builds from source at a pinned tag and installs upstream's data files (D-Bus policy, polkit rule, desktop file, icons) under `$out/share`, so the module can reference them.
Upstream's PAM-editing scripts are not part of the supported path.

The module's default behaviour is limited to infrastructure.
Anything that changes how authentication works is a separate option that defaults to off.

## Consequences

- Consumers choose each authentication hook deliberately, and can test the device first.
- The settings app's buttons that edit PAM configuration have nothing to edit on NixOS and are expected to fail.
- The package must be updated by hand when upstream releases, until an update script exists.
- Records about how a particular machine uses the device belong in that machine's own configuration.
