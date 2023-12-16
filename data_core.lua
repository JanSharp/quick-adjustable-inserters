
qai_data = qai_data or {
  touched_inserters = {}--[[@as table<string, true>]],
}

---@param inserter data.InserterPrototype
---@return boolean
local function is_hidden(inserter)
  for _, flag in pairs(inserter.flags) do
    if flag == "hidden" then
      return true
    end
  end
  return false
end

---@param inserter data.InserterPrototype
local function modify_inserter(inserter)
  inserter.allow_custom_vectors = true
end

local function modify_existing_inserters()
  for name, inserter in pairs(data.raw["inserter"]) do
    if qai_data.touched_inserters[name] or is_hidden(inserter) then goto continue end
    qai_data.touched_inserters[name] = true
    modify_inserter(inserter)
    ::continue::
  end
end

return {
  modify_existing_inserters = modify_existing_inserters,
}
