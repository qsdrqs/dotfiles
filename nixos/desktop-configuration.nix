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
  vscode-wrapper = pkgs.writeShellScriptBin "code-wrapper" ''
    CODE_EXEC=${(pkgs.vscode.override (old: {
      commandLineArgs = (old.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" ];
    }))}/bin/code;
    CONFIG=${config.users.users.qsdrqs.home}/.config/Code/User/settings.json;
    sed -i 's/"window.titleBarStyle": "custom"/"window.titleBarStyle": "native"/g' $CONFIG;
    exec -a "$0" "$CODE_EXEC" "$@" &
    sleep 3
    sed -i 's/"window.titleBarStyle": "native"/"window.titleBarStyle": "custom"/g' $CONFIG;
  '';
in
{
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

  environment.systemPackages = with pkgs; [
    keepassxc
    rathole
    telegram-desktop
    slack
    snapper-gui
    ida64-fhs
    (google-chrome.override (prev: {
      commandLineArgs = (prev.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" ];
    }))
    zoom-us
    kate
    scrcpy
    wineWowPackages.unstableFull
    wpsoffice-hidpi
    vscode-wrapper

    virt-manager
    qemu_full

    obs-studio
    steam-run

    texlive.combined.scheme-full

    android-file-transfer
    android-udev-rules
    android-tools

    pandoc

    # NUR
    config.nur.repos.xddxdd.qq
    # wine wechat
    # (config.nur.repos.xddxdd.wine-wechat.override {
    #   setupSrc = fetchurl {
    #     url = "https://dldir1.qq.com/weixin/Windows/WeChatSetup_x86.exe";
    #     sha256 = "sha256-dXmpS/zzqJ7zPEaxbCK/XLJU9gktXVI/1eoy1AZSa/4=";
    #   };
    #   version = "3.9.5";
    # })
    config.nur.repos.xddxdd.qqmusic
    config.nur.repos.xddxdd.wechat-uos-bin
    config.nur.repos.linyinfeng.wemeet
  ];

  services.teamviewer.enable = true;

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

  systemd = {
    services.mpd.environment = {
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/609
      XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
    };
    services.rathole = {
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
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  virtualisation.libvirtd.enable = true;

  users.users.qsdrqs.extraGroups = [ "wireshark" "libvirtd" ];

  services.xserver = {
    videoDrivers = [ "nvidia" ];
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        gpick
        arandr
        flameshot
        variety
        feh
        picom
      ];
    };
    desktopManager.plasma5.enable = true;
  };

  hardware = {
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      nvidiaSettings = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };
  };

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
