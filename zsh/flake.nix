{
  description = "Z Shell themes and plugins";
  inputs = {
    # omz is only used for the plugins
    omz = {
      url = "github:ohmyzsh/ohmyzsh";
      flake = false;
    };
    fzf-tab = {
      url = "github:Aloxaf/fzf-tab";
      flake = false;
    };
    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
      flake = false;
    };
    fast-syntax-highlighting = {
      url = "github:zdharma-continuum/fast-syntax-highlighting";
      flake = false;
    };
    zsh-vi-mode = {
      url = "github:jeffreytse/zsh-vi-mode";
      flake = false;
    };

    powerlevel10k = {
      url = "github:romkatv/powerlevel10k";
      flake = false;
    };
    spaceship = {
      url = "github:denysdovhan/spaceship-prompt";
      flake = false;
    };

    zinit = {
      url = "github:zdharma-continuum/zinit";
      flake = false;
    };
  };
  outputs = { self, ... }@inputs: {
    inputs = inputs;

    plugins = [ "fzf-tab" "zsh-autosuggestions" "fast-syntax-highlighting" "zsh-vi-mode" ];
    themes = [ "powerlevel10k" "spaceship" ];
  };
}
