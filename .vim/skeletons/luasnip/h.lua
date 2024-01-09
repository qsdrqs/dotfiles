--[[ /*
 * `!v expand('%')`
 *
 * Copyright (C) `date +%Y` username
 *
 * Author: username <email>
 * All Right Reserved
 *
 */
#ifndef `!p snip.rv=fn.replace('.','_').upper()`
#define `!p snip.rv=fn.replace('.','_').upper()`
$1
#endif ]]
local i = require("dotfiles.luasnip.util")

return {
  i.t({
    "/*",
    " * " .. vim.fn.expand("%"),
    " *",
    " * Copyright (C) " .. vim.fn.strftime("%Y") .. " " .. vim.g.skeleton_username,
    " *",
    " * Author: " .. vim.g.skeleton_username .. " <" .. vim.g.skeleton_email .. ">",
    " * All Right Reserved",
    " *",
    " */",
    "#ifndef "
  }),
  i.i(1, "_" .. string.upper(string.gsub(vim.fn.expand("%"), "%.", "_"))),
  i.t({ "", "" }),
  i.f(function(args) return "#define " .. args[1][1] end, { 1 }),
  i.t({ "", "" }),
  i.i(2, ""),
}
