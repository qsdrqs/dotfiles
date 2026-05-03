-- Plugin: nickjvandyke/opencode.nvim

local function focus_context_window(context)
  if context.win and vim.api.nvim_win_is_valid(context.win) then
    vim.api.nvim_set_current_win(context.win)
  end
end

local function open_multiline_prompt(opts)
  opts = opts or {}

  local context = require("opencode.context").new()
  local max_width = math.max(1, vim.o.columns - 4)
  local max_height = math.max(1, vim.o.lines - 4)
  local width = math.min(max_width, math.max(50, math.floor(vim.o.columns * 0.5)))
  local height = math.min(max_height, math.max(8, math.floor(vim.o.lines * 0.3)))
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  local lines = vim.split(opts.default or "", "\n", { plain = true })
  local buf = vim.api.nvim_create_buf(false, true)
  local closed = false

  if #lines == 0 then
    lines = { "" }
  end

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "text"
  vim.bo[buf].modifiable = true
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(buf, true, {
    border = "rounded",
    col = col,
    height = height,
    relative = "editor",
    row = row,
    style = "minimal",
    title = " opencode ",
    title_pos = "center",
    width = width,
  })

  vim.wo[win].linebreak = true
  vim.wo[win].wrap = true
  vim.api.nvim_win_set_cursor(win, { #lines, #(lines[#lines] or "") })

  local function finish(callback)
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    focus_context_window(context)
    if callback then
      callback()
    end
  end

  local function cancel()
    finish(function()
      context:resume()
    end)
  end

  local function submit_prompt(submit)
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if vim.trim(text) == "" then
      vim.notify("Prompt is empty", vim.log.levels.WARN, { title = "opencode" })
      return
    end

    finish(function()
      require("opencode").prompt(text, {
        context = context,
        submit = submit,
      })
    end)
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      if closed then
        return
      end
      closed = true
      focus_context_window(context)
      context:resume()
    end,
    once = true,
  })

  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    submit_prompt(true)
  end, { buffer = buf, desc = "Submit opencode prompt", silent = true })
  vim.keymap.set("n", "<CR>", function()
    submit_prompt(true)
  end, { buffer = buf, desc = "Submit opencode prompt", silent = true })
  vim.keymap.set("n", "q", cancel, { buffer = buf, desc = "Close opencode prompt", silent = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, desc = "Close opencode prompt", silent = true })
  vim.keymap.set("i", "<C-c>", cancel, { buffer = buf, desc = "Close opencode prompt", silent = true })

  vim.cmd.startinsert()
end

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
      "nickjvandyke/opencode.nvim",
      dependencies = { "folke/snacks.nvim" },
      keys = {
        {
          "<localleader>aa",
          function()
            require("opencode").ask("@this: ", { submit = true })
          end,
          mode = { "n", "x" },
          desc = "Ask opencode",
        },
        {
          "<localleader>aA",
          function()
            open_multiline_prompt({ default = "@this: " })
          end,
          mode = { "n", "x" },
          desc = "Compose opencode prompt",
        },
        {
          "<localleader>as",
          function()
            require("opencode").select()
          end,
          mode = { "n", "x" },
          desc = "Select opencode action",
        },
        {
          "<localleader>at",
          function()
            require("opencode").toggle()
          end,
          mode = { "n", "t" },
          desc = "Toggle opencode",
        },
        {
          "go",
          function()
            return require("opencode").operator("@this ")
          end,
          mode = { "n", "x" },
          desc = "Add range to opencode",
          expr = true,
        },
        {
          "goo",
          function()
            return require("opencode").operator("@this ") .. "_"
          end,
          mode = "n",
          desc = "Add line to opencode",
          expr = true,
        },
      },
      cmd = { "OpencodeToggle" },
      config = function()
        vim.g.opencode_opts = {}
        vim.o.autoread = true
        -- create OpencodeToggle command
        vim.api.nvim_create_user_command("OpencodeToggle", function()
          require("opencode").toggle()
        end, { desc = "Toggle opencode" })
      end,
    },

  }
end
