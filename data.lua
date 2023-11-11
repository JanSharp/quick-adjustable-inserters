
local function make_selectable(params)
  return {
    type = "simple-entity-with-owner",
    name = params.name,
    icon = "__core__/graphics/empty.png",
    icon_size = 1,
    force_visibility = "same",
    picture = {
      filename = "__core__/graphics/empty.png",
      size = 1,
    },
    minable = {
      -- It may unintended, but mining time being infinite results in 0 mining percentage
      -- and doesn't show the progress bar.
      mining_time = 1/0,
      results = {},
    },
    selection_box = params.selection_box,
    tile_width = params.tile_width,
    tile_height = params.tile_height,
    collision_box = {{0, 0}, {0, 0}}, -- Technically that's already the default, but whatever.
    collision_mask = {},
    selection_priority = 201,
    flags = {
      "placeable-neutral",
      "placeable-off-grid",
      "not-on-map",
      "not-blueprintable",
      "not-deconstructable",
      "hidden",
      "not-flammable",
      "no-copy-paste",
      "not-upgradable",
      "not-in-kill-statistics",
      "not-rotatable",
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
  },
  make_selectable{
    name = "QAI-selectable-ninth",
    -- 256 / 3 = 85.33333333333333, 86 to round up instead of down to ensure gaps are filled
    selection_box = {{-86 / 256 / 2, -86 / 256 / 2}, {86 / 256 / 2, 86 / 256 / 2}},
  },
  make_selectable{
    name = "QAI-selectable-rect",
    selection_box = {{-1.5, -1}, {1.5, 1}},
  },
}
