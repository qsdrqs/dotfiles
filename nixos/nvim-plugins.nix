{ config, pkgs, lib, inputs, ... }:

let
  commonInstallPhase = ''
    mkdir $out
    cp -r * $out
    runHook postInstall
  '';
  dummyBuildPhase = ''
    # do nothing
  '';
  trivialDerivation = name: src: pkgs.stdenv.mkDerivation {
    name = name;
    src = src;
    buildPhase = dummyBuildPhase;
    installPhase = commonInstallPhase;
  };
  buildDerivations = {
    telescope-fzf-nativeDOTnvim = pkgs.stdenv.mkDerivation {
      name = "telescope-fzf-native.nvim";
      nativeBuildInputs = with pkgs; [ gnumake ];
      src = inputs.nvim-config.inputs.telescope-fzf-nativeDOTnvim;
      installPhase = commonInstallPhase;
    };
    firenvim = trivialDerivation "firenvim" inputs.nvim-config.inputs.firenvim;
    markdown-previewDOTnvim = pkgs.stdenv.mkDerivation {
      name = "markdown-preview.nvim";
      src = inputs.nvim-config.inputs.markdown-previewDOTnvim;
      installPhase = commonInstallPhase + ''
        ln -s ${config.home.homeDirectory}/.local/share/nvim/lazy/markdown-preview.nvim/app/bin $out/app/bin
      '';
    };
    nvim-fundo = trivialDerivation "nvim-fundo" inputs.nvim-config.inputs.nvim-fundo;
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
    LuaSnip = pkgs.stdenv.mkDerivation {
      name = "LuaSnip";
      src = inputs.nvim-config.inputs.LuaSnip;
      buildPhase = dummyBuildPhase;
      installPhase = commonInstallPhase;
      postInstall = ''
        substituteInPlace $out/lua/luasnip/util/feedkeys.lua \
          --replace-fail "o<C-G><C-r>_" \
          "<C-G><C-r>_"
      '';
    };
    avanteDOTnvim = let
      naersk = pkgs.callPackage inputs.naersk {};
    in naersk.buildPackage rec {
      name = "avante.nvim";
      src = inputs.nvim-config.inputs.avanteDOTnvim;
      buildInputs = with pkgs; [ openssl.dev ];
      nativeBuildInputs = with pkgs; [ pkg-config perl ];
      buildPhase = ''
        rm -rf *
        cp -rf ${src}/* .
        make BUILD_FROM_SOURCE=true
      '';
      installPhase = commonInstallPhase;
    };
  };
  genNvimPlugins = entries: builtins.listToAttrs (map
    (entry: {
      name = entry.name + "_";
      value = {
        source =
          if !entry.build && !builtins.hasAttr entry.dotname buildDerivations then
            entry.source
          else
            buildDerivations.${entry.dotname};
        target = "${config.home.homeDirectory}/.local/share/nvim/nix/${entry.name}";
      };
    })
    entries);
in
{
  home.file = genNvimPlugins inputs.nvim-config.plugins_list;

  home.activation.updateNvimFlake = ''
    cd ${config.home.homeDirectory}/dotfiles/nvim
    export PATH=${pkgs.neovim}/bin:${pkgs.git}/bin:$PATH
    ${pkgs.python3}/bin/python3 dump_input.py
    nix flake lock
    cd ${config.home.homeDirectory}/dotfiles
    nix flake lock --update-input nvim-config
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
