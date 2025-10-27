local M = {}
local ls = require("luasnip")
local snipmate_parse_fn = require("luasnip.util.parser").parse_snipmate

local insert = function(skeleton)
  local skeleton_content = vim.fn.readfile(skeleton)
  local joined_skeleton_content = table.concat(skeleton_content, "\n")
  ls.snip_expand(snipmate_parse_fn("", joined_skeleton_content, { trim_empty = false, dedent = false }), {})
end

local insert_luasnip = function(skeleton_lua)
  local path = "skeletons.luasnip." .. vim.fn.fnamemodify(skeleton_lua, ":t:r")
  package.path = skeleton_lua .. ";" .. package.path
  local skeleton_snip = require(path)
  ls.snip_expand(ls.snippet("", skeleton_snip), {})
end

M.insert_skeleton = function(opts)
  vim.g.skeleton_username = opts.username
  vim.g.skeleton_email = opts.email
  -- get skeleton path from rtp
  local skeleton_paths = vim.api.nvim_get_runtime_file("skeletons/", false)
  if #skeleton_paths == 0 then
    return
  end

  local skeleton_path = skeleton_paths[1]
  for _, file in ipairs(vim.fn.globpath(skeleton_path, "*", true, true)) do
    if vim.fn.isdirectory(file) == 1 and vim.fn.fnamemodify(file, ":t") == "luasnip" then
      for _, luasnip_file in ipairs(vim.fn.globpath(file, "*", true, true)) do
        -- get filename
        local filename = vim.fn.fnamemodify(luasnip_file, ":t:r")
        if filename == vim.fn.expand("%:e") then
          print("Inserting skeleton: " .. luasnip_file)
          insert_luasnip(luasnip_file)
          break
        end
      end
    end

    -- get filename
    local filename = vim.fn.fnamemodify(file, ":t")
    if filename == vim.fn.expand("%:t") then
      print("Inserting skeleton: " .. file)
      insert(file)
      break
    end

    -- get extension
    local name_without_ext = vim.fn.fnamemodify(file, ":t:r")
    if name_without_ext == "skeleton" then
      local ext = vim.fn.fnamemodify(file, ":e")
      if ext == vim.fn.expand("%:e") then
        print("Inserting skeleton: " .. file)
        insert(file)
        break
      end
    end
  end
end

return M
