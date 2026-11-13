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

## AI disclosure

An AI assistant helped build this repository.
The assistant is Claude Sonnet 5.5 from Anthropic, used through Claude Code.
It helped with reading upstream's source, drafting the README, the decision records and the ruleset, and working out the packaging.

The maintainer reviews every change, approves and signs every commit, and is responsible for the result.

Each commit made with the assistant's help ends with these trailers:

- `Assisted-by: Claude Code:claude-sonnet-5-5` when the maintainer did most of the work and the assistant helped.
  `Generated-by: Claude Code:claude-sonnet-5-5` takes its place when the assistant produced a large part from prompts.
- `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`, kept only so that GitHub shows that an AI took part.
  It doesn't claim equal authorship, and the other trailers take priority over it.
- `Signed-off-by:` naming the maintainer.
  The maintainer's git configuration adds it, and the assistant never writes it.

Three early commits predate this convention and carry `Co-Authored-By` only: `338eb46`, `ce7b768` and `ac25926`.
They are on `main`, which doesn't allow rewriting history.

## Licence

[Apache-2.0](LICENSE).
This covers the Nix files in this repository.
The immurok source that the package builds is upstream's, under upstream's licence.
