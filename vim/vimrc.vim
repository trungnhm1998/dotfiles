" ****************************************
" Plugins
" ****************************************
call plug#begin('~/.vim/plugged')
Plug 'itchyny/lightline.vim' " For status bar
Plug 'terryma/vim-multiple-cursors' " Sublime/VSCode multi cursor
Plug 'tpope/vim-surround' " Can't live without this
Plug 'tpope/vim-fugitive' " Git Wrapper
Plug 'scrooloose/nerdtree' " File explorer editor on the left like in editor
Plug 'scrooloose/syntastic' " Syntax checking for alot of programming language
Plug 'joshdick/onedark.vim' " THEME!
Plug 'leafgarland/typescript-vim' " For typescript
Plug 'HerringtonDarkholme/yats.vim' " more typescript thingy
Plug 'Quramy/tsuquyomi' " Auto complete. I should change to YCM
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " like ctrl + p in VSCode
Plug 'justinmk/vim-sneak'
Plug 'easymotion/vim-easymotion'
call plug#end()

" ****************************************
" Basic
" ****************************************
set backspace=indent,eol,start " Bring backspace to life
set autoindent
set hidden
set ruler
set wildmenu
set number          " Line numbers
set relativenumber  " Relative line numbers
set hlsearch        " Highlight whole word when searching
set ignorecase      " Ignore case when searching...
set smartcase       " ...except when serach query contains a capital letter
"set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
"set list            " show end of line
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
filetype plugin indent on
set scrolloff=5
set so=5
set history=1000
set incsearch
set nu
set hlsearch
set visualbell
set exchange

syntax on

" fast cursor change when press ESC
set ttimeout
set ttimeoutlen=1
set listchars=tab:>-,trail:~,extends:>,precedes:<,space:.
set ttyfast

" to fix cursor shape in WSL bash add 
" echo -ne "\e[2 q"
" to .bashrc
if &term =~ "xterm"
  let &t_SI = "\<Esc>[6 q"
  let &t_SR = "\<Esc>[3 q"
  let &t_EI = "\<Esc>[2 q"
endif

if (empty($TMUX))
  if (has("nvim"))
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  if (has("termguicolors"))
    set termguicolors
  endif
endif

colorscheme onedark

" color scheme

set laststatus=2
let g:lightline = {
  \ 'colorscheme': 'onedark',
  \ }
" lightline.vim begin
if !has('gui_running')
  set t_Co=256
endif
" end

" Greatest remap EVER!! 
" Let me explain, this remap while in visual mode
" will delete what is currently highlighted and replace it 
" with what is in the register BUT it will YANK (delete) it 
" to a VOID register. Meaning I still have what I originally had
" when I pasted. I don't loose the previous thing I YANKED!
vnoremap <leader>pp "_dP

" ******************************************
" REMAP Y and P for clipboard usages
" * for main clipboard
" + for vim clipboard?
" *****************************************
noremap <Leader>y "*y
noremap <Leader>p "*p
noremap <Leader>Y "+y
noremap <Leader>P "+p


" ******************************************
" FZF Keybinding
" ******************************************
" exec :FZF using <CR>
nnoremap <silent> <C-p> :FZF<CR>

" ******************************************
" NERD Tree Keybinding
" ******************************************
" Toggle NERDTree and go to file with Find
function MintNERDTreeToggle()
  if &filetype == 'nerdtree' || exists("g:NERDTree") && g:NERDTree.IsOpen()
    :NERDTreeToggle
  else
    :NERDTreeFind
  endif
endfunction
" map NERDTree to Ctrl+Shift+E
nnoremap <C-S-e> :call MintNERDTreeToggle()<CR>