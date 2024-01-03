{ config, pkgs, lib, inputs, ... }:

let
  commonInstallPhase = ''
    mkdir $out
    cp -r * $out
    runHook postInstall
  '';
  extraBuildPlugins = [ ];
  dummyBuildPhase = ''
    # do nothing
  '';
  build = {
    telescope-fzf-nativeDOTnvim = pkgs.stdenv.mkDerivation {
      name = "telescope-fzf-native.nvim";
      buildInputs = with pkgs; [ gnumake ];
      src = inputs.nvim-config.inputs.telescope-fzf-nativeDOTnvim;
      installPhase = commonInstallPhase;
    };
    firenvim = pkgs.stdenv.mkDerivation {
      name = "firenvim";
      src = inputs.nvim-config.inputs.firenvim;
      installPhase = commonInstallPhase;
    };
    markdown-previewDOTnvim = pkgs.stdenv.mkDerivation {
      name = "markdown-preview.nvim";
      src = inputs.nvim-config.inputs.markdown-previewDOTnvim;
      installPhase = commonInstallPhase + ''
        ln -s ${config.home.homeDirectory}/.local/share/nvim/lazy/markdown-preview.nvim/app/bin $out/app/bin
      '';
    };
    nvim-fundo = pkgs.stdenv.mkDerivation {
      name = "nvim-fundo";
      src = inputs.nvim-config.inputs.nvim-fundo;
      buildPhase = dummyBuildPhase;
      installPhase = commonInstallPhase;
    };
    nvim-treesitter = pkgs.stdenv.mkDerivation {
      name = "nvim-treesitter";
      src = inputs.nvim-config.inputs.nvim-treesitter;
      installPhase = commonInstallPhase;
      postInstall = ''
        rm -rf $out/parser-info
        rm -rf $out/parser
        ln -s ${config.home.homeDirectory}/.local/share/nvim/lazy/nvim-treesitter/parser-info $out/parser-info
        ln -s ${config.home.homeDirectory}/.local/share/nvim/lazy/nvim-treesitter/parser $out/parser
      '';
    };
  };
  genNvimPlugins = entries: builtins.listToAttrs (map
    (entry: {
      name = entry.name + "_";
      value = {
        source =
          if !entry.build && !builtins.elem entry.name extraBuildPlugins then
            entry.source
          else
            build.${entry.dotname};
        target = "${config.home.homeDirectory}/.local/share/nvim/nix/${entry.name}";
      };
    })
    entries);
in
{
  home.file = genNvimPlugins inputs.nvim-config.plugins_list;

  home.activation.updateNvimFlake = ''
    cd ${config.home.homeDirectory}/dotfiles/nvim/flake
    export PATH=${pkgs.neovim}/bin:${pkgs.git}/bin:$PATH
    ${pkgs.python3}/bin/python3 dump_input.py
    nix flake lock path:.
    cd ${config.home.homeDirectory}/dotfiles
    nix flake lock --update-input nvim-config path:.
  '';

  home.activation.createBuildDirs = ''
    if [ ! -d ${config.home.homeDirectory}/.local/share/nvim/lazy/markdown-preview.nvim/app/bin ]; then
      mkdir -p ${config.home.homeDirectory}/.local/share/nvim/lazy/markdown-preview.nvim/app/bin
    fi
    if [ ! -d ${config.home.homeDirectory}/.local/share/nvim/lazy/nvim-treesitter/parser-info ]; then
      mkdir -p ${config.home.homeDirectory}/.local/share/nvim/lazy/nvim-treesitter/parser-info
    fi
    if [ ! -d ${config.home.homeDirectory}/.local/share/nvim/lazy/nvim-treesitter/parser ]; then
      mkdir -p ${config.home.homeDirectory}/.local/share/nvim/lazy/nvim-treesitter/parser
    fi
  '';
}
