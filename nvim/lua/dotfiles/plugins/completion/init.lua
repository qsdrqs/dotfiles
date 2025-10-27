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
      "xzbdmw/colorful-menu.nvim",
      config = function()
        -- local function_hl = vim.api.nvim_get_hl(0, { name = "Function", link = false })
        -- function_hl.bold = false
        -- vim.api.nvim_set_hl(0, "FunctionNoBold", function_hl)
        require("colorful-menu").setup({
          fallback_highlight = "@variable",
          max_width = 60,
        })
      end,
    },

    {
      "saghen/blink.cmp",
      -- optional: provides snippets for the snippet source
      dependencies = {
        "L3MON4D3/LuaSnip",
        "xzbdmw/colorful-menu.nvim",
        -- 'Kaiser-Yang/blink-cmp-avante',
      },
      version = "1.*",
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
          },
        }
        if vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/blink.cmp/.git") == 0 then
          opts.fuzzy.implementation = "lua" -- no Rust fuzzy matcher available
        end
        require("blink.cmp").setup(opts)
      end,
    },

    { "saghen/blink.compat" },

    { "hrsh7th/vim-vsnip" },

    { "rafamadriz/friendly-snippets", lazy = true },

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

    {
      "zbirenbaum/copilot.lua",
      lazy = true,
      init = function()
        vim.g.copilot_filetypes = {
          ["dap-repl"] = false,
          dapui_watches = false,
          markdown = true,
        }
      end,
      config = function()
        require("copilot").setup({
          panel = {
            keymap = {
              open = "<M-\\>",
            },
            layout = {
              position = "top", -- | top | left | right
              ratio = 0.4,
            },
          },
          suggestion = {
            auto_trigger = true,
            debounce = 75,
            keymap = {
              accept = nil,
              accept_word = false,
              accept_line = false,
              next = "<M-]>",
              prev = "<M-[>",
              dismiss = "<C-]>",
            },
          },
          filetypes = {
            ["dap-repl"] = false,
            dapui_watches = false,
            markdown = true,
          },
        })
        vim.g.copilot_echo_num_completions = 1
        vim.g.copilot_no_tab_map = true
        vim.g.copilot_assume_mapped = true
        vim.g.copilot_tab_fallback = ""
      end,
    },

    {
      "CopilotC-Nvim/CopilotChat.nvim",
      dependencies = {
        "zbirenbaum/copilot.lua",
        "nvim-lua/plenary.nvim",
      },
      cmd = {
        "CopilotChat",
        "CopilotChatModel",
        "CopilotChatModels",
        "CopilotChatToggle",
        "CopilotChatExplain",
        "CopilotChatTests",
        "CopilotChatFixDiagnostic",
        "CopilotChatCommit",
        "CopilotChatCommitStaged",
      },
      config = function()
        require("CopilotChat").setup({
          debug = false, -- Enable or disable debug mode, the log file will be in ~/.local/state/nvim/CopilotChat.nvim.log
          context = "buffer",
          window = {
            layout = "vertical",
            width = 0.3,
          },
          mappings = {
            reset = {
              normal = "<C-S-L>",
              insert = "<C-l>",
            },
          },
        })
      end,
    },

    {
      "MeanderingProgrammer/render-markdown.nvim",
      dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
      config = function()
        require("render-markdown").setup({
          file_types = { "markdown", "codecompanion", "Avante" },
        })
      end,
    },

    {
      "folke/sidekick.nvim",
      dependencies = {
        "zbirenbaum/copilot.lua",
      },
      opts = {
        -- add any options here
        cli = {
          mux = {
            backend = "tmux",
            enabled = true,
          },
          prompts = {
            commit = "Based on the current changes in this Git repository and the commit history, generate a descriptive git commit message that matches the style of previous commits.",
          },
        },
      },
      keys = {
        {
          "<tab>",
          function()
            -- if there is a next edit, jump to it, otherwise apply it if any
            if not require("sidekick").nes_jump_or_apply() then
              return "<Tab>" -- fallback to normal tab
            end
          end,
          expr = true,
          desc = "Goto/Apply Next Edit Suggestion",
        },
        {
          "<c-.>",
          function()
            require("sidekick.cli").toggle()
          end,
          desc = "Sidekick Toggle",
          mode = { "n", "t", "i", "x" },
        },
        {
          "<localleader>aa",
          function()
            require("sidekick.cli").send({ msg = "{file}" })
          end,
          desc = "Send File",
          mode = { "n", "t", "i" },
        },
        {
          "<localleader>as",
          function()
            require("sidekick.cli").select({ filter = { installed = true } })
          end,
          desc = "Select CLI",
        },
        {
          "<localleader>ad",
          function()
            require("sidekick.cli").close()
          end,
          desc = "Detach a CLI Session",
        },
        {
          "<localleader>aa",
          function()
            require("sidekick.cli").send({ msg = "{this}" })
          end,
          mode = { "x" },
          desc = "Send This",
        },
        {
          "<localleader>av",
          function()
            require("sidekick.cli").send({ msg = "{selection}" })
          end,
          mode = { "x" },
          desc = "Send Visual Selection",
        },
        {
          "<localleader>ap",
          function()
            require("sidekick.cli").prompt()
          end,
          mode = { "n", "x" },
          desc = "Sidekick Select Prompt",
        },
        -- Example of a keybinding to open codex directly
        {
          "<localleader>ac",
          function()
            require("sidekick.cli").toggle({ name = "codex", focus = true })
          end,
          desc = "Sidekick Toggle Codex",
        },
      },
    },

    {
      "coder/claudecode.nvim",
      cmd = {
        "ClaudeCode",
        "ClaudeCodeSend",
        "ClaudeCodeAdd",
      },
      dependencies = { "folke/snacks.nvim" },
      opts = {
        terminal = {
          split_side = "right",
        },
      },
    },
  }

  return specs
end

return M
