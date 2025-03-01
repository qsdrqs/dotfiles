{ config, pkgs, lib, pkgs-master, pkgs-stable, pkgs-last, inputs, options, ... }:
let
  hyprlandPackages = with pkgs; [
    waybar
    # inputs.waybar.packages.${pkgs.system}.waybar
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    hyprpaper
    hyprpicker
    hyprland-qtutils
    grim
    slurp
    jq
    swayidle
    inputs.hyprland-contrib.packages.${pkgs.system}.grimblast
    wayvnc
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
    pkgs.firefox-devedition
    firefox-alias
    kitty
    xclip
    wl-clipboard
    pavucontrol
    libnotify
    filelight # disk usage
    mpv
    kdePackages.gwenview
    graphviz

    zathura
    ark
    swaynotificationcenter
    pulseaudio
    alsa-utils
    rofi-wayland
    networkmanagerapplet
    xdotool
    zenity # color picker

    libsecret
    keepassxc
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
    jack.enable = true;
    # wireplumber.package = pkgs-stable.wireplumber;
  };

  systemd = {
    user.targets = {
      hyprland-session = {
        description = "Hyprland session";
        wants = [ "graphical-session-pre.target" ];
        after = [ "graphical-session-pre.target" ];
        bindsTo = [ "graphical-session.target" ];
      };
    };
    user.services = {
      sway-notification-center = {
        wantedBy = [ "graphical-session.target" ];
        unitConfig = {
          Description = "Sway Notification Center";
          PartOf = [ "graphical-session.target" ];
        };
        serviceConfig = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
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
          ExecStart = "${pkgs.kdePackages.dolphin}/bin/dolphin";
        };
      };
      kdeconnectd = {
        wantedBy = [ "graphical-session.target" ];
        unitConfig = {
          Description = "KDE Connect Daemon";
          PartOf = [ "graphical-session.target" ];
        };
        path = [ pkgs.kdePackages.kdeconnect-kde ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnectd";
        };
      };
    };
  };

  programs = {
    dconf.enable = true;
    kdeconnect.enable = true;
  };

  # provide org.freedesktop.secrets
  # services.gnome.gnome-keyring.enable = true;
  # security.pam.services.login.enableGnomeKeyring = true;

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.fira-code
    wqy_zenhei
  ];

  # This fixes the unpopulated MIME menus
  environment.etc."/xdg/menus/applications.menu".text = builtins.readFile "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    autoNumlock = true;
  };
  # Workaround for kwin to work with numlock on
  # system.activationScripts.sddm_kde_display.text = ''
  #   cp -f ${homeDir}/.config/kwinoutputconfig.json /var/lib/sddm/.config/
  #   cp -f ${homeDir}/.config/kcminputrc /var/lib/sddm/.config/
  #   chown sddm:sddm /var/lib/sddm/.config/kwinoutputconfig.json /var/lib/sddm/.config/kcminputrc
  # '';

  programs.hyprland = {
    enable = true;
    # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    # portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  xdg.portal = {
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-hyprland
    ];
    config.hyprland = {
      "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
    };
  };

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
