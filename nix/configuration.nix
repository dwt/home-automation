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

    pre-shared-key = mkOption {
      type = lib.types.string;
      description = ''
        Pre-shared-key for the tradfri bridge
      '';
    };

    fnordlicht-state = mkOption {
      type = lib.types.string;
      description = ''
        Secrets for fnordlicht
      '';
    };

    venv = mkOption {
      type = lib.types.package;
      default = self.packages.${system}.default;
      description = ''
        venv package
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.${name} = {
      description = "${name} server";

      # TODO might need to go to a static user to deploy the secrets
      # FIXME how do I provide the state from pre-shared-key and fnordlicht-state
      serviceConfig = {
        ExecStart = self.apps.${system}.default.program;
        Restart = "on-failure";

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
