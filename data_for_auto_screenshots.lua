
local util = require("__core__.lualib.util")

data:extend{
  {
    type = "tile",
    name = "qai-transparent",
    localised_name = "Transparent",
    map_color = {0, 0, 0},
    collision_mask = {},
    pollution_absorption_per_second = 0,
    layer = 0,
    variants = {
      empty_transitions = true,
      main = {
        {
          count = 1,
          size = 1,
          scale = 32,
          picture = "__core__/graphics/empty.png",
        },
      },
    },
  } --[[@as data.TilePrototype]],
}

local inserter_for_screenshots = util.copy(data.raw["inserter"]["inserter"])
inserter_for_screenshots.name = "qai-inserter-for-screenshots"
inserter_for_screenshots.energy_source = {type = "void"}
inserter_for_screenshots.rotation_speed = 1024
inserter_for_screenshots.extension_speed = 1024
data:extend{inserter_for_screenshots}

-- This isn't for auto screenshots but for easier development.
for _, inserter in pairs(data.raw["inserter"]) do
  inserter.energy_source = {type = "void"}
end
