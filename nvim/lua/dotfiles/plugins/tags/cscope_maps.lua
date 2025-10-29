-- Plugin: dhananjaylatkar/cscope_maps.nvim
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
      "dhananjaylatkar/cscope_maps.nvim",
      lazy = true,
      dependencies = { "folke/which-key.nvim" },
      config = function()
        require("cscope_maps").setup({
          disable_maps = false, -- true disables my keymaps, only :Cscope will be loaded
          skip_input_prompt = true,
          cscope = {
            -- location of cscope db fils
            db_file = "./cscope.out",
            -- cscope executable
            exec = "cscope", -- "cscope" or "gtags-cscope"
            -- choose your fav picker
            picker = "quickfix", -- "telescope", "fzf-lua" or "quickfix"
            -- "true" does not open picker for single result, just JUMP
            skip_picker_for_single_result = true, -- "false" or "true"
            -- these args are directly passed to "cscope -f <db_file> <args>"
            db_build_cmd_args = { "-bqkv" },
            -- statusline indicator, default is cscope executable
            statusline_indicator = nil,
          },
        })
      end,
    },

  }
end
