local M = {}

local configured = false

---Customize runtime behaviour that does not belong to a plugin module.
function M.setup()
  if configured then
    return
  end
  configured = true

  -- mask some deprecate messages
  local original_deprecate = vim.deprecate
  local suppressed = {
    "vim.region",
    "client.request",
    "client.supports_method",
  }
  vim.deprecate = function(name, alt, plugin, backtrace)
    for _, pattern in ipairs(suppressed) do
      if name:find(pattern, 1, true) then
        return
      end
    end
    original_deprecate(name, alt, plugin, backtrace)
  end

  -- improve performance
  vim.keymap.set("n", "<leader>pf", "<cmd>IBLToggleScope<cr><cmd>TSToggle highlight<cr>", { silent = true })

  local function yazi_here()
    local buf_path = vim.fn.expand("%")
    vim.cmd("enew")
    vim.bo.buflisted = false
    vim.bo.swapfile = false
    if buf_path == "" then
      buf_path = vim.fn.getcwd()
    end
    vim.fn.jobstart({
      "yazi",
      buf_path,
    }, { term = true })
    vim.cmd("startinsert")
  end

  vim.keymap.set("n", "-", yazi_here, { desc = "Yazi here" })
end

return M
