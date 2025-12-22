-- Plugin: nvim-treesitter/nvim-treesitter
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
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      branch = "main",
      cond = function()
        return vim.g.treesitter_disable ~= true and not vim.g.vscode
      end,
      config = function()
        if vim.g.treesitter_disable == true or vim.g.vscode then
          return
        end
        local ts = require("nvim-treesitter")
        ts.setup()

        local function register_matlab_parser()
          require("nvim-treesitter.parsers").matlab = {
            install_info = {
              url = "https://github.com/mstanciu552/tree-sitter-matlab.git",
              files = { "src/parser.c" },
              branch = "main",
            },
            filetype = "matlab", -- Keep filetype consistent with parser name.
          }
        end

        register_matlab_parser()

        local group = vim.api.nvim_create_augroup("TreesitterConfig", { clear = true })

        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "TSUpdate",
          callback = register_matlab_parser,
        })

        -- Install parsers (async; no-op if already installed).
        ts.install({ "c", "cpp", "java", "python", "javascript", "rust", "markdown" })

        local function apply_treesitter(bufnr)
          -- Stop treesitter for buffers marked disabled.
          if vim.b[bufnr].treesitter_disable == 1 then
            pcall(vim.treesitter.stop, bufnr)
            return
          end

          -- Require a real filetype.
          local filetype = vim.bo[bufnr].filetype
          if filetype == "" then
            return
          end

          -- Auto-install missing parsers for new filetypes.
          local lang = vim.treesitter.language.get_lang(filetype) or filetype
          if not vim.treesitter.language.add(lang) then
            if require("nvim-treesitter.parsers")[lang] then
              local ok, err = pcall(ts.install, lang)
              if not ok then
                vim.notify(
                  ("treesitter: auto-install failed for %s: %s"):format(lang, err),
                  vim.log.levels.WARN
                )
              else
                -- One-shot retry to enable TS after async install finishes.
                vim.defer_fn(function()
                  if not vim.api.nvim_buf_is_loaded(bufnr) or vim.b[bufnr].treesitter_disable == 1 then
                    return
                  end
                  if vim.treesitter.language.add(lang) then
                    pcall(vim.treesitter.start, bufnr)
                    vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                  end
                end, 500)
              end
            end
            return
          end

          -- Start treesitter; only enable indentexpr on success.
          if pcall(vim.treesitter.start, bufnr) then
            vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end

        vim.api.nvim_create_autocmd("FileType", {
          group = group,
          callback = function(args)
            apply_treesitter(args.buf)
          end,
        })

        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            apply_treesitter(bufnr)
          end
        end
      end,
    },

  }
end
