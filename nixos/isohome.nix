({ config, pkgs, lib, ... }: {
  home.file = {
    ".nvimrc.lua" = lib.mkForce {
      text = ''
        -- dummy function to prevent errors
        local function dummy() end

        LazyLoadPlugins = dummy
        VscodeNeovimHandler = dummy
      '';
    };
    p10kzsh = {
      source = ./scripts/.p10k.zsh.minimal;
      target = ".p10k.zsh";
    };
  };
  home.activation.dotfiles = ''
    cp -rf ${../.} ${config.home.homeDirectory}/dotfiles
    touch ${config.xdg.configHome}/hypr-monitor.conf
  '';
})
