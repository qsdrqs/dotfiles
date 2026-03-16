{ config, pkgs, pkgs-howdy, pkgs-unstable,  pkgs-master, lib, inputs, ... }:
let
  treeSitterGrub = pkgs.stdenv.mkDerivation {
    name = "tree-sitter-grub";
    src = inputs.tree-sitter-grub;
    nativeBuildInputs = [ pkgs.tree-sitter ];
    buildPhase = ''
      HOME=$TMPDIR
      tree-sitter build -o grub.so .
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp grub.so $out/lib/
    '';
  };
  grubPatchPythonEnv = pkgs.python3.withPackages (ps: [ ps.tree-sitter ]);
  installGrubPatch = pkgs.writeShellScript "install-grub-patch" ''
    export PATH="${pkgs.grub2}/bin:$PATH"
    exec ${grubPatchPythonEnv}/bin/python3 ${./scripts/patch_grub_cfg}/install_grub_patch.py \
      --grammar-lib "${treeSitterGrub}/lib/grub.so" "$@"
  '';
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
    enable = true;
    control = "sufficient"; # was told to be insecure
    settings = {
      core.no_confirmation = true;
      video.dark_threshold = 90;
      rubberstamps.enabled = false;
      rubberstamps.stamp_rules = "hotkey 5s failsafe";
    };
  };
  services.linux-enable-ir-emitter = {
    enable = true;
  };

  # Enable polkit-1 integration for howdy
  security.pam.services.polkit-1.howdy.enable = false;

  systemd.services.linux-enable-ir-emitter.preStart =
  let
    video-device = "/dev/${config.services.linux-enable-ir-emitter.device}";
    wait-script = ./scripts/wait-for-ir-emitter-devices.sh;
  in
  ''
    ${wait-script} ${video-device}
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

    # patch grub.cfg to use custom grubenv location (AST-based)
    ${installGrubPatch} --efi-mount ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint} --grub-dir /boot/grub
  '';

  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.10"
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
    wineWow64Packages.unstableFull

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
    ventoy
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
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    gamescopeSession.enable = true;
  };
  programs.gamescope.enable = true;

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
