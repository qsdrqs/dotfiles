{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  dummy = pkgs.callPackage (import ./packages.nix).dummy { };
  termux_root = "/data/data/com.termux/files";
in
{
  nixpkgs.overlays = [
    (
      self: super:
      (lib.listToAttrs (
        map
          (pkg_: {
            name = pkg_;
            value = dummy;
          })
          [
            "fastfetch"
            "htop"
          ]
      ))
    )
  ];
  home.packages = with pkgs; [
    gcc
    opencode
    claude-code
  ];
  home.sessionVariables = {
    # Termux's Android CA paths are not the paths expected by Nix-built tools.
    # Use the Nix CA bundle for HTTPS certificate verification.
    NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    # Point glibc-based programs at the timezone database shipped by Nix.
    TZDIR = "${pkgs.tzdata}/share/zoneinfo";
  };
  home.activation = {
    # Expose the Nix glibc loader and libraries inside the Termux chroot so
    # dynamically linked Nix binaries can start there.
    glibcLoader = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CHROOT_LIB="${termux_root}/chroot-root/lib"
      if [ -e "$CHROOT_LIB" ] && [ ! -L "$CHROOT_LIB" ]; then
        # Never replace a Termux-managed directory with a generated symlink.
        echo "Refusing to replace non-symlink path: $CHROOT_LIB" >&2
        exit 1
      fi
      run ln -sfn ${pkgs.glibc}/lib "$CHROOT_LIB"
    '';

    timeZoneFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ETC="${termux_root}/usr/etc"
      if [ -d $ETC ]; then
        run ln -snf ${pkgs.tzdata}/share/zoneinfo $ETC/zoneinfo
        TZ=$(${termux_root}/usr/bin/getprop persist.sys.timezone)
        run ln -sf $ETC/zoneinfo/$TZ $ETC/localtime
      fi
    '';
  };
  nix.settings.auto-optimise-store = false; # android does not support hardlinks
}
