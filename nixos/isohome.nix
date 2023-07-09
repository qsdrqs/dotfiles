({ config, pkgs, lib, ... }: {
  home.file = {
    dotfiles = {
      source = ../.;
    };
    ".nvimrc.lua" = lib.mkForce {
      text = "";
    };
    p10kzsh = {
      source = ./.p10k.zsh.minimal;
      target = ".p10k.zsh";
    };
  };
})
