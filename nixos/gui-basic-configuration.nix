{ config, pkgs, pkgs-master, lib, inputs, ... }:
let
  wpsoffice-cn-hidpi = pkgs.symlinkJoin {
    name = "wps-office-cn";
    paths = [ pkgs.wpsoffice-cn ];
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
  boot.kernelModules = [
    # "v4l2loopback"
  ];
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

  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.05"
    "electron-11.5.0" # baidunetdisk
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
    wpsoffice-cn-hidpi
    kdePackages.kate
    wineWowPackages.unstableFull
    ventoy-full

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
    drawio

    # NUR
    qq-hidpi
    wemeet
    wechat-uos-hidpi
    # flameshot
    (flameshot.override {
      enableWlrSupport = true;
    })
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
    libvirtd = {
      enable = true;
      qemu.vhostUserPackages = [ pkgs.virtiofsd ];
    };
    docker.enable = true;
  };

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

  services.desktopManager.plasma6.enable = true;
}
