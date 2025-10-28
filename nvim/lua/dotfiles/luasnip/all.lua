local i = require("dotfiles.luasnip.util")
local M = {
  i.s(
    {
      trig = [[CALC%s+([^\n]-)%s+CALC]],
      regTrig = true,
      wordTrig = false,
    },
    i.f(function(_, snip)
      local expr = snip.captures[1]
      if not expr then
        return "<calc error>"
      end
      expr = expr:match("^%s*(.-)%s*$")
      if expr == "" then
        return "<calc error>"
      end

      -- Reject obviously unsafe input early (only allow math-ish characters).
      if expr:find("[^%w_%s%+%-%*/%%%^%(%)%.%,]") then
        return "<calc error>"
      end

      local env = { math = math }
      setmetatable(env, { __index = function() return nil end })

      local chunk, load_err = load("return " .. expr, "calc_expr", "t", env)
      if not chunk then
        return "<calc error>"
      end
      local ok, result = pcall(chunk)
      if not ok then
        return "<calc error>"
      end
      return tostring(result)
    end, {})
  ),
}
return M
