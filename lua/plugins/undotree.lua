return {
  {
    "mbbill/undotree",
    pin = true,
    config = function()
      vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle [U]ndotree"})
    end
  }
}
