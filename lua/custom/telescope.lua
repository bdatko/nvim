local data_rtp = assert( vim.fn.stdpath "data" ) --[[@as string]]


-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
require("telescope").setup {
  -- You can put your default mappings / updates / etc. in here
  --  All the info you're looking for is in `:help telescope.setup()`
  --
  -- defaults = {
  --   mappings = {
  --     i = { ["<c-enter>"] = "to_fuzzy_refine" },
  --   },
  -- },
  -- pickers = {}
  extensions = {
    fzf = {},
  },
}
-- Enable Telescope extensions if they are installed
pcall(require("telescope").load_extension, "fzf")
pcall(require("telescope").load_extension, "ui-select")

local builtin = require "telescope.builtin"

vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "[F]ind [F]iles" })
-- Shortcut for searching your Neovim configuration files
vim.keymap.set("n", "<leader>en",
  function()
    builtin.find_files { cwd = vim.fn.stdpath "config" }
  end,
  { desc = "[E]dit [N]eovim files" }
)
vim.keymap.set("n", "<leader>hs", builtin.help_tags, { desc = "[H]elp [S]earch" })
vim.keymap.set("n", "<leader>fa",
  function()
    -- not sure why, but cannot use the local builtin...?
    require("telescope.builtin").find_files {
      cwd = vim.fs.joinpath(data_rtp, "lazy")
    }
  end,
  { desc = "[F]ind [A]ll plugins" }
)
vim.keymap.set("n", "<leader>km", builtin.keymaps, { desc = "search [K]ey[M]aps" })
vim.keymap.set("n", "<leader>tsb", builtin.builtin, { desc = "search [T]elescope then [S]elect [B]uiltin"})
vim.keymap.set("n", "<leader>fg", require "custom/telescope/multi-ripgrep", { desc = "[F]ind using rip-[G]rep" })
vim.keymap.set("n", "<leader>dl", builtin.diagnostics, { desc = "[D]iagnostics [L]ist" })

-- It's also possible to pass additional configuration options.
--  See `:help telescope.builtin.live_grep()` for information about particular keys
vim.keymap.set("n", "<leader>s/", function()
  builtin.live_grep {
    grep_open_files = true,
    prompt_title = "Live Grep in Open Files",
  }
end, { desc = "[S]earch [/] in Open Files" })
