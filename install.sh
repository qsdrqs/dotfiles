#!/usr/bin/env bash

function zsh_install {
    # oh-my-zsh
    git clone https://github.com/ohmyzsh/ohmyzsh $HOME/.oh-my-zsh
    # zinit
    git clone https://github.com/zdharma-continuum/zinit $HOME/.zinit
    mkdir -p $HOME/.zsh/plugins
    mkdir -p $HOME/.zsh/themes

    # plugins
    git clone https://github.com/Aloxaf/fzf-tab $HOME/.zsh/plugins/fzf-tab &
    git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.zsh/plugins/zsh-autosuggestions &
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
        $HOME/.zsh/plugins/fast-syntax-highlighting &
    git clone https://github.com/rupa/z.git $HOME/.zsh/plugins/z &
    git clone https://github.com/skywind3000/z.lua $HOME/.zsh/plugins/z_lua &

    # themes
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        $HOME/.zsh/themes/powerlevel10k &
    git clone https://github.com/denysdovhan/spaceship-prompt $HOME/.zsh/themes/spaceship-prompt &

    echo "#ZSH_THEME=\"spaceship-prompt\"" > $HOME/theme.zsh
    echo "ZSH_THEME=\"powerlevel10k\"" > $HOME/theme.zsh
}

function main {
    echo installing

    # move vim files
    ln -s $PWD/.vimrc $HOME/.vimrc
    ln -s $PWD/.vimrc.plugs $HOME/.vimrc.plugs
    ln -s $PWD/.nvimrc.lua $HOME/.nvimrc.lua

    if [[ ! -d $HOME/.vim ]];then
        mkdir -p $HOME/.vim
    fi

    # move nvim files
    if [[ ! -d $HOME/.config/nvim ]];then
        mkdir -p $HOME/.config/nvim
    fi
    for FILE in `ls $PWD/.vim`
    do
        ln -s $PWD/.vim/$FILE $HOME/.vim/
        ln -s $HOME/.vim/$FILE $HOME/.config/nvim/
    done
    ln -s $HOME/.vimrc $HOME/.config/nvim/init.vim
    ln -s $PWD/after $HOME/.config/nvim/

    # coc config for nvim
    if [[ ! -d $HOME/.local/share/nvim ]];then
        mkdir -p $HOME/.local/share/nvim
    fi
    ln -s $PWD/coc-settings.json $HOME/.local/share/nvim/coc-settings.json

    # move zsh files
    ln -s $PWD/.zshrc $HOME/.zshrc

    if [[ ! -d $HOME/.oh-my-zsh ]];then
        zsh_install
    fi

    # move ranger files
    if [[ -d $HOME/.config/ranger ]] && [[ ! -L $HOME/.config/ranger ]] && [[ ! -L $HOME/.config/ranger/rc.conf ]];then
        echo "having ranger dir, deleting..."
        rm -rf $HOME/.config/ranger
    fi
    ln -s $PWD/ranger $HOME/.config/

    # move yazi files
    if [[ -d $HOME/.config/yazi ]] && [[ ! -L $HOME/.config/yazi ]] && [[ ! -L $HOME/.config/yazi/yazi.toml ]];then
        echo "having yazi dir, deleting..."
        rm -rf $HOME/.config/yazi
    fi
    ln -s $PWD/yazi $HOME/.config/

    # move tmux files
    ln -s $PWD/.tmux.conf $HOME/.tmux.conf
    ln -s $PWD/.tmux.conf.local $HOME/.tmux.conf.local

    echo finish
}

function nixpre {
    local pwd=$(pwd)
    cd $HOME/dotfiles
    nix flake lock --update-input nvim-config path:. --experimental-features 'nix-command flakes'
    nix flake lock --update-input zsh-config path:. --experimental-features 'nix-command flakes'
    nix flake lock --update-input ranger-config path:. --experimental-features 'nix-command flakes'
    nix flake lock --update-input dev-shell path:. --experimental-features 'nix-command flakes'
    cd $pwd
    echo "preinstall done"
    echo "now run: nixos-rebuild switch --flake .#[config-name]"
}

arg=$1

if [[ $arg == "main" ]];then
    main
elif [[ $arg == "nixpre" ]];then
    nixpre
else
    echo "usage: ./install.sh [main|nixpre]"
fi
