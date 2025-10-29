-- Plugin: L3MON4D3/LuaSnip
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
      "L3MON4D3/LuaSnip",
      lazy = true,
      dependencies = {
        { "rafamadriz/friendly-snippets", rtp = "." },
      },
      config = function()
        vim.opt.rtp:prepend(os.getenv("HOME") .. "/dotfiles/.vim")
        require("luasnip.loaders.from_snipmate").lazy_load()
        require("luasnip.loaders.from_vscode").lazy_load()
        require("dotfiles.luasnip")
        local ls = require("luasnip")
        ls.setup({
          update_events = { "TextChanged", "TextChangedI" },
          enable_autosnippets = true,
        })

        local t = function(str)
          return vim.api.nvim_replace_termcodes(str, true, true, true)
        end

        vim.keymap.set({ "i" }, "<Tab>", function()
          if ls.expand_or_jumpable() then
            return ls.expand_or_jump()
          else
            vim.api.nvim_feedkeys(t("<Tab>"), "n", true)
          end
        end, { silent = true })
        vim.keymap.set({ "i", "s" }, "<Tab>", function()
          if ls.jumpable(1) then
            return ls.jump(1)
          else
            vim.api.nvim_feedkeys(t("<Tab>"), "n", true)
          end
        end, { silent = true })
        vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
          if ls.jumpable(-1) then
            return ls.jump(-1)
          else
            vim.api.nvim_feedkeys(t("<S-Tab>"), "n", true)
          end
        end, { silent = true })

        local function snips_edit()
          local ft = vim.bo.filetype
          vim.cmd("e ~/dotfiles/.vim/snippets/" .. ft .. ".snippets")
        end
        vim.keymap.set("n", "<leader>ss", snips_edit, { silent = true })
        vim.api.nvim_create_autocmd("BufRead", {
          pattern = "*.snippets",
          callback = function()
            vim.bo.filetype = "snippets"
          end,
        })

        -- map <BS> to <BS>i to get in insert
        vim.keymap.set({ "s" }, "<BS>", "<BS>i", { silent = true, noremap = true })
      end,
    },

  }
end
