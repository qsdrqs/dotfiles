local M = {}

---Load a list of lazy.nvim plugin specs on demand.
--@param plugins string[]|table[]
function M.load_plugins(plugins)
  require("lazy").load({ plugins = plugins })
end

---Load a single lazy.nvim plugin on demand.
--@param plugin string|table
function M.load_plugin(plugin)
  require("lazy").load({ plugins = { plugin } })
end

---Merge project specific LSP configuration if available.
--@param config table
--@return table
function M.lsp_merge_project_config(config)
  if vim.g.project_config then
    return vim.tbl_deep_extend("keep", config, vim.g.project_config)
  end
  return config
end

---Setup lazy.nvim filetype based loaders.
--@param definitions { ft: string[] , plugins: string[] }[]
function M.lazy_load_by_filetype(definitions)
  local group = vim.api.nvim_create_augroup("LazyLoadFiletype", { clear = false })

  for _, spec in ipairs(definitions) do
    local should_load = false
    for _, ft in ipairs(spec.ft) do
      if vim.bo.filetype == ft then
        should_load = true
        break
      end
    end

    if should_load then
      M.load_plugins(spec.plugins)
    else
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = spec.ft,
        callback = function()
          M.load_plugins(spec.plugins)
          vim.defer_fn(function()
            vim.api.nvim_exec_autocmds("FileType", { pattern = spec.ft })
          end, 0)
        end,
        once = true,
      })
    end
  end
end

---Trim whitespace at the beginning and end of a string.
--@param text string
--@return string
function M.trim(text)
  return text:match("^%s*(.-)%s*$")
end

return M
