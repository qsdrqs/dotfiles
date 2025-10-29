-- Plugin: Bekaboo/dropbar.nvim
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
      "Bekaboo/dropbar.nvim",
      config = function()
        local no_bold = {}
        for key, _ in pairs(kind_icons_list) do
          table.insert(no_bold, "DropBarKind" .. key)
        end
        for _, hl in ipairs(no_bold) do
          vim.api.nvim_set_hl(0, hl, { bold = false })
        end
        vim.api.nvim_set_hl(0, "DropBarKindFile", { bold = true })
        vim.api.nvim_set_hl(0, "DropBarKindFolder", { bold = true })

        vim.api.nvim_set_hl(0, "DropBarIconUIPickPivot", { link = "Visual" })
        vim.api.nvim_set_hl(0, "DropBarIconKindEnumMember", { link = "Normal" })
        vim.keymap.set("n", "<leader>V", require("dropbar.api").pick, { noremap = true, silent = true })

        local api = require("dropbar.api")
        require("dropbar").setup({
          icons = {
            ui = {
              bar = {
                separator = "  ",
              },
            },
          },
          menu = {
            keymaps = {
              ["<Esc>"] = function()
                local menu = api.get_current_dropbar_menu()
                menu:close()
              end,
              ["h"] = function()
                local menu = api.get_current_dropbar_menu()
                if menu.prev_menu then
                  menu:close()
                end
              end,
              ["l"] = function()
                local menu = require("dropbar.api").get_current_dropbar_menu()
                local cursor = vim.api.nvim_win_get_cursor(menu.win)
                local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
                if component and component.children then
                  menu:click_on(component, nil, 1, "l")
                end
              end,
            },
            win_configs = {
              border = "single",
            },
          },
        })
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "fugitiveblame" },
          callback = function()
            vim.o.winbar = "Git blame"
          end,
        })
      end,
    },

  }
end
