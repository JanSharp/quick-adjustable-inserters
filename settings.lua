
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
    name = "qai-always-use-default-drop-offset",
    order = "e",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "qai-pipette-after-place-and-adjust",
    order = "f",
    setting_type = "runtime-per-user",
    default_value = true,
  },
  {
    type = "bool-setting",
    name = "qai-pipette-copies-vectors",
    order = "g",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "qai-normalize-default-vectors",
    order = "f",
    setting_type = "startup",
    default_value = true,
  },
  {
    type = "string-setting",
    name = "qai-about-smart-inserters",
    order = "g",
    hidden = true,
    setting_type = "startup",
    default_value = "got-it",
    allowed_values = {
      "got-it",
      "yup",
      "yes",
      "mhm",
      "i-see",
      "yea",
      "right",
      "left",
      "up",
      "down",
      "over",
      "under",
      "in-front",
      "behind",
      "upside-down",
      "understood",
      "uhm",
      "sure",
      "alright",
      "confirmed",
      "totally",
      "oh",
      "yeah",
      "affirmative",
    },
  },
  {
    type = "bool-setting",
    name = "qai-mirrored-inserters-only",
    order = "a",
    setting_type = "runtime-global",
    default_value = false,
  },
  {
    type = "string-setting",
    name = "qai-range-for-long-inserters",
    order = "b",
    setting_type = "runtime-global",
    default_value = "retract-then-extend",
    allowed_values = {
      "retract-then-extend",
      "extend-only",
      "extend-only-without-gap",
    },
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

add_if_it_does_not_exist("bool-setting", "bobmods-near-inserters", function()
  return {
    type = "bool-setting",
    name = "bobmods-near-inserters",
    localised_name = {"mod-setting-name.qai-near-inserters"},
    localised_description = {"mod-setting-description.qai-near-inserters"},
    order = "a",
    setting_type = "startup",
    default_value = true,
  }
end)

add_if_it_does_not_exist("bool-setting", "bobmods-inserters-long1", function()
  return {
    type = "bool-setting",
    name = "bobmods-inserters-long1",
    localised_name = {"mod-setting-name.qai-long-inserters-1"},
    localised_description = {"mod-setting-description.qai-long-inserters-1"},
    order = "b",
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
    order = "c",
    setting_type = "startup",
    default_value = true,
  }
end)

add_if_it_does_not_exist("bool-setting", "bobmods-inserters-more1", function()
  return {
    type = "bool-setting",
    name = "bobmods-inserters-more1",
    localised_name = {"mod-setting-name.qai-more-inserters-1"},
    localised_description = {"mod-setting-description.qai-more-inserters-1"},
    order = "d",
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
    order = "e",
    setting_type = "startup",
    default_value = true,
  }
end)

---@param setting_name string
local function hide_bool_setting(setting_name)
  local setting = assert(data.raw["bool-setting"][setting_name])
  setting.hidden = true
end

if mods["Smart_Inserters"] then
  hide_bool_setting("bobmods-near-inserters")
  hide_bool_setting("bobmods-inserters-long1")
  hide_bool_setting("bobmods-inserters-long2")
  hide_bool_setting("bobmods-inserters-more1")
  hide_bool_setting("bobmods-inserters-more2")
  data.raw["string-setting"]["qai-about-smart-inserters"].hidden = false
  local qai_range_setting = data.raw["string-setting"]["qai-range-for-long-inserters"]
  qai_range_setting.localised_name = {"mod-setting-name.qai-range-for-long-inserters-overridden"}
  qai_range_setting.localised_description = {
    "mod-setting-description.qai-range-for-long-inserters-overridden",
    {"mod-setting-description.qai-range-for-long-inserters"},
  }
end
