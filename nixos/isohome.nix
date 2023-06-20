({ config, pkgs, ... }: {
  home.file = {
    dotfiles = {
      source = ../.;
    };
    nvimconf = {
      source = ~/.local/share/nvim;
      target = ".local/share/nvim";
    };
    p10kzsh = {
      source = ./.p10k.zsh.minimal;
      target = ".p10k.zsh";
    };
  };
})
