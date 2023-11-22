
data:extend({
  {
    type = "bool-setting",
    name = "QAI-show-throughput-on-inserter",
    order = "a",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "QAI-show-throughput-on-pickup",
    order = "b",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "QAI-show-throughput-on-drop",
    order = "c",
    setting_type = "runtime-per-user",
    default_value = true,
  },
  {
    type = "bool-setting",
    name = "QAI-always-use-auto-drop-offset",
    localised_description = {"mod-setting-description.QAI-always-use-auto-drop-offset", {"technology-name.near-inserters"}},
    order = "d",
    setting_type = "runtime-per-user",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "QAI-pipette-after-place-and-adjust",
    order = "e",
    setting_type = "runtime-per-user",
    default_value = true,
  },
})
