local M = {}

local modules = {
  require("dotfiles.plugins.completion.colorful_menu"),
  require("dotfiles.plugins.completion.blink_cmp"),
  require("dotfiles.plugins.completion.blink_compat"),
  require("dotfiles.plugins.completion.vim_vsnip"),
  require("dotfiles.plugins.completion.friendly_snippets"),
  require("dotfiles.plugins.completion.lua_snip"),
  require("dotfiles.plugins.completion.copilot"),
  require("dotfiles.plugins.completion.copilot_chat"),
  require("dotfiles.plugins.completion.sidekick"),
  require("dotfiles.plugins.completion.agentic"),
  require("dotfiles.plugins.completion.codecompanion"),
  require("dotfiles.plugins.completion.claudecode"),
}

function M.setup(ctx)
  local specs = {}
  for _, mod in ipairs(modules) do
    local entries = mod(ctx)
    if entries ~= nil then
      for _, spec in ipairs(entries) do
        table.insert(specs, spec)
      end
    end
  end
  return specs
end

return M
