{ config, pkgs, lib, pkgs-fix, inputs, ... }:
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
  qq-hidpi = pkgs.symlinkJoin {
    name = "qq";
    paths = [ config.nur.repos.xddxdd.qq ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/qq \
        --set GDK_DPI_SCALE 1.5
      sed -i "s|Exec=.*|Exec=$out/bin/qq|" $out/share/applications/qq.desktop
    '';
  };
  qqmusic-hidpi = pkgs.symlinkJoin {
    name = "qqmusic";
    paths = [ config.nur.repos.xddxdd.qqmusic ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/qqmusic \
        --set GDK_DPI_SCALE 1.5 \
        --add-flags --no-sandbox
      sed -i "s|Exec=.*|Exec=$out/bin/qqmusic %U|" $out/share/applications/qqmusic.desktop
    '';
  };
  vscode-wrapper = (exec: cmd: pkgs.writeShellScriptBin cmd ''
    CODE_EXEC=${exec};
    CONFIG=${config.users.users.qsdrqs.home}/.config/Code/User/settings.json;
    sed -i 's/"window.titleBarStyle": "custom"/"window.titleBarStyle": "native"/g' $CONFIG;
    exec -a "$0" "$CODE_EXEC" "$@" &
    sleep 3
    sed -i 's/"window.titleBarStyle": "native"/"window.titleBarStyle": "custom"/g' $CONFIG;
  '');
  wineWowUnstable = pkgs-fix.wineWowPackages.unstableFull.overrideAttrs (oldAttrs: {
    patches =
      (oldAttrs.patches or [ ]) ++ [
        ./patches/wine.patch
      ];
  });
in
{
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

  boot.loader = {
    grub = {
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
      gfxmodeEfi = "1024x768";
      default = "saved";
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # enable qemu emulation compile
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment.systemPackages = with pkgs; [
    keepassxc
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
    wineWowUnstable
    wpsoffice-hidpi
    libreoffice
    (vscode-wrapper "${vscode-insiders}/bin/code-insiders" "code-wrapper-insiders")
    # (vscode-wrapper "${vscode}/bin/code" "code-wrapper")

    virt-manager
    linux-wifi-hotspot
    hotspot
    neovide

    obs-studio
    steam-run
    openconnect_openssl

    texlive.combined.scheme-full

    android-file-transfer
    android-udev-rules
    android-tools

    pandoc
    zotero_7
    ffmpeg

    # NUR
    qq-hidpi
    # wine wechat
    # (config.nur.repos.xddxdd.wine-wechat.override {
    #   setupSrc = fetchurl {
    #     url = "https://dldir1.qq.com/weixin/Windows/WeChatSetup_x86.exe";
    #     sha256 = "sha256-dXmpS/zzqJ7zPEaxbCK/XLJU9gktXVI/1eoy1AZSa/4=";
    #   };
    #   version = "3.9.5";
    # })
    qqmusic-hidpi
    # config.nur.repos.xddxdd.wechat-uos-bin
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
  };

  services.zerotierone = {
    enable = true;
    joinNetworks = lib.strings.splitString "\n" (
      builtins.readFile ./private/zerotier-network-id
    );
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  virtualisation = {
    libvirtd.enable = true;
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };

  users.users.qsdrqs.extraGroups = [ "wireshark" "libvirtd" "docker" ];

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
      powerManagement.enable = false;
      nvidiaSettings = true;
      open = false;
      # package = config.boot.kernelPackages.nvidiaPackages.production;
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
  services.btrfs.autoScrub.enable = true;
}
