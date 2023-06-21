{ config, pkgs, lib, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
    vscode
    firefox-devedition
    kitty
    keepassxc
    xclip
    frp
    duf
    pavucontrol
  ];

  # provide org.freedesktop.secrets
  services.gnome.gnome-keyring.enable = true;

  fonts.fonts = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" ]; })
  ];

  services.interception-tools = {
    enable = true;
    plugins = [ pkgs.interception-tools-plugins.caps2esc ];
    udevmonConfig = ''
      - JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE | ${pkgs.interception-tools-plugins.caps2esc}/bin/caps2esc | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
        DEVICE:
          EVENTS:
            EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
    '';
  };

  services.xserver = {
    enable = true;
    videoDrivers = ["nvidia"];
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        flameshot
        variety
        feh
        rofi
        picom
      ];
    };
    displayManager.sddm = {
      enable = true;
      autoNumlock = true;
    };
  };

  nixpkgs.overlays = [
    (self: super: {
      variety = super.variety.overrideAttrs (oldAttrs: {
        prePatch = oldAttrs.prePatch + ''
          substituteInPlace data/scripts/set_wallpaper --replace "\"i3\"" "\"none+i3\""
        '';
      });
    })
  ];

  i18n.inputMethod.enabled = "fcitx5";
  i18n.inputMethod.fcitx5.addons = with pkgs; [ fcitx5-rime fcitx5-gtk ];

  systemd.services.frpc = {
    wantedBy = [ "multi-user.target" ]; 
    after = [ "network.target" ];
    description = "Start the frp client";
    serviceConfig = {
      User = "root";
      ExecStart = ''${pkgs.frp}/bin/frpc -c /etc/frp/frpc.ini'';
    };
  };

  hardware.pulseaudio.enable = true;
  users.extraUsers.qsdrqs.extraGroups = [ "audio" ];
  hardware.pulseaudio.extraConfig = "load-module module-combine-sink module-equalizer-sink module-dbus-protocol";
  hardware.bluetooth.enable = true;
}
