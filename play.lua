local prompt = "App  *.py"

local pieces = vim.split(prompt, "  ")

local args   = { "rg" }

if pieces[1] then
  table.insert(args, "-e")
  table.insert(args, pieces[1])
end

if pieces[2] then
  table.insert(args, "-g")
  table.insert(args, pieces[2])
end

local flags = {
  "--color=never",
  "--no-heading",
  "--with-filename",
  "--line-number",
  "--column",
  "--smart-case"
}

local result = vim.iter(args, flags):flatten():totable()
vim.print(result)
