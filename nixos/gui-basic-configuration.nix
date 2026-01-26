{ config, pkgs, pkgs-howdy, pkgs-unstable,  pkgs-master, lib, inputs, ... }:
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
  wechat-hidpi = pkgs.symlinkJoin {
    name = "wechat";
    paths = [
      pkgs.wechat # need to build glibc
    ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wechat \
        --set QT_FONT_DPI 144
      sed -i "s|Exec=.*|Exec=$out/bin/wechat|" $out/share/applications/wechat.desktop
      # sed -i "s|Exec=.*|Exec=$out/bin/wechat|" $out/share/applications/com.tencent.wechat.desktop
    '';
  };
  google-chromium = pkgs.symlinkJoin {
    name = "google-chromium";
    paths = [ pkgs.chromium ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/chromium \
      --run 'export GOOGLE_DEFAULT_CLIENT_ID=$(cat ${./private/google-default-client-id})' \
      --run 'export GOOGLE_DEFAULT_CLIENT_SECRET=$(cat ${./private/google-default-client-secret})'
      '';
  };
in
{
  # begin howdy
  services.howdy = {
    enable = false;
    settings = {
      # you may not need these
      core.no_confirmation = true;
      video.dark_threshold = 90;
      rubberstamps.enabled = false;
      rubberstamps.stamp_rules = "hotkey 5s failsafe";
    };
  };
  services.linux-enable-ir-emitter = {
    enable = true;
  };

  systemd.services.linux-enable-ir-emitter.preStart =
  let
    video-device = "/dev/${config.services.linux-enable-ir-emitter.device}";
  in
  ''
    until [ -e ${video-device} ]; do
      ${pkgs.coreutils}/bin/sleep 0.5
    done
  '';
  # end howdy

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
      extraGrubInstallArgs = [
        "--disable-shim-lock"
        # "--pubkey=${./gpg-signing.pub}"
        "--modules=tpm gcry_sha512 gcry_rsa"
      ];
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
  };
  boot.loader.grub.extraInstallCommands = ''
    set -euo pipefail

    # sign EFI binaries for Secure Boot
    export PATH=${lib.makeBinPath [ pkgs.sbctl pkgs.util-linux pkgs.gawk pkgs.coreutils ]}:$PATH

    if [ -f /boot/efi/EFI/NixOS-boot-efi/grubx64.efi ]; then
      sbctl sign /boot/efi/EFI/NixOS-boot-efi/grubx64.efi
    fi

    for f in /boot/grub/**/*.efi; do
      [ -e "$f" ] && sbctl sign "$f"
    done

    if [ -d /boot/kernels ]; then
      for f in /boot/kernels/*-bzImage; do
        [ -e "$f" ] && sbctl sign "$f"
      done
    fi

    # patch grub.cfg to use custom grubenv location
    if [ ! -f ${config.boot.loader.efi.efiSysMountPoint}/grubenv ]; then
      cp /boot/grub/grubenv ${config.boot.loader.efi.efiSysMountPoint}/grubenv
    fi
    ${./scripts/patch-grubcfg.sh} /boot/grub/grub.cfg ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint}
  '';

  nixpkgs.config.permittedInsecurePackages = [
    "electron-11.5.0" # baidunetdisk
  ];

  environment.systemPackages = with pkgs; [
    telegram-desktop
    slack
    snapper-gui
    google-chromium
    zoom-us
    scrcpy
    wpsoffice-cn-hidpi
    kdePackages.kate
    neovide
    wineWowPackages.unstableFull

    virt-manager
    linux-wifi-hotspot
    hotspot
    # neovide
    termshark

    pandoc
    zotero
    xournalpp
    apktool
    realvnc-vnc-viewer
    kdePackages.krdc
    drawio

    # NUR
    qq-hidpi
    wemeet
    wechat-hidpi
    # flameshot
    (flameshot.override {
      enableWlrSupport = true;
    })

    samba
    (freerdp.override {
      openh264 = null;
    })

    # secure boot and UEFI tools
    sbsigntool
    efibootmgr
    sbctl
    element-desktop

    kdePackages.kclock

    intel-gpu-tools
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

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  programs.steam = {
    enable = true;
  };
  programs.java.enable = true;

  services.dbus.packages = [ pkgs.kdePackages.kclock ];

  users.users.qsdrqs.extraGroups = [
    "wireshark"
    "libvirtd"
    "docker"
  ];

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      hplip
    ];
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
    boot = {
      SUBVOLUME = "/boot";
      ALLOW_USERS = [ "root" ];
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

  # turn on bluetooth on startup
  systemd.services.rfkill-unblock-bluetooth = {
    description = "Unblock Bluetooth rfkill";
    after = [ "systemd-rfkill.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };

}
