
-- Logic used in both prototype and runtime stage.

---@param inserter data.InserterPrototype|LuaEntityPrototype
---@return boolean
local function should_ignore(inserter)
  local flags = inserter.flags
  if not flags then return false end
  if not data then
    return flags["hidden"] or flags["building-direction-8-way"] or flags["not-selectable-in-game"] or false
  end
  for _, flag in pairs(flags) do
    if flag == "hidden" or flag == "building-direction-8-way" or flag == "not-selectable-in-game" then
      return true
    end
  end
  return false
end

return {
  should_ignore = should_ignore,
}
