
local util = require("__core__.lualib.util")

data:extend{
  {
    type = "tile",
    name = "qai-transparent",
    localised_name = "Transparent",
    map_color = {0, 0, 0},
    collision_mask = {layers = {}},
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

do -- This isn't for auto screenshots but for RenaiTransportation testing.
  -- Renai throwers get created for inserters with electric energy sources. But for faster testing the logic
  -- lower down changes all of them to be void, except for this inserter.
  local inserter = util.copy(data.raw["inserter"]["inserter"])
  local item = util.copy(data.raw["item"]["inserter"])
  inserter.name = "qai-renai-testing-inserter"
  inserter.minable = {mining_time = 0.1, result = "qai-renai-testing-inserter"}
  item.name = "qai-renai-testing-inserter"
  item.place_result = "qai-renai-testing-inserter"
  data:extend{inserter, item}
end

-- This isn't for auto screenshots but for easier development.
for _, inserter in pairs(data.raw["inserter"]) do
  if inserter.name ~= "qai-renai-testing-inserter"  then
    inserter.energy_source = {type = "void"}
  end
end
