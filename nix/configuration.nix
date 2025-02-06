{
  self,
  name,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  module-name = "home-automation";
  cfg = config.services.${module-name};
  inherit (pkgs) system;

  inherit (lib.options) mkOption;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.services.home-automation = {
    enable = mkEnableOption module-name;

    tradfri.secretsFile = mkOption {
      type = lib.types.path;
      default = "/var/lib/private/home-automation/tradfri.conf";
      description = ''
        Path to pre-shared-key for the virtual tradfri devices.

        Write with a secrets manager like sops-nix so it does not become part of the nix store.

        Create by starting light_strip manually, follow the prompts to provide the secret key.
        After the first connectiont test again, no more key should be asked for.
        Then the file is created in the current directory.
      '';
    };

    homekit.secretsFile = mkOption {
      type = lib.types.path;
      default = "/var/lib/private/home-automation/tradfri_bridge.state";
      description = ''
        Path to secrets for tradfri_bridge

        Write with a secrets manager like sops-nix so it does not become part of the nix store.

        Create by starting tradfri_bridge manually, follow the instructions to pair it with
        the HomeKit device, and check it works.
        The file should be created after the initial launch.
      '';
    };

  };

  config = mkIf cfg.enable {
    systemd.services.${name} = {
      description = "${name} server";

      path = [ self.packages.${system}.default ];

      # TODO might need to go to a static user to deploy the secrets
      # FIXME how do I provide the state from pre-shared-key and fnordlicht-state
      # likely at /var/lib/private/home-automation/
      serviceConfig = {
        ExecStart = self.apps.${system}.default.program;
        Restart = "on-failure";

        # https://0pointer.net/blog/dynamic-users-with-systemd.html
        DynamicUser = true;
        StateDirectory = name;
        RuntimeDirectory = name;

        BindReadOnlyPaths = [
          "${
            config.environment.etc."ssl/certs/ca-certificates.crt".source
          }:/etc/ssl/certs/ca-certificates.crt"
          builtins.storeDir
          "-/etc/resolv.conf"
          "-/etc/nsswitch.conf"
          "-/etc/hosts"
          "-/etc/localtime"
        ];
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
