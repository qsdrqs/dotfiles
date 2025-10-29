-- Plugin: numToStr/Comment.nvim
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
      "numToStr/Comment.nvim",
      keys = {
        { "<c-_>", mode = "v" },
        { "<c-s-_>", mode = "v" },
        { "<c-_>", mode = "n" },
        { "<c-s-_>", mode = "n" },
        { "<c-/>", mode = "v" },
        { "<c-s-/>", mode = "v" },
        { "<c-/>", mode = "n" },
        { "<c-s-/>", mode = "n" },
      },
      cond = vim.g.vscode == nil,
      config = function()
        local bindkey
        if os.getenv("TMUX") ~= nil and vim.g.neovide == nil then
          bindkey = {
            line = "<c-_>",
            block = "<c-s-_>",
          }
        else
          bindkey = {
            line = "<c-/>",
            block = "<c-s-/>",
          }
        end
        require("Comment").setup({
          ---Add a space b/w comment and the line
          padding = true,
          ---Whether the cursor should stay at its position
          sticky = true,
          ---Lines to be ignored while (un)comment
          ignore = nil,
          toggler = bindkey,
          opleader = bindkey,
          mappings = {
            basic = true,
            extra = true,
            extended = false,
          },
          ---Function to call before (un)comment
          pre_hook = nil,
          ---Function to call after (un)comment
          post_hook = function(ctx)
            -- execute if ctx.cmotion == 3,4,5
            if ctx.cmotion > 2 then
              if vim.g.plugins_loaded then
                vim.cmd([[ normal gv ]])
              else
                vim.cmd([[ normal gvh ]])
              end
            end
          end,
        })

        local api = require("Comment.api")
        vim.api.nvim_create_user_command("ToggleComment", api.toggle.linewise.current, { nargs = 0 })
        vim.api.nvim_create_user_command("ToggleBlockComment", api.toggle.blockwise.current, { nargs = 0 })
      end,
    },

  }
end
