local helpers = require("dotfiles.core.helpers")

local M = {}

---Handler invoked inside VSCode via vscode-neovim integration.
function M.handler()
  local vscode = require("vscode-neovim")

  helpers.load_plugins({
    "vim-visual-multi",
    "nvim-treesitter-textobjects",
    "vim-matchup",
    "vim-sandwich",
    "gitsigns.nvim",
  })

  vim.keymap.set("n", "<leader>af", function()
    vscode.action("editor.action.formatDocument")
  end, { silent = true })
  vim.keymap.set("v", "<leader>af", function()
    vscode.action("editor.action.formatSelection")
  end, { silent = true })
  vim.keymap.set("n", "gi", function()
    vscode.action("editor.action.goToImplementation")
  end, { silent = true })
  vim.keymap.set("n", "gr", function()
    vscode.action("editor.action.goToReferences")
  end, { silent = true })
  vim.keymap.set("n", "gD", function()
    vscode.action("editor.action.goToDeclaration")
  end, { silent = true })
  vim.keymap.set("n", "<leader>v", function()
    vscode.action("workbench.action.toggleAuxiliaryBar")
  end, { silent = true })
  vim.keymap.set("n", "<leader>n", function()
    vscode.action("workbench.action.toggleSidebarVisibility")
  end, { silent = true })
  vim.keymap.set("n", "<leader>rs", function()
    vscode.action("workbench.action.reloadWindow")
  end, { silent = true })
  vim.keymap.set("n", "<leader>q", function()
    vscode.action("workbench.actions.view.toggleProblems")
  end, { silent = true })
  vim.keymap.set("n", "]d", function()
    vscode.action("editor.action.marker.next")
  end, { silent = true })
  vim.keymap.set("n", "[d", function()
    vscode.action("editor.action.marker.prev")
  end, { silent = true })
  vim.keymap.set("n", "<leader>x", function()
    vscode.action("workbench.action.closeActiveEditor")
  end, { silent = true })
  vim.keymap.set("n", "<leader>at", function()
    vscode.action("workbench.action.tasks.runTask")
  end, { silent = true })
  vim.keymap.set("n", "<leader>ca", function()
    vscode.action("editor.action.quickFix")
  end, { silent = true })
  vim.keymap.set("n", "<leader>rn", function()
    vscode.action("editor.action.rename")
  end, { silent = true })
  vim.keymap.set("n", "<leader>gg", function()
    vscode.action("workbench.action.findInFiles")
  end, { silent = true })
  vim.keymap.set("n", "<leader><leader>", function()
    vscode.call("workbench.action.showCommands")
  end, { silent = true })
  vim.keymap.set("n", "<localleader>t", function()
    vscode.call("workbench.action.createTerminalEditorSide")
  end, { silent = true })
  vim.keymap.set("n", "<localleader>T", function()
    vscode.call("workbench.action.createTerminalEditor")
  end, { silent = true })

  vim.keymap.set("n", "gh", function()
    vscode.call("clangd.switchheadersource")
  end, { silent = true })

  vim.keymap.set("x", "<leader>y", function()
    vscode.call("extension.translateTextPreferred")
  end, { silent = true })
  vim.keymap.set("n", "<leader>y", function()
    vim.cmd([[normal! viw]])
    vscode.call("extension.translateTextPreferred")
  end, { silent = true })

  vim.keymap.set("n", "<leader>gs", function()
    vim.cmd([[normal! yiw]])
    vscode.action("workbench.action.findInFiles")
  end, { silent = true })

  vim.keymap.set({ "n", "x" }, "<C-w>o", function()
    vscode.action("workbench.action.joinAllGroups")
    vscode.action("workbench.action.closeAuxiliaryBar")
    vscode.action("workbench.action.closeSidebar")
    vscode.action("workbench.action.closePanel")
  end, { silent = true })

  vim.keymap.set({ "n", "x" }, "<C-w>c", function()
    vscode.action("workbench.action.closeEditorsInGroup")
  end, { silent = true })

  vim.keymap.set("n", "<leader>ya", function()
    vscode.call("multiCommand.openFileManager")
    vscode.call("workbench.action.terminal.moveToEditor")
    vim.defer_fn(function()
      vscode.call("workbench.action.moveEditorToNewWindow")
    end, 200)
  end, { silent = true })

  -- git (use gitsigns.nvim instead)
  vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(args)
      local bufnr = args.buf
      -- looks like "/home/qsdrqs/foo/bar"
      local cwd = vim.fn.getcwd()

      -- looks like "__vscode_neovim__-file:///home/qsdrqs/foo/bar/baz.txt" for local file
      -- or "__vscode_neovim__-vscode-remote://wsl%2Barch/home/qsdrqs/foo/bar/baz.txt" for wsl file
      local file_long_name = vim.fn.expand("%")
      -- get relative path
      local relative_name = string.sub(file_long_name, string.len("__vscode_neovim__-file://") + 1)
      local wsl_head = "__vscode_neovim__-vscode-remote://wsl"

      if string.find(relative_name, cwd, 1, true) ~= nil then
        -- local file
        relative_name = string.sub(relative_name, string.len(cwd) + 2)
        require("gitsigns").attach(bufnr, {
          file = relative_name,
          toplevel = cwd,
          gitdir = cwd .. "/.git",
        })
      elseif string.find(file_long_name, wsl_head, 1, true) ~= nil then
        -- wsl file
        local absolute_path = string.sub(file_long_name, string.len(wsl_head) + string.len("%2Barch") + 1)
        local absolute_path_dir = vim.fn.fnamemodify(absolute_path, ":h")
        local cwd = vim.fn.system("git -C " .. absolute_path_dir .. " rev-parse --show-toplevel")
        cwd = string.sub(cwd, 1, string.len(cwd) - 1)
        local relative_path = string.sub(absolute_path, string.len(cwd) + 2)
        require("gitsigns").attach(bufnr, {
          file = relative_path,
          toplevel = cwd,
          gitdir = cwd .. "/.git",
        })
      else
        -- remote file, fallback to vscode keybindings
        vim.keymap.set("n", "<leader>gr", function()
          vscode.action("git.revertSelectedRanges")
        end, { silent = true })
        vim.keymap.set("n", "]g", function()
          vscode.action("workbench.action.editor.nextChange")
        end, { silent = true })
        vim.keymap.set("n", "[g", function()
          vscode.action("workbench.action.editor.previousChange")
        end, { silent = true })
      end
    end,
  })

  -- just be used for vscode selection
  vim.keymap.set("v", "<leader>v", function()
    vscode.action("editor.action.goToImplementation")
  end, { silent = true })

  -- same bindings
  vim.keymap.set("n", "<leader>d", function()
    vscode.action("editor.action.showHover")
  end, { silent = true })
  vim.keymap.set("n", "<leader>e", function()
    vscode.action("errorLens.toggleInlineMessage")
  end, { silent = true })

  vim.keymap.set("n", "<leader>f", function()
    vscode.action("workbench.action.quickOpen")
  end, { silent = true })
  vim.keymap.set("n", "<leader>b", function()
    vscode.action("workbench.action.quickOpen")
  end, { silent = true })
  vim.keymap.set("n", "<leader>rf", function()
    vscode.action("workbench.action.gotoSymbol")
  end, { silent = true })
  vim.keymap.set("n", "<leader>rw", function()
    vscode.action("workbench.action.showAllSymbols")
  end, { silent = true })

  -- recover =
  vim.keymap.del({ "n", "x" }, "=", { expr = true })
  vim.keymap.del("n", "==", { expr = true })

  -- recover gf
  vim.keymap.del({ "n", "x" }, "gf", { expr = true })

  -- recover gq
  vim.keymap.del({ "n", "x" }, "gq", { expr = true })

  -- clear background highlight
  vim.cmd([[ hi Normal guibg=None ]])
  vim.cmd([[ hi Visual guibg=None ]])

  -- fold
  vim.keymap.set("n", "zc", function()
    vscode.action("editor.fold")
  end, { silent = true })
  vim.keymap.set("n", "zC", function()
    vscode.action("editor.foldRecursively")
  end, { silent = true })
  vim.keymap.set("n", "zo", function()
    vscode.action("editor.unfold")
  end, { silent = true })
  vim.keymap.set("n", "zO", function()
    vscode.action("editor.unfoldRecursively")
  end, { silent = true })
  vim.keymap.set("n", "za", function()
    vscode.action("editor.toggleFold")
  end, { silent = true })
  vim.keymap.set("n", "zM", function()
    vscode.action("editor.foldAll")
  end, { silent = true })
  vim.keymap.set("n", "zR", function()
    vscode.action("editor.foldAll")
  end, { silent = true })

  vim.keymap.set("n", "<localleader>v", function()
    vscode.action("latex-workshop.synctex")
  end, { silent = true })
  vim.keymap.set("n", "<localleader>b", function()
    vscode.action("latex-workshop.build")
  end, { silent = true })
  vim.keymap.set("n", "<C-g>", function()
    vscode.action("workbench.view.scm")
  end, { silent = true })

  -- comment, use vscode builtin comment
  vim.keymap.set({ "n", "v" }, "<C-/>", function()
    vscode.action("editor.action.commentLine")
  end, { silent = true })
  vim.keymap.set({ "n", "v" }, "<C-s-/>", function()
    vscode.action("editor.action.blockComment")
  end, { silent = true })
  vim.keymap.set("v", "<C-s-/>", function()
    vscode.action("editor.action.blockComment")
  end, { silent = true })

  -- continue
  vim.keymap.set("v", "<localleader>aa", function()
    vscode.action("chatgpt.addToThread")
  end, { silent = true })
  vim.keymap.set("v", "<localleader>ae", function()
    vscode.action("continue.focusEdit")
  end, { silent = true })

  -- rewrap
  vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*.tex",
    callback = function()
      if vim.g.wrap_on_insert_leave == 1 then
        vscode.action("rewrap.rewrapComment")
      end
    end,
  })
end

return M
