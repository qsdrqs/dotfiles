{ config, pkgs, pkgs-howdy,  pkgs-master, lib, inputs, ... }:
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
in
{
  # begin howdy
  disabledModules = [ "security/pam.nix" ];
  imports = [
    "${inputs.nixpkgs-howdy}/nixos/modules/security/pam.nix"
    "${inputs.nixpkgs-howdy}/nixos/modules/services/security/howdy"
    "${inputs.nixpkgs-howdy}/nixos/modules/services/misc/linux-enable-ir-emitter.nix"
  ];
  nixpkgs.overlays = [
    (self: super: {
      linux-enable-ir-emitter = pkgs-howdy.linux-enable-ir-emitter;
      howdy = pkgs-howdy.howdy.overrideAttrs (old:
      let
        # use pkgs.python3 to allow nixpkgs configs
        pyEnv = pkgs-howdy.python3.withPackages (p: [
          p.dlib
          p.elevate
          p.face-recognition.override
          p.keyboard
          (p.opencv4.override { enableGtk3 = true; })
          p.pycairo
          p.pygobject3
        ]);
      in
      {
        patches = old.patches ++ [
          ./patches/howdy.patch
        ];
        mesonFlags = old.mesonFlags ++ [
          "-Dpython_path=${pyEnv.interpreter}"
          "-Dextra_path=${pkgs-howdy.kbd}/bin/"
        ];
      });
    })
  ];
  services.howdy = {
    enable = true;
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
      ${pkgs-howdy.coreutils}/bin/sleep 0.5
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
      efiSysMountPoint = "/boot";
    };
  };
  boot.loader.grub.extraInstallCommands = ''
    set -euo pipefail
    export PATH=${pkgs.sbctl}/bin:$PATH

    if [ -f /boot/EFI/Boot/bootx64.efi ]; then
      sbctl sign /boot/EFI/Boot/bootx64.efi || true
    fi

    if [ -f /boot/EFI/NixOS-boot/grubx64.efi ]; then
      sbctl sign /boot/EFI/NixOS-boot/grubx64.efi
    fi

    for f in /boot/grub/**/*.efi; do
      [ -e "$f" ] && sbctl sign "$f"
    done

    if [ -d /boot/kernels ]; then
      for f in /boot/kernels/*-bzImage; do
        [ -e "$f" ] && sbctl sign "$f"
      done
    fi
  '';

  nixpkgs.config.permittedInsecurePackages = [
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
    wechat
    # flameshot
    (flameshot.override {
      enableWlrSupport = true;
    })

    samba
    freerdp

    # secure boot and UEFI tools
    sbsigntool
    efibootmgr
    sbctl
    element-desktop

    kdePackages.kclock
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

  services.dbus.packages = [ pkgs.kdePackages.kclock ];

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
  };
  services.btrfs.autoScrub.enable = true;

  services.desktopManager.plasma6.enable = true;

  # turn on bluetooth on startup
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="bluetooth", RUN+="${pkgs.util-linux}/bin/rfkill unblock bluetooth"
  '';

}
