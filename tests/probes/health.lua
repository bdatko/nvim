local out = assert(vim.env.NVIM_TEST_HEALTH_OUT, "NVIM_TEST_HEALTH_OUT is not set")

vim.cmd("checkhealth vim.lsp")
vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), out)
vim.cmd("qa!")
