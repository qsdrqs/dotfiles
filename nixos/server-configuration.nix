{ config, pkgs, lib, inputs, options, ... }:

{
  # repair nix store
  # nixpkgs.config.sync-before-registering = true;

  nixpkgs.config.permittedInsecurePackages = [
    "nodejs-16.20.2"
    "openssl-1.1.1w"
  ];

  environment.systemPackages = with pkgs; [
    gcc
    gnumake
    perl
    appimage-run
    nil # nix language server
    nixpkgs-fmt
    python3Packages.ipython
    python3Packages.pip
    cscope
    global
    ctags
    nodejs_16
    firejail

    # pdf2txt
    poppler_utils

    w3m
    # flamegraph
    inferno
  ];

  environment.variables = {
    LIBCLANG_PATH = "${pkgs.llvmPackages_latest.libclang.lib}/lib";
  };

  programs = {
    proxychains = {
      enable = true;
      proxies.v2ray = {
        type = "socks5";
        host = "127.0.0.1";
        port = 1080;
        enable = true;
      };
      quietMode = true;
    };
  };

  services = {
    syncthing = {
      enable = true;
      user = "qsdrqs";
      configDir = "/home/qsdrqs/.config/syncthing";
    };
    v2ray = {
      enable = true;
      configFile = "/etc/v2ray/config.json";
    };
  };

  # avoid v2ray service to create config file
  environment.etc."v2ray/config.json".enable = false;

}
