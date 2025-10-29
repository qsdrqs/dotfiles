-- Plugin: nvim-telescope/telescope.nvim
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
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      cond = vim.g.vscode == nil,
      config = function()
        local action_set = require("telescope.actions.set")

        local function move_selection_next_5(prompt_bufnr)
          action_set.shift_selection(prompt_bufnr, 5)
        end

        local function move_selection_previous_5(prompt_bufnr)
          action_set.shift_selection(prompt_bufnr, -5)
        end

        local t = function(str)
          return vim.api.nvim_replace_termcodes(str, true, true, true)
        end
        local function move_left_7()
          return vim.api.nvim_feedkeys(t("7h"), "n", true)
        end
        local function move_right_7()
          return vim.api.nvim_feedkeys(t("7l"), "n", true)
        end

        local status_ok, trouble_telscope = pcall(require, "trouble.sources.telescope")
        local opts = {
          defaults = {
            mappings = {
              i = {
                ["<C-j>"] = "move_selection_next",
                ["<C-k>"] = "move_selection_previous",
              },
              n = {
                ["K"] = move_selection_previous_5,
                ["J"] = move_selection_next_5,
                ["H"] = move_left_7,
                ["L"] = move_right_7,
                ["q"] = require("telescope.actions").close,
              },
            },
          },
        }
        if status_ok then
          opts.defaults.mappings.i["<C-t>"] = trouble_telscope.open
          opts.defaults.mappings.n["<C-t>"] = trouble_telscope.open
        end
        require("telescope").setup(opts)
      end,
    },

  }
end
