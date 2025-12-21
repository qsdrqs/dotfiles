{ config, pkgs, lib, inputs, ... }:
let
  caps2esc = pkgs.writeScript "start-caps2esc.sh" ''
    ${pkgs.systemd}/bin/systemctl stop interception-tools-ctrl2esc.service
    ${pkgs.systemd}/bin/systemctl start interception-tools-caps2esc.service
  '';
  ctrl2esc = pkgs.writeScript "start-ctrl2esc.sh" ''
    ${pkgs.systemd}/bin/systemctl stop interception-tools-caps2esc.service
    ${pkgs.systemd}/bin/systemctl start interception-tools-ctrl2esc.service
  '';
  hyprMonitorPower = pkgs.writeShellScriptBin "hypr-monitor-power" ''
    exec ${pkgs.python3}/bin/python3 ${./scripts/hypr-monitor-power.py}
  '';
  niriMonitorPower = pkgs.writeShellScriptBin "niri-monitor-power" ''
    exec ${pkgs.python3}/bin/python3 ${./scripts/niri-monitor-power.py}
  '';
in
{
  environment.systemPackages = with pkgs; [
    wluma
    powertop
  ];

  hardware.firmware = with pkgs; [
    linux-firmware
  ];
  hardware.sensor.iio.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "power"; # more aggressive

      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      # CPU_MAX_PERF_ON_BAT = 60;
      CPU_MAX_PERF_ON_BAT = 45; # more aggressive

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "quiet";

      PCIE_ASPM_ON_AC = "default";
      # PCIE_ASPM_ON_BAT = "powersave";
      PCIE_ASPM_ON_BAT = "powersupersave"; # more aggressive

      DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth"; # disable bluetooth when not connected

      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };
  services.power-profiles-daemon.enable = false;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "ignore";
  };

  systemd.sleep.extraConfig = ''
    [Sleep]
    HibernateDelaySec=3h
  '';

  systemd = {
    user.services = {
      libinput-gestures = {
        enable = true;
        path = [ pkgs.hyprland ];
        description = "libinput-gestures service";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.libinput-gestures}/bin/libinput-gestures";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      hypr-monitor-power = {
        enable = true;
        description = "Toggle Hypr powersave include based on AC/battery state";
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        path = [ pkgs.hyprland ];
        serviceConfig = {
          ExecStart = "${hyprMonitorPower}/bin/hypr-monitor-power";
          Restart = "always";
          RestartSec = 5;
        };
      };

      niri-monitor-power = {
        enable = true;
        description = "Toggle niri monitor powersave config based on AC/battery state";
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        path = [ pkgs.niri ];
        serviceConfig = {
          ExecStart = "${niriMonitorPower}/bin/niri-monitor-power";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      libva-vdpau-driver
      intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver
  boot.kernelModules = [ "intel_rapl_common" ];

  # battery monitoring
  services.prometheus = {
    enable = true;
    globalConfig.scrape_interval = "30s";
    exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [ "systemd" ];
    };

    scrapeConfigs = [
      {
        job_name = "laptop-node";
        static_configs = [
          {
            targets = [
              "localhost:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
      {
        job_name = "scaphandre";
        fallback_scrape_protocol = "PrometheusText0.0.4";
        static_configs = [
          {
            targets = [ "127.0.0.1:8081" ];
          }
        ];
      }
    ];
  };
  services.prometheus.exporters.scaphandre = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 8081;
    telemetryPath = "metrics";
    user = "root";
    group = "root";

    extraFlags = [ "--containers" ];
  };
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        domain = "localhost";
      };
    };
  };

  services.udev.extraRules = ''
    # HHKB
    KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", ATTRS{name}=="*HHKB*", ACTION=="add", RUN+="${pkgs.bash}/bin/bash ${ctrl2esc}"
    KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", ATTRS{name}=="*HHKB*", ACTION=="remove", RUN+="${pkgs.bash}/bin/bash ${caps2esc}"
  '';
}
