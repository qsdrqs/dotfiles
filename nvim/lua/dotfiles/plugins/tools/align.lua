-- Plugin: Vonr/align.nvim
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
      "Vonr/align.nvim",
      lazy = true,
      keys = { { "al", mode = "x" } },
      cmd = "Align",
      config = function()
        local NS = { noremap = true, silent = true }
        vim.keymap.set("x", "al", function()
          require("align").align_to_string({ preview = true, regex = true })
        end, NS)
        vim.api.nvim_create_user_command("Align", function(opts)
          _, sr, sc, _ = unpack(vim.fn.getpos("v") or { 0, 0, 0, 0 })
          _, er, ec, _ = unpack(vim.fn.getcurpos())
          require("align").align(opts.args, {
            preview = true,
            regex = true,
            marks = { sr = opts.line1, sc = sc, er = opts.line2, ec = ec },
          })
        end, { nargs = 1, range = true })
      end,
    },

  }
end
