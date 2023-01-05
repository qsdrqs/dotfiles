#!/usr/bin/env bash
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
