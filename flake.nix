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
      # Enable `nix run`
      apps = python-package.apps;

      # Enable `nix build`
      packages = python-package.packages;

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

      nixosModules.default =
        { ... }:
        {
          imports = [ ./nix/configuration.nix ];
          # give module access to self
          # TODO what could be a better way to give the module access to the flake?
          # I don't want to define it inline (that way self would be in scope)
          # I also don't want a function with two arguments, where the outer arg is handed in on import
          # And I definitely don't want to make self and name part of the modules interface with config._module.args
          # as that would make these names available to all nixosModules
          config.services.${name}.self = self;
        };

    };
}
