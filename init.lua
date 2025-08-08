P = function(v)
  print(vim.inspect(v))
  return v
end

if pcall(require, "plenary") then
  RELOAD = require("plenary.reload").reload_module

  R = function(name)
    RELOAD(name)
    return require(name)
  end
end

-- map leader to space
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("set")
require("remap")
require("autocmd")
require("config.lazy")

