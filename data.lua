
local function empty_picture()
  return {
    filename = "__core__/graphics/empty.png",
    size = 1,
  }
end

local function make_selectable(params)
  return {
    type = "simple-entity-with-owner",
    name = params.name,
    icon = "__core__/graphics/empty.png",
    icon_size = 1,
    force_visibility = "ally",
    picture = {
      north = empty_picture(),
      east = empty_picture(),
      south = empty_picture(),
      west = empty_picture(),
    },
    selection_box = params.selection_box,
    tile_width = params.tile_width,
    tile_height = params.tile_height,
    collision_box = {{0, 0}, {0, 0}}, -- Technically that's already the default, but whatever.
    collision_mask = {},
    selection_priority = 201,
    flags = {
      "placeable-neutral",
      "not-on-map",
      "not-blueprintable",
      "not-deconstructable",
      "hidden",
      "not-flammable",
      "no-copy-paste",
      "not-upgradable",
      "not-in-kill-statistics",
      (params.extra_flags or function() end)(), -- var results, allows adding multiple extra flags.
    },
  }
end

data:extend{
  {
    type = "custom-input",
    name = "QAI-adjust",
    action = "lua",
    key_sequence = "CONTROL + SHIFT + R",
  },
  make_selectable{
    name = "QAI-selectable-square",
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    tile_width = 1,
    tile_height = 1,
    extra_flags = function() return "not-rotatable" end,
  },
  make_selectable{
    name = "QAI-selectable-ninth",
    -- 256 / 3 = 85.33333333333333, 86 to round up instead of down to ensure gaps are filled
    selection_box = {{-86 / 256 / 2, -86 / 256 / 2}, {86 / 256 / 2, 86 / 256 / 2}},
    extra_flags = function() return "not-rotatable", "placeable-off-grid" end,
  },
  make_selectable{
    name = "QAI-selectable-rect",
    selection_box = {{-1.5, -1}, {1.5, 1}},
    extra_flags = function() return "placeable-off-grid" end,
  },
}

for _, inserter in pairs(data.raw["inserter"]) do
  inserter.allow_custom_vectors = true
end
