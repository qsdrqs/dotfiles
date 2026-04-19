local M = {}

local uv = vim.loop or vim.uv
local nix_dir = vim.fn.stdpath("data") .. "/nix"
local cache_dir = vim.fn.stdpath("cache") .. "/nix-helptags"

---Check whether a directory contains any .txt help files.
--@param path string
--@return boolean
local function has_help_files(path)
  local handle = uv.fs_scandir(path)
  if not handle then
    return false
  end
  while true do
    local name = uv.fs_scandir_next(handle)
    if not name then
      return false
    end
    if name:match("%.txt$") then
      return true
    end
  end
end

---Resolve the real path of a nix plugin (follows symlinks into the store).
--@param plugin_dir string
--@return string|nil
local function resolve_nix_path(plugin_dir)
  return uv.fs_realpath(plugin_dir)
end

---Read the stored origin path from a sentinel file.
--@param sentinel string
--@return string|nil
local function read_sentinel(sentinel)
  local fd = uv.fs_open(sentinel, "r", 438)
  if not fd then
    return nil
  end
  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return nil
  end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return data
end

---Write the origin path to a sentinel file.
--@param sentinel string
--@param origin string
local function write_sentinel(sentinel, origin)
  local fd = uv.fs_open(sentinel, "w", 420)
  if not fd then
    return
  end
  uv.fs_write(fd, origin, 0)
  uv.fs_close(fd)
end

---Remove all entries inside a directory.
--@param dir string
local function clear_dir(dir)
  local handle = uv.fs_scandir(dir)
  if not handle then
    return
  end
  while true do
    local name = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    uv.fs_unlink(dir .. "/" .. name)
  end
end

---Symlink all files from src into dest.
--@param src string
--@param dest string
local function symlink_contents(src, dest)
  local handle = uv.fs_scandir(src)
  if not handle then
    return
  end
  while true do
    local name = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    uv.fs_symlink(src .. "/" .. name, dest .. "/" .. name)
  end
end

---Generate helptags caches for read-only nix plugin doc directories.
---For each plugin under the nix data dir that ships doc/*.txt files,
---create a writable cache directory with symlinks to the original
---help files and run :helptags on it. Returns the cache paths for
---the caller to feed into lazy.nvim performance.rtp.paths.
--@return string[]
function M.generate()
  local paths = {}
  if vim.fn.isdirectory(nix_dir) == 0 then
    return paths
  end

  local handle = uv.fs_scandir(nix_dir)
  if not handle then
    return paths
  end

  while true do
    local name, ftype = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if ftype == "directory" or ftype == "link" then
      local src_doc = nix_dir .. "/" .. name .. "/doc"
      if uv.fs_stat(src_doc) and has_help_files(src_doc) then
        local plugin_cache = cache_dir .. "/" .. name
        local cached_doc = plugin_cache .. "/doc"
        local sentinel = plugin_cache .. "/.origin"

        local origin = resolve_nix_path(nix_dir .. "/" .. name) or ""
        local stored = read_sentinel(sentinel)

        if stored ~= origin or not uv.fs_stat(cached_doc .. "/tags") then
          vim.fn.mkdir(cached_doc, "p")
          clear_dir(cached_doc)
          symlink_contents(src_doc, cached_doc)
          pcall(vim.cmd.helptags, cached_doc)
          write_sentinel(sentinel, origin)
        end

        paths[#paths + 1] = plugin_cache
      end
    end
  end
  return paths
end

return M
