# immurok-nix

Nix packaging and a NixOS module for the [immurok](https://immurok.com) Bluetooth fingerprint key.

The upstream Linux client is [immurok/app-linux-rs](https://github.com/immurok/app-linux-rs).
It ships `.deb`, `.rpm` and Arch packages that assume a conventional filesystem layout, so it doesn't install on NixOS as released.
This repository packages it from source.

**Status:** work in progress.
Nothing here builds yet.

## Planned contents

- `package.nix`: the derivation for the daemon, CLI, session agent, GUI and PAM module.
- `module.nix`: a NixOS module under `services.immurok`.
  It sets up the daemon and its system user, the D-Bus policy and Bluetooth.
  PAM hooks are separate options that default to off.

## Decisions

Design decisions about the package and module are in [`docs/decisions/`](docs/decisions/README.md).
They cover the package and module for any consumer, not how any one person configures their machine.

## Licence

[Apache-2.0](LICENSE).
This covers the Nix files in this repository.
The immurok source that the package builds is upstream's, under upstream's licence.
