{ config, pkgs, pkgs-stable, lib, inputs, options, ... }:
let
  homeDir = config.users.users.qsdrqs.home;
in
{
  imports = [
    (if builtins.pathExists ./private/server-private.nix then
      ./private/server-private.nix
    else
      lib.warn "No private files found"
        ./empty.nix
    )
  ];

  environment.systemPackages = with pkgs; [
    matrix-synapse-unwrapped
  ];

  systemd = {
    services.frps = {
      enable = lib.mkDefault false;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Start the frp server";
      serviceConfig = {
        ExecStart = ''${pkgs.frp}/bin/frps -c /etc/frp/frps.toml'';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # certbot renew
    services.certbot-renew = {
      enable = lib.mkDefault false;
      description = "Certbot Renewal";
      serviceConfig = {
        ExecStart = "${pkgs.certbot}/bin/certbot renew";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    timers.certbot-renew = {
      enable = config.systemd.services.certbot-renew.enable;
      description = "Daily renewal of Let's Encrypt's certificates by certbot";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    user = {
      services = {
        keepass-backup = {
          description = "backup keepass database";
          serviceConfig = {
            KillSignal = "SIGINT";
            ExecStart = "${pkgs.bash}/bin/sh ${./private/keepass_backup.sh} ${homeDir}";
          };
          path = [ pkgs.gawk ];
        };
      };
      timers = {
        keepass-backup = {
          description = "Hourly backup keepass database";
          timerConfig = {
            OnCalendar = "hourly";
            Persistent = true;
          };
          wantedBy = [ "default.target" ];
        };
      };
    };
  };

  services.nginx = {
    enable = false;
    httpConfig = "include /etc/nginx/nginx.conf;";
  };

  services.matrix-synapse = {
    enable = lib.mkDefault false;
    configFile = "/etc/synapse/homeserver.yaml";
    dataDir = "/var/lib/synapse";
    settings = {
      media_store_path = "/var/lib/synapse/media_store";
      signing_key_path = "/etc/synapse/qsdrqs.site.signing.key";
    };
  };

  systemd.services.matrix-synapse = {
    enable = config.services.matrix-synapse.enable;
    serviceConfig = {
      ExecStart = lib.mkForce ''
        ${pkgs.matrix-synapse}/bin/synapse_homeserver \
        --config-path /etc/synapse/homeserver.yaml
      '';
    };
  };

  services.coturn = {
    enable = lib.mkDefault false;
  };

  systemd.services.coturn =
    let
      runConfig = "/run/coturn/turnserver.cfg";
    in
    {
      enable = config.services.coturn.enable;
      preStart = lib.mkForce ''
        cat /etc/turnserver/turnserver.conf > ${runConfig}
        chmod 640 ${runConfig}
      '';
    };
}
