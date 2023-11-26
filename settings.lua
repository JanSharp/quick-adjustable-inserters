
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
    name = "QAI-highlight-default-drop-offset",
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
  {
    type = "bool-setting",
    name = "QAI-pipette-copies-vectors",
    order = "f",
    setting_type = "runtime-per-user",
    default_value = false,
  },
})