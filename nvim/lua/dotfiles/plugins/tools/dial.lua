-- Plugin: monaqa/dial.nvim
return function(ctx)
  local load_plugin = ctx.load_plugin
  local load_plugins = ctx.load_plugins
  local lsp_merge_project_config = ctx.lsp_merge_project_config
  local kind_icons_list = ctx.kind_icons_list
  local kind_icons = ctx.kind_icons
  local highlight_group_list = ctx.highlight_group_list
  local icons = ctx.icons
  local highlights = ctx.highlights
  local vscode_next_hunk = ctx.vscode_next_hunk
  local vscode_prev_hunk = ctx.vscode_prev_hunk

  return {

    {
      -- enhanced <c-a> and <c-x>
      "monaqa/dial.nvim",
      keys = {
        { "g<C-a>", mode = "v" },
        { "g<C-x>", mode = "v" },
        { "<C-a>" },
        { "<C-x>" },
      },
      config = function()
        vim.keymap.set("n", "<C-a>", require("dial.map").inc_normal(), { noremap = true })
        vim.keymap.set("n", "<C-x>", require("dial.map").dec_normal(), { noremap = true })
        vim.keymap.set("v", "<C-a>", require("dial.map").inc_visual(), { noremap = true })
        vim.keymap.set("v", "<C-x>", require("dial.map").dec_visual(), { noremap = true })
        vim.keymap.set("v", "g<C-a>", require("dial.map").inc_gvisual(), { noremap = true })
        vim.keymap.set("v", "g<C-x>", require("dial.map").dec_gvisual(), { noremap = true })

        local augend = require("dial.augend")
        require("dial.config").augends:register_group({
          -- default augends used when no group name is specified
          default = {
            augend.integer.alias.decimal_int, -- nonnegative decimal number (0, 1, 2, 3, ...)
            augend.integer.alias.hex, -- nonnegative hex number  (0x01, 0x1a1f, etc.)
            augend.integer.alias.binary,
            augend.integer.alias.octal,
            augend.constant.alias.bool,
            augend.constant.new({
              elements = { "True", "False" },
            }),
            augend.constant.new({
              elements = { "yes", "no" },
            }),
            augend.semver.alias.semver,
            augend.date.alias["%Y/%m/%d"], -- date (2022/02/19, etc.)
          },
        })
      end,
    },

  }
end
