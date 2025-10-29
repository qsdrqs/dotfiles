-- Plugin: nvim-treesitter/nvim-treesitter
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
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        if vim.g.treesitter_disable == true or vim.g.vscode then
          return
        end
        require("nvim-treesitter.configs").setup({
          -- One of "all", or a list of languages
          ensure_installed = { "c", "cpp", "java", "python", "javascript", "rust", "markdown" },

          -- Install languages synchronously (only applied to `ensure_installed`)
          sync_install = false,

          -- Automatically install missing parsers when entering buffer
          -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
          auto_install = true,

          -- List of parsers to ignore installing
          ignore_install = { "bash" },

          highlight = {
            -- `false` will disable the whole extension
            enable = true,

            -- list of language that will be disabled
            disable = function(lang, bufnr) -- Disable in large C++ buffers
              return vim.api.nvim_buf_line_count(bufnr) > 20000
            end,

            -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
            -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
            -- Using this option may slow down your editor, and you may see some duplicate highlights.
            -- Instead of true it can also be a list of languages
            additional_vim_regex_highlighting = true,
            custom_captures = {
              -- disable comment hightlight (for javadoc)
              ["comment"] = "NONE",
            },
          },
          indent = {
            enable = false,
          },
        })
        -- matlab
        local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
        parser_config.matlab = {
          install_info = {
            url = "https://github.com/mstanciu552/tree-sitter-matlab.git",
            files = { "src/parser.c" },
            branch = "main",
          },
          filetype = "matlab", -- if filetype does not agrees with parser name
        }
      end,
    },

  }
end
