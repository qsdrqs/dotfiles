{ config, pkgs, lib, ... }:
let
  hyprlandPackages = with pkgs; [
    # Add waybar package here due to: https://github.com/Alexays/Waybar/issues/3300
    # waybar
    # inputs.waybar.packages.${pkgs.system}.waybar
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    hyprpaper
    hyprpicker
    hyprpolkitagent
    hyprland-qtutils
    grim
    slurp
    jq
    swayidle
    grimblast
    wayvnc
  ];
in
{
  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };

  environment.systemPackages = with pkgs; [
    wtype
    vscode
    xclip
    wl-clipboard
    wdisplays # show connected monitors
    libnotify
    mpv
    graphviz

    zathura
    swaynotificationcenter
    rofi
    swaybg
    networkmanagerapplet
    xdotool
    zenity # color picker

    libcamera
    libcamera-qcam
    v4l-utils

    moonlight-qt
  ] ++ hyprlandPackages ++ (with pkgs.kdePackages; [
    dolphin
    kdeconnect-kde
    filelight  # disk usage
    gwenview
    ark

    xlsclients
    xwayland-satellite
  ]);

  qt.platformTheme = "kde";

  services.mpd = {
    enable = true;
    user = "qsdrqs";
    settings = {
      audio_output = [{
        type="pipewire";
        name="My PipeWire Output";
      }];
    };
  };

  systemd = {
    services = {
      mpd.environment = {
        # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/609
        XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
      };
    };
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
      kdeconnect-cli-autorefresh =
      let
        interval_seconds = 10;
      in
      {
        wantedBy = [ "graphical-session.target" ];
        unitConfig = {
          Description = "KDE Connect CLI Auto Refresh";
          PartOf = [ "graphical-session.target" ];
        };
        path = [
          pkgs.kdePackages.kdeconnect-kde
          pkgs.python3
          pkgs.procps
        ];
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python ${./scripts/kdeconnect-cli-autorefresh.py} ${toString interval_seconds}";
        };
      };
    };
  };

  programs.niri.enable = true;
  programs.ydotool.enable = true;
  programs.waybar.enable = true;

  systemd.user.services.waybar.serviceConfig.ExecStartPre =
    let
      waitForKbd = pkgs.writeShellScript "waybar-wait-kbd" ''
        set -euo pipefail
        stable=0
        for i in $(seq 1 200); do
          if ls /dev/input/by-path/*-event-kbd >/dev/null 2>&1 \
             || grep -q 'Handlers=.*kbd.*leds' /proc/bus/input/devices 2>/dev/null; then
            stable=$((stable+1))
            [ "$stable" -ge 10 ] && exit 0
          else
            stable=0
          fi
          sleep 0.1
        done
        echo "waybar: keyboard device not ready" >&2
        exit 1
      '';
    in
    "${waitForKbd}";

  systemd.user.services.waybar.path = [ pkgs.swaynotificationcenter ];
  systemd.user.services.hypridle.path = [
    pkgs.niri
    pkgs.bash
  ];

  services.gnome.gcr-ssh-agent.enable = false;
  services.gnome.gnome-keyring.enable = false;

  # provide org.freedesktop.secrets
  # services.gnome.gnome-keyring.enable = true;
  # security.pam.services.login.enableGnomeKeyring = true;

  services.desktopManager.plasma6.enable = true;

  # This fixes the unpopulated MIME menus
  environment.etc."/xdg/menus/applications.menu".text = builtins.readFile "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    autoNumlock = true;
    settings = {
      Autologin = {
        Session = "niri.desktop";
        User = "qsdrqs";
      };
    };
  };
  # Workaround for kwin to work with numlock on
  # system.activationScripts.sddm_kde_display.text = ''
  #   cp -f ${homeDir}/.config/kwinoutputconfig.json /var/lib/sddm/.config/
  #   cp -f ${homeDir}/.config/kcminputrc /var/lib/sddm/.config/
  #   chown sddm:sddm /var/lib/sddm/.config/kwinoutputconfig.json /var/lib/sddm/.config/kcminputrc
  # '';

  programs.hyprland = {
    enable = true;
    # package = pkgs-master.hyprland;
    # portalPackage = pkgs-master.xdg-desktop-portal-hyprland;
    # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    # portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };
  programs.hyprlock = {
    enable = true;
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # environment.sessionVariables.HYPR_PLUGIN_DIR =
  #   let
  #     hyprPluginDir = pkgs.symlinkJoin {
  #       name = "hyprland-plugins";
  #       paths = with pkgs.hyprlandPlugins; [
  #         hyprbars
  #         hyprfocus
  #         hyprexpo
  #         hyprscrolling
  #         hyprtrails
  #         hyprwinwrap
  #       ];
  #     };
  #   in
  #     hyprPluginDir;
  xdg.portal = {
    config.hyprland = {
      "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
      default = [ "hyprland" "gtk" ];
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-rime
        fcitx5-gtk
      ];
      waylandFrontend = true;
    };
  };

  programs.nix-ld.libraries = with pkgs; [
    config.hardware.graphics.package
    gmp
    gtk3
    libxcb
  ];
  environment.variables.NIX_LD_LIBRARY_PATH = lib.mkOverride 90 "/run/current-system/sw/share/nix-ld/lib:/run/opengl-driver/lib";

  # hardware.pulseaudio.enable = true;
  # hardware.pulseaudio.extraConfig = "load-module module-combine-sink module-equalizer-sink module-dbus-protocol";

}
