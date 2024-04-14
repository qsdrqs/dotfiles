{ config, pkgs, lib, pkgs-master, pkgs-fix, inputs, options, ... }:
let
  hyprlandPackages = with pkgs; [
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
    hyprpaper
    hyprpicker
    grim
    slurp
    jq
    swayidle
    inputs.hyprland-contrib.packages.${pkgs.system}.grimblast
  ];
  firefox-alias = pkgs.writeShellScriptBin "firefox" ''
    ${pkgs.firefox-devedition}/bin/firefox-devedition "$@"
  '';
in
{
  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };

  environment.systemPackages = with pkgs; [
    vscode
    firefox-devedition
    firefox-alias
    kitty
    xclip
    wl-clipboard
    pavucontrol
    libnotify
    baobab # disk usage
    mpv
    libsForQt5.gwenview
    graphviz

    zathura
    ark
    deadd-notification-center
    pulseaudio
    rofi-wayland
    networkmanagerapplet
    xdotool
  ] ++ hyprlandPackages;

  qt.platformTheme = "kde";

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    # jack.enable = true;
    # wireplumber.package = pkgs-fix.wireplumber;
  };

  systemd = {
    user.services = {
      deadd-notification-center = {
        wantedBy = [ "graphical-session.target" ];
        unitConfig = {
          Description = "Deadd Notification Center";
          PartOf = [ "graphical-session.target" ];
        };
        serviceConfig = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = "${pkgs.deadd-notification-center}/bin/deadd-notification-center";
        };
      };
      plasma-dolphin = {
        unitConfig = {
          Description = "Dolphin file manager";
          PartOf = [ "graphical-session.target" ];
        };
        path = [ "/run/current-system/sw" ];
        environment = {
          QT_QPA_PLATFORM = "wayland";
        };
        serviceConfig = {
          Type = "dbus";
          BusName = "org.freedesktop.FileManager1";
          ExecStart = "${pkgs.dolphin}/bin/dolphin";
        };
      };
    };
  };

  programs.dconf.enable = true;

  # provide org.freedesktop.secrets
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "Hack" ]; })
  ];

  services.xserver = {
    enable = true;
    displayManager.sddm = {
      enable = true;
      autoNumlock = true;
    };
  };

  programs.hyprland = {
    enable = true;
  };
  programs.waybar = {
    enable = true;
  };
  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  i18n.inputMethod.enabled = "fcitx5";
  i18n.inputMethod.fcitx5.addons = with pkgs; [ fcitx5-rime fcitx5-gtk ];

  # Enable sound.
  sound.enable = true;
  # hardware.pulseaudio.enable = true;
  users.extraUsers.qsdrqs.extraGroups = [ "audio" ];
  # hardware.pulseaudio.extraConfig = "load-module module-combine-sink module-equalizer-sink module-dbus-protocol";
  hardware.bluetooth.enable = true;

}
