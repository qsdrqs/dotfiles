local i = require("dotfiles.luasnip.util")
local M = {
  i.s(
    {
      trig = [[CALC%s+([^\n]-)%s+CALC]],
      regTrig = true,
      wordTrig = false,
    },
    i.f(function(_, snip)
      local expr = snip.captures[1] -- text between the CALC tags
      -- Evaluate safely via the system’s python (simple use-case; extend as needed).
      local handle = io.popen(string.format("python3 - <<'PY'\nprint(%s)\nPY", expr:gsub("'", [["]])))
      if not handle then
        return "<python error>"
      end
      local out = handle:read("*a")
      handle:close()
      return (out or ""):gsub("%s+$", "") -- strip trailing newline/space
    end, {})
  ),
}
return M
