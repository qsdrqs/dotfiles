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

    {
      "NvChad/nvim-colorizer.lua",
      config = function()
        require("colorizer").setup()
      end,
    },

    {
      "akinsho/bufferline.nvim",
      config = function()
        local opts = {
          options = {
            -- separator_style = "slant",
            diagnostics = "nvim_lsp",
            max_name_length = 100,
            -- name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
            --   -- remove extension from markdown files for example
            --   if buf.bufnr == vim.fn.bufnr() then
            --     return vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
            --   else
            --     return buf.name
            --   end
            -- end,
            diagnostics_indicator = function(count, level, diagnostics_dict, context)
              local s = " "
              for e, n in pairs(diagnostics_dict) do
                local sym = e == "error" and "󰅚 " or (e == "warning" and "  " or " ")
                s = s .. n .. sym
              end
              return s
            end,
          },
          highlights = {
            tab_selected = {
              fg = {
                attribute = "fg",
                highlight = "Pmenu",
              },
            },
            buffer_selected = {
              fg = {
                attribute = "fg",
                highlight = "Pmenu",
              },
            },
            hint_selected = {
              fg = {
                attribute = "fg",
                highlight = "Pmenu",
              },
            },
            indicator_selected = {
              fg = {
                attribute = "fg",
                highlight = "Keyword",
              },
            },
            separator = {
              fg = {
                attribute = "fg",
                highlight = "SpecialKey",
              },
            },
          },
        }

        local statusline_bg_list = {
          "close_button",
          "tab",
          "buffer",
          "diagnostic",
          "hint",
          "hint_diagnostic",
          "info",
          "info_diagnostic",
          "warning",
          "warning_diagnostic",
          "error",
          "error_diagnostic",
          "modified",
          "indicator",
          "duplicate",
        }
        for _, hl in ipairs(statusline_bg_list) do
          local hl_name = hl .. "_selected"
          if opts.highlights[hl_name] then
            opts.highlights[hl_name].bg = {
              attribute = "bg",
              highlight = "StatusLine",
            }
          else
            opts.highlights[hl_name] = {
              bg = {
                attribute = "bg",
                highlight = "StatusLine",
              },
            }
          end
        end

        require("bufferline").setup(opts)

        -- use alt + number to go to buffer
        for i = 1, 9 do
          vim.keymap.set("n", "<M-" .. i .. ">", function()
            require("bufferline").go_to(i, true)
          end, { noremap = true, silent = true })
        end
      end,
    },

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

    { "kyazdani42/nvim-web-devicons" },

    {
      "goolord/alpha-nvim",
      dependencies = { "rmagatti/auto-session" },
      cmd = "Alpha",
      cond = function()
        return vim.g.not_start_alpha ~= true and #vim.fn.argv() == 0 and vim.g.started_by_firenvim == nil
      end,
      config = function()
        -- TODO: slow under WSL, because of PATH
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")

        dashboard.section.header.val = {
          [[ ██\   ██\                    ██\    ██\ ██████\ ██\      ██\  ]],
          [[ ███\  ██ |                   ██ |   ██ |\_██  _|███\    ███ | ]],
          [[ ████\ ██ | ██████\   ██████\ ██ |   ██ |  ██ |  ████\  ████ | ]],
          [[ ██ ██\██ |██  __██\ ██  __██\\██\  ██  |  ██ |  ██\██\██ ██ | ]],
          [[ ██ \████ |████████ |██ /  ██ |\██\██  /   ██ |  ██ \███  ██ | ]],
          [[ ██ |\███ |██   ____|██ |  ██ | \███  /    ██ |  ██ |\█  /██ | ]],
          [[ ██ | \██ |\███████\ \██████  |  \█  /   ██████\ ██ | \_/ ██ | ]],
          [[ \__|  \__| \_______| \______/    \_/    \______|\__|     \__| ]],
        }

        -- https://github.com/AdamWhittingham/vim-config/blob/nvim/lua/config/startup_screen.lua
        local nvim_web_devicons = require("nvim-web-devicons")
        local path = require("plenary.path")
        local function get_extension(fn)
          local match = fn:match("^.+(%..+)$")
          local ext = ""
          if match ~= nil then
            ext = match:sub(2)
          end
          return ext
        end

        local function icon(fn)
          local nwd = require("nvim-web-devicons")
          local ext = get_extension(fn)
          return nwd.get_icon(fn, ext, { default = true })
        end

        local function file_button(fn, sc, short_fn)
          short_fn = short_fn or fn
          local ico_txt
          local fb_hl = {}

          local ico, hl = icon(fn)
          local hl_option_type = type(nvim_web_devicons.highlight)
          if hl_option_type == "boolean" then
            if hl and nvim_web_devicons.highlight then
              table.insert(fb_hl, { hl, 0, 1 })
            end
          end
          if hl_option_type == "string" then
            table.insert(fb_hl, { nvim_web_devicons.highlight, 0, 1 })
          end
          ico_txt = ico .. "  "

          local file_button_el = dashboard.button(sc, ico_txt .. short_fn, "<cmd>e " .. fn .. " <CR>")

          -- change width
          file_button_el.opts.width = 75

          local fn_start = short_fn:match(".*/")
          if fn_start ~= nil then
            table.insert(fb_hl, { "Comment", #ico_txt - 2, #fn_start + #ico_txt - 2 })
          end
          file_button_el.opts.hl = fb_hl
          return file_button_el
        end

        local default_mru_ignore = { "gitcommit" }

        local mru_opts = {
          ignore = function(path, ext)
            return (string.find(path, "COMMIT_EDITMSG")) or (vim.tbl_contains(default_mru_ignore, ext))
          end,
        }
        local function mru(start, cwd, items_number, opts)
          opts = opts or mru_opts
          items_number = items_number or 9

          local oldfiles = {}
          for _, v in pairs(vim.v.oldfiles) do
            if #oldfiles == items_number then
              break
            end
            local cwd_cond
            if not cwd then
              cwd_cond = true
            else
              cwd_cond = vim.startswith(v, cwd)
            end
            local ignore = (opts.ignore and opts.ignore(v, get_extension(v))) or false
            if (vim.fn.filereadable(v) == 1) and cwd_cond and not ignore then
              oldfiles[#oldfiles + 1] = v
            end
          end

          local special_shortcuts = { "a", "s", "d" }
          local target_width = 35

          local tbl = {}
          for i, fn in ipairs(oldfiles) do
            local short_fn
            if cwd then
              short_fn = vim.fn.fnamemodify(fn, ":.")
            else
              short_fn = vim.fn.fnamemodify(fn, ":~")
            end

            if #short_fn > target_width then
              short_fn = path.new(short_fn):shorten(1, { -2, -1 })
              if #short_fn > target_width then
                short_fn = path.new(short_fn):shorten(1, { -1 })
                if #short_fn > target_width then
                  -- trim last path
                  local fname = vim.fn.fnamemodify(fn, ":t")
                  local path_without_fname = short_fn:sub(1, #short_fn - #fname)
                  local remain_space = target_width - #path_without_fname
                  short_fn = path_without_fname .. "..." .. fname:sub(#fname - remain_space + 1)
                end
              end
            end

            local shortcut = ""
            if i <= #special_shortcuts then
              shortcut = special_shortcuts[i]
            else
              shortcut = tostring(i + start - 1 - #special_shortcuts)
            end

            local file_button_el = file_button(fn, shortcut, short_fn)
            tbl[i] = file_button_el
          end
          return {
            type = "group",
            val = tbl,
            opts = { spacing = 1 },
          }
        end
        local section_mru = {
          type = "group",
          val = {
            {
              type = "text",
              val = "Recent Files",
              opts = {
                hl = "SpecialComment",
                shrink_margin = false,
                position = "center",
              },
            },
            {
              type = "group",
              val = function()
                return { mru(1, cdir, 15) }
              end,
              opts = { shrink_margin = false },
            },
          },
          opts = {
            spacing = 1,
          },
        }

        dashboard.section.buttons.val = {
          dashboard.button("e", "  New file", "<cmd>ene <CR>"),
          dashboard.button("l", "󰁯  Load session", "<cmd>AutoSession restore <cr>"),
          dashboard.button("y", "  Open file manager", "<cmd>YaziToggle <cr>"),
          dashboard.button("z", "  Z jump", "<cmd>ZjumpToggle <cr>"),
          dashboard.button("f", "󰍉  Find file", require("fzf-lua").files),
          dashboard.button("h", "󱔗  Recently opened files", require("fzf-lua").oldfiles),
          dashboard.button("g", "󰈬  Find word", require("fzf-lua").live_grep),
          dashboard.button("m", "󰃃  Jump to bookmarks", require("fzf-lua").marks),
          -- dashboard.button("u", "  Update plugins" , ":Lazy sync<CR>"),
          dashboard.button("c", "  Open Config", "<cmd>e ~/dotfiles/.vimrc<cr><cmd>e ~/dotfiles/.nvimrc.lua<cr>"),
          dashboard.button("q", "󰅚  Quit", ":qa<CR>"),
        }

        for _, v in pairs(dashboard.section.buttons.val) do
          v.opts.width = 75
        end

        local hot_keys = {
          type = "text",
          val = "Hot Keys",
          opts = {
            hl = "SpecialComment",
            shrink_margin = false,
            position = "center",
          },
        }

        dashboard.config.layout = {
          { type = "padding", val = 2 },
          dashboard.section.header,
          { type = "padding", val = 1 },
          hot_keys,
          { type = "padding", val = 1 },
          dashboard.section.buttons,
          section_mru,
          { type = "padding", val = 1 },
          dashboard.section.footer,
        }

        alpha.setup(dashboard.config)

        -- override the Alpha command
        vim.api.nvim_create_user_command("Alpha", function(_)
          vim.cmd([[
            silent %bd
            cd ~
          ]])
          require("alpha").start(false)
          local buf_list = vim.fn.getbufinfo({ buflisted = 1 })
          for _, buf in ipairs(buf_list) do
            vim.api.nvim_buf_delete(buf.bufnr, { force = true })
          end
        end, {
          bang = true,
          desc = 'require"alpha".start(false)',
          nargs = 0,
          bar = true,
        })
      end,
    },

    {
      "lewis6991/satellite.nvim",
      config = function()
        require("satellite").setup({
          handlers = {
            cursor = {
              enable = false,
            },
          },
        })
      end,
    },

    {
      "folke/todo-comments.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("todo-comments").setup({
          keywords = {
            NOTE = {
              -- color = "green"
            },
          },
          colors = {
            green = { "GitSignsAdd" },
          },
        })
      end,
    },

    {
      "rcarriga/nvim-notify",
      init = function()
        local banned_messages = {
          "method textDocument/codeLens is not supported by any of the servers registered for the current buffer",
          "method textDocument/inlayHint is not supported by any of the servers registered for the current buffer",
          "[inlay_hints] LSP error:Invalid offset",
          "LSP[rust_analyzer] rust-analyzer failed to load workspace: Failed to read Cargo metadata from Cargo.toml",
          "position_encoding param is required",
          "warning: multiple different client offset_encodings detected for buffer",
          "The language server is either not installed, missing from PATH, or not executable.",
        }

        vim.notify = function(msg, ...)
          for _, banned in ipairs(banned_messages) do
            if string.find(msg, banned, 1, true) then
              return
            end
          end
          if string.find(msg, "signatureHelp", 1, true) then
            print(msg)
            return
          end
          if string.find(msg, "auto-session ERROR: Error restoring session", 1, true) then
            vim.cmd("normal! zR")
            vim.notify("Auto session corrupted, restored the old", "info", { title = "Auto Session" })
            require("auto-session").save_session()
            return
          end
          local ok, notify = pcall(require, "notify")
          if ok then
            -- local stack_trace = debug.traceback()
            -- notify(msg .. "\n\n" .. stack_trace, ...)
            notify(msg, ...)
          end
        end
      end,
    },

    {
      -- provide ui for lsp
      "stevearc/dressing.nvim",
    },

    {
      "levouh/tint.nvim",
      lazy = false,
      cond = vim.g.vscode == nil,
      config = function()
        require("tint").setup({
          tint = -45, -- Darken colors, use a positive value to brighten
          saturation = 0.6, -- Saturation to preserve
        })
        vim.api.nvim_create_user_command("TintToggle", require("tint").toggle, { nargs = 0 })
      end,
    },

    {
      "kyazdani42/nvim-tree.lua",
      lazy = true,
      keys = "<leader>n",
      dependencies = {
        "kyazdani42/nvim-web-devicons", -- optional, for file icon
      },
      config = function()
        vim.keymap.set("n", "<leader>n", "<cmd>NvimTreeFindFileToggle<CR>", { silent = true })
        local api = require("nvim-tree.api")

        local on_attach = function(bufnr)
          local opts = function(desc)
            return {
              desc = "nvim-tree: " .. desc,
              buffer = bufnr,
              noremap = true,
              silent = true,
              nowait = true,
            }
          end

          vim.keymap.set("n", "<C-]>", api.tree.change_root_to_node, opts("CD"))
          vim.keymap.set("n", "<C-e>", api.node.open.replace_tree_buffer, opts("Open: In Place"))
          vim.keymap.set("n", "<C-k>", api.node.show_info_popup, opts("Info"))
          vim.keymap.set("n", "<C-r>", api.fs.rename_sub, opts("Rename: Omit Filename"))
          vim.keymap.set("n", "<C-t>", api.node.open.tab, opts("Open: New Tab"))
          vim.keymap.set("n", "<C-v>", api.node.open.vertical, opts("Open: Vertical Split"))
          vim.keymap.set("n", "<C-x>", api.node.open.horizontal, opts("Open: Horizontal Split"))
          vim.keymap.set("n", "<BS>", api.node.navigate.parent_close, opts("Close Directory"))
          vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
          vim.keymap.set("n", "<Tab>", api.node.open.preview, opts("Open Preview"))
          vim.keymap.set("n", ">", api.node.navigate.sibling.next, opts("Next Sibling"))
          vim.keymap.set("n", "<", api.node.navigate.sibling.prev, opts("Previous Sibling"))
          vim.keymap.set("n", ".", api.node.run.cmd, opts("Run Command"))
          vim.keymap.set("n", "-", api.tree.change_root_to_parent, opts("Up"))
          vim.keymap.set("n", "a", api.fs.create, opts("Create"))
          vim.keymap.set("n", "bmv", api.marks.bulk.move, opts("Move Bookmarked"))
          vim.keymap.set("n", "B", api.tree.toggle_no_buffer_filter, opts("Toggle No Buffer"))
          vim.keymap.set("n", "c", api.fs.copy.node, opts("Copy"))
          vim.keymap.set("n", "C", api.tree.toggle_git_clean_filter, opts("Toggle Git Clean"))
          vim.keymap.set("n", "[c", api.node.navigate.git.prev, opts("Prev Git"))
          vim.keymap.set("n", "]c", api.node.navigate.git.next, opts("Next Git"))
          vim.keymap.set("n", "d", api.fs.remove, opts("Delete"))
          vim.keymap.set("n", "D", api.fs.trash, opts("Trash"))
          vim.keymap.set("n", "E", api.tree.expand_all, opts("Expand All"))
          vim.keymap.set("n", "e", api.fs.rename_basename, opts("Rename: Basename"))
          vim.keymap.set("n", "]e", api.node.navigate.diagnostics.next, opts("Next Diagnostic"))
          vim.keymap.set("n", "[e", api.node.navigate.diagnostics.prev, opts("Prev Diagnostic"))
          vim.keymap.set("n", "F", api.live_filter.clear, opts("Clean Filter"))
          vim.keymap.set("n", "f", api.live_filter.start, opts("Filter"))
          vim.keymap.set("n", "g?", api.tree.toggle_help, opts("Help"))
          vim.keymap.set("n", "gy", api.fs.copy.absolute_path, opts("Copy Absolute Path"))
          vim.keymap.set("n", "<c-h>", api.tree.toggle_hidden_filter, opts("Toggle Dotfiles"))
          vim.keymap.set("n", "I", api.tree.toggle_gitignore_filter, opts("Toggle Git Ignore"))
          vim.keymap.set("n", "m", api.marks.toggle, opts("Toggle Bookmark"))
          vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
          vim.keymap.set("n", "O", api.node.open.no_window_picker, opts("Open: No Window Picker"))
          vim.keymap.set("n", "p", api.fs.paste, opts("Paste"))
          vim.keymap.set("n", "P", api.node.navigate.parent, opts("Parent Directory"))
          vim.keymap.set("n", "q", api.tree.close, opts("Close"))
          vim.keymap.set("n", "r", api.fs.rename, opts("Rename"))
          vim.keymap.set("n", "R", api.tree.reload, opts("Refresh"))
          vim.keymap.set("n", "s", api.node.run.system, opts("Run System"))
          vim.keymap.set("n", "S", api.tree.search_node, opts("Search"))
          vim.keymap.set("n", "U", api.tree.toggle_custom_filter, opts("Toggle Hidden"))
          vim.keymap.set("n", "W", api.tree.collapse_all, opts("Collapse"))
          vim.keymap.set("n", "x", api.fs.cut, opts("Cut"))
          vim.keymap.set("n", "y", api.fs.copy.filename, opts("Copy Name"))
          vim.keymap.set("n", "Y", api.fs.copy.relative_path, opts("Copy Relative Path"))
          vim.keymap.set("n", "<2-LeftMouse>", api.node.open.edit, opts("Open"))
          vim.keymap.set("n", "<2-RightMouse>", api.tree.change_root_to_node, opts("CD"))
          vim.keymap.set("n", "=", api.tree.change_root_to_node, opts("CD"))
          vim.keymap.set("n", "<leader>", api.node.open.edit, opts("Open"))
        end

        require("nvim-tree").setup({
          on_attach = on_attach,
          disable_netrw = true,
          diagnostics = {
            enable = true,
          },
          renderer = {
            highlight_git = true,
            group_empty = true,
          },
          git = {
            ignore = false,
          },
        })
      end,
    },

    {
      "glacambre/firenvim",
      -- Lazy load firenvim
      -- Explanation: https://github.com/folke/lazy.nvim/discussions/463#discussioncomment-4819297
      lazy = not vim.g.started_by_firenvim,
      dependencies = { "zbirenbaum/copilot.lua", "neovim/nvim-lspconfig" },
      build = function()
        require("lazy").load({ plugins = "firenvim", wait = true })
        vim.fn["firenvim#install"](0)
      end,
      config = function()
        vim.o.laststatus = 0
        vim.g.firenvim_config = {
          globalSettings = { alt = "all" },
          localSettings = {
            [".*"] = {
              cmdline = "neovim",
              content = "text",
              priority = 0,
              selector = "textarea",
              takeover = "never",
            },
          },
        }
      end,
    },
  }

  return specs
end

return M
