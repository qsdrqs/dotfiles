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
}
