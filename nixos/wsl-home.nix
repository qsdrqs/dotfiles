{ config, pkgs, inputs, lib, ... }:
let
  linkWinProgram = name: path: ''
    mkdir -p ~/.local/bin
    if [[ ! -L ~/.local/bin/${name} ]]; then
      if [[ -f "/mnt/${path}" ]]; then
        ln -s "/mnt/${path}" ~/.local/bin/${name}
      fi
    fi
  '';
in
{
  home.file.wsl.text = "";
  home.activation = {
    im-select = linkWinProgram "im-select.exe" "c/im-select/im-select.exe";
    google-chrome = linkWinProgram "google-chrome" "c/Program Files/Google/Chrome/Application/chrome.exe";
  };
}
