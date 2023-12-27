{ config, pkgs, lib, inputs, options, hm-module, ... }:
let
  sshd = {
    sshdTmpDirectory = "${config.user.home}/sshd-tmp";
    sshdDirectory = "/etc/sshd";
    pathToPubKey = "${config.user.home}/dotfiles/nixos/private/authorized_keys";
    port = 8022;

  };
  systemConfig = builtins.removeAttrs
    (import ./minimal-configuration.nix {
      inherit config pkgs lib inputs options;
    }) [ "boot" "networking" "console" "users" "programs" "security" "services" "nixpkgs" ];
  environment = (builtins.removeAttrs systemConfig.environment [ "systemPackages" "defaultPackages" ]) // {
    packages = systemConfig.environment.systemPackages ++ (with pkgs; [
      zsh
      neovim
      gnused
      gawk
      xterm
      sudo
      gzip
      findutils
      grep
      (pkgs.writeScriptBin "sshd-start" ''
        #!${pkgs.runtimeShell}

        echo "Starting sshd in non-daemonized way on port ${toString sshd.port}"
        ${pkgs.openssh}/bin/sshd -f "${sshd.sshdDirectory}/sshd_config" -D
      '')
    ]);
  };
  nix = builtins.removeAttrs systemConfig.nix [ "gc" "settings" ];
in
systemConfig // {
  environment = environment // {
    etc = {
      sshd_config = {
        target = "sshd/sshd_config";
        text = ''
          HostKey ${sshd.sshdDirectory}/ssh_host_rsa_key
          Port ${toString sshd.port}
          AuthorizedKeysFile %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
          KbdInteractiveAuthentication no
          PasswordAuthentication no
          PermitRootLogin prohibit-password
        '';
      };
    };
  };
  nix = nix // {
    extraOptions = ''experimental-features = nix-command flakes'';
  };
  system.stateVersion = "23.11";
  user.shell = "${pkgs.zsh}/bin/zsh";
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    config = {
      imports = hm-module;
    } // {
      home.username = lib.mkForce config.user.userName;
      home.homeDirectory = lib.mkForce config.user.home;

    };

    extraSpecialArgs = {
      inherit inputs;
    };
  };

  build.activation.sshd = ''
    $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${config.user.home}/.ssh"
    $DRY_RUN_CMD cat ${sshd.pathToPubKey} > "${config.user.home}/.ssh/authorized_keys"

    gf [[ ! -d "${sshd.sshdDirectory}" ]]; then
      $DRY_RUN_CMD rm $VERBOSE_ARG --recursive --force "${sshd.sshdTmpDirectory}"
      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${sshd.sshdTmpDirectory}"

      $VERBOSE_ECHO "Generating host keys..."
      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "${sshd.sshdTmpDirectory}/ssh_host_rsa_key" -N ""

      $DRY_RUN_CMD mv $VERBOSE_ARG "${sshd.sshdTmpDirectory}" "${sshd.sshdDirectory}"
    fi
  '';

}
