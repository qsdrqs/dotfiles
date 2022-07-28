#!/usr/bin/env bash
echo installing

# move vim files
ln -s ./dotfiles/.vimrc ../.vimrc
ln -s ./dotfiles/.vimrc.plugs ../.vimrc.plugs
ln -s ./dotfiles/.nvimrc.lua ../.nvimrc.lua

if [[ ! -d ../.vim ]];then
    mkdir -p ../.vim
fi

# move nvim files
if [[ ! -d ../.config/nvim ]];then
    mkdir -p ../.config/nvim
fi
for FILE in `ls ./.vim`
do
    ln -s ../dotfiles/.vim/$FILE ../.vim/
    ln -s ../../.vim/$FILE ../.config/nvim/
done
ln -s $HOME/.vimrc $HOME/.config/nvim/init.vim
# coc config for nvim
if [[ ! -d $HOME/.local/share/nvim ]];then
    mkdir -p $HOME/.local/share/nvim
fi
ln -s $HOME/dotfiles/coc-settings.json $HOME/.local/share/nvim/coc-settings.json

# move zsh files
ln -s ./dotfiles/.zshrc ../.zshrc

# move ranger files
if [[ -d ../.config/ranger ]] && [[ ! -L ../.config/ranger ]];then
    echo "having ranger dir, deleting..."
    rm -rf ../.config/ranger
fi
ln -s ../dotfiles/ranger ../.config/

# move tmux files
ln -s ./dotfiles/.tmux.conf ../.tmux.conf
ln -s ./dotfiles/.tmux.conf.local ../.tmux.conf.local

echo finish
