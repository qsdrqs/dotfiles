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
in
{
  hardware.firmware = with pkgs; [
    linux-firmware
  ];
  hardware.sensor.iio.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0=75;
      STOP_CHARGE_THRESH_BAT0=80;
    };
  };
  services.power-profiles-daemon.enable = false;

  systemd = {
    user.services.libinput-gestures = {
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
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiIntel
      vaapiVdpau
      intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver

  # snapshots
  services.snapper.configs = {
    home = {
      SUBVOLUME = "/home";
      ALLOW_USERS = [ "qsdrqs" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 10;
      TIMELINE_LIMIT_DAILY = 10;
      TIMELINE_LIMIT_WEEKLY = 0;
      TIMELINE_LIMIT_MONTHLY = 0;
      TIMELINE_LIMIT_YEARLY = 0;
    };
  };
  services.btrfs.autoScrub.enable = true;
  services.udev.extraRules = ''
    # HHKB
    ACTION=="add",    ATTRS{idVendor}=="04fe", ATTRS{idProduct}=="0021", RUN+="${pkgs.bash}/bin/bash ${ctrl2esc}"
    ACTION=="remove", ATTRS{idVendor}=="04fe", ATTRS{idProduct}=="0021", RUN+="${pkgs.bash}/bin/bash ${caps2esc}"
  '';
}
