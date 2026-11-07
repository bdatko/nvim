return {
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    pin = true,
    dependencies = {
      { 'nvim-lua/plenary.nvim', pin = true },
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        pin = true,
        cond = function()
          return vim.fn.executable 'make' == 1
        end
      },
      { 'nvim-telescope/telescope-ui-select.nvim', pin = true },
      -- Useful for getting pretty icons, but requires a Nerd Font.
      {
        'nvim-tree/nvim-web-devicons',
        enabled = vim.g.have_nerd_font,
        pin = true
      },
    },
    config = function()
      require "custom.telescope"
    end
  }

}
