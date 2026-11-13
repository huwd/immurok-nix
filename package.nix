{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  dbus,
  pam,
  python3,
  gobject-introspection,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
  pango,
  libnotify,
}:

let
  # The auth dialog is a PyGObject script.
  pythonEnv = python3.withPackages (ps: [ ps.pygobject3 ]);
  # The daemon runs `python3 ble-notify-helper.py` for all of its Bluetooth
  # I/O, and the helper imports dbus_fast.
  bleHelperEnv = python3.withPackages (ps: [ ps.dbus-fast ]);
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "immurok";
  version = "0.9.4";

  src = fetchFromGitHub {
    owner = "immurok";
    repo = "app-linux-rs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DyPXYTilZvw3XYPZTerdHP2q3uWNXGm2MAXv5BkotNg=";
  };

  cargoHash = "sha256-iohheKYsPlw+LuZVz+900Adbr22RM4/Yqtn6K2d3oSA=";

  # The settings app (immurok-gui) is packaged separately, so Cargo doesn't
  # build the GTK crates. The session agent's dialog still uses GTK through
  # Python, below.
  cargoBuildFlags = [
    "--workspace"
    "--exclude"
    "immurok-gui"
  ];

  # `cargo test` doesn't use cargoBuildFlags, so repeat the exclusion.
  cargoTestFlags = finalAttrs.cargoBuildFlags;

  checkFlags = [
    # These two assume PID 1 isn't owned by the current user. In the build
    # sandbox the builder is PID 1 and is the current user.
    "--skip=tty::tests::pid_1_is_not_mine"
    # It also assumes PID 1 has no terminal. The builder's output is a
    # terminal, and the sandbox has its own /dev/pts. The path the builder
    # reports can name a pseudo-terminal that another test has opened, so
    # whether the test passes depends on how those numbers line up.
    "--skip=tty::tests::renderer_ignores_pids_that_are_not_ours"
    # Races on how the terminal delivers output: it stops reading once the
    # text appears, then asserts that a newline written separately has
    # arrived. It failed in 12 of 300 runs under CPU load, and 1 of 300 on an
    # idle machine.
    "--skip=tty::tests::spinner_draws_animates_and_leaves_a_final_line"
  ];

  # Upstream's tests for the PAM module's C helpers and the Bluetooth helper.
  postCheck = ''
    make -C pam test
    ${bleHelperEnv.interpreter} scripts/test-ble-notify-helper.py
  '';

  nativeBuildInputs = [
    pkg-config
    gobject-introspection # typelib setup hook, for the dialog
    wrapGAppsHook4
  ];

  buildInputs = [
    dbus # libdbus-sys, used by the BlueZ client
    pam # libpam, linked by the PAM module
    gtk4 # typelibs for the dialog
    libadwaita
    pango
  ];

  # Wrap only the dialog; the Rust binaries don't need the GApps variables.
  dontWrapGApps = true;

  # The PAM module is plain C and has its own Makefile.
  postBuild = ''
    make -C pam
  '';

  postInstall = ''
    install -Dm755 pam/pam_immurok.so $out/lib/security/pam_immurok.so
    install -Dm644 packaging/dbus/immurok.conf $out/share/dbus-1/system.d/immurok.conf
    install -Dm644 packaging/polkit/49-immurok.rules $out/share/polkit-1/rules.d/49-immurok.rules

    # The session agent looks for the dialog next to its own binary.
    install -Dm755 scripts/immurok-auth-dialog $out/bin/immurok-auth-dialog
    substituteInPlace $out/bin/immurok-auth-dialog \
      --replace-fail "#!/usr/bin/python3" "#!${pythonEnv.interpreter}"

    # The daemon finds its Bluetooth helper through IMMUROK_HELPER_DIR.
    install -Dm755 scripts/ble-notify-helper.py $out/libexec/immurok/ble-notify-helper.py
  '';

  preFixup = ''
    wrapProgram $out/bin/immurok-auth-dialog "''${gappsWrapperArgs[@]}"
    wrapProgram $out/bin/immurok-daemon \
      --set IMMUROK_HELPER_DIR $out/libexec/immurok \
      --prefix PATH : ${lib.makeBinPath [ bleHelperEnv ]}
    # notify-send shows the agent's desktop notifications.
    wrapProgram $out/bin/immurok-session-agent \
      --prefix PATH : ${lib.makeBinPath [ libnotify ]}
  '';

  meta = {
    description = "Linux client for the immurok Bluetooth fingerprint key";
    homepage = "https://github.com/immurok/app-linux-rs";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "immurok-cli";
  };
})
