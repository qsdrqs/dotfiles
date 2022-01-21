
"              __     _____ __  __ ____   ____
"              \ \   / /_ _|  \/  |  _ \ / ___|
"               \ \ / / | || |\/| | |_) | |
"                \ V /  | || |  | |  _ <| |___
"                 \_/  |___|_|  |_|_| \_\\____|
"
"-------------------键位映射-----------------------"{{{
let &t_ut=''
let mapleader = ' '                     "The default leader is \, but a space is much better. 尽量减少小指的负担
let maplocalleader = '\'


"----------------------------------------------------------------------
" LEADER  ALT+N 切换 tab
"----------------------------------------------------------------------
if has('nvim') || has('gui_running')
  nnoremap <silent><m-1> :tabn 1<cr>
  nnoremap <silent><m-2> :tabn 2<cr>
  nnoremap <silent><m-3> :tabn 3<cr>
  nnoremap <silent><m-4> :tabn 4<cr>
  nnoremap <silent><m-5> :tabn 5<cr>
  nnoremap <silent><m-6> :tabn 6<cr>
  nnoremap <silent><m-7> :tabn 7<cr>
  nnoremap <silent><m-8> :tabn 8<cr>
  nnoremap <silent><m-9> :tabn 9<cr>
  nnoremap <silent><m-0> :tabn 10<cr>
  nnoremap <silent><leader><m-n> :tabnew<cr>
  nnoremap <silent><leader><m-c> :tabclose<cr>
  nnoremap <silent><leader><m-o> :tabonly<cr>
else
  nnoremap <silent>1 :tabn 1<cr>
  nnoremap <silent>2 :tabn 2<cr>
  nnoremap <silent>3 :tabn 3<cr>
  nnoremap <silent>4 :tabn 4<cr>
  nnoremap <silent>5 :tabn 5<cr>
  nnoremap <silent>6 :tabn 6<cr>
  nnoremap <silent>7 :tabn 7<cr>
  nnoremap <silent>8 :tabn 8<cr>
  nnoremap <silent>9 :tabn 9<cr>
  nnoremap <silent>0 :tabn 10<cr>
  nnoremap <silent><leader>n :tabnew<cr>
  nnoremap <silent><leader>c :tabclose<cr>
  nnoremap <silent><leader>o :tabonly<cr>
endif

"----------------------------------------------------------------------
" Window
"----------------------------------------------------------------------
if has('nvim') || has('gui_running')
  nnoremap <M-j> <C-W><C-J>
  nnoremap <M-k> <C-W><C-K>
  nnoremap <M-l> <C-W><C-L>
  nnoremap <M-h> <C-W><C-H>
  tnoremap <M-h> <C-\><C-N><C-w>h
  tnoremap <M-j> <C-\><C-N><C-w>j
  tnoremap <M-k> <C-\><C-N><C-w>k
  tnoremap <M-l> <C-\><C-N><C-w>l
  tnoremap <M-q> <C-\><C-n>
  inoremap <M-h> <C-\><C-N><C-w>h
  inoremap <M-j> <C-\><C-N><C-w>j
  inoremap <M-k> <C-\><C-N><C-w>k
  inoremap <M-l> <C-\><C-N><C-w>l
  nnoremap <silent><M-,> :bprevious<CR>
  nnoremap <silent><M-.> :bnext<CR>
  nnoremap <silent><M-s> <C-W>s
  nnoremap <silent><M-v> <C-W>v
  nnoremap <silent><M-c> <C-W>c
  nnoremap <silent><M-o> <C-W>o
else
  nnoremap j <C-W><C-J>
  nnoremap k <C-W><C-K>
  nnoremap l <C-W><C-L>
  nnoremap h <C-W><C-H>
  tnoremap h <C-\><C-N><C-w>h
  tnoremap j <C-\><C-N><C-w>j
  tnoremap k <C-\><C-N><C-w>k
  tnoremap l <C-\><C-N><C-w>l
  tnoremap q <C-\><C-n>
  nnoremap <silent>, :bprevious<CR>
  nnoremap <silent>. :bnext<CR>
  nnoremap <silent>s <C-W>s
  nnoremap <silent>v <C-W>v
  nnoremap <silent>c <C-W>c
  nnoremap <silent>o <C-W>o
endif
  nnoremap <right> :vertical resize+1<CR>
  nnoremap <up> :res +1<CR>
  nnoremap <down> :res -1<CR>
  nnoremap <left> :vertical resize-1<CR>



"保存
"nnoremap <leader><leader> :w<CR>

"快速翻页
noremap H <nop>
noremap J <nop>
noremap K <nop>
noremap L <nop>
noremap H 7h
noremap J 5j
noremap K 5k
noremap L 7l

noremap <C-q> ^
noremap <C-e> $
inoremap <c-q> <home>
inoremap <expr><c-e> pumvisible() ? "\<c-e>" : "\<end>"

"make Y same as D and C
noremap Y y$

"使得可以使用c-j,c-k轮询补全.
"inoremap <C-j> <Down>
"inoremap <C-k> <Up>
inoremap <expr><C-j> pumvisible() ? "\<Down>" : "\<C-j>"
inoremap <expr><C-k> pumvisible() ? "\<Up>" : "\<C-k>"

"中文符号的补全
inoremap “ “”<Left>
inoremap ‘ ‘’<Left>
inoremap ” “”<Left>
inoremap ’ ‘’<Left>
inoremap （ （）<left>
inoremap 《 《》<Left>

"" 使用 <C-l> 更改拼写错误
nnoremap <leader><C-l> <c-g>u<Esc>[s1z=`]a<c-g>u
"跳出括号（可能有更好的方法）
inoremap <C-l> <Right>
inoremap <C-h> <Left>

"Termdebug
"if has('nvim')
"  nnoremap \t :set splitbelow<CR>:15split term://zsh<cr>i
"else
"  nnoremap \t :set splitbelow<CR>:terminal ++rows=15<CR>
"endif
nnoremap <localleader>t :set splitbelow<CR>:split term://zsh<cr>i

"lazygit
nnoremap <c-g> :tabe<CR>:-tabmove<CR>:term lazygit<CR>i

"-------------------键位映射-----------------------"}}}


"-------------------colorscheme-----------------------"{{{
colorscheme monokai
set termguicolors
let g:molokai_transparent=1
"-------------------colorscheme-----------------------"}}}

"-------------------加载插件-----------------------"{{{
"运行无插件vim
if get(g:, 'vim_startup', 0) == 1

elseif exists('g:vscode')

else
  if filereadable(expand("~/.vimrc.plugs"))
    "set statusline=%{coc#status()}%{virtualenv#statusline()}
    source ~/.vimrc.plugs
  else
    "自定义的内容
  endif
endif

"-------------------加载插件-----------------------"}}}

"-------------------杂项-----------------------"{{{

set nocompatible
set fileencodings=utf-8,gb2312,gbk,gb18030
set encoding=utf-8
"显示相对行号
set relativenumber
"set t_Co=256                            "Use 256 colors.This is usefull for terminal vim.
set cursorline                          "显示当前行
set number                              "Let's activate line numbers.
"set notimeout                           "设置命令不会超时，对于冲突命令可以使用<esc>解决
set clipboard=unnamedplus               "默认使用系统剪贴板
set showcmd
"屏幕下方保留5行"可以用zz将所在行居中
set scrolloff=5
"在行尾加分号（不是很好用）
"nnoremap ;; A;
packadd termdebug

"-------------------specify type-----------------------"{{{
"for asm
autocmd BufRead *.s set filetype=asm
"for tex class
autocmd BufRead *.cls set filetype=tex
"for elsa
autocmd BufRead *.lc set filetype=haskell

"-------------------specify type-----------------------"}}}

hi Normal ctermbg=NONE
if has("autocmd")
    au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif "可以保存退出时的光标位置"
endif

set omnifunc=syntaxcomplete#Complete

set mouse=a
set fileformat=unix
filetype on
filetype plugin on
filetype plugin indent on
syntax enable                           " 打开语法高亮
syntax on                               " 开启文件类型侦测
"set paste                              "允许粘贴模式（避免粘贴时自动缩进影响格式）
set smarttab

let b:tab2=0

"TODO:改成函数返回参数的，通过返回值来设定tab大小
autocmd BufWinEnter * call Tab_len()
function Tab_len()
for i in ['js', 'vue', 'vim']
  if &filetype == i
    set shiftwidth=2
" 让 vim 把连续数量的空格视为一个制表符
    set softtabstop=2
" " 设置编辑时制表符占用空格数
    set tabstop=2
" 设置格式化时制表符占用空格数
    let b:tab2=1
  endif
endfor
endfunction

if b:tab2==0
  set shiftwidth=4
  " " 让 vim 把连续数量的空格视为一个制表符
  set softtabstop=4
  " " 设置编辑时制表符占用空格数
  set tabstop=4
  " 设置格式化时制表符占用空格数
endif

set expandtab
set smartindent "智能缩进"
set cindent "C 语言风格缩进"
set autoindent "自动缩进"

"使空格和缩进显示字符
set list
set listchars=tab:▸\ ,trail:▫
"hi NonText ctermfg=16 guifg=#4a4a59
"hi SpecialKey ctermfg=15 guifg=#4a4a59

set autochdir                           "在打开多个文件的时候自动切换目录

set wildmenu
set wildmode=longest:full

autocmd BufReadPost *.md setlocal spell spelllang=en_us,cjk
autocmd BufReadPost *.tex setlocal spell spelllang=en_us,cjk
"忽略中文对英文进行拼写检查
set magic
set backspace=indent,eol,start          "Make backspace behave like every other editor

set guifont=FiraCode\ Nerd\ Font\ 9.5
set guioptions-=m

"---------------------Search---------------------------------"
set hlsearch
set incsearch
exec "nohlsearch"
nnoremap <silent><C-l> :<C-u>nohlsearch<CR><C-l>
set ignorecase smartcase
"搜索时忽略大小写，但在有一个或以上大写字母时仍保持对大小写敏感
"---------------------Search---------------------------------"

let g:termdebug_wide = 1
if !has('nvim')
  "把 vim 插入状态的光标改为竖线 For VTE compatible terminals (urxvt, st, xterm,
  "gnome-terminal 3.x, Konsole KDE5 and others)(neovim 不需要)
  "
  let &t_TI = "\<Esc>[2 q"
  let &t_SI = "\<Esc>[6 q"
  let &t_SR = "\<Esc>[4 q"
  let &t_EI = "\<Esc>[2 q"
endif

highlight Comment cterm=italic gui=italic
highlight Function cterm=bold gui=bold

let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"

"au BufRead *.html set filetype=htmlm4 "使得html内联的css和js能够高亮"
"-------------------netrw-----------------------"{{{
"let g:netrw_liststyle= 3

"-------------------netrw-----------------------"}}}
set diffopt=vertical

set synmaxcol=0 " 取消最大行数限制

"-------------------杂项-----------------------"}}}


"-------------------加载项目自定义配置-----------------------"{{{
"function! LoadProjectCustomConfig()
"endfunction
"autocmd BufEnter * call LoadProjectCustomConfig()
if filereadable(expand(getcwd() . "/custom.vim"))
  source custom.vim
endif
"-------------------加载项目自定义配置-----------------------"}}}
