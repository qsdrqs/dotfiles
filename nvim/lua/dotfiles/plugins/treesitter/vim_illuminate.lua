-- Plugin: RRethy/vim-illuminate
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
      "RRethy/vim-illuminate",
      lazy = true,
      config = function()
        require("illuminate").configure({
          -- providers: provider used to get references in the buffer, ordered by priority
          providers = {
            "lsp",
            -- 'treesitter', -- treesitter is too slow!
            "regex",
          },
          -- delay: delay in milliseconds
          delay = 100,
          -- filetype_overrides: filetype specific overrides.
          -- The keys are strings to represent the filetype while the values are tables that
          -- supports the same keys passed to .configure except for filetypes_denylist and filetypes_allowlist
          filetype_overrides = {},
          -- filetypes_denylist: filetypes to not illuminate, this overrides filetypes_allowlist
          filetypes_denylist = {
            "dirvish",
            "fugitive",
          },
          -- filetypes_allowlist: filetypes to illuminate, this is overriden by filetypes_denylist
          filetypes_allowlist = {},
          -- modes_denylist: modes to not illuminate, this overrides modes_allowlist
          modes_denylist = {},
          -- modes_allowlist: modes to illuminate, this is overriden by modes_denylist
          modes_allowlist = {},
          -- providers_regex_syntax_denylist: syntax to not illuminate, this overrides providers_regex_syntax_allowlist
          -- Only applies to the 'regex' provider
          -- Use :echom synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
          providers_regex_syntax_denylist = {},
          -- providers_regex_syntax_allowlist: syntax to illuminate, this is overriden by providers_regex_syntax_denylist
          -- Only applies to the 'regex' provider
          -- Use :echom synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
          providers_regex_syntax_allowlist = {},
          -- under_cursor: whether or not to illuminate under the cursor
          under_cursor = true,
        })

        vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "UnderCursorText" })
        vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "UnderCursorRead" })
        vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "UnderCursorWrite" })
      end,
    },

  }
end
