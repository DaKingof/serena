{
  description = "A powerful coding agent toolkit providing semantic retrieval and editing capabilities (MCP server & Agno integration)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

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

        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = ./.;
        };

        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        pyprojectOverrides = final: prev: {
          ruamel-yaml-clib = prev.ruamel-yaml-clib.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              final.setuptools
            ];
          });

          cryptography = prev.cryptography.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              pkgs.clang
              pkgs.lld
              pkgs.pkg-config
              pkgs.openssl.dev
            ];
            buildInputs = (old.buildInputs or [ ]) ++ [
              pkgs.openssl
            ];
          });
        };

        python = pkgs.python311;

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          }).overrideScope
            (
              lib.composeManyExtensions [
                pyproject-build-systems.overlays.default
                overlay
                pyprojectOverrides
              ]
            );

        # Marksman wrapper:
        # 1. Unset LD_LIBRARY_PATH and OpenSSL-related vars so .NET uses its own runtime libs.
        # 2. Do NOT set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT (Marksman needs ICU).
        # 3. Default to 'server' when called with no args (LSP mode).
        marksman-wrapped = pkgs.writeShellScriptBin "marksman" ''
          unset LD_LIBRARY_PATH
          unset SSL_CERT_FILE
          unset OPENSSL_DIR
          unset OPENSSL_LIB_DIR
          unset OPENSSL_INCLUDE_DIR
          unset PKG_CONFIG_PATH

          if [ "$#" -eq 0 ]; then
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

              nativeBuildInputs = [
                pkgs.makeWrapper
              ];

              buildInputs = [
                pkgs.openssl
                pkgs.stdenv.cc.cc.lib
              ];

              phases = [ "installPhase" ];

              installPhase = ''
                mkdir -p $out
                cp -r ${venv}/* $out/
                chmod -R u+w $out/bin

                # Wrap Serena so the right tools & libraries are available,
                # and our 'marksman' wrapper is the one on PATH.
                wrapProgram $out/bin/serena \
                  --prefix PATH : "${
                    lib.makeBinPath [
                      marksman-wrapped
                      pkgs.rust-analyzer
                      pkgs.rustc
                      pkgs.cargo
                      pkgs.clang
                      pkgs.lld
                      pkgs.gcc
                      pkgs.binutils
                      pkgs.pkg-config
                    ]
                  }" \
                  --prefix LD_LIBRARY_PATH : "${
                    lib.makeLibraryPath [
                      pkgs.openssl
                      pkgs.stdenv.cc.cc.lib
                      pkgs.libclang.lib
                    ]
                  }" \
                  --prefix PKG_CONFIG_PATH : "${pkgs.openssl.dev}/lib/pkgconfig" \
                  --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
                  --set OPENSSL_DIR "${pkgs.openssl.dev}" \
                  --set OPENSSL_LIB_DIR "${pkgs.openssl.out}/lib" \
                  --set OPENSSL_INCLUDE_DIR "${pkgs.openssl.dev}/include" \
                  --set OPENSSL_NO_VENDOR "1" \
                  --set RUST_SRC_PATH "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}" \
                  --set CC "${pkgs.clang}/bin/clang" \
                  --set CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER "${pkgs.clang}/bin/clang" \
                  --set RUSTFLAGS "-C link-arg=-fuse-ld=lld -L ${pkgs.openssl.out}/lib"
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
              pkgs.rust-analyzer
              marksman-wrapped
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
            }
            // lib.optionalAttrs pkgs.stdenv.isLinux {
              LD_LIBRARY_PATH = lib.makeLibraryPath (
                pkgs.pythonManylinuxPackages.manylinux1
                ++ [
                  pkgs.openssl
                  pkgs.stdenv.cc.cc.lib
                ]
              );
            };

            shellHook = ''
              unset PYTHONPATH
            '';
          };
        };
      }
    );
}
