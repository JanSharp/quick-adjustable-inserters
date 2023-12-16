
data:extend({
  {
    type = "bool-setting",
    name = "qai-show-throughput-on-inserter",
    order = "a",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "qai-show-throughput-on-pickup",
    order = "b",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "qai-show-throughput-on-drop",
    order = "c",
    setting_type = "runtime-per-user",
    default_value = true,
  },
  {
    type = "bool-setting",
    name = "qai-highlight-default-drop-offset",
    order = "d",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "qai-pipette-after-place-and-adjust",
    order = "e",
    setting_type = "runtime-per-user",
    default_value = true,
  },
  {
    type = "bool-setting",
    name = "qai-pipette-copies-vectors",
    order = "f",
    setting_type = "runtime-per-user",
    default_value = false,
  },
})

---@generic T
---@param prototype_type string
---@param name string
---@param prototype_getter fun(): T
---@return T
local function add_if_it_does_not_exist(prototype_type, name, prototype_getter)
  local prototype = data.raw[prototype_type] and data.raw[prototype_type][name]
  if prototype then return prototype end
  prototype = prototype_getter()
  data:extend{prototype}
  return prototype
end

add_if_it_does_not_exist("bool-setting", "bobmods-inserters-long1", function()
  return {
    type = "bool-setting",
    name = "bobmods-inserters-long1",
    localised_name = {"mod-setting-name.qai-long-inserters-1"},
    localised_description = {"mod-setting-description.qai-long-inserters-1"},
    order = "a",
    setting_type = "startup",
    default_value = true,
  }
end)

add_if_it_does_not_exist("bool-setting", "bobmods-inserters-long2", function()
  return {
    type = "bool-setting",
    name = "bobmods-inserters-long2",
    localised_name = {"mod-setting-name.qai-long-inserters-2"},
    localised_description = {"mod-setting-description.qai-long-inserters-2"},
    order = "b",
    setting_type = "startup",
    default_value = true,
  }
end)

add_if_it_does_not_exist("bool-setting", "bobmods-inserters-more2", function()
  return {
    type = "bool-setting",
    name = "bobmods-inserters-more2",
    localised_name = {"mod-setting-name.qai-more-inserters-2"},
    localised_description = {"mod-setting-description.qai-more-inserters-2"},
    order = "c",
    setting_type = "startup",
    default_value = true,
  }
end)
