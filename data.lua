
-- This file is not shipped with the final package, so pcall require it is.
pcall(require, "__quick-adjustable-inserters__.data_for_auto_screenshots")

local data_core = require("__quick-adjustable-inserters__.data_core")

data_core.modify_existing_inserters()

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
    name = "qai-adjust",
    action = "lua",
    key_sequence = "SHIFT + F",
  },
  {
    type = "custom-input",
    name = "qai-rotate",
    action = "lua",
    key_sequence = "",
    linked_game_control = "rotate",
  },
  {
    type = "custom-input",
    name = "qai-reverse-rotate",
    action = "lua",
    key_sequence = "",
    linked_game_control = "reverse-rotate",
  },
  make_selectable{
    name = "qai-selectable-square",
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    tile_width = 1,
    tile_height = 1,
  },
  make_selectable{
    name = "qai-selectable-ninth",
    -- 256 / 3 = 85.33333333333333, 86 to round up instead of down to ensure gaps are filled
    selection_box = {{-86 / 256 / 2, -86 / 256 / 2}, {86 / 256 / 2, 86 / 256 / 2}},
  },
  make_selectable{
    name = "qai-selectable-rect",
    selection_box = {{-1.5, -1}, {1.5, 1}},
  },
}

---@generic T : data.PrototypeBase
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

add_if_it_does_not_exist("technology", "near-inserters", function()
  return {
    type = "technology",
    name = "near-inserters",
    localised_name = {"technology-name.qai-near-inserters"},
    localised_description = {"technology-description.qai-near-inserters"},
    icon = "__quick-adjustable-inserters__/graphics/technology/near-inserters.png",
    icon_size = 256, icon_mipmaps = 1,
    prerequisites = {"logistics"},
    effects = {},
    unit = {
      count = 25,
      ingredients = {{"automation-science-pack", 1}},
      time = 15,
    },
    order = "a-d",
  }--[[@as data.TechnologyPrototype]]
end)

if data_core.check_setting("bobmods-inserters-long1", true) then
  add_if_it_does_not_exist("technology", "long-inserters-1", function()
    return {
      type = "technology",
      name = "long-inserters-1",
      localised_name = {"technology-name.qai-long-inserters-1"},
      localised_description = {"technology-description.qai-long-inserters-1"},
      icon = "__quick-adjustable-inserters__/graphics/technology/long-inserters-1.png",
      icon_size = 256, icon_mipmaps = 1,
      prerequisites = {"logistics"},
      effects = {},
      unit = {
        count = 20,
        ingredients = {{"automation-science-pack", 1}},
        time = 15,
      },
      order = "a-e-a",
    }--[[@as data.TechnologyPrototype]]
  end)
end

if data_core.check_setting("bobmods-inserters-long1", true)
  and data_core.check_setting("bobmods-inserters-long2", true)
then
  add_if_it_does_not_exist("technology", "long-inserters-2", function()
    return {
      type = "technology",
      name = "long-inserters-2",
      localised_name = {"technology-name.qai-long-inserters-2"},
      localised_description = {"technology-description.qai-long-inserters-2"},
      icon = "__quick-adjustable-inserters__/graphics/technology/long-inserters-2.png",
      icon_size = 256, icon_mipmaps = 1,
      prerequisites = {"long-inserters-1", "chemical-science-pack"},
      effects = {},
      unit = {
        count = 50,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
        },
        time = 30,
      },
      order = "a-e-b",
    }--[[@as data.TechnologyPrototype]]
  end)
end

local fast_inserter_icon = mods["base"]
  and "__base__/graphics/technology/fast-inserter.png" -- Reuse existing, no need to duplicate it in VRAM.
  or "__quick-adjustable-inserters__/graphics/technology/fast-inserter.png"

add_if_it_does_not_exist("technology", "more-inserters-1", function()
  return {
    type = "technology",
    name = "more-inserters-1",
    localised_name = {"technology-name.qai-more-inserters-1"},
    localised_description = {"technology-description.qai-more-inserters-1"},
    icons = {
      {
        icon = fast_inserter_icon,
        icon_size = 256, icon_mipmaps = 4,
      },
      {
        icon = "__quick-adjustable-inserters__/graphics/technology/constant-more-inserters-1.png",
        icon_size = 128,
        icon_mipmaps = 3,
        shift = {100, 100},
      }
    },
    prerequisites = {"logistics-2"},
    effects = {},
    unit = {
      count = 25,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
      },
      time = 30,
    },
    order = "c-n-a",
  }--[[@as data.TechnologyPrototype]]
end)

if data_core.check_setting("bobmods-inserters-more2", true) then
  add_if_it_does_not_exist("technology", "more-inserters-2", function()
    return {
      type = "technology",
      name = "more-inserters-2",
      localised_name = {"technology-name.qai-more-inserters-2"},
      localised_description = {"technology-description.qai-more-inserters-2"},
      icons = {
        {
          icon = fast_inserter_icon,
          icon_size = 256, icon_mipmaps = 4,
        },
        {
          icon = "__quick-adjustable-inserters__/graphics/technology/constant-more-inserters-2.png",
          icon_size = 128,
          icon_mipmaps = 3,
          shift = {100, 100},
        }
      },
      prerequisites = {"more-inserters-1", "logistics-3"},
      effects = {},
      unit = {
        count = 50,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
        },
        time = 30,
      },
      order = "c-n-b",
    }--[[@as data.TechnologyPrototype]]
  end)
end
