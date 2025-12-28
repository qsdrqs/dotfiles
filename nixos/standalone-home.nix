{ config, pkgs, inputs, lib, ... }:
let
  packages = builtins.mapAttrs (name: value: pkgs.callPackage value { })
    (import ./packages.nix);
in {
  imports = [
    (if builtins.pathExists ./home-custom.nix then
      ./home-custom.nix
    else
      lib.warn "home-custom.nix not found" lib.warn
      "will use username `qsdrqs` and home directory `/home/qsdrqs`"
      ./empty.nix)
  ];

  home.packages = with pkgs; [
    (wrapNeovim packages.neovim-reloadable-unwrapped { withPython3 = true; })
    yazi
    zoxide
    lsd
    fd
    duf
    gdu
    ripgrep
    grc
    fastfetch
    neofetch
    tmux
    nodejs
    config.nix.package
    tree-sitter
  ];

  # Mimic the default nix-ld library set that NixOS exposes at
  # /run/current-system/sw/share/nix-ld/lib. On non-NixOS we can't rely on that
  # path, so build the same search list directly.
  home.sessionVariables = let
    nixLdDefaultLibs = with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ];
  in {
    NIX_LD_LIBRARY_PATH = lib.makeLibraryPath nixLdDefaultLibs;
  };

  nix = {
    settings = {
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" config.home.username "@wheel" "nix-serve" ];
      substituters = [
        "https://yazi.cachix.org"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
    package = pkgs.nixVersions.latest;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
