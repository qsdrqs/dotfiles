{ config, pkgs, lib, inputs, ... }:

let
  genNvimPlugins = entries: builtins.listToAttrs (map
    (entry: {
      name = entry.name + "_";
      value = {
        source = entry.source;
        target = "${config.home.homeDirectory}/.local/share/nvim/nix/${entry.name}";
        recursive = entry.recursive;
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
}
