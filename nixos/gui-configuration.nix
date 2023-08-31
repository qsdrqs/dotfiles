{ config, pkgs, lib, inputs, ... }:
let
  ida64-fhs = pkgs.buildFHSUserEnv {
    name = "ida64";
    runScript = "${config.users.users.qsdrqs.home}/ida/ida64";
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
in
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
    telegram-desktop
    libnotify
    slack
    baobab # disk usage
    snapper-gui
    ida64-fhs
    mpv
    google-chrome
    zoom-us
    libsForQt5.gwenview
    zathura
    poppler_utils
    ark
    gpick
    kate
    dolphin
    arandr

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
    config.nur.repos.linyinfeng.wemeet
  ];

  qt.platformTheme = "kde";

  # provide org.freedesktop.secrets
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

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
    videoDrivers = [ "nvidia" ];
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        flameshot
        variety
        feh
        rofi
        picom
        networkmanagerapplet
      ];
    };
    displayManager.sddm = {
      enable = true;
      autoNumlock = true;
    };
  };

  i18n.inputMethod.enabled = "fcitx5";
  i18n.inputMethod.fcitx5.addons = with pkgs; [ fcitx5-rime fcitx5-gtk ];

  systemd.services.frpc = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Start the frp client";
    serviceConfig = {
      User = "root";
      ExecStart = ''${pkgs.frp}/bin/frpc -c /etc/frp/frpc.ini'';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  users.extraUsers.qsdrqs.extraGroups = [ "audio" ];
  hardware.pulseaudio.extraConfig = "load-module module-combine-sink module-equalizer-sink module-dbus-protocol";
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
