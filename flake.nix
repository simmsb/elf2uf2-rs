{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.devshell.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      perSystem = { system, config, pkgs, ... }:
        let

          native-toolchain = inputs.fenix.packages.${system}.complete.withComponents [
            "cargo"
            "clippy"
            "rust-src"
            "rustc"
            "rustfmt"
          ];

          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain native-toolchain;
          my-crate = craneLib.buildPackage {
            src = craneLib.cleanCargoSource (craneLib.path ./.);

            doCheck = false;

            buildInputs = [
              # Add additional build inputs here
            ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              # Additional darwin specific inputs can be set here
              pkgs.darwin.apple_sdk.frameworks.IOKit
              pkgs.libiconv
            ];

            # Additional environment variables can be set directly
            # MY_CUSTOM_VAR = "some value";
          };
        in

        rec {
          packages.elf2uf2_rs = my-crate;
          apps.elf2uf2_rs.program = "${my-crate}/bin/elf2uf2-rs";

          apps.default = apps.elf2uf2_rs;

          overlayAttrs = {
            inherit (config.packages) elf2uf2_rs;
          };

          devshells.default = {
            packagesFrom = [ my-crate ];

            packages = [
              inputs.fenix.packages.${system}.rust-analyzer
            ];
          };

        };
    };
}
