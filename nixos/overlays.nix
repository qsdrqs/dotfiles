{ config, pkgs, lib, inputs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      neovim-unwrapped = super.neovim-unwrapped.overrideAttrs (oldAttrs: {
        src = inputs.neovim;
        patches = lib.lists.take 1 oldAttrs.patches;
      });

      ranger = super.ranger.overrideAttrs (oldAttrs: {
        src = inputs.ranger;
        propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [pkgs.python3Packages.pylint];
      });

      variety = super.variety.overrideAttrs (oldAttrs: {
        prePatch = oldAttrs.prePatch + ''
          substituteInPlace data/scripts/set_wallpaper --replace "\"i3\"" "\"none+i3\""
          substituteInPlace data/scripts/set_wallpaper --replace "feh --bg-fill" "feh --bg-scale --no-xinerama"
        '';
      });

    })
  ];
}
