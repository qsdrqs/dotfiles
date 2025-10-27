local M = {}

---Resolve lazy.nvim installation path and ensure it is on the runtimepath.
--@param opts table? { use_nix?: boolean }
--@return string lazypath
--@return boolean use_nix
function M.ensure_lazy(opts)
  opts = opts or {}
  local use_nix = opts.use_nix
  if use_nix == nil then
    use_nix = true
  end

  local data_dir = vim.fn.stdpath("data")
  local nix_lazy = data_dir .. "/nix/lazy.nvim"
  local default_lazy = data_dir .. "/lazy/lazy.nvim"

  local lazypath
  if vim.fn.isdirectory(nix_lazy) == 1 and use_nix then
    lazypath = nix_lazy
  else
    lazypath = default_lazy
    use_nix = false
  end

  local loop_or_uv = vim.loop or vim.uv
  if not loop_or_uv.fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "--branch=stable", -- keep parity with legacy bootstrap; remove to track HEAD
      "https://github.com/folke/lazy.nvim.git",
      lazypath,
    })
  end

  if not vim.tbl_contains(vim.opt.rtp:get(), lazypath) then
    vim.opt.rtp:prepend(lazypath)
  end

  return lazypath, use_nix
end

return M
