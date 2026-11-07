local out = assert(vim.env.NVIM_TEST_STARTUP_OUT, "NVIM_TEST_STARTUP_OUT is not set")
local cap = _G.__test_capture or { notifications = {}, deprecations = {} }

local messages = vim.api.nvim_exec2("messages", { output = true }).output or ""

vim.fn.writefile({
  vim.json.encode({
    notifications = cap.notifications,
    deprecations = cap.deprecations,
    messages = messages,
  }),
}, out)

vim.cmd("qa!")
