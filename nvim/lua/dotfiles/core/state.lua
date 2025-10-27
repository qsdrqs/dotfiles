local M = {}

local initialized = false

local g_defaults = {
  format_on_save = 0,
  wrap_on_insert_leave = 0,
  treesitter_disable = false,
  copilot_initialized = 0,
}

---Ensure global variables and options have predictable defaults.
function M.ensure_defaults()
  if initialized then
    return
  end

  for key, value in pairs(g_defaults) do
    if vim.g[key] == nil then
      vim.g[key] = value
    end
  end

  initialized = true
end

return M
