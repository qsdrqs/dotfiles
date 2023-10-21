{ config, pkgs, lib, inputs, options, ... }:
let
  homeDir = config.users.users.qsdrqs.home;
in
{
  services.syncthing.guiAddress = "0.0.0.0:8384";

  systemd = {
    services.rathole-server = {
      enable = false;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Start the rathole server";
      serviceConfig = {
        ExecStart = ''${pkgs.rathole}/bin/rathole /etc/rathole/server.toml'';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    user.services = {
      keepass-backup = {
        description = "backup keepass database";
        serviceConfig = {
          KillSignal = "SIGINT";
          ExecStart = "${pkgs.bash}/bin/sh ${homeDir}/keepass_backup.sh ${homeDir}";
        };
      };
    };
  };
  systemd.user.timers = {
    keepass-backup = {
      description = "Hourly backup keepass database";
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
      wantedBy = [ "default.target" ];
    };
  };
}
