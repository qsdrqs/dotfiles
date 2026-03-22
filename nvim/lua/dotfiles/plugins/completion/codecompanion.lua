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
        -- {
        --   "<C-.>",
        --   "<cmd>CodeCompanionChat Toggle<cr>",
        --   mode = { "n", "v", "i" },
        --   desc = "Toggle CodeCompanion Chat",
        -- },
        -- {
        --   "<localleader>aa",
        --   "<cmd>CodeCompanionChatAddLines<cr>",
        --   mode = { "n" },
        --   desc = "Add selection to CodeCompanion Chat",
        -- },
        -- {
        --   "<localleader>aa",
        --   ":<C-u>'<,'>CodeCompanionChatAddLines<CR>gv",
        --   mode = { "v" },
        --   desc = "Add selection to CodeCompanion Chat",
        -- },
        {
          "<localleader>ae",
          "<cmd>CodeCompanion<cr>",
          mode = { "n", "v" },
          desc = "CodeCompanion Inline Actions",
        },
        -- {
        --   "<localleader>as",
        --   "<cmd>CodeCompanionChatSessionList<cr>",
        --   mode = { "n" },
        --   desc = "List and load ACP sessions",
        -- },
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
              opencode_lite = function()
                return require("codecompanion.adapters").extend("opencode", {
                  env = {
                    OPENCODE_MODEL = "github-copilot/claude-sonnet-4.5",
                  }
                })
              end,
              opencode = function()
                return require("codecompanion.adapters").extend("opencode", {
                  env = {
                    OPENCODE_MODEL = "openai/gpt-5.4",
                  }
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

        local function add_selection_to_chat(cmd_opts)
          local origin_win = vim.api.nvim_get_current_win()

          -- 1. Get the current buffer path and a readable relative path.
          local bufnr = vim.api.nvim_get_current_buf()
          local file_path = vim.api.nvim_buf_get_name(bufnr)
          local relative_path
          if file_path == "" then
            relative_path = "[No Name]"
          else
            relative_path = vim.fn.fnamemodify(file_path, ":.") -- More readable.
          end

          local has_range = cmd_opts and cmd_opts.range and cmd_opts.range > 0
          local start_line
          local end_line
          if has_range then
            start_line = cmd_opts.line1
            end_line = cmd_opts.line2

            if start_line and end_line and start_line > end_line then
              start_line, end_line = end_line, start_line
            end
          end

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
          if has_range and start_line and end_line then
            code_block = string.format("Reference: %s:%d-%d", relative_path, start_line, end_line)
          else
            code_block = string.format("Reference: %s", relative_path)
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

          if origin_win and vim.api.nvim_win_is_valid(origin_win) then
            vim.api.nvim_set_current_win(origin_win)
          end
        end

        -- Create the :CodeCompanionChatAddLines command.
        vim.api.nvim_create_user_command("CodeCompanionChatAddLines", function(cmd_opts)
          add_selection_to_chat(cmd_opts)
        end, { range = true })

        ----------------------Begin ACP Session Resume---------------------------
        -- Allows listing and loading past opencode ACP sessions so that
        -- conversation context is preserved across reconnects / restarts.
        --
        -- Original workaround by @alexghergh:
        --   https://github.com/olimorris/codecompanion.nvim/discussions/2782

        --- Extract displayable text from ACP content blocks.
        --- Handles text, resource_link, resource, image, audio, and arrays.
        --- @param content any ACP content (string | table | nil)
        --- @return string|nil
        local function acp_render_content(content)
          if type(content) == "string" then return content end
          if type(content) ~= "table" then return nil end
          if content.type == "text" and type(content.text) == "string" then
            return content.text
          end
          if content.type == "resource_link" and type(content.uri) == "string" then
            return ("[resource: %s]"):format(content.uri)
          end
          if content.type == "resource" and content.resource then
            if type(content.resource.text) == "string" then return content.resource.text end
            if type(content.resource.uri) == "string" then
              return ("[resource: %s]"):format(content.resource.uri)
            end
          end
          if content.type == "image" then return "[image]" end
          if content.type == "audio" then return "[audio]" end
          -- Array of content blocks
          if content[1] ~= nil then
            local parts = {}
            for _, item in ipairs(content) do
              local text = acp_render_content(item)
              if text and text ~= "" then table.insert(parts, text) end
            end
            return table.concat(parts, "")
          end
          return nil
        end

        --- Ensure an ACP chat with a live connection exists, then call `fn(chat)`.
        --- If no chat is open, one is created automatically (which unavoidably
        --- creates a throwaway session; session/load switches away immediately).
        --- @param fn fun(chat: table)
        local function with_acp_chat(fn)
          local cc = require("codecompanion")
          local chat = cc.last_chat()

          -- Fast path: connection already up
          if chat and chat.acp_connection and chat.acp_connection:is_connected() then
            fn(chat)
            return
          end

          -- Auto-create a chat if needed
          if not chat then
            vim.cmd("CodeCompanionChat")
          end

          -- The chat's ACP connection is established inside vim.schedule,
          -- so defer our callback to run after it.
          vim.schedule(function()
            chat = cc.last_chat()
            if not chat then
              vim.notify("Failed to create CodeCompanion chat", vim.log.levels.ERROR)
              return
            end

            -- Safety net: wait up to 15 s for the connection
            if not (chat.acp_connection and chat.acp_connection:is_connected()) then
              local ok = vim.wait(15000, function()
                return chat.acp_connection ~= nil and chat.acp_connection:is_connected()
              end, 100)
              if not ok then
                vim.notify("ACP connection timeout", vim.log.levels.ERROR)
                return
              end
            end

            fn(chat)
          end)
        end

        --- Load a specific ACP session by ID into the given chat.
        --- Based on @alexghergh's workaround from Discussion #2782.
        --- @param chat table   CodeCompanion.Chat with a live acp_connection
        --- @param session_id string
        local function load_acp_session(chat, session_id)
          local conn = chat.acp_connection
          if conn._active_prompt then
            vim.notify("ACP prompt in progress; wait for it to finish", vim.log.levels.WARN)
            return
          end

          local ACP_METHODS = require("codecompanion.acp.methods")
          local cc_config = require("codecompanion.config")

          -- Install a temporary handler that renders replayed messages
          -- into the chat buffer.  The server sends one sessionUpdate
          -- notification per historical message during session/load.
          local prev_prompt = conn._active_prompt
          conn._active_prompt = {
            handle_session_update = function(_, update)
              if type(update) ~= "table" then return end
              local text = acp_render_content(update.content)
              if not text or text == "" then return end

              if update.sessionUpdate == "user_message_chunk" then
                chat:add_buf_message(
                  { role = cc_config.constants.USER_ROLE, content = text },
                  { type = chat.MESSAGE_TYPES.USER_MESSAGE }
                )
              elseif update.sessionUpdate == "agent_message_chunk" then
                chat:add_buf_message(
                  { role = cc_config.constants.LLM_ROLE, content = text },
                  { type = chat.MESSAGE_TYPES.LLM_MESSAGE }
                )
              elseif update.sessionUpdate == "agent_thought_chunk" then
                chat:add_buf_message(
                  { role = cc_config.constants.LLM_ROLE, content = text },
                  { type = chat.MESSAGE_TYPES.REASONING_MESSAGE }
                )
              end
            end,
            handle_permission_request = function() end,
            handle_error = function() end,
          }

          -- Switch session ID *before* the RPC so incoming notifications
          -- with the new ID pass the Connection's session-ID guard.
          conn.session_id = session_id

          -- Resolve mcpServers from the adapter
          local mcp_servers = {}
          if conn.adapter_modified and conn.adapter_modified.defaults then
            mcp_servers = conn.adapter_modified.defaults.mcpServers or {}
            if mcp_servers == "inherit_from_config" then
              local mcp_ok, mcp_mod = pcall(require, "codecompanion.mcp")
              local cc_cfg = require("codecompanion.config")
              if mcp_ok and cc_cfg.mcp and cc_cfg.mcp.opts and cc_cfg.mcp.opts.acp_enabled then
                mcp_servers = mcp_mod.transform_to_acp()
              else
                mcp_servers = {}
              end
            end
          end

          local result = conn:send_rpc_request(ACP_METHODS.SESSION_LOAD, {
            sessionId = session_id,
            cwd = vim.fn.getcwd(),
            mcpServers = mcp_servers,
          })

          conn._active_prompt = prev_prompt

          if not result then
            vim.notify("session/load failed for: " .. session_id, vim.log.levels.ERROR)
            return
          end

          -- Re-link buffer for ACP commands/completions
          pcall(function()
            require("codecompanion.interactions.chat.acp.commands")
              .link_buffer_to_session(chat.bufnr, session_id)
          end)
          pcall(function() chat:update_metadata() end)

          -- Ensure a fresh user-prompt header is ready
          pcall(function()
            local cc_cfg = require("codecompanion.config")
            if chat._last_role ~= cc_cfg.constants.USER_ROLE then
              chat.cycle = chat.cycle + 1
              chat:add_buf_message({ role = cc_cfg.constants.USER_ROLE, content = "" })
              chat.header_line = vim.api.nvim_buf_line_count(chat.bufnr) - 2
            end
          end)

          vim.notify("ACP session loaded: " .. session_id, vim.log.levels.INFO)
        end

        --- Fetch the session list from the ACP server, show a picker,
        --- and load the selected session.
        --- @param chat table   CodeCompanion.Chat with a live acp_connection
        local function pick_and_load_acp_session(chat)
          local conn = chat.acp_connection

          -- opencode advertises sessionCapabilities.list
          local result = conn:send_rpc_request("session/list", {
            cwd = vim.fn.getcwd(),
          })

          if not result or not result.sessions or #result.sessions == 0 then
            vim.notify("No sessions found (session/list may not be supported)", vim.log.levels.WARN)
            return
          end

          vim.ui.select(result.sessions, {
            prompt = "Load ACP session:",
            format_item = function(s)
              local title = s.title or "Untitled"
              local id_short = s.sessionId and s.sessionId:sub(1, 8) or "?"
              local updated = s.updatedAt or ""
              if #updated > 10 then updated = updated:sub(1, 10) end
              return string.format("[%s] %s  (%s)", id_short, title, updated)
            end,
          }, function(selected)
            if not selected then return end
            load_acp_session(chat, selected.sessionId)
          end)
        end

        vim.api.nvim_create_user_command("CodeCompanionChatSessionList", function()
          with_acp_chat(pick_and_load_acp_session)
        end, { desc = "List and load ACP sessions" })

        vim.api.nvim_create_user_command("CodeCompanionChatSessionLoad", function(cmd_opts)
          if cmd_opts.args and cmd_opts.args ~= "" then
            with_acp_chat(function(chat) load_acp_session(chat, cmd_opts.args) end)
          else
            -- No ID given: fall back to listing
            with_acp_chat(pick_and_load_acp_session)
          end
        end, { nargs = "?", desc = "Load ACP session by ID, or list if no ID given" })
        ----------------------End ACP Session Resume---------------------------

      end
    },

  }
end
