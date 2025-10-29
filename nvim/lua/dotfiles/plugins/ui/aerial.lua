-- Plugin: stevearc/aerial.nvim
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
      "stevearc/aerial.nvim",
      lazy = true,
      keys = "<leader>v",
      cond = vim.g.vscode == nil,
      config = function()
        vim.keymap.set("n", "<leader>v", "<cmd>AerialToggle!<CR>", { silent = true })
        require("aerial").setup({
          backends = { "lsp", "treesitter", "markdown" },

          filter_kind = false,
          guides = {
            -- When the child item has a sibling below it
            mid_item = "├─",
            -- When the child item is the last in the list
            last_item = "└─",
            -- When there are nested child guides to the right
            nested_top = "│ ",
            -- Raw indentation
            whitespace = "  ",
          },
          icons = kind_icons_list,
          layout = {
            max_width = 200,
          },
          lsp = {
            diagnostics_trigger_update = false,
          },
          disable_max_lines = -1,
        })
        -- winbar
        local aerial = require("aerial")

        -- Format the list representing the symbol path
        -- Grab it from https://github.com/stevearc/aerial.nvim/blob/master/lua/lualine/components/aerial.lua
        local function format_symbols(symbols, depth, separator, icons_enabled)
          local parts = {}
          depth = depth or #symbols

          if depth > 0 then
            symbols = { unpack(symbols, 1, depth) }
          else
            symbols = { unpack(symbols, #symbols + 1 + depth) }
          end

          for _, symbol in ipairs(symbols) do
            if icons_enabled then
              table.insert(parts, string.format("%s%s", symbol.icon, symbol.name))
            else
              table.insert(parts, symbol.name)
            end
          end

          return table.concat(parts, separator)
        end

        local winbar_aerial = function()
          -- Get a list representing the symbol path by aerial.get_location (see
          -- https://github.com/stevearc/aerial.nvim/blob/master/lua/aerial/init.lua#L127),
          -- and format the list to get the symbol path.
          -- Grab it from
          -- https://github.com/stevearc/aerial.nvim/blob/master/lua/lualine/components/aerial.lua#L89

          local symbols = aerial.get_location(true)
          local symbol_path = format_symbols(symbols, nil, " > ", true)

          if symbol_path ~= "" then
            return "> " .. symbol_path
          end
          return ""
        end

        local filename_with_icon = function()
          local winbar_aerial_ft_exclude = {}

          for _, ft in ipairs(winbar_aerial_ft_exclude) do
            if vim.o.filetype == ft then
              return ""
            end
          end

          -- nvim-tree
          if vim.o.filetype == "NvimTree" then
            return vim.api.nvim_exec("pwd", true)
          end

          local path_with_slash = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
          path_with_slash = vim.split(path_with_slash, "/", { plain = true })
          local icon = require("nvim-web-devicons").get_icon_by_filetype(vim.o.filetype)
          local file_with_arrow

          if #path_with_slash == 1 then
            if icon ~= nil then
              file_with_arrow = icon .. " " .. path_with_slash[1]
            else
              file_with_arrow = path_with_slash[1]
            end
            return file_with_arrow
          end

          file_with_arrow = path_with_slash[1]
          for i, iter in pairs(path_with_slash) do
            if i ~= 1 and i ~= #path_with_slash then
              file_with_arrow = file_with_arrow .. " > " .. iter
            elseif i == #path_with_slash then
              if icon ~= nil then
                file_with_arrow = file_with_arrow .. " > " .. icon .. " " .. iter
              else
                file_with_arrow = file_with_arrow .. " > " .. iter
              end
            end
          end
          return file_with_arrow
        end

        vim.cmd([[ hi link AerialWinHLFields Constant ]])
        vim.cmd([[ hi link AerialWinHLFile FileName ]])
        -- vim.o.winbar = " %#AerialWinHLFile#%{%v:lua.filename_with_icon()%} %#AerialWinHLFields#%{%v:lua.winbar_aerial()%}"
      end,
    },

  }
end
