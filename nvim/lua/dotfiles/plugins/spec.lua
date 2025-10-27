local helpers = require("dotfiles.core.helpers")
local icons = require("dotfiles.core.icons")
local highlights = require("dotfiles.core.highlights")
local navigation = require("dotfiles.plugins.navigation")
local lsp = require("dotfiles.plugins.lsp")
local completion = require("dotfiles.plugins.completion")
local treesitter = require("dotfiles.plugins.treesitter")
local ui = require("dotfiles.plugins.ui")
local git = require("dotfiles.plugins.git")
local tools = require("dotfiles.plugins.tools")
local session = require("dotfiles.plugins.session")
local dap = require("dotfiles.plugins.dap")
local tags = require("dotfiles.plugins.tags")
local productivity = require("dotfiles.plugins.productivity")
local catalog = require("dotfiles.plugins.catalog")

local load_plugins = helpers.load_plugins
local load_plugin = helpers.load_plugin
local lsp_merge_project_config = helpers.lsp_merge_project_config

local kind_icons_list = icons.kinds
local kind_icons = icons.completion
local highlight_group_list = highlights.colorizer_groups

local function vscode_next_hunk()
  require("vscode-neovim").action("workbench.action.editor.nextChange")
end
local function vscode_prev_hunk()
  require("vscode-neovim").action("workbench.action.editor.previousChange")
end

local context = {
  load_plugins = load_plugins,
  load_plugin = load_plugin,
  lsp_merge_project_config = lsp_merge_project_config,
  kind_icons_list = kind_icons_list,
  kind_icons = kind_icons,
  highlight_group_list = highlight_group_list,
  icons = icons,
  highlights = highlights,
  vscode_next_hunk = vscode_next_hunk,
  vscode_prev_hunk = vscode_prev_hunk,
}

local plugins = {
  { "folke/lazy.nvim", lazy = false },
}

local grouped_specs = {}

for _, module in ipairs({
  { name = "navigation", mod = navigation },
  { name = "lsp", mod = lsp },
  { name = "completion", mod = completion },
  { name = "treesitter", mod = treesitter },
  { name = "ui", mod = ui },
  { name = "git", mod = git },
  { name = "tools", mod = tools },
  { name = "session", mod = session },
  { name = "dap", mod = dap },
  { name = "tags", mod = tags },
  { name = "productivity", mod = productivity },
}) do
  local items = module.mod.setup(context)
  grouped_specs[module.name] = items
  vim.list_extend(plugins, items)
end

catalog.set(grouped_specs)

return plugins
