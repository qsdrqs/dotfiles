# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, options, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.tmp.useTmpfs = true;

  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://127.0.0.1:1081";
  # networking.proxy.noProxy = "127.0.0.1,localhost";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkbOptions in tty.
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.qsdrqs = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles = [
      (if builtins.pathExists ./private/authorized_keys then ./private/authorized_keys else
      lib.warn "No authorized_keys found, please create one in ./private/authorized_keys"
        ./empty)
    ];
  };
  system.activationScripts = {
    root_sshconfig = ''
      if [ -d "/root" ]; then
          # Check if /root/.ssh does not exist
          if [ ! -d "/root/.ssh" ]; then
              echo "/root/.ssh does not exist. Creating directory."
              mkdir /root/.ssh
          fi
          # Copy .ssh keys from /home/qsdrqs/.ssh to /root/.ssh
          cp /home/qsdrqs/.ssh/* /root/.ssh/

          # Change ownership to root for all files in /root/.ssh
          chown root:root /root/.ssh/*
      fi
    '';
  };

  # enable normal users to use reboot or shutdown
  security.polkit.enable = true;

  security.wrappers.direnv = {
    source = "${pkgs.direnv}/bin/direnv";
    owner = "root";
    group = "keys";
    setgid = true;
    setuid = true;
  };

  # gc
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 21d";
    };
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "qsdrqs" "@wheel" ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nixpkgs.config.allowUnfree = true;
  # remove packages installed by default (e.g. nano, etc.)
  environment.defaultPackages = [ ];

  environment.systemPackages = with pkgs; [
    vim-full # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    lsd
    wget
    curl
    ranger
    inputs.yazi.packages.${pkgs.system}.yazi
    tmux
    perl # for tmux to work
    neofetch
    grc
    git
    fzf
    fd
    ripgrep
    gnutar
    unzip
    zip
    p7zip
    gcc
    gnumake
    killall
    (pkgs.buildFHSUserEnv {
      name = "fhs";
      runScript = "zsh";
      targetPkgs = pkgs: with pkgs; [
      ];
    })
    linuxKernel.packages.linux_latest_libre.cpupower
    linuxKernel.packages.linux_latest_libre.perf
    patchelf
    python3
    lsof
    bat
    file
    rsync
    iptables
    kmod
    nmap
    lm_sensors
    lua
    home-manager
    nix-tree
    duf
    lsb-release
    valgrind
    sqlite
    sshfs
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs = {
    zsh = {
      enable = true;
      enableCompletion = false; # enabled in my own zshrc
    };
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    nix-ld.enable = true;
    gnupg.agent.enable = true;
    command-not-found.enable = false;
    nix-index.enable = true;
    bash.interactiveShellInit = ''
      source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
    '';
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = true;
      };
    };
    journald.extraConfig = ''
      SystemMaxUse=500M
      RuntimeMaxUse=500M
    '';
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "unstable"; # Did you read the comment?

}
