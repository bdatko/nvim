return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "folke/lazydev.nvim",
      ft = "lua",
      opts = { library = { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },

    },
    config = function()
      require("lspconfig").lua_ls.setup {}

      require 'lspconfig'.biome.setup {single_file_support = true}

      require'lspconfig'.awk_ls.setup{}

      require'lspconfig'.gopls.setup{}

      require("lspconfig").basedpyright.setup {
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
                callArgumentNames = true
              }
            }
          }
        }
      }

      require("lspconfig").ruff.setup({
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
                "N",           -- prep8-naming
                "Q",           -- flake8-bandit
                "S",           -- flake8-bandit
                "TID",         -- flake8-tidy-imports
              },
              ignore = {
                "PLR", -- Design related pylint codes
              },
            },
          }
        }
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then return end
          -- rename the variable under your cursor.
          -- most language servers support renaming across files, etc.
          if client.supports_method("textDocument/rename") then
            vim.keymap.set("n", "grn",
              function() vim.lsp.buf.rename() end,
              { desc = "[G]oing [R]ight into re[N]ame" })
          end
          if client.supports_method("textDocument/codeAction") then
            -- Execute a code action, usually your cursor needs to be on top of an error
            -- or a suggestion from your LSP for this to activate.
            vim.keymap.set({ "n", "x" }, "gra",
              function() vim.lsp.buf.code_action() end,
              { desc = "[G]oing [R]ight into code [A]ction" })
          end
          if client.supports_method("textDocument/references") then
            -- Find references for the word under your cursor.
            vim.keymap.set("n", "grr",
              function() require("telescope.builtin").lsp_references() end,
              { desc = "[G]oing [R]ight into [R]eferences" })
          end
          if client.supports_method("textDocument/documentSymbol") then
            -- Fuzzy find all the symbols in your current document.
            -- Symbols are things like variables, functions, types, etc.
            vim.keymap.set("n", "gO",
              function() require("telescope.builtin").lsp_document_symbols() end,
              { desc = "[G]lobal [O]verview of document symbols" })
          end
          if client.supports_method("textDocument/signatureHelp") then
            -- Displays signature information about the symbol under the
            -- cursor in a floating window.
            vim.keymap.set("i", "<C-S>",
              function() vim.lsp.buf.signature_help() end,
              { desc = "[S]ignature help" })
          end
          if client.supports_method("textDocument/implementation") then
            -- Create a keymap for vim.lsp.buf.implementation
            -- Jump to the implementation of the word under your cursor.
            -- Useful when your language has ways of declaring types without an actual implementation.
            vim.keymap.set("n", "gri",
              function() vim.lsp.buf.implementation() end,
              { desc = "[G]oing [R]ight into [I]mplementation" }
            )
          end
          if client.supports_method("textDocument/definition") then
            -- Jump to the definition of the word under your cursor.
            -- This is where a variable was first declared, or where a function is defined, etc.
            -- To jump back, press <C-t>.
            vim.keymap.set("n", "grd",
              function() require("telescope.builtin").lsp_definitions() end,
              { desc = "[G]oing [R]ight into [D]efinitins" })
          end
          if client.supports_method("textDocument/typeDefinition*") then
            -- Jump to the type of the word under your cursor.
            --  Useful when you're not sure what type a variable is and you want to see
            --  the definition of its *type*, not where it was *defined*.
            vim.keymap.set("n", "grt",
              function() require("telescope.builtin").lsp_type_definition() end,
              { desc = "[G]oing [R]ight into [T]ype definition" })
          end
          if client.supports_method("textDocument/declaration") then
            -- WARN: This is not Goto Definition, this is Goto Declaration.
            -- For example, in C this would take you to the header.
            vim.keymap.set("n", "grD",
              function() vim.lsp.buf.declaration() end,
              { desc = "[G]oing [R]ight into [D]eclaration" })
          end
          if client.supports_method("workspace/symbol") then
            -- Fuzzy find all the symbols in your current workspace.
            -- Similar to document symbols, except searches over your entire project.
            vim.keymap.set("n", "gwO",
              function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end,
              { desc = "[G]lobal [W]orkspace [O]verview of workspace symbols" })
          end
          if client.supports_method("textDocument/formatting") then
            vim.keymap.set("n", "<leader>f",
              function() vim.lsp.buf.format() end,
              { desc = "[F]ormat buffer" })
          end
          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          if client and client.supports_method("textDocument/documentHighlight") then
            local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = args.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = args.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = "kickstart-lsp-highlight", buffer = event2.buf }
              end,
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
