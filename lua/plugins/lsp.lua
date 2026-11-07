return {
  {
    "neovim/nvim-lspconfig",
    pin = true,
    dependencies = {
      {
        "folke/lazydev.nvim",
        ft = "lua",
        pin = true,
        opts = { library = { path = "${3rd}/luv/library", words = { "vim%.uv" } } },
      },
    },
    config = function()
      -- nvim-lspconfig v2 ships server defaults in its `lsp/` directory.
      -- vim.lsp.config() merges these overrides on top of those defaults.
      -- `require('lspconfig')` is deprecated and will be removed in v3.
      --
      -- NOTE: `single_file_support` no longer exists. Biome's v2 config sets
      -- `workspace_required = true`, so it only starts in a real Biome project.
      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            analysis = {
              diagnosticMode = "openFilesOnly",
              -- table shape is from basedpyright/packages/vscode-pyright/package.json
              diagnosticSeverityOverrides = {
                reportUndefinedVariable = "none", -- covered by ruff (F822)
                reportUnusedImport = false, -- covered by ruff (F401)
                reportUnusedVariable = false, -- covered by ruff (F841)
              },
              inlayHints = {
                callArgumentNames = true,
              },
            },
          },
        },
      })

      vim.lsp.config("ruff", {
        init_options = {
          settings = {
            lint = {
              select = {
                "E", "F", "W", -- flake8
                "B",           -- flake8-bugbear
                "I",           -- isort
                "ARG",         -- flake8-unused-arguments
                "C4",          -- flake8-comprehensions
                "EM",          -- flake8-errmsg
                "ICN",         -- flake8-import-conventions
                "ISC",         -- flake8-implicit-str-concat
                "G",           -- flake8-logging-format
                "PGH",         -- pygrep-hooks
                "PIE",         -- flake8-pie
                "PL",          -- pylint
                "PT",          -- flake8-pytest-style
                "PTH",         -- flake8-use-pathlib
                "RET",         -- flake8-return
                "RUF",         -- Ruff-specific
                "SIM",         -- flake8-simplify
                "T20",         -- flake8-print
                "UP",          -- pyupgrade
                "YTT",         -- flake8-2020
                "EXE",         -- flake8-executable
                "NPY",         -- NumPy specific rules
                "PD",          -- pandas-vet
                "A",           -- flake8-builtins
                "FBT",         -- flake8-boolean-trap
                "N",           -- pep8-naming
                "Q",           -- flake8-bandit
                "S",           -- flake8-bandit
                "TID",         -- flake8-tidy-imports
              },
              ignore = {
                "PLR", -- Design related pylint codes
              },
            },
          },
        },
      })

      vim.lsp.enable({
        "lua_ls",
        "biome",
        "awk_ls",
        "gopls",
        "taplo",
        "basedpyright",
        "ruff",
      })

      -- Neovim 0.12 ships unconditional defaults for these keys. Re-set them
      -- once so keymap search keeps the descriptive labels; the functions are
      -- the built-ins, so behavior matches the defaults.
      vim.keymap.set("n", "grn", vim.lsp.buf.rename,
        { desc = "[G]oing [R]ight into re[N]ame" })
      vim.keymap.set({ "n", "x" }, "gra", vim.lsp.buf.code_action,
        { desc = "[G]oing [R]ight into code [A]ction" })
      vim.keymap.set("n", "gri", vim.lsp.buf.implementation,
        { desc = "[G]oing [R]ight into [I]mplementation" })
      vim.keymap.set({ "i", "s" }, "<C-S>", vim.lsp.buf.signature_help,
        { desc = "[S]ignature help" })

      -- Created once: the previous version re-created the detach augroup with
      -- clear = true on every attach, so only the newest buffer cleaned up.
      local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = true })
      local detach_augroup = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true })

      vim.api.nvim_create_autocmd("LspDetach", {
        group = detach_augroup,
        callback = function(event)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds({ group = highlight_augroup, buf = event.buf })
        end,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then return end
          if client:supports_method("textDocument/references") then
            -- Find references for the word under your cursor.
            vim.keymap.set("n", "grr",
              function() require("telescope.builtin").lsp_references() end,
              { desc = "[G]oing [R]ight into [R]eferences" })
          end
          if client:supports_method("textDocument/documentSymbol") then
            -- Fuzzy find all the symbols in your current document.
            -- Symbols are things like variables, functions, types, etc.
            vim.keymap.set("n", "gO",
              function() require("telescope.builtin").lsp_document_symbols() end,
              { desc = "[G]lobal [O]verview of document symbols" })
          end
          if client:supports_method("textDocument/definition") then
            -- Jump to the definition of the word under your cursor.
            -- This is where a variable was first declared, or where a function is defined, etc.
            -- To jump back, press <C-t>.
            vim.keymap.set("n", "grd",
              function() require("telescope.builtin").lsp_definitions() end,
              { desc = "[G]oing [R]ight into [D]efinitions" })
          end
          if client:supports_method("textDocument/typeDefinition") then
            -- Jump to the type of the word under your cursor.
            --  Useful when you're not sure what type a variable is and you want to see
            --  the definition of its *type*, not where it was *defined*.
            vim.keymap.set("n", "grt",
              function() require("telescope.builtin").lsp_type_definition() end,
              { desc = "[G]oing [R]ight into [T]ype definition" })
          end
          if client:supports_method("textDocument/declaration") then
            -- WARN: This is not Goto Definition, this is Goto Declaration.
            -- For example, in C this would take you to the header.
            vim.keymap.set("n", "grD",
              function() vim.lsp.buf.declaration() end,
              { desc = "[G]oing [R]ight into [D]eclaration" })
          end
          if client:supports_method("workspace/symbol") then
            -- Fuzzy find all the symbols in your current workspace.
            -- Similar to document symbols, except searches over your entire project.
            vim.keymap.set("n", "gwO",
              function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end,
              { desc = "[G]lobal [W]orkspace [O]verview of workspace symbols" })
          end
          if client:supports_method("textDocument/formatting") then
            vim.keymap.set("n", "<leader>f",
              function() vim.lsp.buf.format() end,
              { desc = "[F]ormat buffer" })
          end
          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          if client:supports_method("textDocument/documentHighlight") then
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buf = args.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buf = args.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })
      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = " ",
          },
        } or {},
        virtual_text = {
          source = "if_many",
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }
    end,
  }
}
