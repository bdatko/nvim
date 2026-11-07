local out = assert(vim.env.NVIM_TEST_PINS_OUT, "NVIM_TEST_PINS_OUT is not set")

local plugins = {}

for _, plugin in ipairs(require("lazy").plugins()) do
  plugins[#plugins + 1] = {
    name = plugin.name,
    pin = plugin.pin == true,
    dir = plugin.dir,
  }
end

vim.fn.writefile({ vim.json.encode({ plugins = plugins }) }, out)
vim.cmd("qa!")
