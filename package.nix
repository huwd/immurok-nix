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
    # Asserts that PID 1 isn't owned by the current user. In the build
    # sandbox the builder is PID 1 and is the current user.
    "--skip=tty::tests::pid_1_is_not_mine"
  ];

  # Upstream's tests for the PAM module's C helpers.
  postCheck = ''
    make -C pam test
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
  '';

  preFixup = ''
    wrapProgram $out/bin/immurok-auth-dialog "''${gappsWrapperArgs[@]}"
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
