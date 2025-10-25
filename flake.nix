{
  description = "A powerful coding agent toolkit providing semantic retrieval and editing capabilities (MCP server & Agno integration)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
<<<<<<< HEAD
<<<<<<< HEAD
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
=======

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

>>>>>>> d94ed33 (Update flake.nix)
=======
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
>>>>>>> 6cbb423 (Refactor 'serena' package and update devShells)
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
<<<<<<< HEAD
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

<<<<<<< HEAD
        # Fixed marksman wrapper with proper ICU/.NET environment
        marksman-wrapped = pkgs.writeShellScriptBin "marksman" ''
          # Store original LD_LIBRARY_PATH for ICU libraries
          ORIGINAL_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"

          # Clear Python-specific paths but keep system libraries
          export LD_LIBRARY_PATH=""

          # Add essential system libraries for .NET
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
=======
=======
>>>>>>> 6cbb423 (Refactor 'serena' package and update devShells)
  outputs = {
    nixpkgs,
    uv2nix,
    pyproject-nix,
    pyproject-build-systems,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      inherit (pkgs) lib;
<<<<<<< HEAD
>>>>>>> d94ed33 (Update flake.nix)

          # Clean up LD_LIBRARY_PATH (remove leading/trailing colons)
          export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH#:}"
          export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH%:}"

<<<<<<< HEAD
          # Set ICU specific environment variables
          export ICU_DATA="${pkgs.icu.out}/share/icu"
          export ICU_LIB="${pkgs.icu.out}/lib"

          # Set .NET globalization settings
          export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0
          export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT_MODE=0

          # Set .NET runtime behavior
          export DOTNET_RUNTIME_ID="linux-x64"
          export DOTNET_MULTILEVEL_LOOKUP=0
          export DOTNET_ROOT="${pkgs.dotnet-sdk_8}"
=======
=======
      workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};
>>>>>>> 6cbb423 (Refactor 'serena' package and update devShells)
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel"; # or sourcePreference = "sdist";
      };
      pyprojectOverrides = final: prev: {
        # Add setuptools for packages that need it during build
        ruamel-yaml-clib = prev.ruamel-yaml-clib.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
            final.setuptools
          ];
        });
        
        # Add build dependencies for packages that need native compilation
        cryptography = prev.cryptography.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
            pkgs.clang
            pkgs.lld
            pkgs.pkg-config
            pkgs.openssl.dev
          ];
          buildInputs = (old.buildInputs or []) ++ [
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
    in rec {
      formatter = pkgs.alejandra;
<<<<<<< HEAD
>>>>>>> d94ed33 (Update flake.nix)

<<<<<<< HEAD
          # Clear Python-specific SSL settings to avoid conflicts
          unset SSL_CERT_FILE
          unset OPENSSL_DIR
          unset OPENSSL_LIB_DIR
          unset OPENSSL_INCLUDE_DIR
          unset PKG_CONFIG_PATH
=======
      packages = {
        serena-env = pythonSet.mkVirtualEnv "serena-env" workspace.deps.default;
        serena = pkgs.runCommand "serena" {} ''
          mkdir -p $out/bin
          ln -s ${packages.serena-env}/bin/serena $out/bin/serena
        '';
        default = packages.serena;
      };
>>>>>>> upstream/main

          # Set standard SSL cert path
          export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

<<<<<<< HEAD
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

                wrapProgram $out/bin/serena \
                  --prefix PATH : "${
                    lib.makeBinPath [
                      pkgs.rust-analyzer
                      pkgs.rustc
                      pkgs.cargo
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
                  --set RUST_SRC_PATH "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}" \
                  --set CC "${pkgs.clang}/bin/clang" \
                  --set CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER "${pkgs.clang}/bin/clang" \
                  --set RUSTFLAGS "-C link-arg=-fuse-ld=lld -L ${pkgs.openssl.out}/lib"
              '';
            };
          default = packages.serena;
=======
=======
      packages = {
        serena = let
          venv = pythonSet.mkVirtualEnv "serena" workspace.deps.default;
        in 
          # Wrap the virtualenv to include runtime dependencies
          pkgs.stdenv.mkDerivation {
            pname = "serena";
            version = "0.1.0";
            
            nativeBuildInputs = [
              pkgs.makeWrapper
            ];
            
            buildInputs = [
              pkgs.openssl
              pkgs.stdenv.cc.cc.lib  # For libstdc++
            ];
            
            phases = ["installPhase"];
            
            installPhase = ''
              # Create output directory
              mkdir -p $out
              
              # Copy all files from the venv
              cp -r ${venv}/* $out/
              
              # Make the bin directory writable so we can wrap the program
              chmod -R u+w $out/bin
              
              # Wrap the binary with necessary runtime dependencies
              wrapProgram $out/bin/serena \
                --prefix PATH : "${lib.makeBinPath [
                  pkgs.rust-analyzer
                  pkgs.rustc
                  pkgs.cargo
                  pkgs.clang
                  pkgs.lld
                  pkgs.gcc
                  pkgs.binutils
                  pkgs.pkg-config
                ]}" \
                --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
                  pkgs.openssl
                  pkgs.stdenv.cc.cc.lib
                  pkgs.libclang.lib
                ]}" \
                --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
                --set OPENSSL_DIR "${pkgs.openssl.dev}" \
                --set RUST_SRC_PATH "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}" \
                --set CC "${pkgs.clang}/bin/clang" \
                --set CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER "${pkgs.clang}/bin/clang" \
                --set RUSTFLAGS "-C link-arg=-fuse-ld=lld"
            '';
          };
        default = packages.serena;
      };
      apps.default = {
        type = "app";
        program = "${packages.default}/bin/serena";
      };
>>>>>>> 6cbb423 (Refactor 'serena' package and update devShells)
      devShells = {
        default = pkgs.mkShell {
          packages = [
            python
            pkgs.uv
            pkgs.rustup
            pkgs.rust-analyzer
          ];
          nativeBuildInputs = [
            pkgs.openssl
            pkgs.pkg-config
            pkgs.clang
            pkgs.lld
          ];
          env =
            {
              UV_PYTHON_DOWNLOADS = "never";
              UV_PYTHON = python.interpreter;
              OPENSSL_DIR = "${pkgs.openssl.dev}";
              PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
            }
            // lib.optionalAttrs pkgs.stdenv.isLinux {
              LD_LIBRARY_PATH = lib.makeLibraryPath (
                pkgs.pythonManylinuxPackages.manylinux1 ++ [
                  pkgs.openssl
                  pkgs.stdenv.cc.cc.lib
                ]
              );
            };
          shellHook = ''
            unset PYTHONPATH
          '';
>>>>>>> d94ed33 (Update flake.nix)
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
            '';
          };
        };
      }
    );
}