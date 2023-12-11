{ config, pkgs, lib, inputs, ... }:

let
  symbfile = filenames: lib.genAttrs filenames (filename: {
    source = ../${filename};
    recursive = true;
  });
  symbfileTarget = entries: builtins.listToAttrs (map
    (entry: {
      name = entry.name + "_";
      value = {
        source = ../${entry.name};
        target = entry.target;
        recursive = true;
      };
    })
    entries);
  symbfileTargetNoRecursive = entries: builtins.listToAttrs (map
    (entry: {
      name = entry.name + "_";
      value = {
        source = ../${entry.name};
        target = entry.target;
      };
    })
    entries);

  genZshPlugins = plugins: lib.genAttrs plugins (plugin: {
    source = inputs.zsh-config.inputs.${plugin};
    target = "zsh_custom/plugins/${plugin}";
  });

  genZshThemes = themes: lib.genAttrs themes (theme: {
    source = inputs.zsh-config.inputs.${theme};
    target = "zsh_custom/themes/${theme}";
  });
in
{
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
  symbfileTargetNoRecursive [
    { name = "yazi"; target = ".config/yazi"; }
  ] //
  genZshPlugins inputs.zsh-config.plugins //
  genZshThemes inputs.zsh-config.themes //
  {
    omz = {
      source = inputs.zsh-config.inputs.omz;
      target = ".oh-my-zsh";
    };
    zinit = {
      source = inputs.zsh-config.inputs.zinit;
      target = "zinit";
    };
    # can be override by lib.mkForce
    "theme.zsh" = {
      text = ''
        ZSH_THEME="powerlevel10k"
      '';
    };
  };

  home.activation.updateZshFlake = ''
    cd ${config.home.homeDirectory}/dotfiles/zsh
    nix flake lock path:.
    cd ${config.home.homeDirectory}/dotfiles
    nix flake lock --update-input zsh-config path:.
  '';

}
