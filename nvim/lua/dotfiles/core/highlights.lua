local M = {}

-- Highlight groups reused by color plugins.
M.colorizer_groups = {
  "Color1",
  "Color2",
  "Color3",
  "Color4",
  "Color5",
  "Color6",
}

-- Semantic highlight links applied after colorscheme loads.
M.semantic_links = {
  -- lsp semantic tokens
  ["@lsp.type.class"] = "Class",
  ["@lsp.type.comment"] = "Comment",
  ["@lsp.type.namespace"] = "Class",
  ["@lsp.type.enum"] = "Enum",
  ["@lsp.type.interface"] = "Class",
  ["@lsp.type.typeParameter"] = "TypeParameter",
  ["@lsp.type.enumMember"] = "Constant",
  ["@lsp.type.regexp"] = "SpecialChar",
  ["@lsp.type.decorator"] = "PreProc",
  ["@lsp.type.struct"] = "Class",
  ["@lsp.type.property"] = "Property",
  ["@lsp.type.selfKeyword"] = "Parameter",
  ["@lsp.type.parameter"] = "Parameter",
  ["@lsp.typemod.variable.readonly"] = "Constant",
  ["@lsp.mod.static"] = "Constant",

  -- language specific tweaks
  ["@lsp.type.type.go"] = "Class",
  ["@lsp.type.defaultLibrary.go"] = "Type",
  ["@lsp.type.path.nix"] = "String",
  ["@lsp.mod.definition.nix"] = "Normal",
  ["@lsp.type.module.python"] = "Class",

  -- treesitter captures
  ["@type"] = "Class",
  ["@type.qualifier"] = "Keyword",
  ["@type.builtin"] = "Type",
  ["@function.macro.latex"] = "Keyword",
  ["@namespace.latex"] = "PreProc",
  ["@text.reference.latex"] = "Class",
  ["@punctuation.special.latex"] = "Keyword",
}

---Apply the semantic highlight links in a resilient manner.
function M.apply_semantic_links()
  for new_group, old_group in pairs(M.semantic_links) do
    vim.api.nvim_set_hl(0, new_group, { link = old_group, default = true })
  end
end

return M
