{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  packages = builtins.mapAttrs (name: value: pkgs.callPackage value { }) (import ./packages.nix);
  echoerr = pkgs.writeShellScriptBin "echoerr" ''
    echo "$@" 1>&2
  '';
  vpn_connect = pkgs.writeShellScriptBin "vpn_connect" ''
    sudo sh ${./scripts/vpn_connect.sh}
  '';
  vpn_connect_gui = pkgs.writeShellScriptBin "vpn_connect_gui" ''
    sh ${./scripts/vpn_connect_gui.sh}
  '';
  load_gpg_key = pkgs.writeShellScriptBin "load_gpg_key" ''
    sh ${./scripts/load_gpg_key.sh}
  '';
  homeDir = config.home.homeDirectory;
in
{
  imports = [
    ./dotfiles.nix
  ];
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = lib.mkDefault "qsdrqs";
  home.homeDirectory = lib.mkDefault "/home/qsdrqs";
  home.packages = with pkgs; [
    htop
    iotop
    lazygit
    echoerr
    vpn_connect
    vpn_connect_gui
    load_gpg_key
  ];

  # add some bin to ~/.local/bin
  home.file."editor-wrapped" = {
    source = "${packages.editor-wrapped}/bin/editor-wrapped";
    target = ".local/bin/editor-wrapped";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;

  # enable direnv
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.direnv.enableZshIntegration = false; # self enable

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    initContent = lib.mkBefore ''
      if [ -e $HOME/.zshrc ]; then
        ZSH_CUSTOM="$HOME/.zsh"
        # source grc
        source ${pkgs.grc}/etc/grc.zsh

        source $HOME/.zshrc
      fi
    '';
    history = {
      size = 500000;
      save = 500000;
      expireDuplicatesFirst = true;
      saveNoDups = true;
      path = "${config.home.homeDirectory}/.zsh_history";
    };
    completionInit = ""; # define in my own zshrc
  };
  programs.ssh = {
    enable = true;
    includes = [ "ssh-config" ];
    enableDefaultConfig = false;
  };
  home.file."extra_config" = {
    source = ./private/ssh-config;
    target = ".ssh/ssh-config";
  };

  # enable fzf
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.email = "qsdrqs@gmail.com";
      user.name = "qsdrqs";
      core = {
        editor = "$EDITOR";
        pager = "cat";
      };
      credential = {
        helper = "store";
      };
      pull = {
        rebase = true;
      };
    };
    signing.key = "E2D709340CE26E78";
    signing.signByDefault = true;
  };

  # provide org.freedesktop.secrets

  # services.ssh-agent.enable = true;

  home.sessionVariables = {
    CREDENTIALS_FILE = "${config.home.homeDirectory}/.git-credentials";
    NIX_CONFIG = ''
      $(
        github_token=$(cat /home/qsdrqs/.git-credentials 2>/dev/null | grep github.com | awk -F'[:@]' '{print $3}')
        if [ -n "$github_token" ]; then
          echo "access-tokens = github.com=$github_token";
        fi
      )'';
    _ZO_FZF_OPTS = ''
      --no-sort
      --bind=ctrl-z:ignore,btab:up,tab:down
      --cycle
      --keep-right
      --border=sharp
      --height=45%
      --info=inline
      --layout=reverse
      --tabstop=1
      --exit-0
      --select-1
    '';
  };

  # Windows Fonts
  home.activation = {
    windowsFonts = ''
      mkdir -p ~/.local/share/fonts
      if [ ! -L ~/.local/share/fonts/Windows ]; then
        if [ -d /mnt/c/Windows/Fonts ]; then
          ln -s /mnt/c/Windows/Fonts/ ~/.local/share/fonts/Windows
        elif [ -d /mnt/Windows/Fonts ]; then
          ln -s /mnt/Windows/Fonts/ ~/.local/share/fonts/Windows
        fi
      fi
    '';
    configs =
      let
        linkConfigs = [
          "lazygit"
          "aichat"
        ];
        touchConfigs = [ ];
      in
      ''
        mkdir -p ~/.config
        ${lib.concatMapStringsSep "\n" (cfg: ''
          if [ ! -e ${homeDir}/.config/${cfg} ]; then
            ln -s ${homeDir}/dotfiles/${cfg} ${homeDir}/.config
          fi
        '') linkConfigs}
        ${lib.concatMapStringsSep "\n" (cfg: ''
          if [ ! -e ${homeDir}/.config/${cfg} ]; then
            touch ${homeDir}/.config/${cfg}
          fi
        '') touchConfigs}
      '';
    opencode-config =
      let
        files = [
          "opencode.jsonc"
          "oh-my-opencode.json"
          "skill"
        ];
      in
      ''
        mkdir -p ~/.config/opencode
        ${lib.concatMapStringsSep "\n" (cfg: ''
          if [ ! -e ${homeDir}/.config/opencode/${cfg} ]; then
            ln -s ${homeDir}/dotfiles/opencode/${cfg} ${homeDir}/.config/opencode
          fi
        '') files}
      '';
  };
}
