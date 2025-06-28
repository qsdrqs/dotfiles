local ls = require("luasnip")

ls.add_snippets("c", require("dotfiles.luasnip.c"))
ls.add_snippets("lua", require("dotfiles.luasnip.lua"))
ls.add_snippets("tex", require("dotfiles.luasnip.tex"))
ls.add_snippets("all", require("dotfiles.luasnip.all"))
