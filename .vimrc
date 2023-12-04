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
  nnoremap <silent><leader>1 :tabn 1<cr>
  nnoremap <silent><leader>2 :tabn 2<cr>
  nnoremap <silent><leader>3 :tabn 3<cr>
  nnoremap <silent><leader>4 :tabn 4<cr>
  nnoremap <silent><leader>5 :tabn 5<cr>
  nnoremap <silent><leader>6 :tabn 6<cr>
  nnoremap <silent><leader>7 :tabn 7<cr>
  nnoremap <silent><leader>8 :tabn 8<cr>
  nnoremap <silent><leader>9 :tabn 9<cr>
  nnoremap <silent><leader>0 :tabn 10<cr>
  nnoremap <silent><leader><m-n> :tabnew<cr>
  nnoremap <silent><leader><m-c> :tabclose<cr>
  nnoremap <silent><leader><m-o> :tabonly<cr>
  nnoremap <silent><leader><m-s> :tab split<cr>
else
  nnoremap <silent><leader>1 :tabn 1<cr>
  nnoremap <silent><leader>2 :tabn 2<cr>
  nnoremap <silent><leader>3 :tabn 3<cr>
  nnoremap <silent><leader>4 :tabn 4<cr>
  nnoremap <silent><leader>5 :tabn 5<cr>
  nnoremap <silent><leader>6 :tabn 6<cr>
  nnoremap <silent><leader>7 :tabn 7<cr>
  nnoremap <silent><leader>8 :tabn 8<cr>
  nnoremap <silent><leader>9 :tabn 9<cr>
  nnoremap <silent><leader>0 :tabn 10<cr>
  nnoremap <silent><leader>n :tabnew<cr>
  nnoremap <silent><leader>c :tabclose<cr>
  nnoremap <silent><leader>o :tabonly<cr>
  nnoremap <silent><leader>s :tab split<cr>
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

nnoremap <silent><right> :vertical resize+1<CR>
nnoremap <silent><up> :res +1<CR>
nnoremap <silent><down> :res -1<CR>
nnoremap <silent><left> :vertical resize-1<CR>

"保存
"nnoremap <leader><leader> :w<CR>

"快速翻页
noremap J <nop>
noremap K <nop>
noremap J 7j
noremap K 7k
noremap H <nop>
noremap L <nop>
noremap H 7h
noremap L 7l

noremap <C-q> ^
noremap <C-e> $
inoremap <c-q> <home>
" 其实可以直接设置 inoremap <c-e> <end>, 因为现在的补全框架已经不再使用pum
inoremap <expr><c-e> pumvisible() ? "\<c-e>" : "\<end>"

"make Y same as D and C
noremap Y y$

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
let $NOTMUX = 1
if has('nvim')
  "nnoremap \t :set splitbelow<CR>:15split term://zsh<cr>i
  " use toggleterm instead
  "noremap <localleader>t :set splitright<CR>:exec float2nr(&columns * 0.40) . 'vsplit'<cr>:term<cr>i
else
  "nnoremap \t :set splitbelow<CR>:terminal ++rows=15<CR>
  nnoremap \t :set splitbelow<CR>:terminal<CR>
endif

"lazygit
nnoremap <c-g> :tabe<CR>:-tabmove<CR>:term lazygit<CR>i

"quickfix
autocmd FileType qf nnoremap <silent>q :q<CR>

" 防止visual下复制之后光标移动
vnoremap y ygv<esc>

"-------------------键位映射-----------------------"}}}

"-------------------colorscheme-----------------------"{{{
"colorscheme monokai
if $LIGHT == 1
  colorscheme ghlight
else
  colorscheme ghdark
endif

set termguicolors
let g:molokai_transparent=1
"-------------------colorscheme-----------------------"}}}

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
packadd termdebug

"-------------------file type-----------------------"{{{
"for asm
autocmd BufRead *.s set filetype=asm
"for tex class
autocmd BufRead *.tex set filetype=tex
autocmd BufRead *.cls set filetype=tex
"for log
autocmd BufRead *.log set filetype=log
"for config
autocmd BufRead *.conf set filetype=config
"-------------------file type-----------------------"}}}

"hi Normal ctermbg=NONE
au BufWinEnter * if line("'\"") > 1 && line("'\"") <= line("$")  | exe "normal! g'\"" | endif " 恢复退出时的光标位置，见:h mark
set completeopt=menu,menuone,noinsert

set mouse=a
set fileformat=unix
set autoindent
filetype on
filetype plugin on
filetype plugin indent on
syntax enable                           " 打开语法高亮
syntax on                               " 开启文件类型侦测
"set paste                              "允许粘贴模式（避免粘贴时自动缩进影响格式）
set smarttab

let b:tab2=0

set shiftwidth=4
" " 让 vim 把连续数量的空格视为一个制表符
set softtabstop=4
" " 设置编辑时制表符占用空格数
set tabstop=4
" 设置格式化时制表符占用空格数

