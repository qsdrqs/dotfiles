#
#       _________  _   _ ____   ____
#      |__  / ___|| | | |  _ \ / ___|
#        / /\___ \| |_| | |_) | |
#       / /_ ___) |  _  |  _ <| |___
#      /____|____/|_| |_|_| \_\\____|
#
tmux_new_or_attach() {
    if tmux has-session -t $1 2>/dev/null; then
        vared -p "session $1 exist, want to attach? [Enter/session_name/n]" -c attach
        # delete all '\n' in the string
        attach=${attach//$'\n'/}
        if [[ $attach == "" ]]; then
            tmux attach-session -t $1
        elif [[ $attach != "n" ]]; then
            tmux attach-session -t $attach || tmux new-session -s $attach
        fi
    else
        tmux new-session -s $1
    fi
}

call_tmux() {
    if [[ $2 != "" ]]; then
        (tmux new-window -c $2 && tmux attach-session -t $1) || tmux new-session -s $1
    else
        tmux_new_or_attach $1
    fi
}

if [[ $NOTMUX != 1 ]]; then
    if [[ -x `command -v tmux` ]] && [[ $TMUX == "" ]]; then
        if [[ $WSLPATH != "" ]]; then
            session_name="wsl"
            call_tmux $session_name
        elif [[ "$SSH_CONNECTION" != ""  ]]; then
            session_name="ssh"
            if [[ -x `command -v notify-send` ]]; then
                (timeout 3 notify-send "ssh connected" &)
            fi
            call_tmux $session_name
            #elif [[ "$XDG_SESSION_DESKTOP" == "KDE" ]]; then
            #export session_name="kde"
            #export position=`pwd`
            #call_tmux $session_name $position
        fi
    fi
fi

setopt nonomatch
setopt autocd
setopt re_match_pcre

# history
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=500000
export SAVEHIST=500000
setopt HIST_SAVE_NO_DUPS
setopt HIST_EXPIRE_DUPS_FIRST

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH=$HOME/.local/bin:$HOME/.local/sbin:$PATH
# vman
export PATH="$PATH:$HOME/.vim/plugged/vim-superman/bin"
# haskell
export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
# rust
export PATH="$HOME/.cargo/bin:$PATH"
# nvim mason
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
# wasmtime
export WASMTIME_HOME="$HOME/.wasmtime"
export PATH="$WASMTIME_HOME/bin:$PATH"
# go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env" # ghcup-env

# use console to type gpg passphrase
export GPG_TTY=$(tty)

#Make alacritty compatible with SSH
# if [[ $TERM != "xterm-kitty" && $TMUX != "" ]]; then
#     export TERM="xterm-256color"
# elif [[ $TERM == "xterm" ]]; then
#     export TERM="xterm-256color"
# elif [[ $TERM == "linux" ]]; then
#     export TERM="xterm-256color"
# elif [[ $TERM == "xterm-kitty" ]]; then
#     # alias ssh
#     # alias ssh="kitty +kitten ssh"
# fi

# disable ranger load default rc
export RANGER_LOAD_DEFAULT_RC=false

source $HOME/theme.zsh
if [ -e $HOME/extra.zsh ]; then
    source $HOME/extra.zsh
fi

plugins=(
vi-mode
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
fzf-tab
)

# 光标形状随模式改变
zle -N zle-keymap-select
echo -ne '\e[5 q'

#To make zsh colorful by grc
[[ -s "/etc/grc.zsh"  ]] && source /etc/grc.zsh
# for gentoo
[[ -s "/usr/share/grc/grc.zsh"  ]] && source /usr/share/grc/grc.zsh
# for termux
[[ -s "$HOME/grc/grc.zsh"  ]] && source $HOME/grc/grc.zsh

# 加快加载速度
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# init zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}}/zinit"
source "${ZINIT_HOME}/zinit.zsh"

# load zinit plugins
# need compinit
zicompinit
zinit light $HOME/.zsh/plugins/fast-syntax-highlighting
zinit light $HOME/.zsh/plugins/zsh-vi-mode
zinit light $HOME/.zsh/plugins/zsh-autosuggestions

# load plugins from oh-my-zsh
zinit snippet $HOME/.oh-my-zsh/lib/completion.zsh
zinit light $HOME/.oh-my-zsh/plugins/systemd
zinit light $HOME/.oh-my-zsh/plugins/fd

zinit wait lucid for $HOME/.oh-my-zsh/plugins/fzf
zinit wait lucid for $HOME/.zsh/plugins/fzf-tab

# load zinit themes
zinit light $HOME/.zsh/themes/$ZSH_THEME

# 光标形状随模式改变
function zle-keymap-select {
	if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
		echo -ne '\e[1 q'
	elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
		echo -ne '\e[5 q'
  fi
}

ZVM_VI_HIGHLIGHT_BACKGROUND=#163356
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT

ZSH_COLORIZE_STYLE="colorful"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=blue"

zstyle ':fzf-tab:complete:cd:*' extra-opts --preview=$extract'exa -1 --color=always $realpath'
# export FZF_BASE=/usr/share/fzf
export FZF_DEFAULT_COMMAND='fd'
# TODO: 预览有问题
#export FZF_DEFAULT_OPTS='--preview "[[ $(file --mime {}) =~ binary ]] && echo {} is a binary file || (ccat --color=always {} || highlight -O ansi -l {} || cat {}) 2> /dev/null | head -500"'
export FZF_COMPLETION_TRIGGER='\'

if [[ $LIGHT == 1 ]]; then
    zstyle ':fzf-tab:*' default-color $'\033[38;5;240m'
    zstyle ":fzf-tab:*" fzf-flags --height=70% --layout=reverse \
        --color "fg:#970b16,hl:#87d5a2,fg+:#970b16,bg+:#919191,hl+:#87d5a2" \
        --color "info:#83a598,prompt:#bdae93,spinner:#87d5a2,pointer:#83a598,marker:#fe8019,header:#665c54"
fi

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
# export PAGER=nvimpager

# 添加家目录
hash -d nvim=~/.local/share/nvim

# python虚拟环境
if [ -e "/usr/bin/virtualenvwrapper.sh" ]; then
    export VIRTUALENVWRAPPER_PYTHON=/bin/python3
    export WORKON_HOME=~/.virtualenvs
    export PROJECT_HOME=~/PythonProject
    # NOTE: temporary disable error output
    source /usr/bin/virtualenvwrapper.sh 2>/dev/null
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the .zsh folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias af="alias-finder"
alias lg="lazygit"
alias t="tmux"
alias c="clear"
alias f="fastfetch"
alias n="neofetch"
alias ra="ranger"
alias ya-cli="\ya"
alias ya="yazi"
alias zshrc="$EDITOR $HOME/dotfiles/.zshrc"
alias vimrc="$EDITOR $HOME/dotfiles/.vimrc"
alias vimplug="$EDITOR $HOME/dotfiles/.vimrc.plugs"
alias nvimplug="$EDITOR $HOME/dotfiles/.nvimrc.lua"
alias ls='lsd'
alias ll="ls -l"
alias la="ls -la"
alias load_key_env="source $HOME/dotfiles/nixos/scripts/load_key_env.sh"

# Arch
alias sp="sudo pacman"

# Gentoo
alias sem="sudo emerge -av"
alias sem-deselect="sudo emerge --deselect --ask"
alias sem-depclean="sudo emerge --ask --depclean"
alias sem-update="sudo emerge --ask --verbose --update --deep --newuse --with-bdeps=y @world"

# NixOS
snr-switch() {
    local original_pwd=$(pwd)
    trap "cd ${original_pwd}" EXIT
    sudo echo "building system"
    cd $HOME/dotfiles && find -name "*sync-conflict*" -exec rm {} \;
    # bash ./install.sh nixpre || return 1
    trap "cd ${original_pwd}" INT

    if [[ $1 == "droid" ]]; then
        nix-on-droid switch --flake path:.
    else
        sudo nixos-rebuild switch --flake path:.#$@
    fi
}
snr-switch-remote() {
    local original_pwd=$(pwd)
    trap "cd ${original_pwd}" EXIT
    sudo echo "building system"
    cd $HOME/dotfiles && find -name "*sync-conflict*" -exec rm {} \;

    if [[ -L ./result ]];then
        echo "find result link, directly use it"
    else
        # bash ./install.sh nixpre || return 1
        trap "cd ${original_pwd}" INT
        nixos-rebuild build --flake path:.#$@
    fi
    sudo nix-env -p /nix/var/nix/profiles/system --set $(readlink -f result) && \
    (
        sudo ./result/bin/switch-to-configuration switch
        if [[ -L ./result ]];then
            rm result
        fi
    )
}
hm-switch() {
    local original_pwd=$(pwd)
    trap "cd ${original_pwd}" EXIT
    cd $HOME/dotfiles && find -name "*sync-conflict*" -exec rm {} \;
    # bash ./install.sh nixpre || return 1
    trap "cd ${original_pwd}" INT
    home-manager switch --flake path:.#$@
}
nix-devel() {
    local last_env=$NIX_DEV
    local command=""
    local envs=$last_env
    for i in $@; do
        command="$command nix develop path:$HOME/dotfiles#$i --command"
        envs="$envs $i"
    done
    export NIX_DEV=$envs
    command="$command zsh"
    echo $command
    eval $command
    export NIX_DEV=$last_env
}

# direnv for nix flakes
export DIRENV_LOG_FORMAT=
if [[ -x `command -v direnv` ]]; then
    eval "$(direnv hook zsh)"
fi

export PROX=127.0.0.1
alias prox="export http_proxy=http://$PROX:1081\
&& export https_proxy=http://$PROX:1081\
&& export all_proxy=http://$PROX:1081\
&& export ftp_proxy=http://$PROX:1081
"
alias tra="~/translate-shell/build/trans :zh+en"
alias vim="nvim"
alias vimm="\vim"
# if [[ -x `command -v code-insiders` ]]; then
#     alias code="code-insiders"
# fi
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
    mkdir -p "$1" && cd "$1"
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
if [[ -f ~/.p10k.zsh ]]; then
    source ~/.p10k.zsh
elif [[ -f $ZDOTDIR/.p10k.zsh ]]; then
    source $ZDOTDIR/.p10k.zsh
fi
# set $NIX_DEV
typeset -g POWERLEVEL9K_NIX_SHELL_CONTENT_EXPANSION=$NIX_DEV


#vi-mode
function vi-forward-7-char {
    zle vi-forward-char -n 7
}

function vi-backward-7-char {
    zle vi-backward-char -n 7
}

zle -N vi-forward-7-char
zle -N vi-backward-7-char

# undefine the stty start/stop
unsetopt flow_control

WORDCHARS=${WORDCHARS/\/}
WORDCHARS=${WORDCHARS/./}
WORDCHARS=${WORDCHARS/\#/}
WORDCHARS=${WORDCHARS/-/}

#set -o vi
bindkey -M viins '^L' vi-forward-char
bindkey -M viins '^w' backward-kill-word
bindkey -M viins '^H' vi-backward-char
bindkey -M vicmd 'L'  vi-forward-7-char
bindkey -M vicmd 'H'  vi-backward-7-char
bindkey -M vicmd '^q' vi-beginning-of-line
bindkey -M vicmd '^e' vi-end-of-line

function zvm_after_lazy_keybindings() {
    bindkey -M vicmd 'V' zvm_vi_edit_command_line
}


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

#Make alacritty show colors
unset LSCOLORS
unset LS_COLORS

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
GITSTATUS_LOG_LEVEL=DEBUG

# z.sh
if [[ -x `command -v zoxide` ]]; then
    eval "$(zoxide init zsh)"

    # Completions function rewrite
    # Modified from github:ajeetdsouza/zoxide/templates/zsh.txt
    # which is under MIT License: https://github.com/ajeetdsouza/zoxide/blob/main/LICENSE
    function __zoxide_z_complete() {
        # Only show completions when the cursor is at the end of the line.
        # shellcheck disable=SC2154
        [[ "${#words[@]}" -eq "${CURRENT}" ]] || return 0

        \builtin local result
        # shellcheck disable=SC2086,SC2312
        if result="$(\command zoxide query --exclude "$(__zoxide_pwd)" --interactive -- ${words[2,-1]})"; then
            result="${__zoxide_z_prefix}${result}"
            # shellcheck disable=SC2296
            compadd -U -Q "${(q-)result}"
        fi
        \builtin printf '\e[5n'
        return 0
    }
elif [[ -x `command -v lua` ]]; then
    eval "$(lua $HOME/.zsh/plugins/z_lua/z.lua --init zsh)"
else
    source $HOME/.zsh/plugins/z/z.sh
    export _Z_SRC=$HOME/.zsh/plugins/z/z.sh
    ZSH_DISABLE_COMPFIX=true

    _z_zsh_tab_completion() {
        # tab completion
        reply=(${(f)"$(_z --complete "$compl")"})
        _describe 'values' reply
    }

    compdef _z_zsh_tab_completion _z
fi

# pyenv: not load by default due to performance issue
# if [[ -x `command -v pyenv` ]]; then
#     eval "$(pyenv init -)"
#     eval "$(pyenv virtualenv-init -)"
# fi

# wrapper for vim to support restart
# vim() {
#     while true; do
#         $EDITOR "$@"
#         RET=$?
#         if [[ $RET != 100 ]]; then
#             return $RET
#         fi
#     done
# }

if [[ -S /tmp/ssh-agent.sock ]]; then
    export SSH_AUTH_SOCK=/tmp/ssh-agent.sock
elif [[ -n $XDG_RUNTIME_DIR ]]; then
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
        ssh-agent > "$XDG_RUNTIME_DIR/ssh-agent.env"
    fi
    if [[ ! -S "$SSH_AUTH_SOCK" ]] && [[ ! -f "$SSH_AUTH_SOCK" ]]; then
        if [[ -f "$XDG_RUNTIME_DIR/ssh-agent.env" ]]; then
            source "$XDG_RUNTIME_DIR/ssh-agent.env" >/dev/null
        fi
    fi
fi

# Change Yazi's CWD to PWD on subshell exit
if [[ -n $YAZI_ID ]]; then
    function _yazi_cd() {
        ya-cli emit cd "$PWD"
        # ya-cli pub-to "$YAZI_ID" dds-cd --str "$PWD"
    }
    add-zsh-hook zshexit _yazi_cd
fi

ghcs() {
    eval "$(gh copilot alias -- zsh)"
    ghcs $@
}


