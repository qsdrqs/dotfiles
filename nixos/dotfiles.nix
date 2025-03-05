{ config, pkgs, pkgs-stable, lib, inputs, ... }:

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
        --replace-fail "COLUMNS=500 _ftb__main_complete" "_ftb__main_complete"
      '';
    };
    powerlevel10k = pkgs.stdenv.mkDerivation {
      name = "powerlevel10k";
      src = inputs.zsh-config.inputs.powerlevel10k;
      installPhase = commonInstallPhase;
      postInstall = ''
        substituteInPlace $out/gitstatus/install \
          --replace-fail "local no_check= no_install=" "local no_check= no_install=1"

        sed -E -i 's/version="v[0-9]+(.[0-9]+)+"/version="v${pkgs.gitstatus.version}"/' \
          $out/gitstatus/install.info && \
          grep -q 'version="v${pkgs.gitstatus.version}"' $out/gitstatus/install.info
      '';
    };
  };

  genZshPlugins = plugins: lib.genAttrs plugins (plugin: {
    source =
      if !builtins.hasAttr plugin buildDerivations then
        inputs.zsh-config.inputs.${plugin}
      else
        buildDerivations.${plugin};
    target = ".zsh/plugins/${plugin}";
  });

  genZshThemes = themes: lib.genAttrs themes (theme: {
    source =
      if !builtins.hasAttr theme buildDerivations then
        inputs.zsh-config.inputs.${theme}
      else
        buildDerivations.${theme};
    target = ".zsh/themes/${theme}";
  });

  genTmuxPlugins = plugins: lib.genAttrs plugins (plugin: {
    source = inputs.${plugin};
    target = ".tmux/plugins/${plugin}";
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
    ".editorconfig"
  ] //
  symbfileTarget [
    { name = ".vim"; target = ".config/nvim"; }
    { name = "after"; target = ".config/nvim/after"; }
    { name = ".vimrc"; target = ".config/nvim/init.vim"; }
    { name = "starship/starship-yazi.toml"; target = ".config/starship-yazi.toml"; }
  ] //
  symbfileTargetNoRecursive [
    { name = "nvim/lua"; target = ".config/nvim/lua"; }
  ] //
  genZshPlugins inputs.zsh-config.plugins //
  genZshThemes inputs.zsh-config.themes //
  genTmuxPlugins [
    "tmux-resurrect"
    "tmux-continuum"
  ] //
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

    yazi = {
      source = pkgs.stdenv.mkDerivation {
        name = "yazi-config";
        src = ../yazi;
        installPhase = commonInstallPhase;
        postInstall =
          let
            plugins-3rdpty = [
              "searchjump"
              "starship"
            ];
            plugins-offical = [
              "toggle-pane"
              "mime-ext"
            ];
          in
          lib.strings.concatStrings
            (map
              (plugin: ''
                ln -s ${inputs."yazi-${plugin}"} $out/plugins/${plugin}.yazi
              '')
              plugins-3rdpty) + lib.strings.concatStrings (map
            (plugin: ''
              ln -s ${inputs.yazi-plugins}/${plugin}.yazi $out/plugins/${plugin}.yazi
            '')
            plugins-offical);
      };
      target = ".config/yazi";
    };
  };

}
