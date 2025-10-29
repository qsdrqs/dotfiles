-- Plugin: nvim-lualine/lualine.nvim
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
      "nvim-lualine/lualine.nvim",
      dependencies = { "kyazdani42/nvim-web-devicons" },
      config = function()
        local custom_auto = require("lualine.themes.auto")
        local statusline_hl = vim.api.nvim_get_hl(0, { name = "StatusLine" })
        if vim.g.colors_name == "ghdark" then
          custom_auto.normal.a.fg = "#C4CBD7"
          custom_auto.normal.b.fg = "#9CA5B3"
          custom_auto.normal.c.bg = string.format("#%06X", statusline_hl.bg)
          custom_auto.inactive = {
            a = { fg = "#c6c6c6", bg = "#080808" },
            b = { fg = "#c6c6c6", bg = "#080808" },
            c = { fg = "#c6c6c6", bg = "#080808" },
          }
        end
        local function get_venv()
          local venv_name = os.getenv("VIRTUAL_ENV")
          if venv_name ~= nil then
            local venv_short_name = vim.fn.fnamemodify(venv_name, ":t")
            if venv_short_name == "venv" then
              venv_short_name = vim.fn.fnamemodify(venv_name, ":h:t")
            end
            return "(" .. venv_short_name .. ")"
          else
            return ""
          end
        end
        -- lsp info, from https://github.com/nvim-lualine/lualine.nvim/blob/master/examples/evil_lualine.lua
        --
        local lsp_click = function()
          if vim.o.ft == "python" then
            vim.cmd.VenvSelect()
          end
        end
        local lsp_info = {
          -- Lsp server name .
          function()
            local no_lsp = ""
            local buf_ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
            local clients = vim.lsp.get_clients()
            if next(clients) == nil then
              return no_lsp
            end
            local client_names = {}
            for _, client in ipairs(clients) do
              local filetypes = client.config.filetypes
              if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
                table.insert(client_names, client.name)
              end
            end
            if next(client_names) == nil then
              return no_lsp
            else
              -- remove duplicate items
              local seen = {}
              local unique = {}
              for _, v in ipairs(client_names) do
                if not seen[v] then
                  if v:match("py.*") then
                    v = v .. get_venv()
                  end
                  table.insert(unique, v)
                  seen[v] = true
                end
              end
              return table.concat(unique, ", ")
            end
          end,
          icon = " ",
          color = { gui = "bold" },
          on_click = lsp_click,
        }

        vim.api.nvim_create_autocmd({ "InsertEnter" }, {
          callback = function()
            if vim.g.copilot_initialized == 1 then
              return
            end
            for k, v in pairs(vim.g.copilot_filetypes) do
              if k == vim.bo.filetype and v == false then
                return
              end
            end
            if vim.g.no_load_copilot ~= 1 then
              vim.g.copilot_initialized = 1
            end
          end,
        })

        local copilot = function()
          if vim.g.copilot_initialized == 1 then
            if vim.b.copilot_suggestion_hidden == false then
              return " "
            else
              return "󱃓 "
            end
          else
            return "󱃓 "
          end
        end

        local function gtagsHandler()
          if vim.g.gutentags_load == 1 then
            if vim.api.nvim_eval("gutentags#statusline()") == "" then
              return ""
            else
              return "Tags Indexing..."
            end
          else
            return ""
          end
        end

        local function auto_session_name()
          local status_ok, lib = pcall(require, "auto-session-library")
          if status_ok then
            return lib.current_session_name()
          else
            return ""
          end
        end

        local nix_dev = {
          function()
            -- get $NIX_DEV
            local nix_dev = vim.env.NIX_DEV
            if nix_dev == nil then
              return ""
            end
            return nix_dev
          end,
          icon = " ",
          color = { gui = "bold", fg = "#58A6FF" },
        }

        local function shiftwidth()
          local sw = vim.fn.shiftwidth()
          return "sw:" .. sw
        end

        require("lualine").setup({
          options = {
            icons_enabled = true,
            theme = custom_auto,
            component_separators = { left = ")", right = "(" },
            section_separators = { left = "", right = "" },
            disabled_filetypes = {},
            always_divide_middle = true,
          },
          sections = {
            lualine_a = { { "filename", path = 0 } },
            lualine_b = {
              "branch",
              "diff",
              {
                "diagnostics",
                symbols = { error = " ", warn = " ", info = " ", hint = " " },
              },
            },
            lualine_c = { lsp_info, gtagsHandler },
            lualine_x = { auto_session_name, nix_dev },
            lualine_y = { "fileformat", "filetype", copilot },
            lualine_z = { shiftwidth, "%l/%L,%c", "encoding" },
          },
          inactive_sections = {
            lualine_a = {},
            lualine_b = {},
            lualine_c = { "filename" },
            lualine_x = { "location" },
            lualine_y = {},
            lualine_z = {},
          },
          tabline = {},
          extensions = { "quickfix", "aerial", "fugitive", "nvim-tree" },
        })
      end,
    },

  }
end
