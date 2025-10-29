-- Plugin: nvimtools/none-ls.nvim
return function(ctx)
  local load_plugin = ctx.load_plugin
  local load_plugins = ctx.load_plugins
  local lsp_merge_project_config = ctx.lsp_merge_project_config
  local kind_icons_list = ctx.kind_icons_list
  local kind_icons = ctx.kind_icons
  local highlight_group_list = ctx.highlight_group_list
  local icons = ctx.icons
  local highlights = ctx.highlights
  local vscode_next_hunk = ctx.vscode_next_hunk
  local vscode_prev_hunk = ctx.vscode_prev_hunk

  return {

    {
      -- can be used as formatter
      "nvimtools/none-ls.nvim",
      depedencies = {
        "nvimtools/none-ls-extras.nvim",
      },
      config = function()
        local null_ls = require("null-ls")
        local eslint = require("none-ls.diagnostics.eslint")
        local autopep8 = require("none-ls.formatting.autopep8")

        local isort_always_enabled = true

        null_ls.setup({
          sources = {
            eslint,
            -- null_ls.builtins.completion.spell,
            null_ls.builtins.formatting.prettier,
            null_ls.builtins.completion.tags,
            null_ls.builtins.code_actions.gitsigns,
            -- python
            autopep8.with({
              runtime_condition = function(params)
                if params.options.isort == true then
                  return false
                else
                  return true
                end
              end,
            }),
            null_ls.builtins.formatting.isort.with({
              runtime_condition = function(params)
                if isort_always_enabled == true then
                  return true
                end
                if params.options.isort == true then
                  return true
                else
                  return false
                end
              end,
            }),
          },
        })
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "python" },
          callback = function(args)
            vim.api.nvim_buf_create_user_command(args.buf, "PythonOrganizeImports", function()
              vim.lsp.buf.format({ formatting_options = { isort = true } })
            end, {})
            vim.api.nvim_buf_create_user_command(args.buf, "PythonEnableIsortOnFormat", function()
              isort_always_enabled = true
            end, {})
          end,
        })
      end,
    },

  }
end
