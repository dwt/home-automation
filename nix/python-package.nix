{
  name,
  pythonVersion,
  forAllSystems,
  inputs,
  ...
}:
let
  lib = inputs.nixpkgs.lib;
in
rec {
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ../.; };
  preferBinaryWheelsOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel"; # more stable than "sdist";
  };

  pyprojectBuildSystemOverrides = forAllSystems (
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
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
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      python = pkgs.${pythonVersion};
    in
    # Construct package set
    # Use base package set from pyproject.nix builders
    (pkgs.callPackage inputs.pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.default
          preferBinaryWheelsOverlay
          (inputs.uv2nix_hammer_overrides.overrides pkgs)
          pyprojectBuildSystemOverrides.${system}
        ]
      )
  );

  packages = forAllSystems (
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      util = (pkgs.callPackages inputs.pyproject-nix.build.util { });
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
                echo "Wrapping tradfri_bridge to allow it to call other binaries from the package"
                wrapProgram "$out/bin/tradfri_bridge" --prefix PATH : "$out/bin"
              '';
          });
    }
  );

  apps = forAllSystems (system: {
    default = {
      type = "app";
      program = "${packages.${system}.default}/bin/tradfri_bridge";
    };
  });
}
