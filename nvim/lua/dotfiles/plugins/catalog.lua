local M = {
  categories = {},
}

local function extract_identifier(spec)
  if type(spec) ~= "table" then
    return tostring(spec)
  end
  return spec[1] or spec.name or spec.url or "<unknown>"
end

---Persist the collected plugin specifications grouped by category.
--@param categories table<string, table>
function M.set(categories)
  M.categories = {}
  for name, specs in pairs(categories) do
    M.categories[name] = {}
    for _, spec in ipairs(specs) do
      table.insert(M.categories[name], spec)
    end
  end
end

---Retrieve the cached category table.
--@return table<string, table>
function M.get()
  return M.categories
end

---Print plugins grouped by category to :messages.
function M.print()
  local names = {}
  for name in pairs(M.categories) do
    table.insert(names, name)
  end
  table.sort(names)

  for _, name in ipairs(names) do
    print(string.format("[dotfiles.plugins] %s:", name))
    local entries = {}
    for _, spec in ipairs(M.categories[name]) do
      table.insert(entries, extract_identifier(spec))
    end
    table.sort(entries)
    for _, id in ipairs(entries) do
      print(string.format("  - %s", id))
    end
  end
end

return M
