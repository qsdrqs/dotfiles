{ config, pkgs, inputs, lib, ... }:

{
  home.file.wsl.text = "";
  home.activation = {
    im-select = ''
      mkdir -p ~/.local/bin
      if [ ! -L ~/.local/bin/im-select.exe ]; then
        if [ -f /mnt/c/im-select/im-select.exe ]; then
          ln -s /mnt/c/im-select/im-select.exe ~/.local/bin/
        fi
      fi
    '';
  };
}
