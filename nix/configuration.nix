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
  cfg = config.services.${name};
  inherit (pkgs) system;

  inherit (lib.options) mkOption;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.services.home-automation = {
    enable = mkEnableOption name;

    home = mkOption {
      type = lib.types.path;
      default = "/var/lib/${name}";
      description = ''
        Path to the home directory of the service.
      '';
    };

    tradfri.secretsFile = mkOption {
      type = lib.types.path;
      default = "${cfg.home}/tradfri.conf";
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
      default = "/${cfg.home}/tradfri_bridge.state";
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
    users.users.${name} = {
      isSystemUser = true;
      createHome = true;
      home = "${cfg.home}";
    };

    systemd.services.${name} = {
      description = "${name} server";

      path = [ self.packages.${system}.default ];

      serviceConfig = {
        ExecStart = self.apps.${system}.default.program;
        Restart = "on-failure";

        User = "${name}";
        WorkingDirectory = cfg.home;
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
