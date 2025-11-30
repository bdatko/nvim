--Highlight when yanking (copying) text
-- try it with `yap` in normal mode
-- See `help: vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart highlight yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

--Remove line numbers when in terminal
vim.api.nvim_create_autocmd("TermOpen", {
  desc = "Turn off line numbers when using :terminal",
  group = vim.api.nvim_create_augroup("advent-of-nvim-terminal", { clear = true }),
  callback = function()
    vim.opt.number = false
    vim.opt.relativenumber = false
  end,
})
