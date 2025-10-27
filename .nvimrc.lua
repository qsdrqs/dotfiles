--
--           | \ | | ___  __\ \   / /_ _|  \/  |     | |  | | | | / \
--           |  \| |/ _ \/ _ \ \ / / | || |\/| |     | |  | | | |/ _ \
--           | |\  |  __/ (_) \ V /  | || |  | |  _  | |__| |_| / ___ \
--           |_| \_|\___|\___/ \_/  |___|_|  |_| (_) |_____\___/_/   \_\
--------------------------------------------------------------------------------------

local dotfiles = require("dotfiles")
local lazy_commands = require("dotfiles.commands.lazy")
local vscode_env = require("dotfiles.env.vscode")

local use_nix = true
local context = dotfiles.setup({ use_nix = use_nix })
dotfiles.ensure_state()

local plugins_manager = require("dotfiles.plugins")
local plugins = require("dotfiles.plugins.spec")

local lazy_opts = plugins_manager.setup(plugins, { use_nix = use_nix })

----------------------------Highlights------------------------------------------------
-- semantic highlight links now applied via dotfiles.apply_highlights() to keep parity
dotfiles.apply_highlights()

--------------------------------------------------------------------------------------
----------------------------Lazy Load-------------------------------------------------
-- LazyLoadPlugins/loadTags/qftf moved into dotfiles.commands.lazy; setup keeps globals
lazy_commands.setup(plugins)

-- `nvim --headless --cmd "let g:plugins_loaded=1" -c 'lua DumpPluginsList(); vim.cmd("q")'`

-- vim.g.suda_smart_edit = 1

-- neovide has its own clipboard system
dotfiles.setup_autocmds()
dotfiles.setup_runtime()

---------------------------vscode neovim----------------------------------------------
VscodeNeovimHandler = vscode_env.handler
--------------------------------------------------------------------------------------
