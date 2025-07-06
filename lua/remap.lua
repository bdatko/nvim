vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<CR>", { desc = "Source current file" })
vim.keymap.set("n", "<leader>x", "<cmd>:.lua<CR>", { desc = "Execute the current line" })
vim.keymap.set("v", "<leader>x", ":'<,'>lua<CR>", { desc = "Execute the current visual selection" })

-- Disable PageUp and PageDown
vim.keymap.set({"n", "i", "x"}, "<PageUp>", '<cmd>echo "Disabled! Use <C-B> instead"<CR>')
vim.keymap.set({"n", "i", "x"}, "<PageDown>", '<cmd>echo "Disabled! Use <C-F> instead"<CR>')

-- Disable arrow keys
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

vim.keymap.set("i", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("i", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("i", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("i", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Some of these are from ThePrimeagen https://github.com/ThePrimeagen/init.lua/blob/master/lua/theprimeagen/remap.lua
-- Better vertical movemoment from ThePrimeagen
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Move half a page [U]p then center screen" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Move half a page [D]own then center screen" })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Move highlighted text from ThePrimeagen
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move highlighted text Down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move highlighted text Up" })

-- From ThePrimeagen
vim.keymap.set("n", "J", "mzJ`z", { desc = "Keep the cursor in place when [J]oining lines." })

-- From ThePrimeagen
vim.keymap.set("n", "n", "nzzzv", { desc = "Keep search terms centered on the screen when going down" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Keep search terms centered on the screen when going up" })

-- From ThePrimeagen
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]], { desc = "[Y]ank into the system clipboard" })
vim.keymap.set("n", "<leader>Y", [["+Y]], { desc = "[Y]ank lines into the system clipboard" })

-- From ThePrimeagen
vim.keymap.set("n", "<leader>b", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "su[B]stitute all matches under the cursor interactively" })

-- From ThePrimeagen
vim.keymap.set("n", "<A-k>", "<cmd>cnext<CR>zz", { desc = "Better next quickfix navigation" })
vim.keymap.set("n", "<A-j>", "<cmd>cprev<CR>zz", { desc = "Better previous quickfix navigation" })
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Better next location list navigation" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Better previous location list navigation" })

-- From ThePrimeagen
vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "[P]aste over selection while preserving paste register" })

vim.keymap.set("n", "<leader>mj", "<cmd>!chmod +x %<CR>", { desc = "Change the current file's [M]ode to exec[J]utable", silent = true })

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
-- Remaps for default LSP integration
-- See: https://github.com/neovim/neovim/pull/28650/files#diff-49225a49c226c2f1b36f966d0178c556e204cdc0b660c80db9e4568e03f6ef99
