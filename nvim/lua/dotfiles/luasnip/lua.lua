local i = require("dotfiles.luasnip.util")

local calculate_dashes_pre = function(args)
  local tag_length = args[1][1] and #args[1][1] or 0
  local left_dashes = string.rep("-", (33 - math.floor(tag_length / 2)))
  return left_dashes
end

local calculate_dashes_post = function(args)
  local tag_length = args[1][1] and #args[1][1] or 0
  local right_dashes = string.rep("-", (86 - 35 - math.floor(tag_length / 2)))
  if tag_length % 2 == 0 then
    return right_dashes
  else
    return right_dashes .. "-"
  end
end

local M = {
  i.s("tag", {
    i.f(calculate_dashes_pre, { 1 }),
    i.i(1, "tag"),
    i.f(calculate_dashes_post, { 1 }),
    i.t({ "", "" }),
    i.t({ "", "" }),
    i.f(function(args)
      local pre_len = string.len(calculate_dashes_pre(args))
      local post_len = string.len(calculate_dashes_post(args))
      local tag_length = args[1][1] and #args[1][1] or 0
      local total_length = pre_len + post_len + tag_length
      return string.rep("-", total_length)
    end, { 1 }),
  }),
}

return M
