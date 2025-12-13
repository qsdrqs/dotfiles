-- Plugin: saghen/blink.cmp
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
      "saghen/blink.cmp",
      -- optional: provides snippets for the snippet source
      dependencies = {
        "L3MON4D3/LuaSnip",
        "xzbdmw/colorful-menu.nvim",
        -- 'Kaiser-Yang/blink-cmp-avante',
      },
      version = "1.*",
      flake = true,
      config = function()
        local copilot_suggestion = require("copilot.suggestion")
        local nobold_cache = {}
        local opts = {
          snippets = { preset = "luasnip" }, -- Use 'luasnip' as the snippet engine
          cmdline = {
            keymap = {
              preset = "inherit",
              ["<CR>"] = {
                "fallback",
              },
            },
            completion = {
              menu = {
                auto_show = true,
              },
              list = {
                selection = {
                  preselect = true,
                  auto_insert = false,
                },
              },
            },
          },
          keymap = {
            preset = "default",
            ["<C-k>"] = { "select_prev", "fallback" },
            ["<C-j>"] = { "select_next", "fallback" },
            ["<Tab>"] = {
              function(cmp)
                if cmp.snippet_active() then
                  return cmp.accept()
                else
                  return cmp.select_and_accept()
                end
              end,
              function()
                if copilot_suggestion.is_visible() then
                  copilot_suggestion.accept()
                  return true
                end
              end,
              "snippet_forward",
              "fallback",
            },
            ["<CR>"] = {
              "select_and_accept",
              "fallback",
            },
            ["<C-e>"] = {
              "hide",
              function()
                if copilot_suggestion.is_visible() then
                  copilot_suggestion.dismiss()
                  return true
                end
              end,
              "fallback",
            },
          },

          appearance = {
            -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
            -- Adjusts spacing to ensure icons are aligned
            nerd_font_variant = "mono",
          },

          -- (Default) Only show the documentation popup when manually triggered
          completion = {
            trigger = {
              show_on_keyword = true,
              show_on_trigger_character = true,
            },
            documentation = {
              auto_show = true,
              auto_show_delay_ms = 100,
              window = {
                border = "rounded",
              },
            },
            list = {
              selection = {
                preselect = true,
                auto_insert = false,
              },
            },
            menu = {
              border = "rounded",
              draw = {
                -- We don't need label_description now because label and label_description are already
                -- combined together in label by colorful-menu.nvim.
                columns = { { "kind_icon" }, { "label", gap = 1 } },
                components = {
                  kind_icon = {
                    text = function(ctx)
                      local kind = kind_icons_list[ctx.kind]
                      if kind == nil then
                        error("Unknown kind: " .. ctx.kind)
                      end
                      return kind
                    end,
                    highlight = function(ctx)
                      local hl = ctx.kind_hl
                      if vim.tbl_contains({ "Path" }, ctx.source_name) then
                        local dev_icon, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
                        if dev_icon then
                          hl = dev_hl
                        end
                      end
                      return hl
                    end,
                  },
                  label = {
                    text = function(ctx)
                      return require("colorful-menu").blink_components_text(ctx)
                    end,
                    highlight = function(ctx)
                      local highlights = {}
                      local highlights_info = require("colorful-menu").blink_highlights(ctx)
                      if highlights_info ~= nil then
                        for _, v in ipairs(highlights_info.highlights) do
                          local group = v.group
                          if nobold_cache[group] == nil then
                            local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
                            if hl.bold then
                              hl.bold = false
                              vim.api.nvim_set_hl(0, group .. "NoBold", hl)
                              v.group = group .. "NoBold"
                              nobold_cache[group] = true
                            else
                              nobold_cache[group] = false
                            end
                          elseif nobold_cache[group] == true then
                            v.group = group .. "NoBold"
                          end
                        end
                        highlights = highlights_info.highlights
                      end
                      for _, idx in ipairs(ctx.label_matched_indices) do
                        table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
                      end
                      return highlights
                    end,
                  },
                },
              },
            },
          },

          -- Default list of enabled providers defined so that you can extend it
          -- elsewhere in your config, without redefining it, due to `opts_extend`
          sources = {
            default = function(ctx)
              default = { "lsp", "path", "snippets", "buffer" }
              if vim.bo.filetype == "lua" then
                table.insert(default, 1, "lazydev")
              end
              -- if vim.bo.filetype:find('^Avante') then
              --   table.insert(default, 1, 'avante')
              -- end
              return default
            end,
            providers = {
              lazydev = {
                name = "LazyDev",
                module = "lazydev.integrations.blink",
                -- make lazydev completions top priority (see `:h blink.cmp`)
                score_offset = 100,
              },
              -- avante = {
              --   module = 'blink-cmp-avante',
              --   name = 'Avante',
              --   opts = {
              --     -- options for blink-cmp-avante
              --   }
              -- }
            },
            per_filetype = {
              codecompanion = { "codecompanion" },
            },
          },

          -- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
          -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
          -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
          --
          -- See the fuzzy documentation for more information
          fuzzy = {
            implementation = "prefer_rust",
            prebuilt_binaries = {
              download = false,
              ignore_version_mismatch = true,
            },
          },
        }
        if vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/blink.cmp/.git") == 0 then
          opts.fuzzy.implementation = "lua" -- no Rust fuzzy matcher available
        end
        require("blink.cmp").setup(opts)
      end,
    },

  }
end
