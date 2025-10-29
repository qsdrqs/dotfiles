-- Plugin: kevinhwang91/nvim-ufo
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
      -- smart fold
      "kevinhwang91/nvim-ufo",
      dependencies = { "kevinhwang91/promise-async" },
      config = function()
        if vim.b.treesitter_disable ~= 1 then
          load_plugin("nvim-treesitter")
        end

        vim.o.foldcolumn = "1"
        vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
        vim.o.foldlevelstart = 99
        vim.o.foldenable = true

        local function handler(virt_text, lnum, end_lnum, width, truncate, ctx)
          local result = {}

          local counts = ("󰁂 %d"):format(end_lnum - lnum)
          local prefix = "⋯⋯  "
          local suffix = "  ⋯⋯"
          local padding = ""

          local end_virt_text = ctx.get_fold_virt_text(end_lnum)
          -- trim the end_virt_text
          local leader_num = 0
          for i = 1, #end_virt_text[1][1] do
            local c = end_virt_text[1][1]:sub(i, i)
            if c == " " then
              leader_num = leader_num + 1
            else
              break
            end
          end
          local first_end_text = end_virt_text[1][1]:sub(leader_num + 1, -1)
          if first_end_text == "" then
            table.remove(end_virt_text, 1)
          else
            end_virt_text[1][1] = first_end_text
          end

          local start_virt_text = ctx.get_fold_virt_text(lnum)

          local end_virt_text_width = 0
          for _, item in ipairs(end_virt_text) do
            end_virt_text_width = end_virt_text_width + vim.fn.strdisplaywidth(item[1])
          end

          -- add left parenthesis if missing
          local maybe_left_parenthesis = nil
          if end_virt_text[1] ~= nil and start_virt_text[#start_virt_text] ~= nil then
            if
              string.find(end_virt_text[1][1], "}", 1, true)
              and not string.find(start_virt_text[#start_virt_text][1], "{", 1, true)
            then
              maybe_left_parenthesis = { " {", end_virt_text[1][2] }
            end
            if
              string.find(end_virt_text[1][1], "]", 1, true)
              and not string.find(start_virt_text[#start_virt_text][1], "[", 1, true)
            then
              maybe_left_parenthesis = { " [", end_virt_text[1][2] }
            end
            if
              string.find(end_virt_text[1][1], ")", 1, true)
              and not string.find(start_virt_text[#start_virt_text][1], "(", 1, true)
            then
              maybe_left_parenthesis = { " (", end_virt_text[1][2] }
            end
          end

          if end_virt_text_width > 5 then
            end_virt_text = {}
            end_virt_text_width = 0
          end

          local sufWidth = (2 * vim.fn.strdisplaywidth(suffix)) + vim.fn.strdisplaywidth(counts) + end_virt_text_width

          local target_width = width - sufWidth
          local cur_width = 0

          for _, chunk in ipairs(virt_text) do
            local chunk_text = chunk[1]

            local chunk_width = vim.fn.strdisplaywidth(chunk_text)
            if target_width > cur_width + chunk_width then
              table.insert(result, chunk)
            else
              chunk_text = truncate(chunk_text, target_width - cur_width)
              local hl_group = chunk[2]
              table.insert(result, { chunk_text, hl_group })
              chunk_width = vim.fn.strdisplaywidth(chunk_text)

              if cur_width + chunk_width < target_width then
                padding = padding .. (" "):rep(target_width - cur_width - chunk_width)
              end
              break
            end
            cur_width = cur_width + chunk_width
          end

          if maybe_left_parenthesis then
            table.insert(result, maybe_left_parenthesis)
          end
          table.insert(result, { "...", "UfoFoldedEllipsis" })
          -- table.insert(result, { counts, "MoreMsg" })
          -- table.insert(result, { suffix, "UfoFoldedEllipsis" })

          for _, v in ipairs(end_virt_text) do
            table.insert(result, v)
          end

          table.insert(result, { padding, "" })

          return result
        end

        local function customizeSelector(bufnr)
          local function handleFallbackException(err, providerName)
            if type(err) == "string" and err:match("UfoFallbackException") then
              return require("ufo").getFolds(providerName, bufnr)
            else
              return require("promise").reject(err)
            end
          end

          return require("ufo")
            .getFolds("lsp", bufnr)
            :catch(function(err)
              return handleFallbackException(err, "treesitter")
            end)
            :catch(function(err)
              return handleFallbackException(err, "indent")
            end)
        end

        require("ufo").setup({
          provider_selector = function(bufnr, filetype, buftype)
            return customizeSelector
          end,
          enable_get_fold_virt_text = true,
          fold_virt_text_handler = handler,
        })
        -- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
        vim.keymap.set("n", "zR", require("ufo").openAllFolds)
        vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
      end,
    },

  }
end
