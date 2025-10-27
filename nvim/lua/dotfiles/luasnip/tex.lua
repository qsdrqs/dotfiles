local i = require("dotfiles.luasnip.util")

local M = {
  -- snippet $ "Math"
  -- $${1}$`!p
  -- if t[2] and t[2][0] not in [',', '.', '?', '-', ' ']:
  --     snip.rv = ' '
  -- else:
  --     snip.rv = ''
  -- `$2
  -- endsnippet
  i.s("$", {
    i.t("$"),
    i.i(1),
    i.t("$"),
    i.f(function(args)
      local items = { [","] = true, ["."] = true, ["?"] = true, ["-"] = true, [" "] = true }
      if args[1][1] ~= nil and items[args[1][1]:sub(1, 1)] == nil then
        return " "
      else
        return ""
      end
    end, { 2 }),
    i.i(2),
  }),
  -- snippet '([A-Za-z])(\d)' "auto subscript" wr
  -- `!p snip.rv = match.group(1)`_`!p snip.rv = match.group(2)`
  -- endsnippet
  i.s({
    trig = "([A-Za-z])(%d)",
    trigEngine = "pattern",
    name = "auto subscript",
  }, {
    i.f(function(_, snip)
      local letter, number = snip.captures[1], snip.captures[2]
      return letter .. "_" .. number
    end, {}),
  }),
  -- snippet ^ "superscript" iA
  -- ^{$1}$0
  -- endsnippet
  i.s({
    trig = "^",
    snippetType = "autosnippet",
    wordTrig = false,
    name = "superscript",
  }, {
    i.t("^"),
    i.t("{"),
    i.i(1),
    i.t("}"),
    i.i(2),
  }),
  -- snippet _ "lowerscript" iA
  -- _{$1}$0
  -- endsnippet
  i.s({
    trig = "_",
    snippetType = "autosnippet",
    wordTrig = false,
    name = "lowerscript",
  }, {
    i.t("_"),
    i.t("{"),
    i.i(1),
    i.t("}"),
    i.i(2),
  }),
  -- # 若输入 ‘/’，则检查符号前的字符是否为数字或者字母，
  -- # 将数字或字母作为分子扩展为Latex分数形式然后在分母部分等待输入
  -- snippet '((\d+)|(\d*)(\\)?([A-Za-z]+)((\^|_)(\{\d+\}|\d))*)/' "Fraction" wr
  -- \\frac{`!p snip.rv = match.group(1)`}{$1}$0
  -- endsnippet
  i.postfix({
    trig = "/",
    match_pattern = "[%w%.%_%^%-%{%}]+$",
  }, {
    i.d(1, function(_, parent)
      return i.sn(nil, { i.t("\\frac{" .. parent.env.POSTFIX_MATCH .. "}" .. "{"), i.i(1), i.t("}"), i.i(2) })
    end),
  }),
}

return M
