#!/usr/bin/env bash

function zsh_install(){
    # oh-my-zsh
    git clone https://github.com/ohmyzsh/ohmyzsh $HOME/.oh-my-zsh
    # plugins
    git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab &
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions &
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting &

    # themes
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k &
    git clone https://github.com/denysdovhan/spaceship-prompt ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship-prompt &

    echo "#ZSH_THEME=\"spaceship-prompt/spaceship\"" > $HOME/theme.zsh
    echo "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" > $HOME/theme.zsh
}

function main() {
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
    ln -s $PWD/after $HOME/.config/nvim/after

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
    if [[ -d $HOME/.config/ranger ]] && [[ ! -L $HOME/.config/ranger ]];then
        echo "having ranger dir, deleting..."
        rm -rf $HOME/.config/ranger
    fi
    ln -s $PWD/ranger $HOME/.config/

    # move tmux files
    ln -s $PWD/.tmux.conf $HOME/.tmux.conf
    ln -s $PWD/.tmux.conf.local $HOME/.tmux.conf.local

    echo finish
}

main