" 自定义缩进空格个数
let s:tablist = {
  \'javascript': 2,
  \'vue': 2,
  \'vim': 2,
  \'lua': 2,
  \'nix': 2,
\}
autocmd BufWinEnter * call Tab_len()
function Tab_len()
  for key in keys(s:tablist)
    if &filetype == key
      let b:tab_len = s:tablist[key]
      exec "set shiftwidth=".b:tab_len
      " 让 vim 把连续数量的空格视为一个制表符
      exec "set softtabstop=".b:tab_len
      " " 设置编辑时制表符占用空格数
      exec "set tabstop=".b:tab_len
      " 设置格式化时制表符占用空格数
    endif
  endfor
endfunction

function Delete8half()
  exec "normal 8dd"
  let halfcol = (col("$") - 1) / 2
  exec 'normal 0d' . halfcol . 'l'
endfunction

" use tpope/vim-sleuth to auto detect and adjust
" 使用空格代替制表符
set expandtab
" 对于go文件，使用tab
au BufEnter *.go setlocal noexpandtab
" set cindent "C 语言风格缩进"，会在一些文件类型下(比如nix)导致缩进错误

"使空格和缩进显示字符
set list
set listchars=tab:→\ ,trail:▫,lead:⋅
set fillchars=eob:\ ,fold:\ ,foldopen:,foldsep:\ ,foldclose:

"hi NonText ctermfg=16 guifg=#4a4a59
"hi SpecialKey ctermfg=15 guifg=#4a4a59

set autochdir                           "在打开多个文件的时候自动切换目录

set wildmenu
set wildmode=longest:full

autocmd BufReadPost *.md setlocal spell spelllang=en_us,cjk
"autocmd BufReadPost *.tex setlocal spell spelllang=en_us,cjk
"忽略中文对英文进行拼写检查
set magic
set backspace=indent,eol,start          "Make backspace behave like every other editor

set guifont=FiraCode\ Nerd\ Font:h20
set guioptions-=m
let g:neovide_cursor_animation_length=0
let g:neovide_refresh_rate=60

"---------------------Search---------------------------------"
set hlsearch
set incsearch
exec "nohlsearch"
nnoremap <silent><C-l> :nohlsearch<CR>
" syntax highlight 在光标小于1万行时从文件头开始分析
autocmd BufEnter * if line('.') < 10000 | syntax sync fromstart | endif
" syntax highlight 在文件大于20万行之后就关闭
autocmd BufEnter * if line('$') > 200000 | syntax off | endif
command! SyntaxFromStart syntax sync fromstart
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


let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
let &t_8u = "\<Esc>[58;2;%lu;%lu;%lum"

"au BufRead *.html set filetype=htmlm4 "使得html内联的css和js能够高亮"
"--------------persistent undo------------------"{{{
if has('nvim')
  if(!isdirectory(expand("~/.cache/nvim/backup")) || !isdirectory(expand("~/.cache/nvim/undo")))
    silent !mkdir -p ~/.cache/nvim/backup
    silent !mkdir -p ~/.cache/nvim/undo
  endif
  "silent !mkdir -p ~/.cache/vim/sessions
  set backupdir=~/.cache/nvim/backup,.
  set directory=~/.cache/nvim/backup,.
  if has('persistent_undo')
    set undofile
    set undodir=~/.cache/nvim/undo,.
  endif
else
  if(!isdirectory(expand("~/.cache/vim/backup")) || !isdirectory(expand("~/.cache/vim/undo")))
    silent !mkdir -p ~/.cache/vim/backup
    silent !mkdir -p ~/.cache/vim/undo
  endif
  "silent !mkdir -p ~/.cache/vim/sessions
  set backupdir=~/.cache/vim/backup,.
  set directory=~/.cache/vim/backup,.
  if has('persistent_undo')
    set undofile
    set undodir=~/.cache/vim/undo,.
  endif
endif
"--------------persistent undo------------------"}}}

"-------------------netrw-----------------------"{{{
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1
" let g:netrw_liststyle= 3

"-------------------netrw-----------------------"}}}
set diffopt=vertical
if has('nvim')
  " get the version of neovim
  let nvim_ver = luaeval("vim.version()")
  if nvim_ver.minor >= 9
    set diffopt+=linematch:50
    if !exists('g:vscode')
      let &stc='%=%s%{v:virtnum>0?"":(v:relnum?v:relnum:v:lnum)} %C'
    endif
  end
end

set synmaxcol=0 " 取消最大行数限制

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
set signcolumn=yes

" Some servers have issues with backup files, see coc.nvim #649.(has closed)
set nobackup
set nowritebackup

set hidden "不加的话会导致跳转不能跨文件，详见:h hidden

set noswapfile " 不需要swapfile，因为有自动保存
"
" check one time after 4s of inactivity in normal mode
set autoread
autocmd CursorHold * silent! checktime
set updatetime=300

if filereadable("/usr/bin/python3")
  " 省去寻找python位置的时间，加快nvim加载python文件的速度
  let g:python3_host_prog = expand('/usr/bin/python3')
end

if has('nvim')
  " highlight on yank
  au TextYankPost * silent! lua vim.highlight.on_yank{}
end

