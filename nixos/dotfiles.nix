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

  commonInstallPhase = ''
    mkdir $out
    cp -r * $out
    runHook postInstall
  '';

  buildDerivations = {
    fzf-tab = pkgs.stdenv.mkDerivation {
      name = "fzf-tab";
      src = inputs.zsh-config.inputs.fzf-tab;
      installPhase = commonInstallPhase;
      postInstall = ''
        substituteInPlace $out/fzf-tab.zsh \
        --replace "COLUMNS=500 _ftb__main_complete" "_ftb__main_complete"
      '';
    };
  };

  genZshPlugins = plugins: lib.genAttrs plugins (plugin: {
    source =
      if !builtins.hasAttr plugin buildDerivations then
        inputs.zsh-config.inputs.${plugin}
      else
        buildDerivations.${plugin};
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
    # gitstatusd
    gitstatusd =
      let
        arch_split = lib.strings.splitString "-" pkgs.system;
        arch_reverse = lib.foldr (a: b: if b == "" then a else b + "-" + a) "" arch_split;
      in
      {
        source = "${pkgs.gitstatus}/bin/gitstatusd";
        target = ".cache/gitstatus/gitstatusd-${arch_reverse}";
      };

    ranger = {
      source = pkgs.stdenv.mkDerivation {
        name = "ranger-config";
        src = inputs.ranger-config;
        installPhase = commonInstallPhase;
        postInstall = ''
          cp -r ${inputs.ranger-config.colorschemes} $out/colorschemes
        '' + lib.strings.concatStrings (map
          (plugin: ''
            ln -s ${inputs.ranger-config.inputs.${plugin}} $out/plugins/${plugin}
          '')
          inputs.ranger-config.plugins);
      };
      target = ".config/ranger";
      recursive = true;
    };
  };

}
