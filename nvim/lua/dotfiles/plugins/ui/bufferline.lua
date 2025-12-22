-- Plugin: akinsho/bufferline.nvim
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
        local bufferline_diagnostic_handler = vim.diagnostic.handlers["bufferline"]
        local noop_diagnostic_handler = {
          show = function() end,
          hide = function() end,
        }

        local function set_bufferline_diagnostics(enabled)
          opts.options.diagnostics = enabled and "nvim_lsp" or false
          if enabled then
            if bufferline_diagnostic_handler then
              vim.diagnostic.handlers["bufferline"] = bufferline_diagnostic_handler
            end
          else
            vim.diagnostic.handlers["bufferline"] = noop_diagnostic_handler
          end
          require("bufferline").setup(opts)
        end

        -- Disable bufferline diagnostics when texlab is attached (to avoid slowing down the ui)
        local texlab_bufs = {}
        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if not client or client.name ~= "texlab" then
              return
            end
            if texlab_bufs[args.buf] then
              return
            end
            texlab_bufs[args.buf] = true
            set_bufferline_diagnostics(false)
          end,
        })

        vim.api.nvim_create_autocmd("LspDetach", {
          callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if not client or client.name ~= "texlab" then
              return
            end
            texlab_bufs[args.buf] = nil
            if next(texlab_bufs) == nil then
              set_bufferline_diagnostics(true)
            end
          end,
        })


        -- use alt + number to go to buffer
        for i = 1, 9 do
          vim.keymap.set("n", "<M-" .. i .. ">", function()
            require("bufferline").go_to(i, true)
          end, { noremap = true, silent = true })
        end
      end,
    },

  }
end
