{ config, pkgs, lib, inputs, ... }:

let
  symbfile = filenames: lib.genAttrs filenames (filename: {
    source = ../${filename};
    recursive = true;
  });
  symbfileTarget = entries: builtins.listToAttrs (map (entry: {
    name = entry.name + "_";
    value = {
      source = ../${entry.name};
      target = entry.target;
      recursive = true;
    };
  }) entries);
  symbfileTargetInput = entries: builtins.listToAttrs (map (entry: {
    name = entry.name;
    value = {
      source = inputs.${entry.name};
      target = "zsh_custom/" + entry.target;
    };
  }) entries);
in
{
  home.activation = {
    dotfiles = ''
      PATH=$PATH:${lib.makeBinPath [ pkgs.git ]}
      if [ ! -d "$HOME/dotfiles" ]; then
        git clone https://github.com/qsdrqs/mydotfiles $HOME/dotfiles --recurse-submodules
      fi
      # cd $HOME/dotfiles && ./install.sh
    '';
  };
  home.file = symbfile [
                ".vimrc"
                ".vimrc.plugs"
                ".nvimrc.lua"
                ".tmux.conf"
                ".tmux.conf.local"
                ".zshrc"
                ".vim"
              ] //
              symbfileTarget [
                { name = "ranger"; target = ".config/ranger"; }
                { name = ".vim"; target = ".config/nvim"; }
                { name = "after"; target = ".config/nvim/after"; }
                { name = ".vimrc"; target = ".config/nvim/init.vim"; }
              ] //
              symbfileTargetInput [
                { name = "fzf-tab"; target = "plugins/fzf-tab"; }
                { name = "zsh-autosuggestions"; target = "plugins/zsh-autosuggestions"; }
                { name = "zsh-highlight"; target = "plugins/fast-syntax-highlighting"; }
                { name = "p10k"; target = "themes/powerlevel10k"; }
                { name = "spaceship"; target = "themes/spaceship-prompt"; }
              ] // {
                omz = {
                  source = inputs.omz;
                  target = ".oh-my-zsh";
                };
              };
}
