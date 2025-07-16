{ config, pkgs, pkgs-howdy, lib, inputs, ... }:
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
  disabledModules = [ "security/pam.nix" ];
  imports = [
    "${inputs.nixpkgs-howdy}/nixos/modules/security/pam.nix"
    "${inputs.nixpkgs-howdy}/nixos/modules/services/security/howdy"
    "${inputs.nixpkgs-howdy}/nixos/modules/services/misc/linux-enable-ir-emitter.nix"
  ];
  nixpkgs.overlays = [
    (self: super: {
      linux-enable-ir-emitter = pkgs-howdy.linux-enable-ir-emitter;
      howdy = pkgs-howdy.howdy.overrideAttrs (old:
      let
        pyEnv = pkgs-howdy.python3.withPackages (p: [
          p.dlib
          p.elevate
          p.face-recognition.override
          p.keyboard
          (p.opencv4.override { enableGtk3 = true; })
          p.pycairo
          p.pygobject3
        ]);
        wrappedPy = super.writeShellScriptBin "python-howdy-wrapper" ''
          export OMP_NUM_THREADS=1
          exec ${pyEnv.interpreter} "$@"
        '';
      in
      {
        mesonFlags = old.mesonFlags ++ [
          "-Dpython_path=${wrappedPy}/bin/python-howdy-wrapper"
        ];
      });
    })
  ];
  services.howdy = {
    enable = true;
    settings = {
      # you may not need these
      core.no_confirmation = true;
      video.dark_threshold = 90;
    };
  };
  services.linux-enable-ir-emitter = {
    enable = true;
  };

  hardware.firmware = with pkgs; [
    linux-firmware
  ];
  hardware.sensor.iio.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
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

  services.udev.extraRules = ''
    # HHKB
    ACTION=="add",    ATTRS{idVendor}=="04fe", ATTRS{idProduct}=="0021", RUN+="${pkgs.bash}/bin/bash ${ctrl2esc}"
    ACTION=="remove", ATTRS{idVendor}=="04fe", ATTRS{idProduct}=="0021", RUN+="${pkgs.bash}/bin/bash ${caps2esc}"
  '';
}
