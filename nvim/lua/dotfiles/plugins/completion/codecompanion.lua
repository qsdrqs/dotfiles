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
      "olimorris/codecompanion.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
      cmd = {
        "CodeCompanion",
        "CodeCompanionChat",
        "CodeCompanionActions",
        "CodeCompanionCmd",
      },
      keys = {
        {
          "<C-.>",
          "<cmd>CodeCompanionChat Toggle<cr>",
          mode = { "n", "v", "i" },
          desc = "Toggle CodeCompanion Chat",
        },
        {
          "<localleader>aa",
          "<cmd>CodeCompanionChatAddLines<cr>",
          mode = { "v" },
          desc = "Add selection to CodeCompanion Chat",
        },
        {
          "<localleader>ae",
          "<cmd>CodeCompanion<cr>",
          mode = { "n", "v" },
          desc = "CodeCompanion Inline Actions",
        },
      },
      config = function()
        local copilot_adapter = {
          name = "copilot",
          model = "claude-sonnet-4.5",
        }
        local opts = {
          adapters = {
            acp = {
              codex = function()
                return require("codecompanion.adapters").extend("codex", {
                  defaults = {
                    auth_method = "chatgpt",
                  },
                })
              end,
            },
          },
          display = {
            chat = {
              window = {
                position = "right",
                width = 0.4,
              },
            },
          },
          interactions = {
            background = {
              adapter = copilot_adapter,
            },
            -- chat = {
            --   adapter = "codex",
            -- },
            -- chat = {
            --   adapter = copilot_adapter,
            -- },
            chat = {
              adapter = "opencode",
            },
            inline = {
              adapter = copilot_adapter,
            },
            cmd = {
              adapter = copilot_adapter,
            },
          },
          rules = {
            programmer = {
              description = "Codex skill for programming tasks.",
               files = {
                "~/.codex/skills/programmer/SKILL.md",
              }
            },
            plan = {
              description = "Codex skill for planning tasks and projects.",
              files = {
                "~/.codex/skills/plan/SKILL.md",
              }
            },
            coach = {
              description = "Codex skill for coaching and mentoring.",
              files = {
                "~/.codex/skills/coach/SKILL.md",
              }
            },
          }
        }
        require("codecompanion").setup(opts)

        local function add_selection_to_chat()
          -- 1. Get the current buffer path and a readable relative path.
          local bufnr = vim.api.nvim_get_current_buf()
          local file_path = vim.api.nvim_buf_get_name(bufnr)
          local relative_path = vim.fn.fnamemodify(file_path, ":.") -- More readable.

          -- Get the visual selection range (last visual selection marks).
          local _, start_line, _, _ = unpack(vim.fn.getpos("'<"))
          local _, end_line, _, _ = unpack(vim.fn.getpos("'>"))

          -- Note: after leaving visual mode, getpos can be stale. For accuracy,
          -- nvim_buf_get_mark is better, but this keeps the command simple.

          local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

          -- 2. Get or initialize the CodeCompanion chat instance.
          local cc = require("codecompanion")
          local chat = cc.last_chat()

          if not chat then
            -- If there is no active chat, open one (optional).
            vim.cmd("CodeCompanionChat")
            chat = cc.last_chat()
          end

          if not chat then
            vim.notify("CodeCompanion chat window not found", vim.log.levels.ERROR)
            return
          end

          -- 3. Build the message.
          local code_block
          if #lines == 0 then
            code_block = string.format("Reference: %s", relative_path)
          else
            code_block = string.format("Reference: %s:%d-%d", relative_path, start_line, end_line)
          end

          -- 4. Append content to the chat buffer.
          -- chat.bufnr is the chat window buffer ID.
          if chat.bufnr and vim.api.nvim_buf_is_valid(chat.bufnr) then
            -- Get the current line count.
            local last_line = vim.api.nvim_buf_line_count(chat.bufnr)

            -- Insert as a list of lines.
            local content_lines = vim.split(code_block, "\n", { plain = true })
            vim.api.nvim_buf_set_lines(chat.bufnr, last_line, last_line, false, content_lines)

            local target_line = last_line + #content_lines
            local target_col = #(content_lines[#content_lines] or "")
            for _, winid in ipairs(vim.fn.win_findbuf(chat.bufnr)) do
              vim.api.nvim_win_set_cursor(winid, { target_line, target_col })
            end

          else
            vim.notify("Cannot access chat buffer", vim.log.levels.ERROR)
          end
        end

        -- Create the :CodeCompanionChatAddLines command.
        vim.api.nvim_create_user_command("CodeCompanionChatAddLines", function()
          add_selection_to_chat()
        end, { range = true })
      end
    },

  }
end
