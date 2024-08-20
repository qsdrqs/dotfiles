{ config, pkgs, lib, pkgs-master, pkgs-fix, inputs, options, ... }:
let
  hyprlandPackages = with pkgs; [
    # waybar
    inputs.waybar.packages.${pkgs.system}.waybar
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
  homeDir = config.users.users.qsdrqs.home;
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

  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    autoNumlock = true;
    # wayland = {
    #   enable = true;
    #   compositor = "kwin";
    # };
  };
  # Workaround for kwin to work with numlock on
  # system.activationScripts.sddm_kde_display.text = ''
  #   cp -f ${homeDir}/.config/kwinoutputconfig.json /var/lib/sddm/.config/
  #   cp -f ${homeDir}/.config/kcminputrc /var/lib/sddm/.config/
  #   chown sddm:sddm /var/lib/sddm/.config/kwinoutputconfig.json /var/lib/sddm/.config/kcminputrc
  # '';

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [ fcitx5-rime fcitx5-gtk ];
      waylandFrontend = true;
    };
  };

  # hardware.pulseaudio.enable = true;
  users.extraUsers.qsdrqs.extraGroups = [ "audio" ];
  # hardware.pulseaudio.extraConfig = "load-module module-combine-sink module-equalizer-sink module-dbus-protocol";
  hardware.bluetooth.enable = true;

}
