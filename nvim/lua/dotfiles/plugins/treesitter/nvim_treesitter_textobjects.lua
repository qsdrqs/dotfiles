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
      cond = function()
        return vim.b.treesitter_disable ~= true
      end,
      config = function()
        if vim.g.treesitter_disable == true then
          return
        end
        local opts = {
          textobjects = {
            select = {
              enable = true,

              -- Automatically jump forward to textobj, similar to targets.vim
              lookahead = true,

              keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner",
                ["ap"] = "@parameter.outer",
                ["ip"] = "@parameter.inner",
              },
            },
            swap = {
              enable = true,
              swap_next = {
                ["<leader>sl"] = "@parameter.inner",
              },
              swap_previous = {
                ["<leader>sh"] = "@parameter.inner",
              },
            },
          },
        }
        if vim.bo.filetype ~= "lua" then
          opts.textobjects.move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
              ["]m"] = "@function.outer",
            },
            goto_next_end = {
              ["]M"] = "@function.outer",
            },
            goto_previous_start = {
              ["[m"] = "@function.outer",
            },
            goto_previous_end = {
              ["[M"] = "@function.outer",
            },
          }
        end
        require("nvim-treesitter.configs").setup(opts)
      end,
    },

  }
end
