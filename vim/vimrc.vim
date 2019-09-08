call plug#begin('~/.vim/plugged')

" specific system
"Plug 'kien/ctrlp.vim'
"Plug 'felikz/ctrlp-py-matcher'

" npm instal at .vim/bundle/tern_for_vim
Plug 'marijnh/tern_for_vim'
Plug 'moll/vim-node'
Plug 'sheerun/vim-polyglot'
" Plug 'ervandew/supertab'
Plug 'itchyny/lightline.vim'
Plug 'leafgarland/typescript-vim'
Plug 'flazz/vim-colorschemes'
Plug 'valloric/matchtagalways'
Plug 'endel/vim-github-colorscheme'
Plug 'isruslan/vim-es6'
Plug 'epilande/vim-es2015-snippets'
Plug 'pangloss/vim-javascript'
Plug 'justinj/vim-react-snippets'
Plug 'mxw/vim-jsx'
Plug 'elzr/vim-json'
Plug 'tpope/vim-fugitive'
Plug 'junegunn/gv.vim'
Plug 'tpope/vim-scriptease'
Plug 'w0rp/ale'
Plug 'mattn/emmet-vim'
Plug 'easymotion/vim-easymotion'
Plug 'tpope/vim-surround'
Plug 'terryma/vim-multiple-cursors'
"Plug 'vim-airline/vim-airline-themes'
Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'tomtom/tlib_vim'
Plug 'honza/vim-snippets'
Plug 'vasconcelloslf/vim-interestingwords'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'ap/vim-css-color'
Plug 'garbas/vim-snipmate' "{{{
  imap <C-J> <esc>a<Plug>snipMateNextOrTrigger
  smap <C-J> <Plug>snipMateNextOrTrigger
"}}}
Plug 'scrooloose/nerdcommenter'
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' } "{{{
  nnoremap <silent> <c-b> :NERDTreeToggle<cr>
  "nnoremap <silent> <F4> :NERDTreeToggle<CR>
  nnoremap <silent> <F5> :NERDTreeFind<CR>
"}}}
Plug 'Valloric/YouCompleteMe', { 'do': './install.py --tx-completer' }
Plug 'junegunn/goyo.vim' "{{{
  nnoremap <C-K> :Goyo<cr>
"}}}
Plug 'joshdick/onedark.vim'

call plug#end()

" vim key binding
" FZF
"nnoremap <c-p> :FZF<cr>
silent! nmap <C-P> :GFiles<CR>
"enable keyboard shortcuts
let g:tern_map_keys=1
""show argument hints
let g:tern_show_argument_hints='on_hold'

" vim setting
set nocompatible
set encoding=utf8
set backspace=indent,eol,start
" Show line number
set number relativenumber
set lazyredraw
set laststatus=2
set statusline=%-4m%f\ %y\ \ %=%{&ff}\ \|\ %{&fenc}\ [%l:%c]
set incsearch hlsearch
set backspace=indent,eol,start
set nostartofline
set autoread
set scrolloff=3
set wildmenu wildignorecase wildmode=list:longest,full
set cursorline
set ignorecase smartcase
set showmode showcmd
set shortmess+=I
set hidden
set history=1000
set complete-=i completeopt=menu
set splitright splitbelow
set display+=lastline
set foldenable foldmethod=syntax foldlevelstart=99
set ttimeoutlen=50
set switchbuf=useopen
set mouse=a
set breakindent
set autoindent
set updatetime=500
set synmaxcol=400
set guifont=DejaVu\ Sans\ Mono\ for\ Powerline:h14
set spell spelllang=en_us

" NerdTree config
let g:NERDTreeDirArrowExpandable = '▸' 
let g:NERDTreeDirArrowCollapsible = '▾'
filetype plugin indent on

let g:onedark_termcolors = 256

set list
"set listchars=eol:¬,tab:▸\
if has('gui_running')
    set listchars=eol:¬,tab:▶\ ,trail:·,extends:\#,nbsp:.
else
    set listchars=tab:→\ ,eol:¬,trail:⋅,extends:❯,precedes:❮,nbsp:.
    set showbreak=↪
endif
let &showbreak = '^'
" javascript lint setup
let g:ale_sign_error = '●' " Less aggressive than the default '>>'
let g:ale_sign_warning = '.'
let g:ale_lint_on_enter = 0 " Less distracting when opening a new file
let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 0
let g:javascript_plugin_flow = 1
let g:javascript_plugin_jsdoc = 1
let g:javascript_plugin_ngdoc = 1
let g:jsx_ext_required = 0
set tabstop=2 softtabstop=0 expandtab shiftwidth=2 smarttab
let g:mta_filetypes = {
  \ 'javascript.jsx': 1,
  \}
"let g:user_emmet_leader_key='<Tab>'
let g:user_emmet_settings = {
\  'javascript.jsx' : {
\      'extends' : 'jsx',
\  },
\}
augroup javascript_folding
    au!
    au FileType javascript setlocal foldmethod=syntax
augroup END

" Start autocompletion after 4 chars
let g:ycm_min_num_of_chars_for_completion = 4
let g:ycm_min_num_identifier_candidate_chars = 4
let g:ycm_enable_diagnostic_highlighting = 0
"" Don't show YCM's preview window [ I find it really annoying ]
set completeopt-=preview
let g:ycm_add_preview_to_completeopt = 0

"if (empty($TMUX))
"  if (has("nvim"))
"    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
"  endif
"  if (has("termguicolors"))
"    set termguicolors
"  endif
"endif
set hlsearch!

nnoremap <F3> :set hlsearch!<CR>

if (has("nvim"))
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif
if (has("termguicolors"))
  set termguicolors
endif

" update style theme for airline and backspace button
" Colorscheme and themes
set background=dark
set t_Co=256
let g:lightline = {
  \ 'colorscheme': 'onedark',
  \ }
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
let g:airline_theme = 'onedark'
syntax on
colorscheme onedark
