# immurok-nix

Nix packaging and a NixOS module for the [immurok](https://immurok.com) Bluetooth fingerprint key.

The upstream Linux client is [immurok/app-linux-rs](https://github.com/immurok/app-linux-rs).
It ships `.deb`, `.rpm` and Arch packages that assume a conventional filesystem layout, so it doesn't install on NixOS as released.
This repository packages it from source.

**Status:** work in progress, and not yet tested with a real device.
The package builds and passes upstream's tests, and the module passes a VM test.
Pairing, enrolment and the PAM hooks haven't been tried.

## Contents

- `package.nix`: upstream's daemon, CLI, session agent and PAM module, with the Bluetooth helper and the dialog the daemon and agent run.
  The settings app (`immurok-gui`) isn't packaged yet.
- `module.nix`: a NixOS module under `services.immurok`.
  It sets up the daemon and its system user, the D-Bus policy, Bluetooth and the session agent.
  It doesn't touch PAM, so enabling it can't change how a login or `sudo` works.
- `tests/module.nix`: a VM test of the module.

## Usage

Add the flake as an input, import the module and enable it:

```nix
{
  inputs.immurok.url = "github:huwd/immurok-nix";

  # In your NixOS configuration:
  imports = [ inputs.immurok.nixosModules.default ];
  services.immurok.enable = true;
}
```

Then pair the key with `immurok-cli pair`.

Options:

- `services.immurok.package`: the package to use.
- `services.immurok.sessionAgent.enable`: run the session agent for every user.
  It's on by default.
- `services.immurok.lockScreen.enable`: allow the daemon to lock and unlock the session through logind.
  It's off by default, because it grants the `immurok` user that permission without authentication.

Don't turn on the `ssh_takeover` setting if `~/.ssh/config` is a read-only file managed by another tool.
The session agent rewrites that file when the setting is on.

## Using the key for `sudo` and other logins

The module doesn't add the key to any login path, and that is deliberate.

- **NixOS generates `/etc/pam.d`.** There's no file to edit by hand, and upstream's installer, its PAM helper and the settings app's PAM buttons all edit those files, so they can't work here.
- **It's a policy, and one that can lock you out.** Which services accept the key, and whether it comes before or after your password or another fingerprint reader, decides how logging in works on a given machine. A wrong rule can break `sudo`. That choice belongs in the configuration of the machine, where it is reviewed and rolled back like any other change, and not in a package that other people install.

To use the key for `sudo`, add a PAM rule in your own configuration:

```nix
{ config, ... }:
{
  security.pam.services.sudo.rules.auth.immurok = {
    # Just before the password rule, so the key is tried first.
    order = config.security.pam.services.sudo.rules.auth.unix.order - 10;
    control = "sufficient";
    modulePath = "${config.services.immurok.package}/lib/security/pam_immurok.so";
    # Wait ten seconds for a touch, not the default forty.
    args = [ "timeout=10" ];
  };
}
```

This generates `auth sufficient …/pam_immurok.so timeout=10` ahead of the password rule in `/etc/pam.d/sudo`.

- **Keep `control = "sufficient"`.** A key that doesn't answer then falls through to the next rule, and your password still works. With `required` or `requisite`, a missing or flat key would block `sudo` altogether.
- **If the daemon isn't running,** the module fails to connect within two seconds and falls through to the password. If the daemon is running and the key isn't there, it waits for the timeout, and a keypress at the prompt gives up early.
- **If you also use `fprintd`,** set `order` relative to its rule instead, to choose whether the key or the laptop reader goes first.
- **Other services** such as `polkit-1` use the same pattern under `security.pam.services.<name>`.
  The one exception is `gdm-password`, the GNOME screen-unlock service.
  It has no terminal, so the module steps aside and your password rule handles it.
  The daemon unlocks the session itself when a finger matches, through logind, which needs `services.immurok.lockScreen.enable`.

Before relying on it:

1. Pair the key and enrol a finger first, with the module enabled and no PAM rule.
2. Keep a root shell open in another terminal while you test.
3. Check `sudo` from a second terminal before closing the first. If something is wrong, the previous generation in the boot menu undoes the change.

## Limits

- Upstream's own installer, its PAM helper and the settings app's PAM buttons edit `/etc/pam.d`, which NixOS generates, so they can't work here.
- A NixOS VM has no Bluetooth adapter, so the test can't cover pairing or the device.
- The package's closure is large, mostly because of GTK4 and Python for the dialog.

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
