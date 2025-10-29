-- Plugin: mfussenegger/nvim-jdtls
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
      "mfussenegger/nvim-jdtls",
      dependencies = "nvim-lspconfig",
      config = function()
        -- java
        local jdt_config = get_lsp_common_config()
        local java_exec
        if vim.fn.filereadable("/run/current-system/sw/bin/java") then
          java_exec = "/run/current-system/sw/bin/java"
        else
          java_exec = "java"
        end
        jdt_config.cmd = {
          vim.fn.stdpath("data") .. "/mason/bin/jdtls",
          "--java-executable=" .. java_exec,
        }

        -- 💀
        -- This is the default if not provided, you can remove it. Or adjust as needed.
        -- One dedicated LSP server & client will be started per unique root_dir
        jdt_config.root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew", ".classpath", ".exrc" })

        -- Here you can configure eclipse.jdt.ls specific settings
        -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
        -- for a list of options
        jdt_config.settings = {
          java = {
            completion = {
              overwrite = true,
              guessMethodArguments = true,
            },
            selectionRange = {
              enabled = true,
            },
            inlayHints = {
              parameterNames = {
                enabled = "all",
              },
            },
            implementationsCodeLens = true,
            referencesCodeLens = true,
          },
        }

        jdt_config.name = "jdtls"

        -- progress_report
        jdt_config.handlers = {
          -- disable default progress report
          ["language/status"] = function() end,
        }

        -- Language server `initializationOptions`
        -- You need to extend the `bundles` with paths to jar files
        -- if you want to use additional eclipse.jdt.ls plugins.
        --
        -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
        --
        -- If you don't plan on using the debugger or other eclipse.jdt.ls plugins you can remove this
        local bundles = {
          vim.fn.glob(
            vim.fn.stdpath("data")
              .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
          ),
        }
        vim.list_extend(
          bundles,
          vim.split(vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/java-test/extension/server/*.jar"), "\n")
        )
        jdt_config.init_options = {
          bundles = bundles,
        }

        vim.api.nvim_create_user_command("JdtDebugTestClass", "lua require('jdtls').test_class()", { nargs = 0 })
        vim.api.nvim_create_user_command(
          "JdtDebugTestMethod",
          "lua require('jdtls').test_nearest_method()",
          { nargs = 0 }
        )

        jdt_config.on_attach = function(client, bufnr)
          -- With `hotcodereplace = 'auto' the debug adapter will try to apply code changes
          -- you make during a debug session immediately.
          -- Remove the option if you do not want that.
          require("jdtls").setup_dap({ hotcodereplace = "auto" })
          common_on_attach(client, bufnr)
          require("jdtls.dap").setup_dap_main_class_configs()
        end

        local jdt_config = lsp_merge_project_config(jdt_config)

        -- jdtls needs to be started by FileType, and executed every time for each java file
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "java",
          callback = function()
            require("jdtls").start_or_attach(jdt_config)
          end,
        })
      end,
    },

  }
end
