{ config, pkgs, lib, ... }:

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
in
{
  home.activation = {
    dotfiles = ''
      PATH=$PATH:${lib.makeBinPath [ pkgs.git ]}
      if [ ! -d "$HOME/dotfiles" ]; then
        git clone https://github.com/qsdrqs/mydotfiles $HOME/dotfiles --recurse-submodules
        # cd $HOME/dotfiles && ./install.sh
      fi
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
              ];
}
