{ config, pkgs, lib, pkgs-master, inputs, ... }:
let
  ida64-fhs = pkgs.buildFHSUserEnv {
    name = "ida64";
    runScript = "env QT_FONT_DPI=144 ${config.users.users.qsdrqs.home}/ida/ida64";
    targetPkgs = pkgs: with pkgs; [
      libglvnd
      zlib
      libGL
      fontconfig
      freetype
      libxkbcommon
      dbus
      fuse
      glib
      gtk3
      libnotify
      libxml2
      libxslt
      openssl.dev
      pkg-config
      strace
      udev
      vulkan-loader
      xorg.libX11
      xorg.xcbutilwm
      xorg.xcbutilimage
      xorg.xcbutilrenderutil
      xorg.libSM
      xorg.libICE
      xorg.libxcb
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXScrnSaver
      xorg.libxshmfence
      xorg.libXtst
      xorg.xcbutilkeysyms
    ];
  };
  wpsoffice-hidpi = pkgs.symlinkJoin {
    name = "wps-office";
    paths = [ pkgs.wpsoffice ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $(ls $out/bin); do
        wrapProgram $out/bin/$bin \
          --set QT_FONT_DPI 144
      done
    '';
  };
  hyprlandPackages = with pkgs; [
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
    hyprpaper
    hyprpicker
    grim
    slurp
    jq
    inputs.hyprland-contrib.packages.${pkgs.system}.grimblast
  ];
in
{
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };

  environment.systemPackages = with pkgs; [
    (pkgs-master.vscode.override (prev: {
      commandLineArgs = (prev.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" ];
    }))
    vscodium
    firefox-devedition
    kitty
    keepassxc
    xclip
    wl-clipboard
    frp
    rathole
    duf
    pavucontrol
    telegram-desktop
    libnotify
    slack
    baobab # disk usage
    snapper-gui
    ida64-fhs
    mpv
    (google-chrome.override (prev: {
      commandLineArgs = (prev.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" ];
    }))
    zoom-us
    libsForQt5.gwenview
    zathura
    poppler_utils
    ark
    gpick
    kate
    dolphin
    arandr
    scrcpy
    dunst
    wineWowPackages.unstableFull
    qemu_full
    virt-manager
    obs-studio
    pulseaudio
    wpsoffice-hidpi
    steam-run
    w3m
    inferno

    android-file-transfer
    android-udev-rules
    android-tools

    # NUR
    config.nur.repos.xddxdd.qq
    # wine wechat
    (config.nur.repos.xddxdd.wine-wechat.override {
      setupSrc = fetchurl {
        url = "https://dldir1.qq.com/weixin/Windows/WeChatSetup_x86.exe";
        sha256 = "sha256-dXmpS/zzqJ7zPEaxbCK/XLJU9gktXVI/1eoy1AZSa/4=";
      };
      version = "3.9.5";
    })
    config.nur.repos.xddxdd.qqmusic
    config.nur.repos.xddxdd.wechat-uos-bin
    config.nur.repos.linyinfeng.wemeet
  ] ++ hyprlandPackages;

  qt.platformTheme = "kde";
  services.teamviewer.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    jack.enable = true;
  };

  services.mpd = {
    enable = true;
    user = "qsdrqs";
    extraConfig = ''
      audio_output {
        type "pipewire"
        name "My PipeWire Output"
      }
    '';
  };
  systemd.services.mpd.environment = {
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/609
    XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;
  users.users.qsdrqs.extraGroups = [ "wireshark" "libvirtd" ];

  # provide org.freedesktop.secrets
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "Hack" ]; })
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
    videoDrivers = [ "nvidia" ];
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        flameshot
        variety
        feh
        rofi-wayland
        picom
        networkmanagerapplet
      ];
    };
    displayManager.sddm = {
      enable = true;
      autoNumlock = true;
    };
    desktopManager.plasma5.enable = true;
  };

  programs.hyprland = {
    enable = true;
    enableNvidiaPatches = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
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
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      nvidiaSettings = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  i18n.inputMethod.enabled = "fcitx5";
  i18n.inputMethod.fcitx5.addons = with pkgs; [ fcitx5-rime fcitx5-gtk ];

  systemd.services.rathole = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Start the rathole client";
    serviceConfig = {
      User = "root";
      ExecStart = ''${pkgs.rathole}/bin/rathole /etc/rathole/client.toml'';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Enable sound.
  sound.enable = true;
  # hardware.pulseaudio.enable = true;
  users.extraUsers.qsdrqs.extraGroups = [ "audio" ];
  # hardware.pulseaudio.extraConfig = "load-module module-combine-sink module-equalizer-sink module-dbus-protocol";
  hardware.bluetooth.enable = true;

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
}
