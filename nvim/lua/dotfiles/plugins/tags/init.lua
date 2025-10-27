local M = {}

function M.setup(ctx)
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

  local specs = {
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

    {
      --管理gtags，集中存放tags
      "skywind3000/vim-gutentags",
      lazy = true,
      init = function()
        vim.g.gutentags_define_advanced_commands = 1
      end,
      config = function()
        -- vim.g.gutentags_modules = {'ctags', 'gtags_cscope'}
        vim.g.gutentags_modules = { "ctags", "gtags_cscope", "cscope_maps" }

        -- config project root markers.
        vim.g.gutentags_project_root = { ".root", ".svn", ".git", ".hg", ".project", ".exrc", "pom.xml" }

        -- generate datebases in my cache directory, prevent gtags files polluting my project
        vim.g.gutentags_cache_dir = os.getenv("HOME") .. "/.cache/tags"

        -- change focus to quickfix window after search (optional).
        vim.g.gutentags_plus_switch = 1

        vim.g.gutentags_load = 1
      end,
    },

    {
      "skywind3000/gutentags_plus",
      init = function()
        vim.g.gutentags_plus_nomap = 1
      end,
      lazy = true,
      config = function()
        vim.cmd([[
          noremap <silent> <leader>cgs :GscopeFind s <C-R><C-W><cr>
          noremap <silent> <leader>cgg :GscopeFind g <C-R><C-W><cr>
          noremap <silent> <leader>cgc :GscopeFind c <C-R><C-W><cr>
          noremap <silent> <leader>cgt :GscopeFind t <C-R><C-W><cr>
          noremap <silent> <leader>cge :GscopeFind e <C-R><C-W><cr>
          noremap <silent> <leader>cgf :GscopeFind f <C-R>=expand("<cfile>")<cr><cr>
          noremap <silent> <leader>cgi :GscopeFind i <C-R>=expand("<cfile>")<cr><cr>
          noremap <silent> <leader>cgd :GscopeFind d <C-R><C-W><cr>
          noremap <silent> <leader>cga :GscopeFind a <C-R><C-W><cr>
          noremap <silent> <leader>cgz :GscopeFind z <C-R><C-W><cr>
        ]])
      end,
    },
  }

  return specs
end

return M
