local M = {}

---Map `use_nix` flag to the plugin development pattern.
--@param use_nix boolean?
--@return string
local function resolve_pattern(use_nix)
  if use_nix then
    return "."
  end
  return "*"
end

---Build lazy.nvim setup options so they can be reused when needed.
--@param use_nix boolean?
--@return table
function M.build_options(use_nix)
  local pattern = resolve_pattern(use_nix)
  return {
    defaults = {
      lazy = true,
    },
    dev = {
      path = vim.fn.stdpath("data") .. "/nix",
      patterns = { pattern },
      fallback = true,
    },
    install = {
      missing = false,
    },
  }
end

---Configure lazy.nvim with the provided plugin specification.
--@param plugins table
--@param opts table? { use_nix?: boolean }
--@return table lazy_opts
function M.setup(plugins, opts)
  opts = opts or {}
  local use_nix = opts.use_nix
  if use_nix == nil then
    use_nix = true
  end

  local lazy_opts = M.build_options(use_nix)
  require("lazy").setup(plugins, lazy_opts)
  return lazy_opts
end

---Print the registered plugins grouped by category.
function M.print_categories()
  require("dotfiles.plugins.catalog").print()
end

return M
