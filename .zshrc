#
#       _________  _   _ ____   ____
#      |__  / ___|| | | |  _ \ / ___|
#        / /\___ \| |_| | |_) | |
#       / /_ ___) |  _  |  _ <| |___
#      /____|____/|_| |_|_| \_\\____|
#
call_tmux(){
    if [[ $2 != "" ]];then
        (tmux new-window -c $2 && tmux attach-session -t $1) || tmux new-session -s $1
    else
        tmux attach-session -t $1 || tmux new-session -s $1
    fi
}

if [[ -x `command -v tmux` ]] && [[ $TMUX == "" ]]; then
    if [[ -e "$HOME/wsl" ]]; then
        export session_name="wsl"
        call_tmux $session_name
    elif [[ "$SSH_CONNECTION" != ""  ]]; then
        export session_name="ssh"
        call_tmux $session_name
    #elif [[ "$XDG_SESSION_DESKTOP" == "KDE" ]]; then
        #export session_name="kde"
        #export position=`pwd`
        #call_tmux $session_name $position
    fi
fi

setopt nonomatch
source $HOME/dotfiles/z/z.sh
ZSH_DISABLE_COMPFIX=true
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
# rust
export PATH=$HOME/.local/bin:$HOME/.local/sbin:$HOME/.cargo/bin:$PATH
# vman
export PATH="$PATH:$HOME/.vim/plugged/vim-superman/bin"
#haskell
export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

#Make alacritty compatible with SSH
export TERM="xterm-256color"
# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="spaceship"
# ZSH_THEME="powerlevel10k/powerlevel10k"
source ~/theme.zsh
# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
vi-mode
alias-finder #af
systemd
git
colored-man-pages
#使ccat和cless有色彩
colorize
zsh-autosuggestions
fast-syntax-highlighting
#替代find命令
fd
ubuntu
#像ubuntu一样提示要安装的软件包
command-not-found
#找文件 (CTRL-T, CTRL-R, ALT-C):
fzf
#fzf-tab
)

#To make zsh colorful by grc
[[ -s "/etc/grc.zsh"  ]] && source /etc/grc.zsh

# 光标形状随模式改变
zle -N zle-keymap-select
echo -ne '\e[5 q'
# 加快加载速度
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#init zsh
source $ZSH/oh-my-zsh.sh
source $ZSH/custom/plugins/fzf-tab/fzf-tab.zsh

# 光标形状随模式改变
function zle-keymap-select {
	if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
		echo -ne '\e[1 q'
	elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
		echo -ne '\e[5 q'
  fi
}

ZSH_COLORIZE_STYLE="colorful"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=blue"

zstyle ':fzf-tab:complete:cd:*' extra-opts --preview=$extract'exa -1 --color=always $realpath'
export FZF_BASE=/usr/share/fzf
export FZF_DEFAULT_COMMAND='fd'
# TODO: 预览有问题
#export FZF_DEFAULT_OPTS='--preview "[[ $(file --mime {}) =~ binary ]] && echo {} is a binary file || (ccat --color=always {} || highlight -O ansi -l {} || cat {}) 2> /dev/null | head -500"'
export FZF_COMPLETION_TRIGGER='\'


# User configuration

# export MANPATH="/usr/local/man:$MANPATH"
# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -x `command -v nvim` ]]; then
    export EDITOR='nvim'
    export VISUAL='nvim'
else
    export EDITOR='vim'
    export VISUAL='vim'
fi
# 使用nvim作为默认pager
export PAGER=nvimpager

# python虚拟环境
if [ -e "/usr/bin/virtualenvwrapper.sh" ]; then
    export VIRTUALENVWRAPPER_PYTHON=/bin/python3
    export WORKON_HOME=~/.virtualenvs
    export PROJECT_HOME=~/PythonProject
    source /usr/bin/virtualenvwrapper.sh
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias af="alias-finder"
alias lg="lazygit"
alias t="tmux"
alias sp="sudo pacman"
alias c="clear"
alias n="neofetch"
alias ra="ranger"
alias zshrc="$EDITOR ~/.zshrc"
alias vimrc="$EDITOR ~/.vimrc"
alias vimplug="$EDITOR ~/.vimrc.plugs"

export PROX=127.0.0.1
alias prox="export http_proxy=http://$PROX:1081\
&& export https_proxy=http://$PROX:1081\
&& export all_proxy=http://$PROX:1081\
&& export ftp_proxy=http://$PROX:1081
"
alias tra="python3 ~/translator/translator.py"
alias vim="$EDITOR"
alias vimm="/usr/bin/vim"
alias vi="$EDITOR --cmd 'let g:vim_startup=1'"
#Turn off the touch pad 
#Sometimes system suspend will make touchpad unable to work, so it needs 3 times to make it work.
alias to="/sbin/trackpad-toggle.sh"
alias sshconfig="vim ~/.ssh/config"
alias ta="python ~/.vim/plugged/asynctasks.vim/bin/asynctask.py -f"

#avoid mistakes
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
mkcd() {
    mkdir -p $1 && cd $1
}

# global replacement
glorep() {
    count=0
    if [[ -x `command -v rg` ]]; then
        for item in `rg -l "$1" ./`; do
            sed -i "s/$1/$2/g" $item
            let count+=1
        done
    else
        for item in `grep -rl "$1" ./`; do
            sed -i "s/$1/$2/g" $item
            let count+=1
        done
    fi

    echo "successfully changed \033[32m$count\033[0m files of \"$1\" into \"$2\"."
}
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


#ranger
export RANGER_LOAD_DEFAULT_RC=FALSE

#vi-mode
# TODO:看看文档找找更好的办法
function vi-forward-7-char {
    zle vi-forward-char
    zle vi-forward-char
    zle vi-forward-char
    zle vi-forward-char
    zle vi-forward-char
    zle vi-forward-char
    zle vi-forward-char
}

function vi-backward-7-char {
    zle vi-backward-char
    zle vi-backward-char
    zle vi-backward-char
    zle vi-backward-char
    zle vi-backward-char
    zle vi-backward-char
    zle vi-backward-char
}

zle -N vi-forward-7-char
zle -N vi-backward-7-char

#set -o vi
bindkey -M viins '^L' vi-forward-char
bindkey -M viins '^w' backward-kill-word
bindkey -M viins '^H' vi-backward-char
bindkey -M vicmd 'L'  vi-forward-7-char
bindkey -M vicmd 'H'  vi-backward-7-char
bindkey -M vicmd '^q' vi-beginning-of-line
bindkey -M vicmd '^e' vi-end-of-line
bindkey -M vicmd 'V' edit-command-line


KEYTIMEOUT=1

if [[ -x `command -v thefuck` ]]; then
    eval $(thefuck --alias)
fi
# This speeds up pasting w/ autosuggest 
# https://github.com/zsh-users/zsh-autosuggestions/issues/238
paste-init() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
}

paste-finish() {
  zle -N self-insert $OLD_SELF_INSERT
}
zstyle :bracketed-paste-magic paste-init pasteinit 
zstyle :bracketed-paste-magic paste-finish pastefinish

alias ls='lsd'
#Make alacritty show colors
unset LSCOLORS
unset LS_COLORS

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
GITSTATUS_LOG_LEVEL=DEBUG
compdef vman="man"

pyenvon(){
    if [[ -x `command -v pyenv` ]]; then
        eval "$(pyenv init -)"
        eval "$(pyenv init --path)"
        eval "$(pyenv virtualenv-init -)"
        export PYENV_VIRTUALENV_DISABLE_PROMPT=1
    fi
}
