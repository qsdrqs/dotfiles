{ pkgs, lib, ... }:
let
  # Chrome's sandbox (both SUID and namespace) fails inside Steam's bwrap
  # because of the restricted environment (NoNewPrivs, empty CapBnd).
  # Steam itself uses --no-sandbox for its own CEF (steamwebhelper).
  # This wrapper detects Steam's bwrap by checking for /init (the FHS
  # container-init) and adds --no-sandbox only in that case.
  chromium-no-sandbox-in-bwrap-bin = pkgs.writeShellScriptBin "chromium-no-sandbox-in-bwrap" ''
    exec chromium --password-store=basic --no-sandbox "$@"
  '';
  chromium-no-sandbox-in-bwrap = pkgs.symlinkJoin {
    name = "chromium-no-sandbox-in-bwrap";
    paths = [
      chromium-no-sandbox-in-bwrap-bin
      (pkgs.makeDesktopItem {
        name = "chromium-no-sandbox-in-bwrap";
        desktopName = "Chromium (No Sandbox)";
        exec = "chromium-no-sandbox-in-bwrap %U";
        icon = "chromium";
        categories = [ "Network" "WebBrowser" ];
      })
    ];
  };
in
{
  imports = [ ./grub-efi-configuration.nix ];
  # Jovian binary cache
  nix.settings = {
    substituters = [ "https://jovian-nixos.cachix.org" ];
    trusted-public-keys = [ "jovian-nixos.cachix.org-1:mAWLjAxLNlfxAnozUjOqGj4AxQwCl7HwCkEIF0OmIVI=" ];
  };

  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "qsdrqs";
    desktopSession = "plasma";
  };

  # Use Jovian's kernel
  boot.kernelPackages = pkgs.linuxPackages_jovian;

  environment.systemPackages = with pkgs; [
    protonup-qt
    chromium-no-sandbox-in-bwrap
  ];

  # Ensure CEF debugging is enabled for Decky Loader
  systemd.user.tmpfiles.rules = [
    "f /home/qsdrqs/.steam/steam/.cef-enable-remote-debugging 0644 qsdrqs users -"
  ];

  # decky-sunshine hardcodes "cp /usr/bin/bwrap"; provide the expected path
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/bwrap - - - - ${pkgs.bubblewrap}/bin/bwrap"
  ];

  # Plasma 6 as desktop mode (via "Switch to Desktop" in Steam)
  services.desktopManager.plasma6.enable = true;

  # Extra Proton compatibility
  programs.steam.extraCompatPackages = with pkgs; [ proton-ge-bin ];

  # Decky Loader
  jovian.decky-loader = {
    enable = true;
    user = "qsdrqs";
    extraPackages = [ pkgs.flatpak pkgs.drm_info pkgs.bubblewrap pkgs.bash ];
    package = pkgs.decky-loader.overridePythonAttrs (old: {
      patches = (old.patches or []) ++ [
        ./patches/decky-loader-env.patch
      ];
    });
  };

  # Decky plugins need extra shared libs (HueSync: libhidapi, SimpleDeckyTDP: libpci)
  # Use `ldd /path/to/plugin.so` to find missing shared libs and add them here
  systemd.services.decky-loader.environment.LD_LIBRARY_PATH = lib.makeLibraryPath [
    pkgs.hidapi
    pkgs.pciutils
  ];

  # Handheld Daemon (HHD) for controller support
  # Patch: use Chrome DevTools WebSocket instead of steam binary for power
  # button actions. The steam binary (32-bit ELF) cannot execute on NixOS
  # outside the bwrap sandbox, so steam://shortpowerpress never works.
  services.handheld-daemon = {
    enable = true;
    user = "qsdrqs";
    package = pkgs.handheld-daemon.overridePythonAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./patches/hhd-devtools-powerbutton.patch
      ];
    });
  };

  # ASUS hardware daemon
  services.asusd.enable = true;

  # udev rules for input device access (HHD needs rw on hidraw + evdev)
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod 0666 /sys/class/backlight/%k/brightness"
  '';

  # hide GRUB menu on handheld (shared GRUB config in grub-efi-configuration.nix)
  boot.loader.timeout = 0;

  # Silent GRUB: skip gfxterm/background/font so GRUB stays on black screen
  # and boots immediately (like SteamOS). Menu still works when holding Shift.
  boot.loader.grub.splashImage = null;
  boot.loader.grub.font = null;
  boot.loader.grub.gfxmodeEfi = lib.mkForce "auto";
  boot.loader.grub.extraConfig = ''
    set timeout_style=hidden
  '';

  # Clean boot: plymouth splash hides systemd [OK] messages
  boot.plymouth.enable = true;

  # Silent boot: redirect kernel console to hidden VT, Plymouth uses DRM directly
  # quiet + loglevel=0: suppress very early kernel messages (ACPI errors = level 3)
  # that appear before console=tty2 takes effect
  # mkAfter so loglevel=0 comes after Jovian's loglevel=4 (last one wins)
  boot.kernelParams = lib.mkAfter [
    "quiet"
    "console=tty2"                       # kernel messages to invisible tty
    "vt.global_cursor_default=0"         # hide blinking cursor
    "plymouth.ignore-serial-consoles"    # Plymouth uses DRM, ignores console=tty2
    "loglevel=0"
  ];

  hardware.graphics.enable = true;

  services.btrfs.autoScrub.enable = true;
  networking.networkmanager.wifi.powersave = false;

  services.flatpak.enable = true;
}
