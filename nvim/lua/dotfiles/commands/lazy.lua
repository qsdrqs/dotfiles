local helpers = require("dotfiles.core.helpers")

local M = {}

local lazy_filetype_specs = {
  {
    ft = { "java" },
    plugins = { "nvim-jdtls" },
  },
  {
    ft = { "c", "cpp" },
    plugins = { "clangd_extensions.nvim" },
  },
  {
    ft = { "rust" },
    plugins = { "rustaceanvim" },
  },
}

---Load plugins for specific filetypes and eager-load key groups.
function M.lazy_load()
  helpers.lazy_load_by_filetype(lazy_filetype_specs)

  helpers.load_plugins({
    -- begin lsp
    "nvim-lspconfig",
    "nvim-lightbulb",
    "fidget.nvim",
    "none-ls.nvim",
    "lsp_signature.nvim",
    "dropbar.nvim",
    "actions-preview.nvim",
    -- end lsp

    -- begin git
    "gitsigns.nvim",
    "git-conflict.nvim",
    -- end git

    -- begin vim plugins
    "vim-sandwich",
    "vim-log-highlighting",
    "vim-visual-multi",
    -- end vim plugins

    -- begin ui
    "dressing.nvim",
    "nvim-colorizer.lua",
    "bufferline.nvim",
    "nvim-notify",
    "nvim-hlslens",
    "satellite.nvim",
    "lualine.nvim",
    "alpha-nvim",
    "todo-comments.nvim",
    "statuscol.nvim",
    -- end ui

    -- begin misc
    "which-key.nvim",
    "project.nvim",
    "nvim-ufo",
    "toggleterm.nvim",
    "direnv.vim",
    "nvim-dap",
    "auto-session",
    -- end misc
  })

  -- replace netrw
  local function open_nvim_tree(data)
    local directory = vim.fn.isdirectory(data.file) == 1
    if not directory then
      return
    end

    vim.cmd.cd(data.file)
    vim.defer_fn(require("nvim-tree.api").tree.open, 0)
  end
  vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })

  vim.api.nvim_create_autocmd("InsertEnter", {
    callback = function()
      helpers.load_plugins({
        "blink.cmp",
        "copilot.lua",
      })
      vim.b.copilot_suggestion_hidden = false
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    callback = function()
      helpers.load_plugins({
        "sidekick.nvim",
      })
      vim.b.copilot_suggestion_hidden = false
    end,
    once = true,
  })

  if vim.b.treesitter_disable ~= 1 then
    -- begin treesitter (slow performance)
    helpers.load_plugins({
      "rainbow-delimiters.nvim",
      "indent-blankline.nvim",
      "nvim-treesitter-context",
      "nvim-ts-autotag",
      "hlargs.nvim",
      "vim-matchup",
      "vim-illuminate",
      "nvim-treesitter-textobjects",
    })
  -- end treesitter
  else
    vim.treesitter.stop()
    helpers.load_plugins({
      "rainbow",
    })
    vim.schedule(function()
      vim.fn["rainbow_main#load"]()
    end)
  end

  -- change <leader><leader> to telescope commands
  vim.keymap.set("n", "<leader><leader>", require("fzf-lua").commands, { silent = true })
end

---Ensure cscope/gutentags plugins are loaded and expose :LoadTags.
function M.setup_tags_command()
  local function loadTags()
    helpers.load_plugins({
      "cscope_maps.nvim",
      "vim-gutentags",
      "gutentags_plus",
    })
    vim.cmd("edit %")
    vim.keymap.set("n", "<leader>gt", "<cmd>exec 'ltag ' . expand('<cword>') . '| lopen' <CR>", { silent = false })
  end

  vim.cmd("command! LoadTags lua LoadTags()")
  _G.LoadTags = loadTags
end

---Lazy load quickfix companion when needed.
function M.setup_quickfix()
  _G.qftf = function(info)
    helpers.load_plugin("nvim-bqf")
    local items
    local ret = {}
    if info.quickfix == 1 then
      items = vim.fn.getqflist({ id = info.id, items = 0 }).items
    else
      items = vim.fn.getloclist(info.winid, { id = info.id, items = 0 }).items
    end
    local limit = 99
    local max = 0
    for i = info.start_idx, info.end_idx do
      local e = items[i]
      if e.valid == 1 and e.bufnr > 0 then
        local fname = vim.fn.bufname(e.bufnr)
        if max < #fname then
          max = #fname
        end
      end
    end
    local length = math.min(max, limit)
    local fname_fmt1, fname_fmt2 = "%-" .. length .. "s", "…%." .. (length - 1) .. "s"
    local valid_fmt = "%s │%5d:%-3d│%s %s"
    for i = info.start_idx, info.end_idx do
      local e = items[i]
      local fname = ""
      local str
      if e.valid == 1 then
        if e.bufnr > 0 then
          fname = vim.fn.bufname(e.bufnr)
          if fname == "" then
            fname = "[no name]"
          else
            fname = fname:gsub("^" .. os.getenv("HOME"), "~")
          end
          if #fname <= length then
            fname = fname_fmt1:format(fname)
          else
            fname = fname_fmt2:format(fname:sub(1 - length))
          end
        end
        local lnum = e.lnum > 99999 and -1 or e.lnum
        local col = e.col > 999 and -1 or e.col
        local qtype = e.type == "" and "" or " " .. e.type:sub(1, 1):upper()
        str = valid_fmt:format(fname, lnum, col, qtype, e.text)
      else
        str = e.text
      end
      table.insert(ret, str)
    end
    return ret
  end

  vim.o.qftf = "{info -> v:lua._G.qftf(info)}"
end

---Register globals expected by legacy configuration.
---`nvim --headless --cmd "let g:plugins_loaded=1" -c 'lua DumpPluginsList(); vim.cmd("q")'`
local function dump_plugins_list(plugins)
  for _, plugin in ipairs(plugins) do
    local opt = {}
    if plugin.branch ~= nil then
      opt.branch = plugin.branch
    end
    if plugin.tag ~= nil then
      opt.tag = plugin.tag
    end
    if plugin.version ~= nil then
      opt.version = plugin.version
    end
    if plugin.build ~= nil then
      opt.build = true
    end
    if plugin.dependencies ~= nil then
      opt.dependencies = plugin.dependencies
    end
    if plugin.commit ~= nil then
      opt.commit = plugin.commit
    end
    if plugin[1] ~= nil then
      print(plugin[1], vim.json.encode(opt))
    else
      print(plugin.url, vim.json.encode(opt))
    end
    print("\n")
  end
  print("\n")
end

function M.setup(spec)
  _G.LazyLoadPlugins = M.lazy_load
  M.setup_tags_command()
  M.setup_quickfix()
  _G.DumpPluginsList = function(plugins)
    if plugins == nil or vim.tbl_isempty(plugins) then
      dump_plugins_list(spec or {})
    else
      dump_plugins_list(plugins)
    end
  end
end

return M
