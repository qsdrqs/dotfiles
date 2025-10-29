-- Plugin: ibhagwan/fzf-lua
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
      "ibhagwan/fzf-lua",
      -- optional for icon support
      dependencies = { "nvim-tree/nvim-web-devicons" },
      cond = vim.g.vscode == nil,
      cmd = {
        "FzfLua",
      },
      keys = {
        "<leader>f",
        "<leader>b",
        "<leader>gs",
        "<leader>gg",
        "<leader>gG",
        "<leader>t",
        "<leader>rc",
        "<leader>rf",
        "<leader>rw",
        "<leader>rl",
        "<leader>rt",
      },
      -- or if using mini.icons/mini.nvim
      -- dependencies = { "echasnovski/mini.icons" },
      config = function()
        local fzf_lua = require("fzf-lua")
        fzf_lua.setup({
          grep = {
            rg_glob = true,
            -- first returned string is the new search query
            -- second returned string are (optional) additional rg flags
            -- @return string, string?
            rg_glob_fn = function(query, opts)
              local regex, flags = query:match("^(.-)%s%-%-(.*)$")
              -- If no separator is detected will return the original query
              return (regex or query), flags
            end,
          },
          winopts = {
            preview = {
              default = "bat_native",
              horizontal = "right:55%",
            },
            width = 0.85,
          },
          keymap = {
            fzf = {
              true,
              -- Use <c-q> to select all items and add them to the quickfix list
              ["ctrl-q"] = "select-all+accept",
            },
          },
          fzf_opts = {
            ["--cycle"] = true,
          },
        })
        vim.keymap.set("n", "<leader>f", fzf_lua.files, { silent = true })
        vim.keymap.set("n", "<leader>F", function()
          fzf_lua.files({ no_ignore = true })
        end, { silent = true })
        vim.keymap.set("n", "<leader>b", fzf_lua.buffers, { silent = true })
        vim.keymap.set("n", "<leader>gs", fzf_lua.grep_cword, { silent = true })
        vim.keymap.set("v", "<leader>gs", fzf_lua.grep_visual, { silent = true })
        vim.keymap.set("n", "<leader>gg", fzf_lua.live_grep, { silent = false })
        vim.keymap.set("n", "<leader>gG", fzf_lua.live_grep_glob, { silent = true })
        vim.keymap.set("n", "<leader>t", fzf_lua.builtin, { silent = true })
        vim.keymap.set("n", "<leader>rc", fzf_lua.command_history, { silent = true })
        vim.keymap.set("n", "<leader>rf", fzf_lua.lsp_document_symbols, { silent = true })
        vim.keymap.set("n", "<leader>rw", fzf_lua.lsp_workspace_symbols, { silent = true })
        vim.keymap.set("n", "<leader>rl", fzf_lua.blines, { silent = true })
        vim.keymap.set("n", "<leader>rt", fzf_lua.treesitter, { silent = true })
      end,
    },

  }
end
