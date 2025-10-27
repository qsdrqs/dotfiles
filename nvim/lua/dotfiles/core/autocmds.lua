local helpers = require("dotfiles.core.helpers")

local M = {}

-- neovide has its own clipboard system
---Configure clipboard behaviour for WSL when neovide is not active.
local function setup_clipboard()
  if vim.g.neovide == nil and vim.fn.has("wsl") == 1 and vim.fn.executable("win32yank.exe") == 1 then
    vim.g.clipboard = {
      name = "win32yank",
      -- TODO: may change to async here
      copy = {
        ["+"] = { "win32yank.exe", "-i", "--crlf" },
        ["*"] = { "win32yank.exe", "-i", "--crlf" },
      },
      paste = {
        ["+"] = { "win32yank.exe", "-o", "--lf" },
        ["*"] = { "win32yank.exe", "-o", "--lf" },
      },
    }
  end
end

local function setup_fundo()
  if vim.g.vscode == nil then
    helpers.load_plugin("nvim-fundo")
    require("fundo").setup()
  end
end

---Automatic skeleton insertion on new files.
-- vim skeletons
local function setup_skeletons()
  vim.api.nvim_create_autocmd("BufNewFile", {
    callback = function()
      require("dotfiles.skeletons").insert_skeleton({
        username = "qsdrqs",
        email = "qsdrqs@gmail.com",
      })
    end,
  })
end

-- begin im switch
---Handle input method switching between insert and normal modes.
local function setup_input_method_switch()
  local im_switch
  local default_im
  local restored_im
  local is_windows = false
  local im_switch_job

  if vim.fn.has("wsl") == 1 and os.getenv("SSH_CONNECTION") == nil then
    im_switch = "im-select.exe"
    default_im = "1033"
    is_windows = true
  else
    im_switch = "fcitx5-remote"
    default_im = "keyboard-us"
  end

  if vim.fn.executable(im_switch) == 0 then
    return
  end

  local function trim(s)
    return s:match("^%s*(.-)%s*$")
  end

  if is_windows then
    im_switch_job = require("plenary.job"):new({
      command = im_switch,
      on_stdout = vim.schedule_wrap(function(_, data)
        if not data then
          return
        end
        restored_im = trim(data)
        if restored_im ~= default_im then
          -- TODO: may change to async here
          vim.fn.system(im_switch .. " " .. default_im)
        end
      end),
    })
  end

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    callback = function()
      if not is_windows then
        restored_im = trim(vim.fn.system(im_switch .. " -n"))
        if restored_im ~= default_im then
          vim.fn.system(im_switch .. " -s " .. default_im)
        end
      else
        -- async switch
        im_switch_job:start()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertEnter" }, {
    callback = function()
      if not is_windows then
        if restored_im ~= nil and restored_im ~= default_im then
          vim.fn.system(im_switch .. " -s " .. restored_im)
        end
      else
        if restored_im ~= nil and restored_im ~= default_im then
          vim.fn.system(im_switch .. " " .. restored_im)
        end
      end
    end,
  })
end
-- end im switch

function M.setup()
  setup_clipboard()
  setup_fundo()
  setup_skeletons()
  setup_input_method_switch()
end

return M
