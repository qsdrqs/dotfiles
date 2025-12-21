-- Plugin: nvim-treesitter/nvim-treesitter-textobjects
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
      "nvim-treesitter/nvim-treesitter-textobjects",
      lazy = true,
      branch = "main",
      cond = function()
        return vim.g.treesitter_disable ~= true and not vim.g.vscode
      end,
      config = function()
        if vim.g.treesitter_disable == true then
          return
        end
        local textobjects = require("nvim-treesitter-textobjects")
        textobjects.setup({
          select = {
            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,
          },
          move = {
            set_jumps = true, -- whether to set jumps in the jumplist
          },
        })

        local select = require("nvim-treesitter-textobjects.select")
        local swap = require("nvim-treesitter-textobjects.swap")
        local move = require("nvim-treesitter-textobjects.move")

        local function map_select(lhs, capture)
          vim.keymap.set({ "x", "o" }, lhs, function()
            select.select_textobject(capture, "textobjects")
          end)
        end

        map_select("af", "@function.outer")
        map_select("if", "@function.inner")
        map_select("ac", "@class.outer")
        map_select("ic", "@class.inner")
        map_select("ap", "@parameter.outer")
        map_select("ip", "@parameter.inner")

        vim.keymap.set("n", "<leader>sl", function()
          swap.swap_next("@parameter.inner", "textobjects")
        end)
        vim.keymap.set("n", "<leader>sh", function()
          swap.swap_previous("@parameter.inner", "textobjects")
        end)

        if vim.bo.filetype ~= "lua" then
          vim.keymap.set({ "n", "x", "o" }, "]m", function()
            move.goto_next_start("@function.outer", "textobjects")
          end)
          vim.keymap.set({ "n", "x", "o" }, "]M", function()
            move.goto_next_end("@function.outer", "textobjects")
          end)
          vim.keymap.set({ "n", "x", "o" }, "[m", function()
            move.goto_previous_start("@function.outer", "textobjects")
          end)
          vim.keymap.set({ "n", "x", "o" }, "[M", function()
            move.goto_previous_end("@function.outer", "textobjects")
          end)
        end
      end,
    },

  }
end
