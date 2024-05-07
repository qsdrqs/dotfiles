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
  wechat-uos-hidpi = pkgs.symlinkJoin {
    name = "qq";
    paths = [ config.nur.repos.xddxdd.wechat-uos ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wechat-uos \
        --set QT_FONT_DPI 144
      sed -i "s|Exec=.*|Exec=$out/bin/wechat-uos|" $out/share/applications/wechat-uos.desktop
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

  # For wechat-uos
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];

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
    wineWowPackages.unstableFull
    wpsoffice-hidpi
    libreoffice
    gnome.seahorse # keyring manager

    # (vscode-wrapper "${vscode-insiders}/bin/code-insiders" "code-wrapper-insiders")
    # (vscode-wrapper "${vscode}/bin/code" "code-wrapper")

    virt-manager
    linux-wifi-hotspot
    hotspot
    neovide
    termshark

    obs-studio
    openconnect_openssl

    texlive.combined.scheme-full

    android-file-transfer
    android-udev-rules
    android-tools

    pandoc
    zotero_7
    xournalpp
    thunderbird
    betterbird
    birdtray

    # NUR
    qq-hidpi
    qqmusic-hidpi
    config.nur.repos.linyinfeng.wemeet
    wechat-uos-hidpi
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
    docker.enable = true;
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
  };
  services.desktopManager.plasma6.enable = true;

  nixpkgs.config.nvidia.acceptLicense = true;
  hardware = {
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      nvidiaSettings = true;
      open = false;
      package = (config.boot.kernelPackages.nvidiaPackages.production.overrideAttrs (oldAttrs: rec {
        version = "535.154.05";
        pkgSuffix = oldAttrs.pkgSuffix or "";
        src = builtins.fetchurl {
          url = "https://download.nvidia.com/XFree86/Linux-x86_64/${version}/NVIDIA-Linux-x86_64-${version}${pkgSuffix}.run";
          sha256 = "sha256-fpUGXKprgt6SYRDxSCemGXLrEsIA6GOinp+0eGbqqJg=";
        };
      }));
    };
  };
  # https://wiki.hyprland.org/Nvidia/#fixing-random-flickering-nuclear-method
  environment.etc."modprobe.d/nvidia.conf".text = ''
    options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"
  '';

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
