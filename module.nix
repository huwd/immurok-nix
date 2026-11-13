{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.immurok;
in
{
  options.services.immurok = {
    enable = lib.mkEnableOption "the immurok Bluetooth fingerprint key daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.immurok;
      defaultText = lib.literalExpression "immurok-nix.packages.\${pkgs.stdenv.hostPlatform.system}.immurok";
      description = "The immurok package to use.";
    };

    sessionAgent.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run the session agent for every user. The daemon has no display and no
        session bus, so it asks this agent to show the touch and approval
        dialogs and desktop notifications.

        The agent can also edit `~/.ssh/config`, but only when the daemon's
        `ssh_takeover` setting is on, and that setting is off by default.
        Don't turn it on if `~/.ssh/config` is a read-only file managed by
        another tool.
      '';
    };

    lockScreen.enable = lib.mkEnableOption ''
      a polkit rule that lets the daemon lock and unlock the active graphical
      session through logind. The daemon runs as its own user, and logind
      asks polkit before it lets one user act on another's session. Without
      this rule the daemon can't lock or unlock the screen. The rule grants
      the `immurok` user that permission without authentication'';
  };

  config = lib.mkIf cfg.enable {
    # BlueZ is how the daemon reaches the device.
    hardware.bluetooth.enable = lib.mkDefault true;

    # The daemon runs as its own user, so no process of a logged-in user can
    # stop it, replace its binary or read the pairing key.
    users = {
      users.immurok = {
        isSystemUser = true;
        group = "immurok";
        description = "immurok fingerprint daemon";
      };
      groups.immurok = { };
    };

    environment = {
      systemPackages = [ cfg.package ];

      etc."polkit-1/rules.d/49-immurok.rules" = lib.mkIf cfg.lockScreen.enable {
        source = "${cfg.package}/share/polkit-1/rules.d/49-immurok.rules";
      };
    };

    # The package's D-Bus policy lets the `immurok` user talk to BlueZ.
    services.dbus.packages = [ cfg.package ];

    security.polkit.enable = lib.mkIf cfg.lockScreen.enable (lib.mkDefault true);

    systemd = {
      # Recreate /run/immurok early at boot, so anything that refers to the
      # sockets in it never finds the directory missing.
      tmpfiles.rules = [ "d /run/immurok 0755 immurok immurok -" ];

      services.immurok-daemon = {
        description = "immurok BLE fingerprint authentication daemon";
        after = [
          "bluetooth.target"
          "dbus.service"
        ];
        wants = [ "bluetooth.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe' cfg.package "immurok-daemon";
          User = "immurok";
          Group = "immurok";

          # /run/immurok holds the PAM and SSH agent sockets. It stays across
          # restarts, so a path that refers to it never points at a missing
          # directory.
          RuntimeDirectory = "immurok";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "yes";
          # /var/lib/immurok holds the pairing key and its caches.
          StateDirectory = "immurok";
          StateDirectoryMode = "0700";
          LogsDirectory = "immurok";
          LogsDirectoryMode = "0750";

          Restart = "on-failure";
          RestartSec = 5;

          # Everything outside the three directories above is read-only, so a
          # compromised daemon can't rewrite its own binary or the PAM
          # configuration that trusts it.
          NoNewPrivileges = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          # D-Bus and the sockets are Unix sockets, and the runtime uses
          # netlink for device events. The daemon does no networking.
          RestrictAddressFamilies = "AF_UNIX AF_NETLINK";
        };
      };

      user.services.immurok-session-agent = lib.mkIf cfg.sessionAgent.enable {
        description = "immurok session agent (dialogs, notifications)";
        # default.target, not graphical-session.target: a text-only login
        # needs the terminal hints too, and not every window manager starts
        # the graphical target.
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe' cfg.package "immurok-session-agent";
          Restart = "always";
          RestartSec = 2;
        };
      };
    };
  };
}
