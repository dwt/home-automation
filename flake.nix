{
  description = "Hello world flake using uv2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix_hammer_overrides.url = "github:TyberiusPrime/uv2nix_hammer_overrides";
    uv2nix_hammer_overrides.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    {
      self,
      nixpkgs,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      uv2nix_hammer_overrides,
      ...
    }:
    let
      name = "home-automation";
      inherit (nixpkgs) lib;
      pythonVersion = "python313";

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
      preferBinaryWheelsOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel"; # more stable than "sdist";
      };

      pyprojectBuildSystemOverrides = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        (final: prev: {
          # use dtlssocket from nixpkgs (slightly newer than what we want)
          # dtlssocket = pkgs.python313Packages.dtlssocket;
          # or build from source
          dtlssocket = prev.dtlssocket.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [
              pkgs.autoconf
              pkgs.automake
              pkgs.pkg-config
              (final.resolveBuildSystem {
                cython = [ ];
                setuptools = [ ];
              })
            ];
          });
        })
      );

      pythonSets = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.${pythonVersion};
        in
        # Construct package set
        # Use base package set from pyproject.nix builders
        (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              preferBinaryWheelsOverlay
              (uv2nix_hammer_overrides.overrides pkgs)
              pyprojectBuildSystemOverrides.${system}
            ]
          )
      );
    in
    {
      # Enable `nix build`
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          util = (pkgs.callPackages pyproject-nix.build.util { });
          venv = pythonSets.${system}.mkVirtualEnv "${name}-env" workspace.deps.default;
        in
        {
          default =
            # mkApplicationhides all the details of the virtualenv and exposes only the application scripts
            (util.mkApplication {
              venv = venv;
              package = pythonSets.${system}.${name};
            })
            # Wrapping the main program, so it sets up PATH correctly to enable
            # calling the other programs from the package
            .overrideAttrs
              (old: {
                nativeBuildInputs = old.nativeBuildInputs ++ [
                  pkgs.makeWrapper
                ];
                buildCommand =
                  old.buildCommand
                  + ''
                    echo "Wrapping tradfri_bridge to hardcode correct path"
                    wrapProgram "$out/bin/tradfri_bridge" --prefix PATH : "$out/bin"
                  '';
              });
        }
      );

      # Enable `nix run`
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/tradfri_bridge";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.${pythonVersion};
        in
        {
          default = import ./nix/shell.nix {
            inherit pkgs python lib;
          };
        }
      );

      nixosModules = {
        home-automation = import ./nix/configuration.nix {
          inherit self name;
        };
      };

    };
}
