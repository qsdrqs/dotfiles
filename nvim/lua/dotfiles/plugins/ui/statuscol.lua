-- Plugin: luukvbaal/statuscol.nvim
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
      "luukvbaal/statuscol.nvim",
      branch = "0.10",
      cond = vim.g.vscode == nil,
      config = function()
        local builtin = require("statuscol.builtin")
        vim.o.numberwidth = vim.o.numberwidth + 2 -- fix numberwidth mismatch
        require("statuscol").setup({
          -- Builtin line number string options for ScLn() segment
          thousands = false, -- or line number thousands separator string ("." / ",")
          relculright = true, -- whether to right-align the cursor line number with 'relativenumber' set
          bt_ignore = { "nofile" },
          -- Builtin 'statuscolumn' options
          setopt = true, -- whether to set the 'statuscolumn', providing builtin click actions
          -- Default segments (fold -> sign -> line number + separator)
          segments = {
            {
              sign = { name = { ".*" }, namespace = { ".*" }, maxwidth = 1, colwidth = 2 },
              click = "v:lua.ScSa",
            },
            {
              text = { builtin.lnumfunc },
              condition = { true, builtin.not_empty },
              click = "v:lua.ScLa",
            },
            {
              sign = { namespace = { "gitsigns" }, maxwidth = 1, colwidth = 1, auto = false },
              click = "v:lua.ScSa",
            },
            { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
          },
          ft_ignore = {
            "toggleterm",
            "dapui_scopes",
            "dapui_breakpoints",
            "dapui_stacks",
            "dapui_watches",
            "dap-repl",
          }, -- lua table with filetypes for which 'statuscolumn' will be unset
          -- Click actions
          clickhandlers = {
            Lnum = builtin.lnum_click,
            FoldClose = builtin.foldclose_click,
            FoldOpen = builtin.foldopen_click,
            FoldOther = builtin.foldother_click,
            DapBreakpointRejected = builtin.toggle_breakpoint,
            DapBreakpoint = builtin.toggle_breakpoint,
            DapBreakpointCondition = builtin.toggle_breakpoint,
            DiagnosticSignError = builtin.diagnostic_click,
            DiagnosticSignHint = builtin.diagnostic_click,
            DiagnosticSignInfo = builtin.diagnostic_click,
            DiagnosticSignWarn = builtin.diagnostic_click,
            GitSignsTopdelete = builtin.gitsigns_click,
            GitSignsUntracked = builtin.gitsigns_click,
            GitSignsAdd = builtin.gitsigns_click,
            GitSignsChangedelete = builtin.gitsigns_click,
            GitSignsDelete = builtin.gitsigns_click,
            gitsigns_extmark_signs_ = builtin.gitsigns_click,
          },
        })
      end,
    },

  }
end
