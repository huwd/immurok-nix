{
  description = "Nix packaging and NixOS module for the immurok fingerprint key";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        immurok = pkgs.callPackage ./package.nix { };
        default = immurok;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # Tools that run on the build machine.
          nativeBuildInputs = [
            pkgs.cargo
            pkgs.rustc
            pkgs.rustfmt
            pkgs.clippy
            pkgs.pkg-config
            pkgs.glib # glib-compile-resources, used by the GUI's build.rs
            pkgs.nixfmt
            pkgs.nix-update
          ];
          # Libraries the code links against.
          buildInputs = [
            pkgs.dbus
            pkgs.gtk4
            pkgs.libadwaita
            pkgs.pam
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
