#!/usr/bin/env bash
echo installing

# move vim files
ln -s ./dotfiles/.vimrc ../.vimrc
ln -s ./dotfiles/.vimrc.plugs ../.vimrc.plugs
ln -s ./dotfiles/.vim ../

# move nvim files
if [[ ! -d ../.config/nvim ]];then
    mkdir -p ../.config/nvim
fi
for FILE in `ls ./.vim`
do
    if [[ -d $FILE ]];then
        ln -s ../../.vim/$FILE ../.config/nvim/
    else
        ln -s ../../.vim/$FILE ../.config/nvim/$FILE
    fi
done
ln -s ../../.vimrc ../.config/nvim/init.vim

# move zsh files
ln -s ./dotfiles/.oh-my-zsh ../
ln -s ./dotfiles/.zshrc ../.zshrc

echo '#ZSH_THEME="spaceship"
ZSH_THEME="powerlevel10k/powerlevel10k"' > ../theme.zsh

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
