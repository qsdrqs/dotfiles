{ config, pkgs, lib, inputs, ... }:
let
  wpsoffice-hidpi = pkgs.symlinkJoin {
    name = "wps-office";
    paths = [ pkgs.wpsoffice ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $(ls $out/bin); do
        wrapProgram $out/bin/$bin \
          --set QT_FONT_DPI 144
      done
      for desktop in $(ls $out/share/applications); do
        sed -i "s|Exec=.*/bin/\(.*\)|Exec=$out/bin/\1|" $out/share/applications/$desktop
      done
    '';
  };
  qq-hidpi = pkgs.symlinkJoin {
    name = "qq";
    paths = [ pkgs.qq ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      sed -i "s|Exec=.*/bin/qq \(.*\)|Exec=$out/bin/qq --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime \1|" $out/share/applications/qq.desktop
    '';
  };
  wechat-uos-hidpi = pkgs.symlinkJoin {
    name = "wechat";
    paths = [
      pkgs.wechat-uos # need to build glibc
    ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wechat-uos \
        --set QT_FONT_DPI 144
      # sed -i "s|Exec=.*|Exec=$out/bin/wechat-uos|" $out/share/applications/wechat-uos.desktop
      sed -i "s|Exec=.*|Exec=$out/bin/wechat-uos|" $out/share/applications/com.tencent.wechat.desktop
    '';
  };
in
{
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

  hardware.firmware = with pkgs; [
    linux-firmware
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w" # For wechat-uos
    "electron-11.5.0" # For baidunetdisk
  ];

  environment.systemPackages = with pkgs; [
    telegram-desktop
    slack
    snapper-gui
    (google-chrome.override (prev: {
      commandLineArgs = (prev.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" ];
    }))
    zoom-us
    scrcpy
    wpsoffice-hidpi

    virt-manager
    linux-wifi-hotspot
    hotspot
    # neovide
    termshark

    texlive.combined.scheme-full

    pandoc
    zotero
    xournalpp
    apktool
    realvnc-vnc-viewer

    # NUR
    qq-hidpi
    wemeet
    wechat-uos-hidpi
    flameshot
  ];

  programs.nix-ld.libraries = with pkgs; [
    gmp
  ];

  # services.teamviewer.enable = true;

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-vaapi # optional AMD hardware acceleration
      obs-gstreamer
      obs-vkcapture
    ];
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

  services.tlp = {
    enable = true;
  };
  services.power-profiles-daemon.enable = false;

  systemd = {
    user.services.libinput-gestures = {
      enable = true;
      path = [ pkgs.hyprland ];
      description = "libinput-gestures service";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.libinput-gestures}/bin/libinput-gestures";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    services.mpd.environment = {
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/609
      XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
    };
  };

  services.zerotierone = {
    enable = true;
    joinNetworks = lib.strings.splitString "\n" (builtins.readFile ./private/zerotier-network-id);
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu.vhostUserPackages = [ pkgs.virtiofsd ];
    };
    docker.enable = true;
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver

  users.users.qsdrqs.extraGroups = [
    "wireshark"
    "libvirtd"
    "docker"
  ];

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
