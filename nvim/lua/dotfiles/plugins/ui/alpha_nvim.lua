-- Plugin: goolord/alpha-nvim
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

  }
end
