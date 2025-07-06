vim.g.has_nerd_font = true

-- Setting opts
vim.opt.number = true
vim.opt.relativenumber = true

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Don't show the mode, since it's already in the status line
-- since I am using mini.nvim
vim.opt.showmode = false

-- Enable break indent
vim.opt.breakindent = true

-- Disable line wrapping
vim.opt.wrap = false


-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep sign column on by default
vim.opt.signcolumn = "yes"

-- Decrease the update time
vim.opt.updatetime = 1000

-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 500

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help "list"`
--  and `:help "listchars"`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.colorcolumn = "88"

-- From ThePrimeagen
-- https://github.com/ThePrimeagen/init.lua/blob/master/lua/theprimeagen/set.lua#L17
-- Save undo history
vim.opt.undofile = true
vim.opt.swapfile = false

-- Turning off the python provide meaning no python plugins
-- see :h g:python3_host_prog
-- this added a lot to the startup time without specificing a neovim venv
vim.g.loaded_python3_provider = 0
