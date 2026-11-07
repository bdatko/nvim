local out = assert(vim.env.NVIM_TEST_DEPRECATED_OUT, "NVIM_TEST_DEPRECATED_OUT is not set")
local proj = assert(vim.env.NVIM_TEST_PROJECT, "NVIM_TEST_PROJECT is not set")

vim.cmd.edit(proj .. "/a.lua")

vim.wait(15000, function()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client.name == "lua_ls" then
      return true
    end
  end

  return false
end, 100)

vim.cmd("checkhealth vim.deprecated")
vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), out)
vim.cmd("qa!")
