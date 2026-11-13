# Boots a VM with the module enabled and checks what the module sets up.
# The VM has no Bluetooth adapter, so BlueZ never starts. This can't test
# pairing, the device, or the D-Bus policy in action.
{ self, pkgs }:
let
  immurok = self.packages.${pkgs.stdenv.hostPlatform.system}.immurok;
in
pkgs.testers.runNixOSTest {
  name = "immurok-module";

  nodes.machine = _: {
    imports = [ self.nixosModules.default ];
    services.immurok = {
      enable = true;
      lockScreen.enable = true;
    };
    users.users.alice = {
      isNormalUser = true;
      # Start her user manager at boot, so the session agent can run.
      linger = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("the daemon user and its directories exist"):
        machine.succeed("id immurok")
        machine.succeed("stat -c '%U:%G %a' /var/lib/immurok | grep -x 'immurok:immurok 700'")
        machine.succeed("stat -c '%U:%G %a' /run/immurok | grep -x 'immurok:immurok 755'")

    with subtest("the unit runs as the daemon user"):
        machine.succeed("systemctl show immurok-daemon.service -p User --value | grep -x immurok")

    with subtest("D-Bus reads the package's policy"):
        machine.succeed("grep -qF '<includedir>${immurok}/share/dbus-1/system.d</includedir>' /etc/dbus-1/system.conf")
        machine.succeed("grep -q 'user=\"immurok\"' ${immurok}/share/dbus-1/system.d/immurok.conf")

    with subtest("the daemon can run its Bluetooth helper"):
        # Use the environment the wrapper gave the running daemon.
        machine.succeed(r"""
          pid=$(systemctl show -p MainPID --value immurok-daemon.service)
          eval "$(tr '\0' '\n' < /proc/$pid/environ | grep -E '^(PATH|IMMUROK_HELPER_DIR)=' | sed "s/^/export /; s/=/='/; s/\$/'/")"
          python3 -c 'import dbus_fast'
          test -f "$IMMUROK_HELPER_DIR/ble-notify-helper.py"
        """)

    with subtest("the polkit rule is installed"):
        machine.succeed("grep -q lock-sessions /etc/polkit-1/rules.d/49-immurok.rules")

    with subtest("the session agent starts for a user"):
        machine.wait_for_unit("immurok-session-agent.service", "alice")

    # Without an adapter the daemon may keep restarting. Keep its state in the
    # log, to see what it does.
    machine.log(machine.execute("systemctl status immurok-daemon.service --no-pager")[1])
    machine.log(machine.execute("journalctl -u immurok-daemon.service --no-pager")[1])
  '';
}
