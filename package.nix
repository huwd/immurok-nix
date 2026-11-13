{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  dbus,
  pam,
}:

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

  # The settings app (immurok-gui) is packaged separately, so the daemon,
  # CLI and session agent don't pull in GTK.
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

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    dbus # libdbus-sys, used by the BlueZ client
    pam # libpam, linked by the PAM module
  ];

  # The PAM module is plain C and has its own Makefile.
  postBuild = ''
    make -C pam
  '';

  postInstall = ''
    install -Dm755 pam/pam_immurok.so $out/lib/security/pam_immurok.so
    install -Dm644 packaging/dbus/immurok.conf $out/share/dbus-1/system.d/immurok.conf
    install -Dm644 packaging/polkit/49-immurok.rules $out/share/polkit-1/rules.d/49-immurok.rules
  '';

  meta = {
    description = "Linux client for the immurok Bluetooth fingerprint key";
    homepage = "https://github.com/immurok/app-linux-rs";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "immurok-cli";
  };
})
