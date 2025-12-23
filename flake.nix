{
  description = "A powerful coding agent toolkit providing semantic retrieval and editing capabilities (MCP server & Agno integration)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        nixpkgs.follows = "nixpkgs";
      };
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      nixpkgs,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;

        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
        overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

        pyprojectOverrides = final: prev: {
          ruamel-yaml-clib = prev.ruamel-yaml-clib.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.setuptools ];
          });

          cryptography = prev.cryptography.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              pkgs.clang
              pkgs.lld
              pkgs.pkg-config
              pkgs.openssl.dev
            ];
            buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.openssl ];
          });
        };

        python = pkgs.python311;
        pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
          lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
            pyprojectOverrides
          ]
        );

        # Fixed marksman wrapper with proper ICU/.NET environment
        marksman-wrapped = pkgs.writeShellScriptBin "marksman" ''
          ORIGINAL_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
          export LD_LIBRARY_PATH=""

          for libdir in ${
            lib.makeLibraryPath [
              pkgs.icu
              pkgs.stdenv.cc.cc.lib
              pkgs.openssl
              pkgs.zlib
              pkgs.curl
              pkgs.libkrb5
              pkgs.libunwind
            ]
          }; do
            export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$libdir"
          done

          export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH#:}"
          export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH%:}"

          export ICU_DATA="${pkgs.icu.out}/share/icu"
          export ICU_LIB="${pkgs.icu.out}/lib"

          export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0
          export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT_MODE=0
          export DOTNET_RUNTIME_ID="linux-x64"
          export DOTNET_MULTILEVEL_LOOKUP=0
          export DOTNET_ROOT="${pkgs.dotnet-sdk_8}"

          unset SSL_CERT_FILE
          unset OPENSSL_DIR
          unset OPENSSL_LIB_DIR
          unset OPENSSL_INCLUDE_DIR
          unset PKG_CONFIG_PATH

          export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

          if [ "$#" -eq 0 ]; then
            echo "Starting marksman language server..." >&2
            exec ${pkgs.marksman}/bin/marksman server
          else
            exec ${pkgs.marksman}/bin/marksman "$@"
          fi
        '';
      in
      rec {
        formatter = pkgs.alejandra;

        packages = {
          serena =
            let
              venv = pythonSet.mkVirtualEnv "serena" workspace.deps.default;
            in
            pkgs.stdenv.mkDerivation {
              pname = "serena";
              version = "0.1.0";

              nativeBuildInputs = [ pkgs.makeWrapper ];

              buildInputs = [
                pkgs.openssl
                pkgs.stdenv.cc.cc.lib
              ];

              phases = [ "installPhase" ];

              installPhase = ''
                mkdir -p $out
                cp -r ${venv}/* $out/
                chmod -R u+w $out/bin

                wrapProgram $out/bin/serena \
                  --run 'export CARGO_HOME="''${CARGO_HOME:-$HOME/.cargo}"' \
                  --run 'export RUSTUP_HOME="''${RUSTUP_HOME:-$HOME/.rustup}"' \
                  --run 'export PATH="$HOME/.cargo/bin:$PATH"' \
                  --prefix PATH : "${
                    lib.makeBinPath [
                      pkgs.rustup
                      marksman-wrapped
                      pkgs.clang
                      pkgs.lld
                      pkgs.gcc
                      pkgs.binutils
                      pkgs.pkg-config
                      pkgs.dotnet-sdk_8
                    ]
                  }" \
                  --prefix LD_LIBRARY_PATH : "${
                    lib.makeLibraryPath [
                      pkgs.openssl
                      pkgs.stdenv.cc.cc.lib
                      pkgs.libclang.lib
                      pkgs.icu
                      pkgs.libunwind
                      pkgs.libkrb5
                      pkgs.curl
                      pkgs.zlib
                    ]
                  }" \
                  --set ICU_DATA "${pkgs.icu.out}/share/icu" \
                  --set ICU_LIB "${pkgs.icu.out}/lib" \
                  --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT "0" \
                  --set DOTNET_ROOT "${pkgs.dotnet-sdk_8}" \
                  --prefix PKG_CONFIG_PATH : "${pkgs.openssl.dev}/lib/pkgconfig" \
                  --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
                  --set OPENSSL_DIR "${pkgs.openssl.dev}" \
                  --set OPENSSL_LIB_DIR "${pkgs.openssl.out}/lib" \
                  --set OPENSSL_INCLUDE_DIR "${pkgs.openssl.dev}/include" \
                  --set OPENSSL_NO_VENDOR "1" \
                  --set CC "${pkgs.clang}/bin/clang"
              '';
            };

          default = packages.serena;
        };

        apps.default = {
          type = "app";
          program = "${packages.default}/bin/serena";
        };

        devShells = {
          default = pkgs.mkShell {
            packages = [
              python
              pkgs.uv
              pkgs.rustup
              marksman-wrapped
              pkgs.icu
              pkgs.dotnet-sdk_8
              pkgs.libunwind
              pkgs.libkrb5
              pkgs.curl
            ];

            nativeBuildInputs = [
              pkgs.openssl
              pkgs.pkg-config
              pkgs.clang
              pkgs.lld
            ];

            env = {
              UV_PYTHON_DOWNLOADS = "never";
              UV_PYTHON = python.interpreter;

              OPENSSL_DIR = "${pkgs.openssl.dev}";
              OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
              OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
              PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";

              ICU_DATA = "${pkgs.icu.out}/share/icu";
              ICU_LIB = "${pkgs.icu.out}/lib";

              # rustup locations (user-writable)
              CARGO_HOME = "$HOME/.cargo";
              RUSTUP_HOME = "$HOME/.rustup";
            }
            // lib.optionalAttrs pkgs.stdenv.isLinux {
              LD_LIBRARY_PATH = lib.makeLibraryPath (
                pkgs.pythonManylinuxPackages.manylinux1
                ++ [
                  pkgs.openssl
                  pkgs.stdenv.cc.cc.lib
                  pkgs.icu
                  pkgs.libunwind
                  pkgs.libkrb5
                  pkgs.curl
                ]
              );
            };

            shellHook = ''
              unset PYTHONPATH
              export PATH="$HOME/.cargo/bin:$PATH"

              # optional: bootstrap toolchain if missing (no-op if already installed)
              if ! rustup toolchain list | grep -q '^stable'; then
                echo "Installing rustup stable toolchain..."
                rustup toolchain install stable
              fi
              rustup component add rust-analyzer >/dev/null 2>&1 || true
            '';
          };
        };
      }
    );
}