for i in ['c', 'cpp', 'lua', 'python']
  if &filetype == i
    silent! loadview
    augroup remember_folds
      autocmd!
      autocmd BufWinLeave * silent! mkview
      autocmd BufWinEnter * silent! loadview
    augroup END
  endif
endfor

if mapcheck("<leader>x") == ""
  nmap <leader>x :bd!<CR>
endif

" open all folds by default
set foldlevel=99
set foldcolumn=1

" zsh shell
set shell=zsh

" show current syntax highlighting
" neovim can use ":Inspect" instead
function! Syn()
  for id in synstack(line("."), col("."))
    echo synIDattr(id, "name")
  endfor
endfunction
command! -nargs=0 Syn call Syn()

" 设置补全窗口最大高度为15，最小宽度为50
set pumheight=15

if has('nvim')
  " set winbar highlight
  highlight WinBar guifg=#EEEEEE
  highlight WinBarNC guifg=#8B949E
  " set global statusline
  set laststatus=3
endif

" limit textwidth in markdown and latex
autocmd FileType markdown,tex set textwidth=80
set formatoptions+=m

function! s:wrapPara()
  if exists('g:vscode')
    return
  endif
  if g:wrap_on_insert_leave == 1
    normal! mf gqip `f
  endif
endfunction

" autocmd InsertLeave *.tex call s:wrapPara()
if !exists('g:wrap_on_insert_leave')
  let g:wrap_on_insert_leave = 1
endif
command! WrapToggle let g:wrap_on_insert_leave = !g:wrap_on_insert_leave

" 加载项目自定义配置(为了兼容使用.exrc)
set exrc
if filereadable(expand(getcwd() . "/.prerc.vim"))
  if has('nvim')
    " 判断是否可以安全加载prerc文件
      if luaeval('vim.secure.read(vim.fn.expand(vim.fn.getcwd() .. "/.prerc.vim")) ~= nil')
        source .prerc.vim
      endif
  endif
endif

" 重启vim，设置退出return 100为重启，需要shell相关函数支持
nnoremap <leader>rs <cmd>cquit 100<cr>

" 不要自动添加EOL
set nofixeol

" 自动删除trailing spaces
autocmd BufWritePre * :%s/\s\+$//e

"-------------------杂项-----------------------"}}}
"
"-------------------Syntax highlight-----------------------"{{{
" quick fix
highlight Comment cterm=italic gui=italic
highlight Function cterm=bold gui=bold

augroup custom_highlight
  au Syntax * syn match Todo  /\v\.<TODO:/ containedin=.*Comment.*
  au Syntax * syn match Fixme  /\v<FIXME:/ containedin=.*Comment.*
  au Syntax * syn match Note  /\v<NOTE:/ containedin=.*Comment.*
  au Syntax * syn match searchme /\v<searchme:/ containedin=.*
  au Syntax matlab syn match Operator /=/ containedin=.*
augroup END
hi! Todo guifg=#26302B guibg=#FFBD2A
hi! Fixme guifg=#26302B guibg=#F06292
if has('nvim')
  hi! Note guifg=#2AFF2C guibg=none
  hi! searchme guifg=#F06292 guibg=none gui=bold
endif

" disable luaError and luaParenError
if has('nvim')
  au FileType vim hi link luaError Normal
  au FileType vim hi link luaParenError Normal
endif
"-------------------Syntax highlight-----------------------"}}}

"-------------------加载插件-----------------------"{{{
" nvim lua 插件加载
function! TriggerPlugins() "加载插件配置以及一些原生vim插件
  if exists('g:plugins_loaded') && g:plugins_loaded == 1
    return
  endif
  let max_line = 20000 " file exceed 20000 lines will disable treesitter
  let max_size = 1024 * 1024 * 100
  if line('$') > max_line || getfsize(expand('%')) > max_size
    let b:treesitter_disable = 1
  endif
  lua lazyLoadPlugins()

  let g:plugins_loaded = 1
  " execute autocmd
  doautocmd User PluginsLoaded
endfunction

"运行无插件vim
if get(g:, 'vim_startup', 0) == 1

elseif exists('g:vscode')
  if file_readable(expand("~/.nvimrc.lua"))
    source ~/.nvimrc.lua
    lua VscodeNeovimHandler()
  endif
else
  if has('nvim')
    if file_readable(expand("~/.nvimrc.lua"))
      source ~/.nvimrc.lua
      nnoremap <leader><leader> <CMD>call TriggerPlugins()<CR><CMD>doautocmd BufRead<CR>

      let load_plugins_on_start = v:false
      if load_plugins_on_start
        call TriggerPlugins()
      elseif (len(argv()) == 0 || isdirectory(argv()[0])) && !exists('g:plugins_loaded') && !exists('g:started_by_firenvim')
        " call plugins if no args
        call TriggerPlugins()
      endif

      " call plugins if in filetype
      autocmd Filetype gitcommit call TriggerPlugins()
    endif
    " source ~/.vimrc.plugs
  else
    if filereadable(expand("~/.vimrc.plugs"))
      "set statusline=%{coc#status()}%{virtualenv#statusline()}
      source ~/.vimrc.plugs
    endif
  endif
endif

"-------------------加载插件-----------------
