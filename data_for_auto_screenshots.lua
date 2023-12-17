
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

for _, inserter in pairs(data.raw["inserter"]) do
  inserter.energy_source = {type = "void"}
  inserter.rotation_speed = 1024
  inserter.extension_speed = 1024
end