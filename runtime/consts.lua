---@enum LongInserterRangeTypeQAI
local long_inserter_range_type = {
  retract_then_extend = 1,
  extend_only = 2,
  extend_only_without_gap = 3,
  ---Only used with smart inserters, because it's pretty nonsensical. I'd much prefer playing without any
  ---range technologies, so just having 1 range. I mean yea that is different because long handed inserters
  ---won't be able to reach closer to their base, which is fair I suppose, but balance and logic wise I'd
  ---prefer just having 1 range and that's it. Could play with extend_only_without_gap as well, the only
  ---difference then is that you've got all the range from the start of the game. But :shrug:.
  retract_only = 4,
}

---@enum AnimationTypeQAI
local animation_type = {
  circle = 1,
  rectangle = 2,
  line = 3,
  color = 4,
}

---@class ConstsQAI
local consts = {
  use_smart_inserters = not not script.active_mods["Smart_Inserters"],

  long_inserter_range_type = long_inserter_range_type,
  animation_type = animation_type,

  square_entity_name = "qai-selectable-square",
  ninth_entity_name = "qai-selectable-ninth",
  rect_entity_name = "qai-selectable-rect",

  finish_animation_frames = 16,
  finish_animation_expansion = 3 / 16,
  grid_fade_in_frames = 8, -- Valid values are those where 1 / consts.grid_fade_in_frames keeps all precision.
  grid_fade_out_frames = 12,
  grid_background_opacity = 0.2,
  direction_arrow_opacity = 0.6,

  ---Flipped along a diagonal going from left top to right bottom.
  is_east_or_west_lut = { [defines.direction.east] = true, [defines.direction.west] = true },
  flip_direction_lut = {
    [defines.direction.north] = defines.direction.west,
    [defines.direction.south] = defines.direction.east,
  },
}
consts.finish_animation_highlight_box_step = (consts.finish_animation_expansion / 2) / consts.finish_animation_frames

if consts.use_smart_inserters then
  consts.techs_we_care_about = {
    ["si-unlock-cross"] = true,
    ["si-unlock-offsets"] = true,
    ["si-unlock-x-diagonals"] = true,
    ["si-unlock-all-diagonals"] = true,
  }
  consts.cardinal_inserters_name = "si-unlock-cross"
  consts.near_inserters_name = "si-unlock-offsets"
  consts.more_inserters_1_name = "si-unlock-x-diagonals"
  consts.more_inserters_2_name = "si-unlock-all-diagonals"
  consts.range_technology_pattern = "^si%-unlock%-range%-([1-9]%d*)$" -- Does not accept leading zeros.
  consts.range_technology_format = "si-unlock-range-%d"
else
  consts.techs_we_care_about = {
    ["bob-near-inserters"] = true,
    ["bob-more-inserters-1"] = true,
    ["bob-more-inserters-2"] = true,
  }
  consts.cardinal_inserters_name = nil
  consts.near_inserters_name = "bob-near-inserters"
  consts.more_inserters_1_name = "bob-more-inserters-1"
  consts.more_inserters_2_name = "bob-more-inserters-2"
  consts.range_technology_pattern = "^bob%-long%-inserters%-([1-9]%d*)$" -- Does not accept leading zeros.
  consts.range_technology_format = "bob-long-inserters-%d"
end

---TODO: Check if 2.0 actually behaves this way.
---Inserters can have any of the 8 directions, even with the "not-rotatable" flag when set through script.
---This mod only works with 4 directions for inserters however.
---"simple-entity-with-owner" only have 4 directions, it appears to be impossible to set their direction to
---any of the diagonals. Don't have to worry about those.
consts.collapse_direction_lut = {
  [defines.direction.north] = defines.direction.north,
  [defines.direction.northnortheast] = defines.direction.north,
  [defines.direction.northeast] = defines.direction.north,
  [defines.direction.eastnortheast] = defines.direction.north,
  [defines.direction.east] = defines.direction.east,
  [defines.direction.eastsoutheast] = defines.direction.east,
  [defines.direction.southeast] = defines.direction.east,
  [defines.direction.southsoutheast] = defines.direction.east,
  [defines.direction.south] = defines.direction.south,
  [defines.direction.southsouthwest] = defines.direction.south,
  [defines.direction.southwest] = defines.direction.south,
  [defines.direction.westsouthwest] = defines.direction.south,
  [defines.direction.west] = defines.direction.west,
  [defines.direction.westnorthwest] = defines.direction.west,
  [defines.direction.northwest] = defines.direction.west,
  [defines.direction.northnorthwest] = defines.direction.west,
}

consts.inverse_direction_lut = {
  [defines.direction.north] = defines.direction.south,
  [defines.direction.east] = defines.direction.west,
  [defines.direction.south] = defines.direction.north,
  [defines.direction.west] = defines.direction.east,
}

consts.rotate_direction_lut = {
  [defines.direction.north] = defines.direction.east,
  [defines.direction.east] = defines.direction.south,
  [defines.direction.south] = defines.direction.west,
  [defines.direction.west] = defines.direction.north,
}

consts.reverse_rotate_direction_lut = {
  [defines.direction.north] = defines.direction.west,
  [defines.direction.east] = defines.direction.north,
  [defines.direction.south] = defines.direction.east,
  [defines.direction.west] = defines.direction.south,
}

return consts
