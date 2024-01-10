({ config, pkgs, lib, ... }: {
  home.file = {
    dotfiles = {
      source = ../.;
    };
    ".nvimrc.lua" = lib.mkForce {
      text = ''
        -- dummy function to prevent errors
        local function dummy() end

        lazyLoadPlugins = dummy
        VscodeNeovimHandler = dummy
      '';
    };
    p10kzsh = {
      source = ./.p10k.zsh.minimal;
      target = ".p10k.zsh";
    };
  };
})
