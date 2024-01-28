{ config, pkgs, pkgs-master, lib, inputs, options, ... }:
let
  packages = pkgs.callPackage ./packages.nix { inputs = inputs; };
  homeDir = config.users.users.qsdrqs.home;
in
{
  # repair nix store
  # nixpkgs.config.sync-before-registering = true;

  nixpkgs.config.permittedInsecurePackages = [
  ];

  environment.systemPackages = with pkgs; [
    appimage-run
    nil # nix language server
    nixpkgs-fmt
    python3Packages.ipython
    python3Packages.pip
    cscope
    global
    ctags
    nodejs
    firejail
    (if config.nixpkgs.system == "x86_64-linux" then cloudflare-warp else packages.dummy)
    openssl
    parted
    gh
    exiftool
    nix-serve

    poppler_utils # pdf2txt

    w3m
    inferno # flamegraph
    wireguard-tools
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
      dataDir = "/home/qsdrqs";
    };
    v2ray = {
      enable = true;
      configFile = "/etc/v2ray/config.json";
    };
  };

  systemd = {
    services.rathole-client = {
      enable = false;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Start the rathole client";
      serviceConfig = {
        User = "root";
        ExecStart = ''${pkgs.rathole}/bin/rathole /etc/rathole/client.toml'';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    services.warp-svc = {
      enable = if config.nixpkgs.system == "x86_64-linux" then true else false;
      wantedBy = [ "multi-user.target" ];
      after = [ "pre-network.target" ];
      description = "CloudflareWARP daemon";
      serviceConfig =
        if config.nixpkgs.system == "x86_64-linux" then {
          ExecStart = ''${pkgs.cloudflare-warp}/bin/warp-svc'';
          CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE";
          AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE";
          Restart = "always";
          DynamicUser = "no";
        } else { };
    };
  };

  # avoid v2ray service to create config file
  environment.etc."v2ray/config.json".enable = false;

  networking.wireguard.interfaces = {
    wg0 = {
      listenPort = 51820;
      privateKeyFile = "${homeDir}/.wireguard/private";
      peers = (pkgs.callPackage ./private/wireguard-peers.nix { inputs = inputs; });
    };
  };
}
