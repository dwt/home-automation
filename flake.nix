{
  description = "Häckers Home Automation using uv2nix";

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

    uv2nix_hammer_overrides = {
      url = "github:TyberiusPrime/uv2nix_hammer_overrides";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
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
      python-package = import nix/python-package.nix {
        inherit
          name
          pythonVersion
          forAllSystems
          inputs
          ;
      };
    in
    {
      # Enable `nix build`
      packages = python-package.packages;

      # Enable `nix run`
      apps = python-package.apps;

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

      nixosModules.default = import ./nix/configuration.nix {
        inherit self name;
      };

    };
}
