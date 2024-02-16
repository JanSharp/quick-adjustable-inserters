
local inserter_throughput = require("__inserter-throughput-lib__.inserter_throughput")
local vec = require("__inserter-throughput-lib__.vector")

---cSpell:ignore rects, IDQAI

---Unique table for a ghost in the world. So multiple LuaEntity instances can evaluate to the same id.
---Specifically when they are actually a reference to the same ghost entity in the world.\
---Must store information purely to be able to remove the id from the `global.ghosts_id` table again, because
---the entity may be destroyed before the id gets removed.
---@class EntityGhostIDQAI
---@field surface_index uint32
---@field x double
---@field y double

---`unit_number` or a unique table for ghosts which don't have a `ghost_unit_number`.
---@alias EntityIDQAI uint32|EntityGhostIDQAI

---@class GlobalDataQAI
---@field players table<int, PlayerDataQAI>
---@field forces table<uint8, ForceDataQAI>
---@field inserters_in_use table<EntityIDQAI, PlayerDataQAI>
---@field active_players PlayerDataQAI[]|{count: integer, next_index: integer}
---@field active_animations AnimationQAI[]|{count: integer}
---Selectable entity unit number => player data.
---@field selectable_entities_to_player_lut table<uint32, PlayerDataQAI>
---Selectable entity unit number => entity with that unit number.
---@field selectable_entities_by_unit_number table<uint32, LuaEntity>
---Selectable square unit number => inserter.
---@field selectable_dummy_redirects table<uint32, LuaEntity>
---@field ghost_ids table<uint32, table<double, table<double, EntityGhostIDQAI>>>
---@field only_allow_mirrored boolean
global = {}

---@alias AnimationQAI
---| AnimatedCircleQAI
---| AnimatedRectangleQAI
---| AnimatedLineQAI
---| AnimatedColorQAI

---@enum AnimationTypeQAI
local animation_type = {
  circle = 1,
  rectangle = 2,
  line = 3,
  color = 4,
}

---@class AnimationBaseQAI
---@field type AnimationTypeQAI
---@field id uint64
---@field remaining_updates integer @ Stays alive when going to 0, finishes the next update.
---@field destroy_on_finish boolean?

---@class AnimatedCircleQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field radius number @ Matches the current value.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.
---@field radius_step number @ Added each tick.

---@class AnimatedRectangleQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field left_top MapPosition @ Matches the current value.
---@field right_bottom MapPosition @ Matches the current value.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.
---@field left_top_step MapPosition @ Matches the current value.
---@field right_bottom_step MapPosition @ Matches the current value.

---@class AnimatedLineQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field from MapPosition @ Matches the current value.
---@field to MapPosition @ Matches the current value.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.
---@field from_step MapPosition @ Matches the current value.
---@field to_step MapPosition @ Matches the current value.

---@class AnimatedColorQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.

---@class ForceDataQAI
---@field force_index uint32
---@field force LuaForce
---@field inserter_cache_lut table<string, InserterCacheQAI>
---@field tech_level TechnologyLevelQAI

---@class LineDefinitionQAI
---@field from MapPosition
---@field to MapPosition

---@class DirectionArrowDefinitionQAI
---@field position MapPosition
---@field direction defines.direction

---@class InserterCacheQAI
---@field disabled_because_of_tech_level boolean? @ When true everything else is `nil`.
---Always check valid before using, because prototypes can be removed and in the process of migrating before
---or in on_configuration_changed any other could could still end up running.
---@field prototype LuaEntityPrototype
---@field raw_tile_width integer @ Raw value from the prototype.
---@field raw_tile_height integer @ Raw value from the prototype.
---@field tech_level TechnologyLevelQAI
---@field range integer @ Without smart inserters this is always equal to tech_level.range.
---@field min_extra_reach_distance number @ The minimum extra reach distance when building this entity.
---@field diagonal_by_default boolean
---@field default_drop_offset_multiplier -1|0|1 @ -1 = near, 0 = center, 1 = far. Vanilla is all far, fyi.
---@field min_extra_build_distance number @ The minimum extra reach distance when building this entity.
---@field is_square boolean @ When false, `vertical_offset_from_inserter ~= horizontal_offset_from_inserter`.
---@field base_range integer
---@field range_gap_from_center integer
---Defines how to calculate the left top position of the grid when given an inserter entity. By adding
---this value to the inserter's position, the left top position - the grid origin - has been found. All
---other positions in this definition are then relative to this calculated position.\
---For inserters placable off grid, the tiles, lines and simply everything from this mod will also be off
---grid.
---@field offset_from_inserter MapPosition
---@field offset_from_inserter_flipped MapPosition @ Use when `player.should_flip` is true.
---@field grid_center MapPosition
---@field grid_center_flipped MapPosition
---@field radius_for_circle_on_inserter number
---@field placeable_off_grid boolean
---The width of the open inner grid, occupied by the collision box and selection box of the inserter.
---@field tile_width integer
---The height of the open inner grid, occupied by the collision box and selection box of the inserter.
---@field tile_height integer
---@field only_drop_offset boolean
---@field tiles MapPosition[] @ `nil` when only_drop_offset.
---@field tiles_flipped MapPosition[] @ `nil` when only_drop_offset.
---@field tiles_background_vertices ScriptRenderVertexTarget[] @ `nil` when only_drop_offset.
---@field tiles_background_vertices_flipped ScriptRenderVertexTarget[] @ `nil` when only_drop_offset.
---@field lines LineDefinitionQAI[] @ `nil` when only_drop_offset.
---@field lines_flipped LineDefinitionQAI[] @ `nil` when only_drop_offset.
---@field not_rotatable boolean
---@field direction_arrows_indicator_lines LineDefinitionQAI[] @ `nil` when not_rotatable.
---@field direction_arrows_indicator_lines_flipped LineDefinitionQAI[] @ `nil` when not_rotatable.
---`nil` when not_rotatable. 4 when square, otherwise 2 (north and south).
---@field direction_arrows DirectionArrowDefinitionQAI[]
---@field direction_arrow_position MapPosition @ `nil` when not_rotatable.
---@field direction_arrow_vertices ScriptRenderVertexTarget[] @ `nil` when not_rotatable.
---@field extension_speed number
---@field rotation_speed number
---@field chases_belt_items boolean

---@class TechnologyLevelQAI
---@field range integer
---@field drop_offset boolean
---@field cardinal boolean @ Meaning horizontal and vertical. Couldn't find a better term.
---@field diagonal boolean
---@field all_tiles boolean @ When true, `cardinal` and `diagonal` are implied to also be true.

---@alias PlayerStateQAI
---| "idle"
---| "selecting-pickup"
---| "selecting-drop"

---@class PlayerDataQAI
---@field player LuaPlayer
---@field player_index uint
---If at any point a mod changes a player's force and some mod causes this mod here to use this force_index
---inside of their on_player_changed_force, before this mod here gets the event, then there will be errors
---I'm guessing. But that's worth the performance improvement of having this cached for all the performance
---critical code paths using it. (Same applies to force merging, probably.)
---@field force_index uint8
---Current internal direction of the cursor, represented as orientation for simplified computation. Performing
---math on direction values is bad practice because the values of defines is not part of the specification.
---@field current_cursor_orientation RealOrientation
---@field state PlayerStateQAI
---Always `nil` when not idle. Set to `true` when `keep_rendering` was set for `switch_to_idle`, because then
---the rendering objects are still alive even though the state is idle. This can then be used to ensure these
---objects get destroyed if another state switch happens before these objects were able to be reused. Which
---can only happen when mods do things in a raised event during our `switch_to_idle`.
---@field rendering_is_floating_while_idle boolean?
---@field index_in_active_players integer @ Non `nil` when non idle or has_active_inserter_speed_text.
---`nil` when idle. Must be stored, because we can switch to idle _after_ an entity has been invalidated.
---@field target_inserter_id EntityIDQAI
---@field target_inserter LuaEntity @ `nil` when idle.
---@field target_inserter_cache InserterCacheQAI @ `nil` when idle.
---@field target_inserter_position MapPosition @ `nil` when idle.
---`nil` when idle. Used purely to detect changes. All other logic re-fetches the pickup position.
---@field target_inserter_pickup_position MapPosition
---`nil` when idle. Used purely to detect changes. All other logic re-fetches the drop position.
---@field target_inserter_drop_position MapPosition
---@field target_inserter_direction defines.direction @ `nil` when idle.
---@field target_inserter_force_index uint32 @ `nil` when idle.
---`nil` when idle.\
---`true` for non square inserters facing west or east.
---Those end up pretending to be north and south, but flipped diagonally.
---@field should_flip boolean
---@field is_rotatable boolean @ `nil` when idle.
---@field current_surface_index uint @ `nil` when idle.
---@field current_surface LuaSurface @ `nil` when idle.
---Can be `nil` even when not idle. Used to redirect interaction to the inserter itself when selecting drop
---within a single tile. Allows for quick double tap to finish adjustment when using only_allow_mirrored for
---example.
---@field dummy_pickup_square LuaEntity?
---@field dummy_pickup_square_unit_number uint32? @ Can be `nil` even when not idle.
---@field used_squares uint[]
---@field used_ninths uint[]
---@field used_rects uint[]
---Contains a rectangle id instead, when highlighting a single tile as the drop position.
---@field line_ids uint64[]
---@field direction_arrows_indicator_line_ids uint64[]
---`nil` when idle. Contains a rectangle id instead, when highlighting a single tile as the drop position.
---@field background_polygon_id uint64
---`nil` when idle. Can be `nil` when destroying all rendering objects due to being part of an animation.
---@field inserter_circle_id uint64
---@field direction_arrow_id uint64? @ Can be `nil` even when not idle. It only exists when `is_rotatable`.
---@field pickup_highlight_id uint64 @ `nil` when idle.
---@field drop_highlight_id uint64 @ `nil` when idle.
---Can be `nil` even when not idle. Can even be `nil` when `pickup_highlight_id` is not `nil`.
---@field line_to_pickup_highlight_id uint64?
---@field default_drop_highlight LuaEntity? @ Can be `nil` even when not idle.
---@field mirrored_highlight LuaEntity? @ Can be `nil` even when not idle. Only used with only_allow_mirrored.
---`nil` when idle. Ghosts don't need reach checks, and when going from ghost to real, it still shouldn't do
---reach checks, because that'd be annoying. Imagine bots kicking you out of adjustment.
---@field no_reach_checks boolean?
---@field has_active_inserter_speed_text boolean? @ Value is entirely unrelated to `state`.
---@field inserter_speed_reference_inserter LuaEntity @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_stack_size integer @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_pickup_position MapPosition @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_drop_position MapPosition @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_text_id uint64? @ Only `nil` initially, once it exists, it's never destroyed (by this mod).
---@field inserter_speed_text_surface_index uint32? @ Only `nil` initially, once it exists, it exists.
---@field show_throughput_on_drop boolean
---@field show_throughput_on_pickup boolean
---@field show_throughput_on_inserter boolean
---@field highlight_default_drop_offset boolean
---@field pipette_after_place_and_adjust boolean
---@field pipette_copies_vectors boolean
---@field pipette_when_done boolean?
---@field reactivate_inserter_when_done boolean?
---@field pipetted_inserter_name string?
---@field pipetted_pickup_vector MapPosition @ `nil` when `pipetted_inserter_name` is `nil`.
---@field pipetted_drop_vector MapPosition @ `nil` when `pipetted_inserter_name` is `nil`.

local ev = defines.events

local consts = {
  use_smart_inserters = not not script.active_mods["Smart_Inserters"],

  square_entity_name = "qai-selectable-square",
  ninth_entity_name = "qai-selectable-ninth",
  rect_entity_name = "qai-selectable-rect",

  finish_animation_frames = 16,
  finish_animation_expansion = 3/16,
  grid_fade_in_frames = 8, -- Valid values are those where 1 / consts.grid_fade_in_frames keeps all precision.
  grid_fade_out_frames = 12,
  grid_background_opacity = 0.2,
  direction_arrow_opacity = 0.6,
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
    ["near-inserters"] = true,
    ["more-inserters-1"] = true,
    ["more-inserters-2"] = true,
  }
  consts.cardinal_inserters_name = nil
  consts.near_inserters_name = "near-inserters"
  consts.more_inserters_1_name = "more-inserters-1"
  consts.more_inserters_2_name = "more-inserters-2"
  consts.range_technology_pattern = "^long%-inserters%-([1-9]%d*)$" -- Does not accept leading zeros.
  consts.range_technology_format = "long-inserters-%d"
end

---@param name string
local function do_we_care_about_this_technology(name)
  return consts.techs_we_care_about[name]
    or string.find(name, consts.range_technology_pattern)
end

local dirs = {}

---Inserters can have any of the 8 directions, even with the "not-rotatable" flag when set through script.
---This mod only works with 4 directions for inserters however.
---"simple-entity-with-owner" only have 4 directions, it appears to be impossible to set their direction to
---any of the diagonals. Don't have to worry about those.
dirs.collapse_direction_lut = {
  [defines.direction.north] = defines.direction.north,
  [defines.direction.northeast] = defines.direction.north,
  [defines.direction.east] = defines.direction.east,
  [defines.direction.southeast] = defines.direction.east,
  [defines.direction.south] = defines.direction.south,
  [defines.direction.southwest] = defines.direction.south,
  [defines.direction.west] = defines.direction.west,
  [defines.direction.northwest] = defines.direction.west,
}

dirs.inverse_direction_lut = {
  [defines.direction.north] = defines.direction.south,
  [defines.direction.east] = defines.direction.west,
  [defines.direction.south] = defines.direction.north,
  [defines.direction.west] = defines.direction.east,
}

dirs.rotate_direction_lut = {
  [defines.direction.north] = defines.direction.east,
  [defines.direction.east] = defines.direction.south,
  [defines.direction.south] = defines.direction.west,
  [defines.direction.west] = defines.direction.north,
}

dirs.reverse_rotate_direction_lut = {
  [defines.direction.north] = defines.direction.west,
  [defines.direction.east] = defines.direction.north,
  [defines.direction.south] = defines.direction.east,
  [defines.direction.west] = defines.direction.south,
}

local get_cursor_item_prototype

local cursor_direction
do -- Start of cursor_direction "file"
-- This is basically like a separate file, but I'm keeping it in here because I'm too committed to putting
-- everything into this one file.
-- It's kind of been like an experiment, and I've determined that there is such a thing as too large files.
-- First of all I did actually hit the 200 locals limit in this file, which was/is annoying.
-- Second of all there are logically different units/parts of code in this file that are basically asking for
-- separation into separate files. Animation code, general util functions for interacting with the api, like
-- real/ghost helper functions, cursor helper functions, all the rendering in general, the constants, the type
-- annotations. So I suppose it isn't the fact that this file is too long, it's the fact that too many 
-- different things got thrown into a single file.
-- To do a bit more recapping, I've successfully written mostly small functions in this file and kept logic
-- duplication to a minimum, which made adding the mirrored inserters only feature as well as handling of many
-- random edge cases I thought of very straight forward. And I still believe that even though this file
-- contains too many logically different parts of the code, with the usage of go to definition, find all
-- references and control F it is still quite maintainable.
-- Last note, even though this is a do end block there is no indentation, because if at some point I make the
-- smart decision and split this file into many files, it'd make git history of this part of the code slightly
-- cleaner. I also don't like large parts of the code having 1 extra layer of indentation. That's all.

--[[

rotation rules while holding item in cursor

- [x] if place result 8 way, press R: apply 0.125 rotation
- [x] if place result 4 way (normal, even robots, tanks, chests, spider trons), press R: apply 0.25 rotation.
  Does not snap, the result can be 0.125 for example
- [x] if place as tile, press R: behave like above
- [x] if rolling stock, press R: apply 0.5 rotation, Does not snap, see 4 way
- [x] if rolling stock, hovering rails: does nothing
- [x] if rail and using rail planner to build: reset to north. I don't believe we can detect the usage of the rail planner.
- [x] if signal or train stop, hovering next to rail: sets cursor direction accordingly, impossible to detect.
  Closest would be on build
- [x] if offshore pump, hovering at a shore: same as signals. Closest would be using on build
- [x] finishing selection with a blueprint item: reset to north.
  Could use on_player_setup_blueprint, however that only gets raised if entities were actually selected, but
  the direction gets reset even on an empty selection. Not only that, copy or cut do not change the cursor
  direction, yet they also raise on_player_setup_blueprint _and_ the item name is "blueprint" in all cases.
  Unfortunate, but at least the best solution is to just not handle it at all, so it's less code.
- [x] finishing selection with a copy or cut tool: does nothing
- [x] rotating a blueprint: does nothing - they have a rotation state of their own it seems

depending on the internal cursor rotation state, the actual visualization then rounds down to the nearest
valid direction. And w hen building it of course also rounds down.

underground belts and pipes appear to have another internal flag saying "flip my current direction" which does
not affect the internal cursor direction. This flag gets toggled every time one is built. The 2 are actually
sharing this flag.

pipette:

- [x] on a rolling stock: uses orientation and _rounds_ to nearest 4 way direction (when in the middle, rounds up. Like 0.125 becomes 0.25)
- [x] on an underground belt: uses direction, if belt_to_ground_type == "output" apply 0.5 rotation (flip)
- [x] on an underground pipe: uses direction, nothing special
- [x] on a loader: uses direction, if loader_type == "input" apply 0.5 rotation (flip)
- [x] on an entity that does not support direction: does not affect rotation state
- [x] on an entity that does support direction: use its direction as is to set cursor direction

send help, please, how does the game determine if an assembling machine has directions or not
Ah! Saved! Thank you for the api and docs, the answer is simple! LuaEntity::supports_direction! Done!
supports_direction on an entity also handles entities like assembling machines which can conditionally support
direction.

]]

---@param orientation RealOrientation
local function validate_orientation(orientation)
  if ((orientation * 8) % 1) ~= 0 then
    error("The cursor rotation, while it is represented using an orientation, is only allowed to have \z
      steps in 1/8 (0.125) increments. Invalid rotation value: "..orientation.."."
    )
  end
end

---@param player PlayerDataQAI
---@param reverse boolean
---@param rotation RealOrientation
local function rotate_cursor(player, reverse, rotation)
  validate_orientation(rotation)
  local current = player.current_cursor_orientation
  player.current_cursor_orientation = (current + rotation * (reverse and -1 or 1)) % 1
end

---@param player PlayerDataQAI
---@param orientation RealOrientation
local function set_cursor_orientation(player, orientation)
  validate_orientation(orientation)
  player.current_cursor_orientation = orientation % 1
end

local rolling_stock_type_lut = {
  ["artillery-wagon"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["locomotive"] = true,
}

---@param player PlayerDataQAI
---@param reverse boolean
---@param entity LuaEntityPrototype
local function handle_rotation_for_entity_place_result(player, reverse, entity)
  if rolling_stock_type_lut[entity.type] then
    rotate_cursor(player, reverse, 0.5)
    return
  end
  local is_eight_way = entity.has_flag("building-direction-8-way")
  rotate_cursor(player, reverse, is_eight_way and 0.125 or 0.25)
end

---@param player PlayerDataQAI
---@param reverse boolean
local function handle_rotation_for_tile_place_result(player, reverse)
  rotate_cursor(player, reverse, 0.25)
end

---@param player PlayerDataQAI
---@param reverse boolean
local function handle_rotation(player, reverse)
  local item_prototype = get_cursor_item_prototype(player)
  if not item_prototype then return end
  local place_result = item_prototype.place_result
  if place_result then
    handle_rotation_for_entity_place_result(player, reverse, place_result)
    return
  end
  local tile_place_result = item_prototype.place_as_tile_result
  if tile_place_result then
    handle_rotation_for_tile_place_result(player, reverse)
    return
  end
end

---@param player PlayerDataQAI
---@param pipetted_entity LuaEntity
local function handle_pipette_direction(player, pipetted_entity)
  local entity_type = inserter_throughput.get_real_or_ghost_entity_type(pipetted_entity)

  if rolling_stock_type_lut[entity_type] then
    local orientation = pipetted_entity.orientation
    orientation = math.floor(orientation * 4 + 0.5) / 4
    set_cursor_orientation(player, orientation)
    return
  end

  -- Rolling stocks don't support direction, however they do affect the cursor direction when pipetted.
  -- That's why this check is below that logic
  if not pipetted_entity.supports_direction then return end

  if entity_type == "underground-belt" then
    local orientation = pipetted_entity.orientation
    if pipetted_entity.belt_to_ground_type == "output" then
      orientation = orientation + 0.5
    end
    set_cursor_orientation(player, orientation)
    return
  end

  if entity_type == "loader" or entity_type == "loader-1x1" then
    local orientation = pipetted_entity.orientation
    if pipetted_entity.loader_type == "input" then
      orientation = orientation + 0.5
    end
    set_cursor_orientation(player, orientation)
    return
  end

  set_cursor_orientation(player, pipetted_entity.orientation)
end

local snapping_entity_type_lut = {
  ["offshore-pump"] = true,
  ["rail-signal"] = true,
  ["rail-chain-signal"] = true,
  ["train-stop"] = true,
}

---This doesn't exist because placing an entity affects the cursor direction. It just exists because these
---entities have snapping behavior while hovering them, so by using the build event for them we have a higher
---chance at catching those direction changes through hovers than we would have without this at all.
---@param player PlayerDataQAI
---@param created_entity LuaEntity @ Can be any entity.
---@param entity_type string?
local function handle_built_rail_connectable_or_offshore_pump(player, created_entity, entity_type)
  entity_type = entity_type or inserter_throughput.get_real_or_ghost_entity_type(created_entity)

  if snapping_entity_type_lut[entity_type] then
    set_cursor_orientation(player, created_entity.orientation)
    return
  end

  -- It would be bad to use the direction of other created entities, because things like fluid tanks only have
  -- 2 directions, however holding them in the cursor or placing them does not change the direction of the
  -- cursor, even if the cursor direction is south or or west. Also for any 4 way entities, placing them
  -- doesn't have an effect on the cursor direction either, so you can switch to an 8 way entity and it would
  -- still be diagonal (if it was diagonal previously).
end

local eight_way_orientation_to_four_directions_lut = {
  [0] = defines.direction.north,
  [0.125] = defines.direction.north,
  [0.25] = defines.direction.east,
  [0.375] = defines.direction.east,
  [0.5] = defines.direction.south,
  [0.625] = defines.direction.south,
  [0.75] = defines.direction.west,
  [0.875] = defines.direction.west,
}

---@param player PlayerDataQAI
---@return defines.direction
local function get_cursor_direction_four_way(player)
  return eight_way_orientation_to_four_directions_lut[player.current_cursor_orientation]
end

local eight_way_orientation_to_eight_directions_lut = {
  [0] = defines.direction.north,
  [0.125] = defines.direction.northeast,
  [0.25] = defines.direction.east,
  [0.375] = defines.direction.southeast,
  [0.5] = defines.direction.south,
  [0.625] = defines.direction.southwest,
  [0.75] = defines.direction.west,
  [0.875] = defines.direction.northwest,
}

---@param player PlayerDataQAI
---@return defines.direction
local function get_cursor_direction_eight_way(player)
  return eight_way_orientation_to_eight_directions_lut[player.current_cursor_orientation]
end

---Because it isn't part of the game state, it'll reset to north on game load. Cannot detect that in single
---player, but in multiplayer we can so might as well.
---@param player PlayerDataQAI
local function on_player_joined(player)
  set_cursor_orientation(player, 0)
end

---@param player PlayerDataQAI
local function init_player(player)
  set_cursor_orientation(player, 0)
end

cursor_direction = {
  handle_rotation = handle_rotation,
  handle_pipette_direction = handle_pipette_direction,
  handle_built_rail_connectable_or_offshore_pump = handle_built_rail_connectable_or_offshore_pump,
  get_cursor_direction_four_way = get_cursor_direction_four_way,
  get_cursor_direction_eight_way = get_cursor_direction_eight_way,
  on_player_joined = on_player_joined,
  init_player = init_player,
}

end -- End of cursor_direction "file".

---The created iterator allows removal of the current key while iterating. Not the next key though, that one
---must continue to exist.
---@generic K, V
---@param tab table<K, V>
---@return fun(): K, V
local function safer_pairs(tab)
  local next = next
  local next_k, next_v = next(tab)
  return function()
    local k, v = next_k, next_v
    next_k, next_v = next(tab, k)
    return k, v
  end
end

local remove_player

---@param player PlayerDataQAI?
---@return PlayerDataQAI?
local function validate_player(player)
  if not player then return end
  if player.player.valid then return player end
  remove_player(player)
end

---@param player_index uint32
---@return PlayerDataQAI?
local function get_player_raw(player_index)
  return validate_player(global.players[player_index])
end

---@param event EventData|{player_index: uint32}
---@return PlayerDataQAI?
local function get_player(event)
  return get_player_raw(event.player_index)
end

local init_force

---@param force ForceDataQAI
local function remove_force(force)
  global.forces[force.force_index] = nil
end

---@param force ForceDataQAI?
---@return ForceDataQAI?
local function validate_force(force)
  if not force then return end
  if force.force.valid then return force end
  remove_force(force)
end

---@param force_index uint32
---@return ForceDataQAI?
local function get_force(force_index)
  return validate_force(global.forces[force_index])
end

---Can be called even if the given `force_index` actually does not exist at this point in time.
---@param force_index uint32
---@return ForceDataQAI?
local function get_or_init_force(force_index)
  local force_data = get_force(force_index)
  if force_data then return force_data end
  local force = game.forces[force_index]
  return force and init_force(force) or nil
end

---@param animation AnimationQAI
local function add_animation(animation)
  local active_animations = global.active_animations
  active_animations.count = active_animations.count + 1
  active_animations[active_animations.count] = animation
end

---@param animation AnimatedCircleQAI
local function add_animated_circle(animation)
  animation.type = animation_type.circle
  return add_animation(animation) -- Return to make it a tail call.
end

---@param animation AnimatedRectangleQAI
local function add_animated_rectangle(animation)
  animation.type = animation_type.rectangle
  return add_animation(animation) -- Return to make it a tail call.
end

---@param animation AnimatedLineQAI
local function add_animated_line(animation)
  animation.type = animation_type.line
  return add_animation(animation) -- Return to make it a tail call.
end

---@param animation AnimatedColorQAI
local function add_animated_color(animation)
  animation.type = animation_type.color
  return add_animation(animation) -- Return to make it a tail call.
end

---@param player PlayerDataQAI
---@param pos MapPosition
---@return MapPosition
local function flip(player, pos)
  if player.should_flip then
    pos.x, pos.y = pos.y, pos.x
  end
  return pos
end

local generate_cache_for_inserter
do -- Similar to cursor_direction, this is like a separate file. See up there as to why this isn't indented.

---@return "equal"|"inserter"|"incremental"|string
local function get_range_adder_setting_value()
  local setting = settings.startup["si-range-adder"]
  -- A setting from another mod, we cannot trust it actually existing.
  -- There's an argument to be made that this should throw an error if the setting does not exist, and yea
  -- I'm considering it. But also :shrug:.
  return setting and setting.value--[[@as string]] or "equal"
end

---Needs `cache.base_range`.
---@param cache InserterCacheQAI
local function generate_range_cache(cache)
  if not consts.use_smart_inserters then
    cache.range = cache.tech_level.range
    return
  end
  local range_adder_type = get_range_adder_setting_value()
  if range_adder_type == "incremental" then
    cache.range = cache.base_range + cache.tech_level.range - 1
  elseif range_adder_type == "inserter" then
    cache.range = math.min(cache.base_range, cache.tech_level.range)
  else -- not elseif, because this is a setting from another mod so we cannot trust its values.
    cache.range = cache.tech_level.range
  end
end

---@param cache InserterCacheQAI
---@param inserter LuaEntityPrototype
local function generate_pickup_and_drop_position_related_cache(cache, inserter)
  local tile_width = cache.tile_width
  local tile_height = cache.tile_height
  local pickup_position = inserter.inserter_pickup_position ---@cast pickup_position -nil
  local drop_position = inserter.inserter_drop_position ---@cast drop_position -nil
  local pickup_x = math.abs(pickup_position[1])
  local pickup_y = math.abs(pickup_position[2])
  local drop_x = math.abs(drop_position[1])
  local drop_y = math.abs(drop_position[2])

  cache.base_range = math.ceil(math.max(
    pickup_x - (tile_width / 2),
    pickup_y - (tile_height / 2),
    drop_x - (tile_width / 2),
    drop_y - (tile_height / 2)
  ))
  generate_range_cache(cache)
  cache.range_gap_from_center = math.max(0, cache.base_range - cache.range)

  cache.diagonal_by_default = math.abs(pickup_x - pickup_y) < 1/16 and math.abs(drop_x - drop_y) < 1/16

  if drop_x == 0 and drop_y == 0 then
    cache.default_drop_offset_multiplier = 0
    return
  end

  -- Remember, drop_x and drop_y are absolute (so positive) values.
  local drop_vector = {
    x = drop_x,
    y = drop_y,
  }
  -- Using prototype values here instead of cached, because cached values actually have different meaning.
  local offset_vector = {
    x = ((drop_x + (cache.raw_tile_width % 2) / 2) % 1) - 0.5,
    y = ((drop_y + (cache.raw_tile_height % 2) / 2) % 1) - 0.5,
  }
  -- What this basically does is project the offset vector which originates from the center of the target tile
  -- onto the drop vector. The resulting number can be interpreted as the length of said projected vector,
  -- where it being negative means the offset vector is generally pointing towards the inserter.
  local projected_offset = vec.dot_product(drop_vector, offset_vector) / vec.get_length(drop_vector)
  -- Vanilla's drop offset is ~0.2, so 0.1 being the threshold between near/far and center seems logical.
  cache.default_drop_offset_multiplier
    = projected_offset < -0.1 and -1
      or projected_offset <= 0.1 and 0
      or 1
  -- Do not add more code here, there's an early return further up.
end

---@param cache InserterCacheQAI
local function generate_tiles_cache(cache)
  -- Positions are integers, top left is 0, 0.
  local tile_width = cache.tile_width
  local tile_height = cache.tile_height
  local gap = cache.range_gap_from_center
  local tech_level = cache.tech_level
  local max_range = cache.range + gap
  local grid_width = tile_width + max_range * 2
  local grid_height = tile_height + max_range * 2

  local count = 0
  local tiles = cache.tiles
  local tiles_flipped = cache.tiles_flipped
  ---@param x integer @ 1 based values.
  ---@param y integer @ 1 based values.
  local function add(x, y)
    -- Convert to 0 based.
    x = x - 1
    y = y - 1
    count = count + 1
    tiles[count] = {x = x, y = y}
    tiles_flipped[count] = {x = y, y = x}
  end

  if tech_level.all_tiles then
    for y = 1, grid_height do
      for x = 1, grid_width do
        if not (cache.range < x and x <= cache.range + tile_width + gap * 2
          and cache.range < y and y <= cache.range + tile_height + gap * 2)
        then
          add(x, y)
        end
      end
    end
    return
  end

  local cardinal = tech_level.cardinal
  local diagonal = tech_level.diagonal
  assert(cardinal or diagonal, "Having both cardinal and diagonal be disabled means there is \z
    nowhere for an inserter to pickup from or drop to, which makes no sense."
  )

  if cache.diagonal_by_default and cardinal ~= diagonal then
    cardinal = not cardinal
    diagonal = not diagonal
  end

  if cardinal then
    for y = max_range + 1, max_range + tile_height do
      for x = 1, cache.range * 2 do
        if x > cache.range then
          x = x + tile_width + gap * 2
        end
        add(x, y)
      end
    end
    for x = max_range + 1, max_range + tile_width do
      for y = 1, cache.range * 2 do
        if y > cache.range then
          y = y + tile_height + gap * 2
        end
        add(x, y)
      end
    end
  end

  if diagonal then
    for i = 1, cache.range * 2 do
      add(
        i > cache.range and (i + tile_width + gap * 2) or i,
        i > cache.range and (i + tile_height + gap * 2) or i
      )
      local x = cache.range * 2 - i + 1
      add(
        x > cache.range and (x + tile_width + gap * 2) or x,
        i > cache.range and (i + tile_height + gap * 2) or i
      )
    end
  end
end

---@param x uint16
---@param y uint16
---@return uint32
local function get_point(x, y)
  return x * 2^16 + y
end

---@param point uint32
---@return uint16 x
---@return uint16 y
local function get_xy(point)
  -- Not using bit32 because math is faster than those function calls.
  local y = point % 2^16 -- Basically bitwise AND on lower 16 bits.
  return (point - y) / 2^16, y -- Basically right shift by 16 for x.
end

---@return boolean @ Returns true if the point existed.
local function check_and_remove_point(grid, point)
  local exists = grid[point]
  grid[point] = nil
  return exists
end

---@return boolean @ Returns true if all the points in the row existed.
local function check_and_remove_point_row(grid, left, right, y)
  for x = left, right do
    if not grid[get_point(x, y)] then return false end
  end
  for x = left, right do
    grid[get_point(x, y)] = nil
  end
  return true
end

---@param cache InserterCacheQAI
local function generate_tiles_background_cache(cache)
  local count = 0
  local vertices = cache.tiles_background_vertices
  local vertices_flipped = cache.tiles_background_vertices_flipped
  local function add(x, y)
    count = count + 1
    vertices[count] = {target = {x = x, y = y}}
    vertices_flipped[count] = {target = {x = y, y = x}}
  end

  ---@type table<uint32, true>
  local grid = {}

  for _, tile in ipairs(cache.tiles) do
    grid[get_point(tile.x, tile.y)] = true
  end

  while true do
    local base_point = next(grid)
    if not base_point then break end
    grid[base_point] = nil

    local left, top = get_xy(base_point)
    local right, bottom = left, top
    while check_and_remove_point(grid, get_point(left - 1, top)) do
      left = left - 1
    end
    while check_and_remove_point(grid, get_point(right + 1, top)) do
      right = right + 1
    end
    while check_and_remove_point_row(grid, left, right, top - 1) do
      top = top - 1
    end
    while check_and_remove_point_row(grid, left, right, bottom + 1) do
      bottom = bottom + 1
    end

    -- For example, with left, right, top and bottom all being 0 it's actually a 1 by 1 area.
    right = right + 1
    bottom = bottom + 1
    -- Drawing each rectangle disconnected from each other even when some of their vertices are touching is
    -- slightly less efficient, but overall doesn't actually add that many vertices.
    add(left, top)
    add(left, top)
    add(left, bottom)
    add(right, top)
    add(right, bottom)
    add(right, bottom)
  end
end

---@param lines LineDefinitionQAI[]
---@param lines_flipped LineDefinitionQAI[]
---@return fun(line: LineDefinitionQAI)
local function line_adder_factory(lines, lines_flipped)
  local count = 0
  ---@param line LineDefinitionQAI
  return function(line)
    count = count + 1
    lines[count] = line
    lines_flipped[count] = {
      from = {
        x = line.from.y,
        y = line.from.x,
      },
      to = {
        x = line.to.y,
        y = line.to.x,
      },
    }
  end
end

---@param cache InserterCacheQAI
local function generate_lines_cache(cache)
  local add = line_adder_factory(cache.lines, cache.lines_flipped)

  -- The final lines are represented as points in these grids.
  -- 0, 0 in horizontal_grid is the line going from the top left corner 1 tile to the right.
  -- 0, 0 in vertical_grid is the line going from the top left corner 1 tile downwards.
  ---@type table<uint32, true>
  local horizontal_grid = {}
  ---@type table<uint32, true>
  local vertical_grid = {}

  -- Define grid lines.
  for _, tile in ipairs(cache.tiles) do
    horizontal_grid[get_point(tile.x, tile.y)] = true
    horizontal_grid[get_point(tile.x, tile.y + 1)] = true
    vertical_grid[get_point(tile.x, tile.y)] = true
    vertical_grid[get_point(tile.x + 1, tile.y)] = true
  end

  -- Combine horizontal lines.
  while true do
    local point = next(horizontal_grid)
    if not point then break end
    horizontal_grid[point] = nil
    local x, y = get_xy(point)
    local from_x = x
    local to_x = x
    while check_and_remove_point(horizontal_grid, get_point(from_x - 1, y)) do
      from_x = from_x - 1
    end
    while check_and_remove_point(horizontal_grid, get_point(to_x + 1, y)) do
      to_x = to_x + 1
    end
    add{
      from = {x = from_x, y = y},
      to = {x = to_x + 1, y = y},
    }
  end

  -- Combine vertical lines. Copy paste from horizontal with flipped axis.
  while true do
    local point = next(vertical_grid)
    if not point then break end
    vertical_grid[point] = nil
    local x, y = get_xy(point)
    local from_y = y
    local to_y = y
    while check_and_remove_point(vertical_grid, get_point(x, from_y - 1)) do
      from_y = from_y - 1
    end
    while check_and_remove_point(vertical_grid, get_point(x, to_y + 1)) do
      to_y = to_y + 1
    end
    add{
      from = {x = x, y = from_y},
      to = {x = x, y = to_y + 1},
    }
  end
end

---@param cache InserterCacheQAI
local function generate_direction_arrows_indicator_lines_cache(cache)
  local add = line_adder_factory(
    cache.direction_arrows_indicator_lines,
    cache.direction_arrows_indicator_lines_flipped
  )

  local line_length = 0.5
  local arrow_width = 3 -- For north and south, otherwise it would be height.
  local arrow_height = 2 -- For north and south, otherwise it would be width.
  local max_range = cache.range + cache.range_gap_from_center
  local grid_width = max_range * 2 + cache.tile_width
  local grid_height = max_range * 2 + cache.tile_height
  local from_top = max_range - (arrow_width - cache.tile_height) / 2
  local from_left = max_range - (arrow_width - cache.tile_width) / 2
  for i = 0, 1 do -- Add the lines "facing inwards".
    local x = i * (grid_width + arrow_height * 2 - line_length) - arrow_height
    local y = i * (grid_height + arrow_height * 2 - line_length) - arrow_height
    for j = 0, arrow_width, arrow_width do
      if cache.is_square then
        add{
          from = {x = x, y = from_top + j},
          to = {x = x + line_length, y = from_top + j},
        }
      end
      add{
        from = {x = from_left + j, y = y},
        to = {x = from_left + j, y = y + line_length},
      }
    end
  end
  for i = 0, 1 do -- Add the lines "going along the outside".
    local x = i * (grid_width + arrow_height * 2) - arrow_height
    local y = i * (grid_height + arrow_height * 2) - arrow_height
    for j = 0, arrow_width - line_length, arrow_width - line_length do
      if cache.is_square then
        add{
          from = {x = x, y = from_top + j},
          to = {x = x, y = from_top + j + line_length},
        }
      end
      add{
        from = {x = from_left + j, y = y},
        to = {x = from_left + j + line_length, y = y},
      }
    end
  end
end

---@param cache InserterCacheQAI
local function generate_direction_arrow_cache(cache)
  local tile_width = cache.tile_width
  local tile_height = cache.tile_height
  local max_range = cache.range + cache.range_gap_from_center
  cache.direction_arrows = {
    {
      direction = defines.direction.north,
      position = {
        x = max_range + tile_width / 2,
        y = -1,
      },
    },
    {
      direction = defines.direction.south,
      position = {
        x = max_range + tile_width / 2,
        y = max_range * 2 + tile_height + 1,
      },
    },
    -- Only define west and east for square grids. Otherwise north and south are flipped diagonally when needed.
    cache.is_square and {
      direction = defines.direction.west,
      position = {
        x = -1,
        y = max_range + tile_height / 2,
      },
    } or nil,
    cache.is_square and {
      direction = defines.direction.east,
      position = {
        x = max_range * 2 + tile_width + 1,
        y = max_range + tile_height / 2,
      },
    } or nil,
  }
  cache.direction_arrow_position = {
    x = max_range + tile_width / 2,
    y = max_range + tile_height / 2,
  }
  -- The y values are positive, so pointing south, because an inserter with direction north moves items south.
  -- This is a consistent convention in base and mods.
  cache.direction_arrow_vertices = {
    {target = {x = -1.3, y = max_range + tile_height / 2 + 0.35}},
    {target = {x = 0, y = max_range + tile_height / 2 + 0.35 + 1.3}},
    {target = {x = 1.3, y = max_range + tile_height / 2 + 0.35}},
  }
end

---Centers the given box both horizontally and vertically, by taking the distance from the center and
---making both left and right have the same - higher - distance. Same goes for top and bottom.
---@param box BoundingBox
local function normalize_box(box)
  local x_distance = math.max(-box.left_top.x, box.right_bottom.x)
  local y_distance = math.max(-box.left_top.y, box.right_bottom.y)
  box.left_top.x = -x_distance
  box.left_top.y = -y_distance
  box.right_bottom.x = x_distance
  box.right_bottom.y = y_distance
end

---@param cache InserterCacheQAI
---@param inserter LuaEntityPrototype
local function generate_collision_box_related_cache(cache, inserter)
  local collision_box = inserter.collision_box
  local selection_box = inserter.selection_box
  local relevant_box = {
    left_top = {
      x = math.min(collision_box.left_top.x, selection_box.left_top.x),
      y = math.min(collision_box.left_top.y, selection_box.left_top.y),
    },
    right_bottom = {
      x = math.max(collision_box.right_bottom.x, selection_box.right_bottom.x),
      y = math.max(collision_box.right_bottom.y, selection_box.right_bottom.y),
    },
  }
  normalize_box(relevant_box)

  -- These do not match the values from the prototype, because it seems that changing the pickup and drop
  -- positions does not care about being inside of the tile width/height of the inserter itself. It even
  -- allows them being inside of the collision box of the inserter itself.
  -- However, I do not wish to put the pickup or drop position inside of the collision box and the tiles said
  -- box is touching, therefore the width and height is evaluated manually, with snapping in mind.
  local tile_width
  local tile_height
  local offset_from_inserter
  local placeable_off_grid = inserter.has_flag("placeable-off-grid")
  if placeable_off_grid then
    local col_width = relevant_box.right_bottom.x - relevant_box.left_top.x
    local col_height = relevant_box.right_bottom.y - relevant_box.left_top.y
    tile_width = math.ceil(col_width)
    tile_height = math.ceil(col_height)
    offset_from_inserter = { -- Range will be taken into account later.
      x = relevant_box.left_top.x - ((tile_width - col_width) / 2),
      y = relevant_box.left_top.y - ((tile_height - col_height) / 2),
    }
  else
    local odd_width = (cache.raw_tile_width % 2) == 1
    local odd_height = (cache.raw_tile_height % 2) == 1
    local shifted_left_top = {
      x = relevant_box.left_top.x + (odd_width and 0.5 or 0),
      y = relevant_box.left_top.y + (odd_height and 0.5 or 0),
    }
    local snapped_left_top = {
      x = math.floor(shifted_left_top.x),
      y = math.floor(shifted_left_top.y),
    }
    local snapped_right_bottom = {
      x = math.ceil(relevant_box.right_bottom.x + (odd_width and 0.5 or 0)),
      y = math.ceil(relevant_box.right_bottom.y + (odd_height and 0.5 or 0)),
    }
    tile_width = snapped_right_bottom.x - snapped_left_top.x
    tile_height = snapped_right_bottom.y - snapped_left_top.y
    offset_from_inserter = { -- Range will be taken into account later.
      x = relevant_box.left_top.x - (shifted_left_top.x - snapped_left_top.x),
      y = relevant_box.left_top.y - (shifted_left_top.y - snapped_left_top.y),
    }
  end

  cache.min_extra_build_distance = math.min(
    -collision_box.left_top.x,
    -collision_box.left_top.y,
    collision_box.right_bottom.x,
    collision_box.right_bottom.y
  )
  cache.is_square = tile_width == tile_height
  cache.offset_from_inserter = offset_from_inserter
  cache.offset_from_inserter_flipped = (nil)--[[@as any]] -- Set in generate_left_top_and_center_cache.
  cache.placeable_off_grid = placeable_off_grid
  cache.tile_width = tile_width
  cache.tile_height = tile_height
  cache.radius_for_circle_on_inserter = math.min(tile_width, tile_height) / 2 - 0.25
end

---@param cache InserterCacheQAI
local function generate_left_top_offset_and_grid_center_cache(cache)
  local offset_from_inserter = cache.offset_from_inserter
  local total_grid_range = cache.range + cache.range_gap_from_center
  offset_from_inserter.x = offset_from_inserter.x - total_grid_range
  offset_from_inserter.y = offset_from_inserter.y - total_grid_range
  cache.offset_from_inserter_flipped = {
    x = offset_from_inserter.y,
    y = offset_from_inserter.x,
  }
  cache.grid_center = {
    x = total_grid_range + (cache.tile_width / 2),
    y = total_grid_range + (cache.tile_height / 2),
  }
  cache.grid_center_flipped = {
    x = cache.grid_center.y,
    y = cache.grid_center.x,
  }
end

---@param inserter LuaEntityPrototype
---@param tech_level TechnologyLevelQAI
---@return InserterCacheQAI
function generate_cache_for_inserter(inserter, tech_level)
  if not tech_level.cardinal and not tech_level.diagonal and not tech_level.drop_offset then
    -- If both cardinal and diagonal are false then all_tiles is also false.
    return {disabled_because_of_tech_level = true}
  end

  local only_drop_offset = not tech_level.cardinal and not tech_level.diagonal and tech_level.drop_offset
  local not_rotatable = inserter.has_flag("not-rotatable")

  ---@type InserterCacheQAI
  local cache = {
    name = inserter.name,
    raw_tile_width = inserter.tile_width,
    raw_tile_height = inserter.tile_height,
    tech_level = tech_level,
    only_drop_offset = only_drop_offset,
    ---@diagnostic disable: assign-type-mismatch
    tiles = not only_drop_offset and {} or nil,
    tiles_flipped = not only_drop_offset and {} or nil,
    tiles_background_vertices = not only_drop_offset and {} or nil,
    tiles_background_vertices_flipped = not only_drop_offset and {} or nil,
    lines = not only_drop_offset and {} or nil,
    lines_flipped = not only_drop_offset and {} or nil,
    ---@diagnostic enable: assign-type-mismatch
    not_rotatable = not_rotatable,
    ---@diagnostic disable: assign-type-mismatch
    direction_arrows_indicator_lines = not not_rotatable and {} or nil,
    direction_arrows_indicator_lines_flipped = not not_rotatable and {} or nil,
    direction_arrows = not not_rotatable and {} or nil,
    direction_arrow_vertices = not not_rotatable and {} or nil,
    ---@diagnostic enable: assign-type-mismatch
    extension_speed = inserter.inserter_extension_speed,
    rotation_speed = inserter.inserter_rotation_speed,
    chases_belt_items = inserter.inserter_chases_belt_items,
  }

  generate_collision_box_related_cache(cache, inserter)
  generate_pickup_and_drop_position_related_cache(cache, inserter)
  generate_left_top_offset_and_grid_center_cache(cache)
  if not only_drop_offset then
    generate_tiles_cache(cache)
    generate_tiles_background_cache(cache)
    generate_lines_cache(cache)
  end
  if not not_rotatable then
    generate_direction_arrows_indicator_lines_cache(cache)
    generate_direction_arrow_cache(cache)
  end
  return cache
end

end -- End of generate_cache_for_inserter "file".

---This is effectively adding a field to the LuaEntity class, it's just that you do `is_ghost[entity]` instead
---of `entity.is_ghost`.
---
---It is also abusing the fact that the type of an entity is static, allowing this table to cache whether an
---entity is a ghost or not, without actually storing the data in `global`. But why? In order to prematurely
---optimize the code by reducing the amount of api calls and (interned) string creations there are, because an
---entity gets checked for being a ghost multiple times throughout several code paths. And I mean hey, the
---difference between `is_ghost(entity)` and `is_ghost[entity]` is pretty minor, it's just the implementation
---that's different.
---@type table<LuaEntity, boolean>
local is_ghost = setmetatable({}, {
  __mode = "k", -- Weak keys, so it doesn't keep the LuaEntity objects alive.
  ---@param tab table<LuaEntity, boolean>
  ---@param entity LuaEntity
  __index = function(tab, entity)
    local result = entity.type == "entity-ghost"
    tab[entity] = result
    return result
  end,
})

---@param entity LuaEntity
---@return boolean
local function is_real_or_ghost_inserter(entity)
  return (is_ghost[entity] and entity.ghost_type or entity.type) == "inserter"
end

---@param entity LuaEntity
---@return string
local function get_real_or_ghost_name(entity)
  return is_ghost[entity] and entity.ghost_name or entity.name
end

---@param entity LuaEntity @ Must not be a ghost of a tile.
---@return LuaEntityPrototype
local function get_real_or_ghost_prototype(entity)
  return is_ghost[entity] and entity.ghost_prototype--[[@as LuaEntityPrototype]] or entity.prototype
end

---@param surface LuaSurface
---@param name string
---@param position MapPosition
---@return LuaEntity?
local function find_ghost_entity(surface, name, position)
  local ghost = surface.find_entity("entity-ghost", position)
  if not ghost then return nil end
  return ghost.ghost_name == name and ghost or nil
end

---@param surface LuaSurface
---@param name string
---@param position MapPosition
---@return LuaEntity?
local function find_real_or_ghost_entity(surface, name, position)
  local entity = surface.find_entity(name, position)
  if entity then return entity end
  return find_ghost_entity(surface, name, position)
end

---@param surface LuaSurface
---@param prototype LuaEntityPrototype
---@param position MapPosition
---@return LuaEntity?
local function find_real_or_ghost_entity_from_prototype(surface, prototype, position)
  if not prototype.valid then return end -- Could be removed while a player is adjusting it.
  return find_real_or_ghost_entity(surface, prototype.name, position)
end

---@param inserter LuaEntity @ Can actually be a real or a ghost entity, but it always uses `global.ghost_ids`.
---@return EntityIDQAI?
local function get_ghost_id(inserter)
  -- The following code is just the annoying way of writing:
  -- return global.ghost_ids[inserter.surface_index]?[inserter.position.x]?[inserter.position.y]
  local x_lut = global.ghost_ids[inserter.surface_index]
  if not x_lut then return end
  local position = inserter.position
  local y_lut = x_lut[position.x]
  if not y_lut then return end
  return y_lut[position.y]
end

---@param inserter LuaEntity
---@return EntityIDQAI?
local function get_id(inserter)
  if not is_ghost[inserter] then return inserter.unit_number end
  return inserter.ghost_unit_number or get_ghost_id(inserter)
end

---@generic K
---@generic V : table
---@param tab table<K, V>
---@param key K
---@return V value
local function get_or_create_table(tab, key)
  local value = tab[key]
  if value then return value end
  value = {}
  tab[key] = value
  return value
end

---@param inserter LuaEntity
---@return EntityIDQAI
local function get_or_create_id(inserter)
  if not is_ghost[inserter] then return inserter.unit_number end
  local unit_number = inserter.ghost_unit_number
  if unit_number then return unit_number end
  local surface_index = inserter.surface_index
  local position = inserter.position
  local x = position.x
  local y = position.y
  local f = get_or_create_table -- This is so dumb, but it somehow actually makes it more readable. What?
  local id = f(f(f(global.ghost_ids, surface_index), x), y)
  if not id.surface_index then
    id.surface_index = surface_index
    id.x = x
    id.y = y
  end
  return id
end

---@param id EntityIDQAI
local function remove_id(id)
  if type(id) == "number" then return end
  local x_lut = global.ghost_ids[id.surface_index]
  local y_lut = x_lut[id.x]
  y_lut[id.y] = nil
  if next(y_lut) then return end
  x_lut[id.x] = nil
  -- Do not remove the table from global.ghost_ids, because its keys are just the surface index, so those will
  -- get reused quite frequently. x and y positions will be different 99% of the time however.
end

---@param entities uint32[]
local function destroy_entities(entities)
  local selectable_entities_to_player_lut = global.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = global.selectable_entities_by_unit_number
  for i = #entities, 1, -1 do
    local unit_number = entities[i]
    entities[i] = nil
    selectable_entities_to_player_lut[unit_number] = nil
    local entity = selectable_entities_by_unit_number[unit_number]
    selectable_entities_by_unit_number[unit_number] = nil
    if entity.valid then
      entity.destroy()
    end
  end
end

---Can most likely raise events (instantly) through destroy trigger effects.\
---If that is true then the mod will very, very most likely break when that happens, specifically because this
---gets called in switch_to_idle and there is no validation after the call. But then again, who is going to
---add destroy trigger effects to highlight entities? If anyone does that, I'm fine with this mod breaking.
---And if someone adds a destroy trigger effect to the internal entities of this mod then... I mean that
---speaks for itself.
---@param entity LuaEntity? @ Potentially `nil` or invalid entity.
local function destroy_entity_safe(entity)
  if entity and entity.valid then
    entity.destroy()
  end
end

---@param player PlayerDataQAI
local function destroy_dummy_pickup_square(player)
  local entity = player.dummy_pickup_square
  if not entity then return end
  global.selectable_dummy_redirects[player.dummy_pickup_square_unit_number] = nil
  player.dummy_pickup_square = nil
  player.dummy_pickup_square_unit_number = nil
  destroy_entity_safe(entity)
end

---@param player PlayerDataQAI
local function destroy_default_drop_highlight(player)
  local entity = player.default_drop_highlight
  player.default_drop_highlight = nil
  destroy_entity_safe(entity)
end

---@param player PlayerDataQAI
local function destroy_mirrored_highlight(player)
  local entity = player.mirrored_highlight
  player.mirrored_highlight = nil
  destroy_entity_safe(entity)
end

---@param current_color Color @ Gets modified.
---@param final_color Color
---@param frames integer
---@param start_on_first_frame boolean? @ When true `init` will have `step` added to it once already.
---@return Color init @ Same table as `current_color`.
---@return Color step @ New table.
---@return integer remaining_updates
local function get_color_init_and_step(current_color, final_color, frames, start_on_first_frame)
  local step_r = (final_color.r - current_color.r) / frames
  local step_g = (final_color.g - current_color.g) / frames
  local step_b = (final_color.b - current_color.b) / frames
  local step_a = (final_color.a - current_color.a) / frames
  -- Truncate precision which could be lost throughout the [-1,1] range. This means so long as the value
  -- remains within the [-1,1] range it can be modified without any precision lost. It can be multiplied,
  -- added, subtracted, it doesn't matter, so long as the result is is also within [-1,1].
  -- And so long as all input values are properly truncated. And there's more technicalities.
  step_r = step_r - (step_r % (1 / 2^53))
  step_g = step_g - (step_g % (1 / 2^53))
  step_b = step_b - (step_b % (1 / 2^53))
  step_a = step_a - (step_a % (1 / 2^53))
  local step = {
    r = step_r,
    g = step_g,
    b = step_b,
    a = step_a,
  }
  -- Change init color such that adding step to it `frames` times will result in the exact `final_color`.
  local remaining_updates = start_on_first_frame and (frames - 1) or frames
  current_color.r = final_color.r - step_r * remaining_updates
  current_color.g = final_color.g - step_g * remaining_updates
  current_color.b = final_color.b - step_b * remaining_updates
  current_color.a = final_color.a - step_a * remaining_updates
  return current_color, step, remaining_updates
end

---@param id uint64
---@param final_color Color
---@param frames integer
---@param destroy_on_finish boolean?
local function animate_fade_to_color(id, final_color, frames, destroy_on_finish)
  local current_color = rendering.get_color(id) ---@cast current_color -nil
  -- `start_on_first_frame` set to true to have the same animation length as newly created objects.
  -- Basically all animations start on the first frame in this mod, not the initial color/value.
  local color_init, color_step, remaining_updates
    = get_color_init_and_step(current_color, final_color, frames, true)
  add_animated_color{
    id = id,
    destroy_on_finish = destroy_on_finish,
    color = color_init,
    color_step = color_step,
    remaining_updates = remaining_updates,
  }
end

---@return boolean do_animate
local function should_animate()
  return not game.tick_paused
end

---@param id uint64
---@param frames integer
local function fade_out(id, frames)
  animate_fade_to_color(id, {r = 0, g = 0, b = 0, a = 0}, frames, true)
end

---Destroys if `should_animate()` is `false`.
---@param id uint64
---@param frames integer
local function fade_out_or_destroy(id, frames)
  if should_animate() then
    fade_out(id, frames)
  else
    rendering.destroy(id)
  end
end

---@param ids uint64[]
local function animate_lines_disappearing(ids)
  local opacity = 1 / consts.grid_fade_out_frames
  local color_step = {r = -opacity, g = -opacity, b = -opacity, a = -opacity}
  for i = #ids, 1, -1 do
    add_animated_color{
      id = ids[i],
      remaining_updates = consts.grid_fade_out_frames - 1,
      destroy_on_finish = true,
      color = {r = 1, g = 1, b = 1, a = 1},
      color_step = color_step,
    }
    ids[i] = nil
  end
end

---Can only animate the color white.
---@param id uint64
---@param current_opacity number
local function animate_id_disappearing(id, current_opacity)
  local opacity = current_opacity / consts.grid_fade_out_frames
  local color_step = {r = -opacity, g = -opacity, b = -opacity, a = -opacity}
  add_animated_color{
    id = id,
    remaining_updates = consts.grid_fade_out_frames - 1,
    destroy_on_finish = true,
    color = {r = current_opacity, g = current_opacity, b = current_opacity, a = current_opacity},
    color_step = color_step,
  }
end

---Can only animate the color white.
---@param ids uint64[]
local function destroy_and_clear_rendering_ids(ids)
  local destroy = rendering.destroy
  for i = #ids, 1, -1 do
    destroy(ids[i])
    ids[i] = nil
  end
end

---Must only be called when the rendering objects actually exist.
---@param player PlayerDataQAI
local function destroy_grid_lines_and_background(player)
  if should_animate() then
    animate_lines_disappearing(player.line_ids)
    animate_id_disappearing(player.background_polygon_id, consts.grid_background_opacity)
  else
    destroy_and_clear_rendering_ids(player.line_ids)
    rendering.destroy(player.background_polygon_id)
  end
  player.background_polygon_id = nil
end

---Must only be called when the rendering objects actually exist.
---@param player PlayerDataQAI
local function destroy_everything_but_grid_lines_and_background(player)
  local destroy = rendering.destroy
  if should_animate() then
    animate_lines_disappearing(player.direction_arrows_indicator_line_ids)
    if player.direction_arrow_id then animate_id_disappearing(player.direction_arrow_id, consts.direction_arrow_opacity) end
    if player.inserter_circle_id then animate_id_disappearing(player.inserter_circle_id, 1) end
    if player.pickup_highlight_id then fade_out(player.pickup_highlight_id, consts.grid_fade_out_frames) end
    if player.drop_highlight_id then animate_id_disappearing(player.drop_highlight_id, 1) end
    if player.line_to_pickup_highlight_id then fade_out(player.line_to_pickup_highlight_id, consts.grid_fade_out_frames) end
  else
    destroy_and_clear_rendering_ids(player.direction_arrows_indicator_line_ids)
    if player.direction_arrow_id then destroy(player.direction_arrow_id) end
    if player.inserter_circle_id then destroy(player.inserter_circle_id) end
    if player.pickup_highlight_id then destroy(player.pickup_highlight_id) end
    if player.drop_highlight_id then destroy(player.drop_highlight_id) end
    if player.line_to_pickup_highlight_id then destroy(player.line_to_pickup_highlight_id) end
  end
  player.inserter_circle_id = nil
  player.direction_arrow_id = nil
  player.pickup_highlight_id = nil
  player.drop_highlight_id = nil
  player.line_to_pickup_highlight_id = nil
end

---Must only be called when the rendering objects actually exist.
---@param player PlayerDataQAI
local function destroy_all_rendering_objects(player)
  destroy_grid_lines_and_background(player)
  destroy_everything_but_grid_lines_and_background(player)
end

---@param player PlayerDataQAI
local function destroy_all_rendering_objects_if_kept_rendering(player)
  if not player.rendering_is_floating_while_idle then return end
  player.rendering_is_floating_while_idle = nil
  destroy_all_rendering_objects(player)
end

---@param player PlayerDataQAI
local function confirm_rendering_was_kept_successfully(player)
  player.rendering_is_floating_while_idle = nil
end

local update_player_active_state
do
  ---@param player PlayerDataQAI
  local function add_active_player(player)
    local active_players = global.active_players
    active_players.count = active_players.count + 1
    active_players[active_players.count] = player
    player.index_in_active_players = active_players.count
  end

  ---@param player PlayerDataQAI
  local function remove_active_player(player)
    local active_players = global.active_players
    local count = active_players.count
    local index = player.index_in_active_players
    active_players[index] = active_players[count]
    active_players[index].index_in_active_players = index
    active_players[count] = nil
    active_players.count = count - 1
    player.index_in_active_players = nil
  end

  ---@param player PlayerDataQAI
  ---@param is_not_idle boolean? @ When `nil` will be evaluated using the current `player.state`.
  function update_player_active_state(player, is_not_idle)
    is_not_idle = is_not_idle == nil and (player.state ~= "idle") or is_not_idle
    local should_be_active = is_not_idle or player.has_active_inserter_speed_text
    if (player.index_in_active_players ~= nil) == should_be_active then return end
    if should_be_active then
      add_active_player(player)
    else
      remove_active_player(player)
    end
  end
end

---@param player PlayerDataQAI
local function hide_inserter_speed_text(player)
  local id = player.inserter_speed_text_id
  if id and rendering.is_valid(id) then
    rendering.set_visible(id, false)
  end
  player.has_active_inserter_speed_text = false
  player.inserter_speed_reference_inserter = nil
  player.inserter_speed_stack_size = nil
  player.inserter_speed_pickup_position = nil
  player.inserter_speed_drop_position = nil
  update_player_active_state(player)
end

---@param player PlayerDataQAI
local function destroy_inserter_speed_text(player)
  if player.inserter_speed_text_id then
    rendering.destroy(player.inserter_speed_text_id)
    player.inserter_speed_text_id = nil
    player.inserter_speed_text_surface_index = nil
  end
end

---@param player PlayerDataQAI
---@param inserter LuaEntity
local function deactivate_inserter(player, inserter)
  if is_ghost[inserter] then return end -- Ghosts are always inactive.
  if inserter.active then -- If another mod already deactivated it then this mod shall not reactivate it.
    inserter.active = false
    player.reactivate_inserter_when_done = true
  end
end

---@param inserter LuaEntity
local function reactivate_inserter(inserter)
  if is_ghost[inserter] then return end -- Ghosts are always inactive.
  if inserter.valid then
    inserter.active = true
  end
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
local function forget_about_restoring(player, target_inserter)
  player.reactivate_inserter_when_done = nil
  reactivate_inserter(target_inserter)
  player.pipette_when_done = nil
end

---Supports all directions, not just 4.
---@param player PlayerDataQAI
---@param inserter_name string
---@param inserter LuaEntity
local function save_pipetted_vectors(player, inserter_name, inserter)
  local direction = inserter.direction
  local position = inserter.position
  player.pipetted_inserter_name = inserter_name
  player.pipetted_pickup_vector = vec.rotate_by_direction(vec.sub(inserter.pickup_position, position), -direction)
  player.pipetted_drop_vector = vec.rotate_by_direction(vec.sub(inserter.drop_position, position), -direction)
end

---@param player PlayerDataQAI
---@return LuaItemPrototype?
---@return boolean is_cursor_ghost
function get_cursor_item_prototype(player)
  local actual_player = player.player
  local cursor = actual_player.cursor_stack
  if cursor and cursor.valid_for_read then
    return cursor.prototype, false
  end
  return actual_player.cursor_ghost--[[@as LuaItemPrototype?]], true
end

---@param player PlayerDataQAI
---@return LuaEntityPrototype?
---@return boolean is_cursor_ghost
local function get_cursor_item_place_result(player)
  local item_prototype, is_cursor_ghost = get_cursor_item_prototype(player)
  return item_prototype and item_prototype.place_result, is_cursor_ghost
end

local validate_cursor_stack_associated_data

---Can raise an event.
---@param player PlayerDataQAI
---@param target_inserter LuaEntity @ Can be invalid.
---@param surface LuaSurface @ Can be invalid.
---@param inserter_position MapPosition
local function restore_after_adjustment(player, target_inserter, surface, inserter_position)
  if player.reactivate_inserter_when_done then
    player.reactivate_inserter_when_done = nil
    reactivate_inserter(target_inserter)
  end

  validate_cursor_stack_associated_data(player)
  if player.pipette_when_done then
    player.pipette_when_done = nil
    if not player.pipette_after_place_and_adjust or not target_inserter.valid then goto leave_pipette end
    local name = get_real_or_ghost_name(target_inserter)
    player.player.pipette_entity(is_ghost[target_inserter] and name or target_inserter)
    -- Manually set the cursor_ghost for 2 reasons:
    -- 1) pipette_entity does not set a ghost cursor even though the "Pick ghost item if no items are available"
    --    setting is enabled.
    -- 2) the pipette_when_done feature works in cohesion with place and adjust feature. Therefore the point
    --    is for the player to be able to place an inserter ghost, adjust it immediately, and then continue
    --    placing ghosts. So basically this doesn't care about the setting mentioned above.
    -- There is the issue that the game plays the error sound in the pipette_entity call when the player does
    -- not have any items to build that inserter anymore. That is how it is.
    local cursor = player.player.cursor_stack
    if cursor and not cursor.valid_for_read and not player.player.cursor_ghost then
      local items = (game.entity_prototypes[name]--[[@as LuaEntityPrototype]]).items_to_place_this
      local item = items and items[1]
      player.player.cursor_ghost = item and item.name
    end

    if not surface.valid then goto leave_pipette end
    ---@diagnostic disable-next-line: cast-local-type
    target_inserter = target_inserter.valid
      and target_inserter
      or find_real_or_ghost_entity(surface, name, inserter_position)
    if not player.pipette_copies_vectors or not target_inserter then goto leave_pipette end
    local place_result = get_cursor_item_place_result(player)
    if place_result and place_result.name == name then
      save_pipetted_vectors(player, name--[[@as string]], target_inserter)
    end
  end
  ::leave_pipette::
end

local update_inserter_speed_text

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
local function extra_clean_up_for_removed_player(player, target_inserter)
  destroy_inserter_speed_text(player)
  forget_about_restoring(player, target_inserter)
end

---This function can raise an event, so make sure to expect the world to be in any state after calling it.
---This includes the state of this mod. Calling switch_to_idle does not mean that the player's state will
---actually be idle afterwards.
---@param player PlayerDataQAI
---@param keep_rendering boolean? @ When true, no rendering objects will get destroyed.
---@param do_not_restore boolean? @ When true, do not script enable the inserter and do not pipette it.
local function switch_to_idle(player, keep_rendering, do_not_restore)
  if player.state == "idle" then return end
  local target_inserter = player.target_inserter
  local surface = player.current_surface
  local position = player.target_inserter_position

  player.current_surface_index = nil
  player.current_surface = nil
  destroy_entities(player.used_squares)
  destroy_entities(player.used_ninths)
  destroy_entities(player.used_rects)
  destroy_dummy_pickup_square(player)
  destroy_default_drop_highlight(player)
  destroy_mirrored_highlight(player)
  player.rendering_is_floating_while_idle = keep_rendering
  if not keep_rendering or global.only_allow_mirrored then
    destroy_grid_lines_and_background(player)
  end
  if not keep_rendering then
    destroy_everything_but_grid_lines_and_background(player)
  end
  remove_id(player.target_inserter_id)
  global.inserters_in_use[player.target_inserter_id] = nil
  update_player_active_state(player, false)
  player.target_inserter_id = nil
  player.target_inserter = nil
  player.target_inserter_cache = nil
  player.target_inserter_position = nil
  player.target_inserter_pickup_position = nil
  player.target_inserter_drop_position = nil
  player.target_inserter_direction = nil
  player.target_inserter_force_index = nil
  player.should_flip = nil
  player.is_rotatable = nil
  player.no_reach_checks = nil
  player.state = "idle"

  local actual_player = player.player
  if not actual_player.valid then -- Only happens when coming from `remove_player()`.
    extra_clean_up_for_removed_player(player, target_inserter)
    return
  end

  update_inserter_speed_text(player)

  if not do_not_restore then
    restore_after_adjustment(player, target_inserter, surface, position)
  end
end

---@param player PlayerDataQAI
---@return MapPosition
local function get_offset_from_inserter(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.offset_from_inserter_flipped
    or cache.offset_from_inserter
end

---@param player PlayerDataQAI
---@return MapPosition @ A new table, can be modified without worry.
local function get_current_grid_left_top(player)
  return vec.add(vec.copy(player.target_inserter_position), get_offset_from_inserter(player))
end

---@param player PlayerDataQAI
---@return MapPosition
local function get_grid_center(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.grid_center_flipped
    or cache.grid_center
end

---@param player PlayerDataQAI
---@return MapPosition @ A new table, can be modified without worry.
local function get_current_grid_center_position(player)
  return vec.add(get_current_grid_left_top(player), get_grid_center(player))
end

---@param player PlayerDataQAI
---@return MapPosition[]
local function get_tiles(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.tiles_flipped
    or cache.tiles
end

---@param player PlayerDataQAI
---@return LineDefinitionQAI[]
local function get_lines(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.lines_flipped
    or cache.lines
end

---@param player PlayerDataQAI
---@return LineDefinitionQAI[]
local function get_direction_arrows_indicator_lines(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.direction_arrows_indicator_lines_flipped
    or cache.direction_arrows_indicator_lines
end

---@param player PlayerDataQAI
---@return ScriptRenderVertexTarget[]
local function get_tiles_background_vertices(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.tiles_background_vertices_flipped
    or cache.tiles_background_vertices
end

local snap_position_to_tile_center_relative_to_inserter

---@param player PlayerDataQAI
local function get_snapped_pickup_position(player)
  local pickup_position = player.target_inserter.pickup_position
  snap_position_to_tile_center_relative_to_inserter(player, pickup_position)
  return pickup_position
end

---@param player PlayerDataQAI
---@param single_drop_tile MapPosition
local function place_dummy_square_at_pickup(player, single_drop_tile)
  local drop_tile_position = vec.add(get_current_grid_left_top(player), single_drop_tile)
  local pickup_position = get_snapped_pickup_position(player)
  if vec.vec_equals(pickup_position, drop_tile_position) then return end
  local entity = player.current_surface.create_entity{
    name = consts.square_entity_name,
    force = player.force_index,
    position = pickup_position,
  }
  if not entity then
    error("Creating an internal entity required by Quick Adjustable Inserters failed.")
  end
  player.dummy_pickup_square = entity
  player.dummy_pickup_square_unit_number = entity.unit_number
  global.selectable_dummy_redirects[player.dummy_pickup_square_unit_number] = player.target_inserter
end

---@param player PlayerDataQAI
---@param specific_tiles MapPosition[]? @ Relative to grid left top.
local function place_squares(player, specific_tiles)
  local left_top = get_current_grid_left_top(player)
  local left, top = left_top.x, left_top.y -- Micro optimization.
  local selectable_entities_to_player_lut = global.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = global.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = consts.square_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  for i, tile in ipairs(specific_tiles or get_tiles(player)) do
    position.x = left + tile.x + 0.5
    position.y = top + tile.y + 0.5
    local entity = create_entity(arg)
    if not entity then
      error("Creating an internal entity required by Quick Adjustable Inserters failed.")
    end
    local unit_number = entity.unit_number ---@cast unit_number -nil
    player.used_squares[i] = unit_number
    selectable_entities_to_player_lut[unit_number] = player
    selectable_entities_by_unit_number[unit_number] = entity
  end
end

---@param player PlayerDataQAI
---@param specific_tiles MapPosition? @ Relative to grid left top.
local function place_ninths(player, specific_tiles)
  local left_top = get_current_grid_left_top(player)
  local left, top = left_top.x, left_top.y -- Micro optimization.
  local selectable_entities_to_player_lut = global.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = global.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = consts.ninth_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  local count = 0
  for _, tile in ipairs(specific_tiles or get_tiles(player)) do
    for inner_x = 0, 2 do
      for inner_y = 0, 2 do
        position.x = left + tile.x + inner_x / 3 + 1 / 6
        position.y = top + tile.y + inner_y / 3 + 1 / 6
        local entity = create_entity(arg)
        if not entity then
          error("Creating an internal entity required by Quick Adjustable Inserters failed.")
        end
        count = count + 1
        local unit_number = entity.unit_number ---@cast unit_number -nil
        player.used_ninths[count] = unit_number
        selectable_entities_to_player_lut[unit_number] = player
        selectable_entities_by_unit_number[unit_number] = entity
      end
    end
  end
end

---@param full_opacity number
---@return boolean do_animate
---@return number opacity
---@return Color color_step
local function get_color_for_potential_animation(full_opacity)
  local do_animate = should_animate()
  local opacity = do_animate and (full_opacity / consts.grid_fade_in_frames) or full_opacity
  return do_animate, opacity, {r = opacity, g = opacity, b = opacity, a = opacity}
end

---@param id uint64
---@param opacity number
---@param color_step Color
local function add_grid_fade_in_animation(id, opacity, color_step)
  return add_animated_color{ -- Return to make it a tail call.
    id = id,
    remaining_updates = consts.grid_fade_in_frames - 1,
    color = {r = opacity, g = opacity, b = opacity, a = opacity},
    color_step = color_step,
  }
end

---@param id uint64
---@param opacity number
---@param color_step Color
---@param color Color @ Each component will be multiplied by opacity.
local function add_non_white_grid_fade_in_animation(id, opacity, color_step, color)
  color.r = color.r * opacity
  color.g = color.g * opacity
  color.b = color.b * opacity
  color.a = color.a * opacity
  return add_animated_color{ -- Return to make it a tail call.
    id = id,
    remaining_updates = consts.grid_fade_in_frames - 1,
    color = color,
    color_step = color_step,
  }
end

---@param player PlayerDataQAI
local function draw_direction_arrow(player)
  if not player.is_rotatable then return end
  local inserter_position = player.target_inserter_position
  local cache = player.target_inserter_cache
  inserter_position.x = inserter_position.x + cache.offset_from_inserter.x + cache.direction_arrow_position.x
  inserter_position.y = inserter_position.y + cache.offset_from_inserter.y + cache.direction_arrow_position.y
  local do_animate, opacity, color_step = get_color_for_potential_animation(consts.direction_arrow_opacity)
  player.direction_arrow_id = rendering.draw_polygon{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    vertices = player.target_inserter_cache.direction_arrow_vertices,
    orientation = player.target_inserter.orientation,
    target = inserter_position,
  }
  if do_animate then
    add_grid_fade_in_animation(player.direction_arrow_id, opacity, color_step)
  end
end

---@param player PlayerDataQAI
local function update_direction_arrow(player)
  rendering.set_orientation(player.direction_arrow_id, player.target_inserter.orientation)
end

-- Flipped along a diagonal going from left top to right bottom.
local is_east_or_west_lut = {[defines.direction.east] = true, [defines.direction.west] = true}
local flip_direction_lut = {
  [defines.direction.north] = defines.direction.west,
  [defines.direction.south] = defines.direction.east,
}

---@param player PlayerDataQAI
local function place_rects(player)
  if not player.is_rotatable then return end
  local cache = player.target_inserter_cache
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = cache.offset_from_inserter
  local selectable_entities_to_player_lut = global.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = global.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = consts.rect_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  for _, dir_arrow in ipairs(cache.direction_arrows) do
    position.x = offset_from_inserter.x + dir_arrow.position.x
    position.y = offset_from_inserter.y + dir_arrow.position.y
    flip(player, position)
    position.x = position.x + inserter_position.x
    position.y = position.y + inserter_position.y
    arg.direction = player.should_flip and flip_direction_lut[dir_arrow.direction] or dir_arrow.direction
    local entity = create_entity(arg)
    if not entity then
      error("Creating an internal entity required by Quick Adjustable Inserters failed.")
    end
    local unit_number = entity.unit_number ---@cast unit_number -nil
    player.used_rects[#player.used_rects+1] = unit_number
    selectable_entities_to_player_lut[unit_number] = player
    selectable_entities_by_unit_number[unit_number] = entity
  end
end

---@param player PlayerDataQAI
---@param new_direction defines.direction @
---If you look at the feet of the inserter, the forwards pointing feet should be the direction this variable
---is defining.
local function set_direction(player, new_direction)
  local inserter = player.target_inserter
  local pickup_position = inserter.pickup_position
  local drop_position = inserter.drop_position
  -- However, the actual internal direction of inserters appears to be the direction they are picking up from.
  -- This confuses me, so I'm pretending it's the other way around and only flipping it when writing/reading.
  local actual_direction = dirs.inverse_direction_lut[new_direction]
  inserter.direction = actual_direction
  inserter.pickup_position = pickup_position
  inserter.drop_position = drop_position
  player.target_inserter_direction = actual_direction
end

local switch_to_idle_and_back

---@param player PlayerDataQAI
---@param new_direction defines.direction @
---If you look at the feet of the inserter, the forwards pointing feet should be the direction this variable
---is defining.\
---Only accepts 4 directions. If the direction is obtained from "simple-entity-with-owner" then nothing needs
---to be done because those can only have 4 directions anyway.
local function set_direction_and_update_arrow(player, new_direction)
  -- Recheck if the inserter is rotatable. Don't recheck the cache, because that's a static prototype flag.
  if not player.target_inserter.rotatable then
    switch_to_idle_and_back(player)
    return
  end
  set_direction(player, new_direction)
  update_direction_arrow(player)
end

---@param player PlayerDataQAI
local function draw_circle_on_inserter(player)
  local cache = player.target_inserter_cache
  local do_animate, opacity, color_step = get_color_for_potential_animation(1)
  player.inserter_circle_id = rendering.draw_circle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    radius = cache.radius_for_circle_on_inserter,
    width = 2,
    target = get_current_grid_center_position(player),
  }
  if do_animate then
    add_grid_fade_in_animation(player.inserter_circle_id, opacity, color_step)
  end
end

---@param player PlayerDataQAI
---@param line_ids int64[]
---@param lines LineDefinitionQAI[]
local function draw_lines_internal(player, line_ids, lines)
  local left_top = get_current_grid_left_top(player)
  local left, top = left_top.x, left_top.y -- Micro optimization.
  local from = {}
  local to = {}
  local do_animate, opacity, color_step = get_color_for_potential_animation(1)
  ---@type LuaRendering.draw_line_param
  local line_param = {
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    width = 1,
    from = from,
    to = to,
  }

  for i, line in ipairs(lines) do
    from.x = left + line.from.x
    from.y = top + line.from.y
    to.x = left + line.to.x
    to.y = top + line.to.y
    local id = rendering.draw_line(line_param)
    line_ids[i] = id
    if do_animate then
      add_grid_fade_in_animation(id, opacity, color_step)
    end
  end
end

---@param player PlayerDataQAI
local function draw_grid_lines(player)
  draw_lines_internal(player, player.line_ids, get_lines(player))
end

---@param player PlayerDataQAI
local function draw_direction_arrows_indicator_lines(player)
  if not player.is_rotatable then return end
  draw_lines_internal(
    player,
    player.direction_arrows_indicator_line_ids,
    get_direction_arrows_indicator_lines(player)
  )
end

---@param player PlayerDataQAI
local function draw_grid_background(player)
  local do_animate, opacity, color_step = get_color_for_potential_animation(consts.grid_background_opacity)
  player.background_polygon_id = rendering.draw_polygon{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    vertices = get_tiles_background_vertices(player),
    target = get_current_grid_left_top(player),
  }
  if do_animate then
    add_grid_fade_in_animation(player.background_polygon_id, opacity, color_step)
  end
end

---@param player PlayerDataQAI
---@param single_tile MapPosition @ Relative to grid left top.
local function draw_single_tile_grid(player, single_tile)
  single_tile = vec.add(vec.copy(single_tile), get_current_grid_left_top(player))
  ---@type LuaRendering.draw_rectangle_param
  local arg = {
    surface = player.current_surface_index,
    forces = {player.force_index},
    left_top = single_tile,
    right_bottom = vec.add_scalar(vec.copy(single_tile), 1),
  }

  local do_animate, opacity, color_step = get_color_for_potential_animation(consts.grid_background_opacity)
  arg.color = color_step
  arg.filled = true
  player.background_polygon_id = rendering.draw_rectangle(arg)
  if do_animate then
    add_grid_fade_in_animation(player.background_polygon_id, opacity, color_step)
  end

  arg.filled = nil
  do_animate, opacity, color_step = get_color_for_potential_animation(1)
  arg.color = color_step
  arg.width = 1
  player.line_ids[1] = rendering.draw_rectangle(arg)
  if do_animate then
    add_grid_fade_in_animation(player.line_ids[1], opacity, color_step)
  end
end

---When rendering objects were kept alive when switching to idle previously, don't create another set.
---@param player PlayerDataQAI
---@return boolean
local function did_keep_rendering(player)
  return player.inserter_circle_id--[[@as boolean]]
end

---@param player PlayerDataQAI
---@param single_tile MapPosition?
local function draw_grid_lines_and_background(player, single_tile)
  if single_tile then
    -- Do not check keep_rendering. This only happens when the grid is not kept.
    draw_single_tile_grid(player, single_tile)
    return
  end
  if did_keep_rendering(player) then return end
  draw_grid_background(player)
  draw_grid_lines(player)
end

---@param player PlayerDataQAI
local function draw_grid_everything_but_lines_and_background(player)
  if did_keep_rendering(player) then return end
  draw_direction_arrow(player)
  draw_direction_arrows_indicator_lines(player)
  draw_circle_on_inserter(player)
end

local function format_inserter_speed(items_per_second, is_estimate)
  return string.format((is_estimate and "~ " or "").."%.3f/s", items_per_second)
end

---Using `display_scale` for better support for large displays. Not going directly off of `display_resolution`
---because the pixel density is unknown, however players will adjust the scale to make the GUI look good,
---which is basically them adjusting based on pixel density.
---@param player PlayerDataQAI
---@return number
local function get_scale_for_inserter_speed_text(player)
  return 1.5 * player.player.display_scale
end

---@param player PlayerDataQAI
---@param position MapPosition
---@param items_per_second number
---@param is_estimate boolean
---@param reference_inserter LuaEntity
local function set_inserter_speed_text(player, position, items_per_second, is_estimate, reference_inserter)
  player.has_active_inserter_speed_text = true
  player.inserter_speed_reference_inserter = reference_inserter
  player.inserter_speed_stack_size = reference_inserter.inserter_target_pickup_count
  player.inserter_speed_pickup_position = reference_inserter.pickup_position
  player.inserter_speed_drop_position = reference_inserter.drop_position
  update_player_active_state(player)

  local id = player.inserter_speed_text_id
  local surface_index = reference_inserter.surface_index
  if not id or not rendering.is_valid(id) or player.inserter_speed_text_surface_index ~= surface_index then
    if id then rendering.destroy(id) end -- Was on a different surface.
    player.inserter_speed_text_surface_index = surface_index
    player.inserter_speed_text_id = rendering.draw_text{
      -- Can't use `player.current_surface_index` because that's nil when idle.
      surface = surface_index,
      players = {player.player_index},
      color = {1, 1, 1},
      target = position,
      text = format_inserter_speed(items_per_second, is_estimate),
      scale = get_scale_for_inserter_speed_text(player),
      scale_with_zoom = true,
      vertical_alignment = "middle",
    }
    return
  end
  rendering.set_text(id, format_inserter_speed(items_per_second, is_estimate))
  rendering.set_target(id, position)
  rendering.set_visible(id, true)
  rendering.bring_to_front(id)
end

---@param player PlayerDataQAI
local function update_inserter_speed_text_scale(player)
  local id = player.inserter_speed_text_id
  if not id or not rendering.is_valid(id) then return end
  rendering.set_scale(id, get_scale_for_inserter_speed_text(player))
end

---@param player PlayerDataQAI
---@param position MapPosition @ Gets modified.
local function mirror_position(player, position)
  local grid_center_position = get_current_grid_center_position(player)
  vec.add(vec.mul_scalar(vec.sub(position, grid_center_position), -1), grid_center_position)
end

local calculate_actual_drop_position

---@param player PlayerDataQAI
---@param selected_position MapPosition @ Position of the selected square or ninth.
---@return number items_per_second
---@return boolean is_estimate
local function estimate_inserter_speed(player, selected_position)
  local cache = player.target_inserter_cache
  local target_inserter = player.target_inserter
  local target_inserter_position = player.target_inserter_position
  ---@type InserterThroughputDefinition
  local def = {
    inserter = {
      extension_speed = cache.extension_speed,
      rotation_speed = cache.rotation_speed,
      chases_belt_items = cache.chases_belt_items,
      stack_size = inserter_throughput.get_stack_size(target_inserter),
      inserter_position_in_tile = inserter_throughput.get_position_in_tile(target_inserter_position),
    },
  }

  if player.state == "selecting-pickup" then
    inserter_throughput.pickup_from_position_and_set_pickup_vector(
      def,
      player.current_surface,
      selected_position,
      target_inserter,
      target_inserter_position
    )
    if not global.only_allow_mirrored then
      inserter_throughput.drop_to_drop_target_of_inserter_and_set_drop_vector(def, target_inserter)
    else
      local drop_position = vec.copy(selected_position)
      mirror_position(player, drop_position)
      inserter_throughput.drop_to_position_and_set_drop_vector(
        def,
        player.current_surface,
        calculate_actual_drop_position(player, drop_position, true),
        target_inserter,
        target_inserter_position
      )
    end
  else
    inserter_throughput.pickup_from_pickup_target_of_inserter_and_set_pickup_vector(def, target_inserter)
    inserter_throughput.drop_to_position_and_set_drop_vector(
      def,
      player.current_surface,
      calculate_actual_drop_position(player, selected_position),
      target_inserter,
      target_inserter_position
    )
  end

  return inserter_throughput.estimate_inserter_speed(def), inserter_throughput.is_estimate(def)
end

---@param inserter LuaEntity
---@return number items_per_second
---@return boolean is_estimate
local function estimate_inserter_speed_for_inserter(inserter)
  local def = inserter_throughput.make_full_definition_for_inserter(inserter)
  return inserter_throughput.estimate_inserter_speed(def), inserter_throughput.is_estimate(def)
end

---@param inserter LuaEntity
local function get_inserter_speed_position_next_to_inserter(inserter)
  local prototype = get_real_or_ghost_prototype(inserter)
  local box = prototype.selection_box
  local offset = math.max(-box.left_top.x, -box.left_top.y, box.right_bottom.x, box.right_bottom.y)
  local position = inserter.position
  position.x = position.x + offset + 0.15
  return position
end

---@param player PlayerDataQAI
---@param inserter LuaEntity
---@param position MapPosition
local function update_inserter_speed_text_using_inserter(player, inserter, position)
  local items_per_second, is_estimate = estimate_inserter_speed_for_inserter(inserter)
  set_inserter_speed_text(player, position, items_per_second, is_estimate, inserter)
end

local validate_target_inserter

---@param player PlayerDataQAI
---@param position MapPosition @ Gets modified.
function snap_position_to_tile_center_relative_to_inserter(player, position)
  -- Not checking state == "idle" because it is valid to use this
  -- function in the process of switching to selecting pickup or drop.
  if not player.target_inserter_position then
    error("Attempt to snap_position_to_tile_center_relative_to_inserter when player state is idle.")
  end
  local left_top = get_current_grid_left_top(player)
  vec.add_scalar(vec.sub(position, vec.mod_scalar(vec.sub(vec.copy(position), left_top), 1)), 0.5)
end

---If the selected entity is a dummy entity for the pickup position then this function will pretend as though
---the selected entity is the inserter itself.
---@param selected LuaEntity?
---@return LuaEntity? selected
local function get_redirected_selected_entity(selected)
  if not selected then return end
  if selected.name == consts.square_entity_name then
    local inserter = global.selectable_dummy_redirects[selected.unit_number]
    if inserter then
      -- It is a dummy entity, so it should never be return itself. If the redirection target inserter is
      -- invalid then just return `nil`, not `selected`.
      return inserter.valid and inserter or nil
    end
  end
  return selected
end

---@param player PlayerDataQAI
---@param selectable LuaEntity
local function get_inserter_speed_position_next_to_selectable(player, selectable)
  local position = selectable.position
  if selectable.name == consts.ninth_entity_name then
    snap_position_to_tile_center_relative_to_inserter(player, position)
  end
  position.x = position.x + 0.6
  return position
end

local should_skip_selecting_drop

---@param player PlayerDataQAI
function update_inserter_speed_text(player)
  -- There are a few cases where this function gets called where the target inserter is already guaranteed to
  -- be valid, however a lot of the time that is not the case. So just always validate.
  validate_target_inserter(player)

  local actual_selected = player.player.selected
  local selected = get_redirected_selected_entity(actual_selected)
  if not selected then
    hide_inserter_speed_text(player)
    return
  end
  ---@cast actual_selected -nil

  local show_due_to_state = player.state == "selecting-drop" and player.show_throughput_on_drop
    or player.state == "selecting-pickup" and (
      player.show_throughput_on_pickup
        or should_skip_selecting_drop(player) and player.show_throughput_on_drop
    )

  if (show_due_to_state
      and selected == player.target_inserter
    )
    or (player.show_throughput_on_inserter
      and is_real_or_ghost_inserter(selected)
      and selected.force.is_friend(player.force_index)
    )
  then
    local position = is_real_or_ghost_inserter(actual_selected)
      and get_inserter_speed_position_next_to_inserter(actual_selected)
      or get_inserter_speed_position_next_to_selectable(player, actual_selected)
    update_inserter_speed_text_using_inserter(player, selected, position)
    return
  end

  if not show_due_to_state then
    hide_inserter_speed_text(player)
    return
  end

  local name = selected.name
  if not (name == consts.square_entity_name or name == consts.ninth_entity_name) ---@cast selected -nil
    or global.selectable_entities_to_player_lut[selected.unit_number] ~= player
  then
    hide_inserter_speed_text(player)
    return
  end

  local position = selected.position
  local items_per_second, is_estimate = estimate_inserter_speed(player, position)
  if name == consts.ninth_entity_name then
    snap_position_to_tile_center_relative_to_inserter(player, position)
  end
  position.x = position.x + 0.6
  set_inserter_speed_text(player, position, items_per_second, is_estimate, player.target_inserter)
end

---@param color Color @ Assumes `r`, `g` and `b` to be the color at full opacity. Current `a` is ignored.
---@param opacity number
local function pre_multiply_and_set_alpha(color, opacity)
  color.r = color.r * opacity
  color.g = color.g * opacity
  color.b = color.b * opacity
  color.a = opacity
end

---@param player PlayerDataQAI
---@return MapPosition left_top
---@return MapPosition right_bottom
local function get_pickup_box(player)
  local pickup_pos = get_snapped_pickup_position(player)
  return {x = pickup_pos.x - 0.5, y = pickup_pos.y - 0.5},
    {x = pickup_pos.x + 0.5, y = pickup_pos.y + 0.5}
end

---@param id uint64
---@param left_top MapPosition
---@param right_bottom MapPosition
---@return boolean
local function rectangle_positions_equal(id, left_top, right_bottom)
  return vec.vec_equals(left_top, rendering.get_left_top(id).position)
    and vec.vec_equals(right_bottom, rendering.get_right_bottom(id).position)
end

---@param player PlayerDataQAI
---@param final_opacity number
---@param color Color @ `r`, `b` and `b` must be provided. `a` will be set to `final_opacity`.
---@return boolean
local function try_reuse_existing_pickup_highlight(player, final_opacity, color)
  local id = player.pickup_highlight_id
  if not id or not rendering.is_valid(id) then return false end

  local left_top, right_bottom = get_pickup_box(player)
  if not rectangle_positions_equal(id, left_top, right_bottom) then
    -- Not checking surface or force, because those will trigger switch_to_idle_and_back anyway.
    fade_out_or_destroy(id, consts.grid_fade_in_frames)
    return false
  end

  if not should_animate() then
    rendering.set_color(id, color)
    return true
  end

  pre_multiply_and_set_alpha(color, final_opacity)
  animate_fade_to_color(id, color, consts.grid_fade_in_frames)
  return true
end

---@param player PlayerDataQAI
---@param width number
---@param left_top MapPosition
---@param right_bottom MapPosition
---@param final_opacity number
---@param color Color @ `r`, `b` and `b` must be provided. `a` will be set to `final_opacity`.
---@return uint64 id
local function draw_pickup_or_drop_highlight(player, width, left_top, right_bottom, final_opacity, color)
  local do_animate, opacity, color_step = get_color_for_potential_animation(final_opacity)
  color_step.r = color_step.r * color.r
  color_step.g = color_step.g * color.g
  color_step.b = color_step.b * color.b
  local id = rendering.draw_rectangle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    width = width,
    left_top = left_top,
    right_bottom = right_bottom,
  }
  if do_animate then
    color.a = final_opacity
    add_non_white_grid_fade_in_animation(id, opacity, color_step, color)
  end
  return id
end

---@param player PlayerDataQAI
---@param final_opacity number
---@param color Color @ `r`, `b` and `b` must be provided. `a` will be set to `final_opacity`.
local function draw_pickup_highlight_internal(player, final_opacity, color)
  if try_reuse_existing_pickup_highlight(player, final_opacity, color) then return end
  local left_top, right_bottom = get_pickup_box(player)
  player.pickup_highlight_id
    = draw_pickup_or_drop_highlight(player, 2.999, left_top, right_bottom, final_opacity, color)
end

---@param player PlayerDataQAI
local function draw_green_pickup_highlight(player)
  draw_pickup_highlight_internal(player, 1, {r = 0, g = 1, b = 0})
end

---@param player PlayerDataQAI
local function draw_white_pickup_highlight(player)
  draw_pickup_highlight_internal(player, 1, {r = 1, g = 1, b = 1})
end

---@param player PlayerDataQAI
---@param square_position MapPosition @ Gets modified.
---@param square_radius number @ Half of the length of the sides of the square.
---@return MapPosition? from
---@return MapPosition? to
---@return number length
local function get_from_and_to_for_line_from_center(player, square_position, square_radius)
  local grid_center_position = get_current_grid_center_position(player)
  local vector_to_square = vec.sub(square_position, grid_center_position)
  if vector_to_square.x == 0 and vector_to_square.y == 0 then return nil, nil, 0 end
  local distance_from_pickup = (3/32) + vec.get_length(vec.div_scalar(
    vec.copy(vector_to_square),
    math.max(math.abs(vector_to_square.x), math.abs(vector_to_square.y)) / square_radius
  ))
  local distance_from_center = (2/32) + player.target_inserter_cache.radius_for_circle_on_inserter
  local length = vec.get_length(vector_to_square) - distance_from_pickup - distance_from_center
  if length <= 0 then return nil, nil, length end

  local from = vec.add(
    vec.copy(grid_center_position),
    vec.set_length(vector_to_square, distance_from_center)
  )
  local to = vec.add(
    grid_center_position, -- No need to copy here too.
    vec.set_length(vector_to_square, distance_from_center + length)
  )
  return from, to, length
end

---@param player PlayerDataQAI
local function draw_line_to_pickup_highlight(player)
  local from, to = get_from_and_to_for_line_from_center(player, get_snapped_pickup_position(player), 0.5)
  if not from then return end ---@cast to -nil
  local do_animate, opacity, color_step = get_color_for_potential_animation(1)
  color_step.r = 0
  color_step.b = 0
  local id = rendering.draw_line{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    width = 2,
    from = from,
    to = to,
  }
  player.line_to_pickup_highlight_id = id
  if do_animate then
    add_non_white_grid_fade_in_animation(id, opacity, color_step, {r = 0, g = 1, b = 0, a = 1})
  end
end

---@param player PlayerDataQAI
---@param message LocalisedString
---@return false
local function show_error(player, message)
  player.player.create_local_flying_text{
    create_at_cursor = true,
    text = message,
  }
  player.player.play_sound{path = "utility/cannot_build"}
  return false
end

---@param player PlayerDataQAI
local function should_be_rotatable(player)
  return player.target_inserter.rotatable and not player.target_inserter_cache.not_rotatable
end

---@param player PlayerDataQAI
---@param inserter LuaEntity
---@return InserterCacheQAI?
local function get_cache_for_inserter(player, inserter)
  local force = get_or_init_force(player.force_index)
  return force and force.inserter_cache_lut[get_real_or_ghost_name(inserter)]
end

---@param player PlayerDataQAI
---@param entity LuaEntity
---@return boolean
local function can_reach_entity(player, entity)
  return player.player.can_reach_entity(entity)
end

local function try_override_can_reach_entity()
  -- HACK: All of this is over complicated in order to preemptively support a can_reach_entity function in the
  -- RemoteConfiguration remote interface. Once that function actually exist, or once we've decided that that
  -- function won't ever exist this should be cleaned up significantly.
  local rc_interface = remote.interfaces["RemoteConfiguration"]
  if not rc_interface or not rc_interface.can_reach_entity then
    -- Since RemoteConfiguration.can_reach_entity isn't actually a thing yet, just always return true when
    -- the actual RemoteConfiguration mod is enabled.
    if script.active_mods["RemoteConfiguration"] then
      can_reach_entity = function() return true end
    end
    return
  end
  ---@param player PlayerDataQAI
  ---@param entity LuaEntity
  ---@return boolean
  can_reach_entity = function(player, entity)
    local function func()
      -- The function signature is unknown, this is just a guess. Therefore it gets pcall-ed.
      return remote.call("RemoteConfiguration", "can_reach_entity", player.player, entity)
    end
    local success, result = pcall(func)
    if success then
      return result
    else
      return player.player.can_reach_entity(entity)
    end
  end
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---It should only perform reach checks when the player is selecting a new inserter. Any other state switching
---should not care about being out of reach. Going out of reach while adjusting an inserter is handled in the
---player position changed event, which is raised for each tile the player moves.
---@param do_check_reach boolean?
---@param carry_over_no_reach_checks boolean?
---@return boolean
local function try_set_target_inserter(player, target_inserter, do_check_reach, carry_over_no_reach_checks)
  local force = get_or_init_force(player.force_index)
  if not force then return false end
  -- Can't use get_cache_for_inserter because the force not existing is handled differently here.

  local cache = force.inserter_cache_lut[get_real_or_ghost_name(target_inserter)]
  if not cache then
    return show_error(player, {"qai.cant-change-inserter-at-runtime"})
  end

  if cache.disabled_because_of_tech_level then
    return show_error(player, {"qai.cant-adjust-due-to-lack-of-tech"})
  end

  -- Specifically check if the force of the inserter is friends with the player. Friendship is one directional.
  if not target_inserter.force.is_friend(player.force_index) then
    return show_error(player, {"qai.cant-adjust-enemy-inserters"})
  end

  if not target_inserter.operable then
    return show_error(player, {"not-operable"})
  end

  if do_check_reach
    and not carry_over_no_reach_checks
    and not can_reach_entity(player, target_inserter)
  then
    return show_error(player, {"cant-reach"})
  end

  local id = get_or_create_id(target_inserter)
  if validate_player(global.inserters_in_use[id]) then
    return show_error(player, {"qai.only-one-player-can-adjust"})
  end

  global.inserters_in_use[id] = player
  update_player_active_state(player, true)
  player.target_inserter_id = id
  player.target_inserter = target_inserter
  player.target_inserter_cache = cache
  player.target_inserter_position = target_inserter.position
  player.target_inserter_pickup_position = target_inserter.pickup_position
  player.target_inserter_drop_position = target_inserter.drop_position
  local direction = dirs.collapse_direction_lut[target_inserter.direction]
  player.target_inserter_direction = direction
  player.target_inserter_force_index = target_inserter.force_index
  player.should_flip = not player.target_inserter_cache.is_square
    and is_east_or_west_lut[direction]
  player.is_rotatable = should_be_rotatable(player)
  player.current_surface_index = target_inserter.surface_index
  player.current_surface = target_inserter.surface
  player.no_reach_checks = carry_over_no_reach_checks or is_ghost[target_inserter]
  return true
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
---@return boolean success
local function ensure_is_idle_and_try_set_target_inserter(player, target_inserter, do_check_reach)
  -- If we are in here because of a raised event during another switch_to_idle call, we must first clean up
  -- the rendering objects for that were potentially kept alive in that call.
  destroy_all_rendering_objects_if_kept_rendering(player)
  local prev_target_inserter = player.target_inserter
  local prev_surface = player.current_surface
  local prev_position = player.target_inserter_position
  local carry_over_no_reach_checks = player.no_reach_checks and prev_target_inserter == target_inserter
  if player.state ~= "idle" then
    local is_same_inserter = prev_target_inserter == target_inserter
    if not is_same_inserter then
      forget_about_restoring(player, prev_target_inserter)
    end
    switch_to_idle(player, is_same_inserter, true)
    if not target_inserter.valid or player.state ~= "idle" then return false end
  end
  if not try_set_target_inserter(player, target_inserter, do_check_reach, carry_over_no_reach_checks) then
    destroy_all_rendering_objects_if_kept_rendering(player)
    if prev_target_inserter then
      restore_after_adjustment(player, prev_target_inserter, prev_surface, prev_position)
    end
    return false
  end
  confirm_rendering_was_kept_successfully(player)
  deactivate_inserter(player, target_inserter)
  return true
end

local draw_white_drop_highlight

---Similar to switch_to_idle, this function can raise an event, so make sure to expect the world and the mod
---to be in any state after calling it.
---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function switch_to_selecting_pickup(player, target_inserter, do_check_reach)
  if player.state == "selecting-pickup" and player.target_inserter == target_inserter then return end
  if not ensure_is_idle_and_try_set_target_inserter(player, target_inserter, do_check_reach) then return end

  -- When only_drop_offset is true, selecting pickup makes no sense. However if the validations above pass,
  -- then it is no longer valid to say "nope, not switching into this state". By allowing switching to
  -- selecting pickup even when only_drop_offset is true, it's handling potential edge cases, and if this
  -- function were to be exposed through the remote interface then mods could do crazy things.
  if not player.target_inserter_cache.only_drop_offset then
    place_squares(player)
    place_rects(player)
    draw_grid_lines_and_background(player)
  end
  draw_grid_everything_but_lines_and_background(player)
  draw_white_drop_highlight(player) -- Below pickup highlight.
  draw_white_pickup_highlight(player)
  player.state = "selecting-pickup"
  update_inserter_speed_text(player)
end

---@param player PlayerDataQAI
local function can_only_select_single_drop_tile(player)
  return global.only_allow_mirrored or player.target_inserter_cache.only_drop_offset
end

---@param player PlayerDataQAI
---@return MapPosition
local function get_single_drop_tile(player)
  local position = player.target_inserter.drop_position
  snap_position_to_tile_center_relative_to_inserter(player, position)
  return vec.sub(vec.sub_scalar(position, 0.5), get_current_grid_left_top(player))
end

---@param player PlayerDataQAI
---@return boolean
local function should_use_auto_drop_offset(player)
  return not player.target_inserter_cache.tech_level.drop_offset
end

---Similar to switch_to_idle, this function can raise an event, so make sure to expect the world and the mod
---to be in any state after calling it.
---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function switch_to_selecting_drop(player, target_inserter, do_check_reach)
  if player.state == "selecting-drop" and player.target_inserter == target_inserter then return end
  if not ensure_is_idle_and_try_set_target_inserter(player, target_inserter, do_check_reach) then return end

  local is_single_tile = can_only_select_single_drop_tile(player)
  local single_drop_tile = is_single_tile and get_single_drop_tile(player) or nil
  if should_use_auto_drop_offset(player) then
    place_squares(player, is_single_tile and {single_drop_tile} or nil)
  else
    place_ninths(player, is_single_tile and {single_drop_tile} or nil)
  end
  if is_single_tile then ---@cast single_drop_tile -nil
    place_dummy_square_at_pickup(player, single_drop_tile)
  end
  place_rects(player)

  draw_grid_lines_and_background(player, single_drop_tile)
  draw_grid_everything_but_lines_and_background(player)
  draw_white_drop_highlight(player) -- Below pickup highlight and line to pickup.
  draw_green_pickup_highlight(player)
  draw_line_to_pickup_highlight(player)
  player.state = "selecting-drop"
  update_inserter_speed_text(player)
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@return boolean
local function should_skip_selecting_pickup(player, target_inserter)
  local cache = get_cache_for_inserter(player, target_inserter)
  return cache and cache.only_drop_offset or false
end

---@param player PlayerDataQAI
---@return boolean
function should_skip_selecting_drop(player)
  return global.only_allow_mirrored and should_use_auto_drop_offset(player)
end

local play_finish_animation

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function advance_to_selecting_drop(player, target_inserter, do_check_reach)
  if should_skip_selecting_drop(player) then
    if player.state == "idle" then return end -- Cannot player finish animation on idle player.
    play_finish_animation(player) -- Before switching to idle because some rendering objects get reused.
    switch_to_idle(player)
    return
  end
  switch_to_selecting_drop(player, target_inserter, do_check_reach)
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function advance_to_selecting_pickup(player, target_inserter, do_check_reach)
  if should_skip_selecting_pickup(player, target_inserter) then
    if should_skip_selecting_drop(player) then
      error("There should never be a case where both selecting pickup and selecting drop would be skipped.")
    end
    switch_to_selecting_drop(player, target_inserter, do_check_reach)
  else
    switch_to_selecting_pickup(player, target_inserter, do_check_reach)
  end
end

---@param player PlayerDataQAI
---@param do_check_reach boolean?
---@param new_target_inserter LuaEntity? @ Use this when an inserter changed to/from being real or ghost.
function switch_to_idle_and_back(player, do_check_reach, new_target_inserter)
  if player.state == "idle" then return end
  if new_target_inserter and do_check_reach then
    error("When an inserter gets revived or dies while being adjusted, do not do reach checks.")
  end
  local target_inserter = new_target_inserter or player.target_inserter
  local surface = player.current_surface
  local cache = player.target_inserter_cache
  local position = player.target_inserter_position
  local original_player_state = player.state
  local carry_over_no_reach_checks = player.no_reach_checks
  do_check_reach = do_check_reach and not carry_over_no_reach_checks

  switch_to_idle(player, false, true)
  if player.state ~= "idle" then
    forget_about_restoring(player, target_inserter)
    return
  end
  ---@diagnostic disable-next-line: cast-local-type
  target_inserter = target_inserter.valid and target_inserter
    or surface.valid and find_real_or_ghost_entity_from_prototype(surface, cache.prototype, position)
  if not target_inserter then return end

  if original_player_state == "selecting-pickup" then
    advance_to_selecting_pickup(player, target_inserter, do_check_reach)
  else
    advance_to_selecting_drop(player, target_inserter, do_check_reach)
  end

  -- Carry it over for things like tech level changes, etc. Set it when `new_target_inserter` is non `nil`
  -- because if a robot, another player or a script revived the inserter, moving around should not cause you
  -- to get switched to idle. Especially relevant for the place and adjust feature.
  if (carry_over_no_reach_checks or new_target_inserter)
    and player.state == original_player_state
    and player.target_inserter == target_inserter
  then
    player.no_reach_checks = true
  end
end

---@param player PlayerDataQAI
---@return boolean @ `true` if the player results in a non idle state with a valid inserter.
function validate_target_inserter(player)
  if player.state == "idle" then return false end
  local inserter = player.target_inserter
  if inserter.valid then
    if inserter.operable then return true end
    switch_to_idle(player)
    return false
  end
  ---@diagnostic disable-next-line: cast-local-type
  inserter = player.current_surface.valid and find_real_or_ghost_entity_from_prototype(
    player.current_surface,
    player.target_inserter_cache.prototype,
    player.target_inserter_position
  )
  if not inserter then
    switch_to_idle(player)
    return false
  end
  local expected_state = player.state
  switch_to_idle_and_back(player, false, inserter)
  if player.state ~= expected_state or player.target_inserter ~= inserter then return false end
  if not inserter.valid then
    -- A switch_to_idle_and_back attempt was made, the inserter is once again invalid, so now just give up.
    switch_to_idle(player)
    return false
  end
  return true
end

---@param player PlayerDataQAI
---@param position MapPosition
---@param offset_from_tile_center number
---@param auto_determine_drop_offset boolean? @ Should it move the drop offset away from the inserter?
local function snap_drop_position(player, position, offset_from_tile_center, auto_determine_drop_offset)
  local cache = player.target_inserter_cache
  local left_top = get_current_grid_left_top(player)
  local relative_x = position.x - left_top.x
  local relative_y = position.y - left_top.y
  local x_offset
  local y_offset
  if auto_determine_drop_offset then
    offset_from_tile_center = offset_from_tile_center * cache.default_drop_offset_multiplier
    local max_range = cache.range + cache.range_gap_from_center
    local tile_width = player.should_flip and cache.tile_height or cache.tile_width
    local tile_height = player.should_flip and cache.tile_width or cache.tile_height
    x_offset = relative_x < max_range and -offset_from_tile_center
      or (max_range + tile_width) < relative_x and offset_from_tile_center
      or 0
    y_offset = relative_y < max_range and -offset_from_tile_center
      or (max_range + tile_height) < relative_y and offset_from_tile_center
      or 0
  else
    -- Modulo always returns a positive number.
    local x_from_tile_center = (relative_x % 1) - 0.5
    local y_from_tile_center = (relative_y % 1) - 0.5
    x_offset = x_from_tile_center == 0 and 0
      or x_from_tile_center < 0 and -offset_from_tile_center
      or offset_from_tile_center
    y_offset = y_from_tile_center == 0 and 0
      or y_from_tile_center < 0 and -offset_from_tile_center
      or offset_from_tile_center
  end
  return {
    x = left_top.x + math.floor(relative_x) + 0.5 + x_offset,
    y = left_top.y + math.floor(relative_y) + 0.5 + y_offset,
  }
end

---@param player PlayerDataQAI
---@param position MapPosition
---@return MapPosition
local function calculate_visualized_drop_position(player, position)
  return snap_drop_position(player, position, 85/256)
end

---@param player PlayerDataQAI
---@param position MapPosition
---@return MapPosition
local function calculate_visualized_default_drop_position(player, position)
  return snap_drop_position(player, position, 85/256, true)
end

---@param player PlayerDataQAI
---@param position MapPosition
---@param auto_determine_drop_offset_no_matter_what boolean?
---@return MapPosition
function calculate_actual_drop_position(player, position, auto_determine_drop_offset_no_matter_what)
  local auto_drop_offset = auto_determine_drop_offset_no_matter_what or should_use_auto_drop_offset(player)
  -- 51 / 256 = 0.19921875. Vanilla inserter drop positions are offset by 0.2 away from the center, however
  -- it ultimately gets rounded to 51 / 256, because of map positions. In other words, this matches vanilla.
  return snap_drop_position(player, position, 51/256, auto_drop_offset)
end

local update_default_drop_highlight
local update_mirrored_highlight
do
  local left_top = {x = 0, y = 0}
  local right_bottom = {x = 0, y = 0}
  ---@type LuaSurface.create_entity_param
  local create_entity_arg = {
    name = "highlight-box",
    render_player_index = 0, -- Set in the actual function.
    position = {x = 0, y = 0}, -- Required but not used since bounding_box is set.
    bounding_box = {
      left_top = left_top,
      right_bottom = right_bottom,
    },
    box_type = nil, -- Set in the actual function.
  }

  ---@param player PlayerDataQAI
  ---@return LuaEntity?
  local function get_and_validate_selected(player)
    local selected = player.player.selected
    if selected
      and (selected.name == consts.ninth_entity_name or selected.name == consts.square_entity_name)
      and global.selectable_entities_to_player_lut[selected.unit_number] == player
    then
      return selected
    end
  end

  ---@param player PlayerDataQAI
  ---@param position MapPosition
  ---@param existing_highlight LuaEntity?
  ---@param size number
  ---@param box_type CursorBoxRenderType
  ---@return LuaEntity? highlight
  local function place_highlight(player, position, existing_highlight, size, box_type)
    if existing_highlight and existing_highlight.valid then -- Guaranteed to be on the surface of the inserter.
      local existing_position = existing_highlight.position
      if existing_position.x == position.x and existing_position.y == position.y then
        return existing_highlight
      end
    end

    -- "highlight-box"es cannot be teleported, so they have to be destroyed and recreated.
    destroy_entity_safe(existing_highlight)
    if not player.current_surface.valid then return end

    create_entity_arg.render_player_index = player.player_index
    create_entity_arg.box_type = box_type
    local radius = size / 2
    left_top.x = position.x - radius
    left_top.y = position.y - radius
    right_bottom.x = position.x + radius
    right_bottom.y = position.y + radius
    return player.current_surface.create_entity(create_entity_arg)
  end

  ---@param player PlayerDataQAI
  function update_default_drop_highlight(player)
    if not player.highlight_default_drop_offset then return end
    if player.state ~= "selecting-drop"
      and not (player.state == "selecting-pickup" and should_skip_selecting_drop(player))
    then
      return
    end

    local selected = get_and_validate_selected(player)
    if not selected then
      destroy_default_drop_highlight(player)
      return
    end

    local position = selected.position
    if player.state == "selecting-pickup" then -- only_allow_mirrored is true.
      mirror_position(player, position)
    end
    position = calculate_visualized_default_drop_position(player, position)

    player.default_drop_highlight
      = place_highlight(player, position, player.default_drop_highlight, 6/32, "electricity")
  end

  ---@param player PlayerDataQAI
  function update_mirrored_highlight(player)
    if not global.only_allow_mirrored then return end
    if player.state ~= "selecting-pickup" then return end

    local selected = get_and_validate_selected(player)
    if not selected then
      destroy_mirrored_highlight(player)
      return
    end

    local position = selected.position
    mirror_position(player, position)
    -- No snapping required, the pickup position (the square entity position) is already centered.

    player.mirrored_highlight = place_highlight(player, position, player.mirrored_highlight, 1, "entity")
  end
end

---@param player PlayerDataQAI
---@param position MapPosition @ Gets modified if `only_allow_mirrored` is true.
local function set_pickup_position(player, position)
  player.target_inserter.pickup_position = position
  if not global.only_allow_mirrored then return end
  mirror_position(player, position)
  player.target_inserter.drop_position = calculate_actual_drop_position(player, position, true)
end

---@param player PlayerDataQAI
---@param position MapPosition
local function set_drop_position(player, position)
  player.target_inserter.drop_position = calculate_actual_drop_position(player, position)
end

---@return Color
local function get_finish_animation_color()
  return {r = 0, g = 1, b = 0, a = 1}
end

---@return Color
local function get_finish_animation_color_step()
  return {r = 0, g = -1 / consts.finish_animation_frames, b = 0, a = -1 / consts.finish_animation_frames}
end

---@param position MapPosition
---@return MapPosition left_top
---@return MapPosition right_bottom
local function get_drop_box(position)
  -- 44/256 ~= 1.7 . I had wanted ~1.6 however 42 and 43 would form non squares depending on where we are in a
  -- tile. So 44 it is.
  local left_top = {x = position.x - 44/256, y = position.y - 44/256}
  local right_bottom = {x = position.x + 44/256, y = position.y + 44/256}
  return left_top, right_bottom
end

---@param player PlayerDataQAI
---@param visual_drop_position MapPosition
---@return boolean
local function try_reuse_existing_drop_highlight(player, visual_drop_position)
  local id = player.drop_highlight_id
  if not id or not rendering.is_valid(id) then return false end
  local left_top, right_bottom = get_drop_box(visual_drop_position)
  if not rectangle_positions_equal(id, left_top, right_bottom) then
    fade_out_or_destroy(id, consts.grid_fade_in_frames)
    return false
  end
  -- The color is the same, so nothing to do.
  return true
end

---@param player PlayerDataQAI
function draw_white_drop_highlight(player)
  local position = calculate_visualized_drop_position(player, player.target_inserter.drop_position)
  if try_reuse_existing_drop_highlight(player, position) then return end
  local left_top, right_bottom = get_drop_box(position)
  player.drop_highlight_id
    = draw_pickup_or_drop_highlight(player, 1, left_top, right_bottom, 1, {r = 1, g = 1, b = 1})
end

---@param player PlayerDataQAI
---@param position MapPosition
local function play_drop_highlight_animation(player, position)
  if player.drop_highlight_id then
    rendering.destroy(player.drop_highlight_id)
    player.drop_highlight_id = nil
  end

  local color = get_finish_animation_color()
  local left_top, right_bottom = get_drop_box(position)
  local id = rendering.draw_rectangle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color,
    width = 2.999,
    left_top = left_top,
    right_bottom = right_bottom,
  }

  local step = consts.finish_animation_highlight_box_step
  add_animated_rectangle{
    id = id,
    remaining_updates = consts.finish_animation_frames - 1,
    destroy_on_finish = true,
    color = color,
    left_top = left_top,
    right_bottom = right_bottom,
    color_step = get_finish_animation_color_step(),
    left_top_step = {x = -step, y = -step},
    right_bottom_step = {x = step, y = step},
  }
end

---@param from MapPosition
---@param to MapPosition
---@param length number
---@return integer frames
---@return MapPosition step_vector
local function get_frames_and_step_vector_for_line_to_highlight(from, to, length)
  local final_length = length - consts.finish_animation_expansion
  local length_step = consts.finish_animation_expansion / consts.finish_animation_frames
  local frames = math.max(1, consts.finish_animation_frames - math.floor(math.max(0, -final_length) / length_step))
  local step_vector = vec.set_length(vec.sub(vec.copy(to), from), length_step / 2)
  return frames, step_vector
end

---@param player PlayerDataQAI
---@param position MapPosition
local function play_line_to_drop_highlight_animation(player, position)
  local from, to, length = get_from_and_to_for_line_from_center(
    player,
    vec.copy(position),
    44/256
  )
  if not from then return end ---@cast to -nil

  local color = get_finish_animation_color()
  local id = rendering.draw_line{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color,
    width = 2,
    from = from,
    to = to,
  }

  local frames, step_vector = get_frames_and_step_vector_for_line_to_highlight(from, to, length)
  add_animated_line{
    type = animation_type.line,
    id = id,
    remaining_updates = frames - 1,
    destroy_on_finish = true,
    color = color,
    from = from,
    to = to,
    color_step = get_finish_animation_color_step(),
    from_step = step_vector,
    to_step = vec.mul_scalar(vec.copy(step_vector), -1),
  }
end

---@param player PlayerDataQAI
local function play_circle_on_inserter_animation(player)
  if not rendering.is_valid(player.inserter_circle_id) then return end
  local color = get_finish_animation_color()
  rendering.set_color(player.inserter_circle_id, color)
  add_animated_circle{
    id = player.inserter_circle_id,
    remaining_updates = consts.finish_animation_frames - 1,
    destroy_on_finish = true,
    color = color,
    radius = player.target_inserter_cache.radius_for_circle_on_inserter,
    color_step = get_finish_animation_color_step(),
    radius_step = (consts.finish_animation_expansion / 2) / consts.finish_animation_frames,
  }
  player.inserter_circle_id = nil -- Destroying is now handled by the animation.
end

---@param player PlayerDataQAI
local function play_pickup_highlight_animation(player)
  if not rendering.is_valid(player.pickup_highlight_id) then return end
  local step = (consts.finish_animation_expansion / 2) / consts.finish_animation_frames
  local left_top, right_bottom = get_pickup_box(player)
  add_animated_rectangle{
    id = player.pickup_highlight_id,
    remaining_updates = consts.finish_animation_frames - 1,
    destroy_on_finish = true,
    color = get_finish_animation_color(),
    left_top = left_top,
    right_bottom = right_bottom,
    color_step = get_finish_animation_color_step(),
    left_top_step = {x = -step, y = -step},
    right_bottom_step = {x = step, y = step},
  }
  player.pickup_highlight_id = nil -- Destroying is now handled by the animation.
end

---@param player PlayerDataQAI
local function play_line_to_pickup_highlight_animation(player)
  local from, to, length = get_from_and_to_for_line_from_center(
    player,
    get_snapped_pickup_position(player),
    0.5
  )
  -- The pickup position might have changed since the last time we checked.
  if not from then ---@cast to -nil
    -- Instantly destroy here, otherwise it would play a fade out animation.
    if player.line_to_pickup_highlight_id then rendering.destroy(player.line_to_pickup_highlight_id) end
    player.line_to_pickup_highlight_id = nil
    return
  end

  local id = player.line_to_pickup_highlight_id
  player.line_to_pickup_highlight_id = nil -- Destroying will be handled by the animation.
  if not id or not rendering.is_valid(id) then
    id = rendering.draw_line{
      surface = player.current_surface_index,
      forces = {player.force_index},
      color = get_finish_animation_color(),
      width = 2,
      from = from,
      to = to,
    }
  end

  local frames, step_vector = get_frames_and_step_vector_for_line_to_highlight(from, to, length)
  add_animated_line{
    id = id,
    remaining_updates = frames - 1,
    destroy_on_finish = true,
    color = get_finish_animation_color(),
    from = from,
    to = to,
    color_step = get_finish_animation_color_step(),
    from_step = step_vector,
    to_step = vec.mul_scalar(vec.copy(step_vector), -1),
  }
end

---@param player PlayerDataQAI
function play_finish_animation(player)
  if not should_animate() then return end
  if player.state == "idle" then
    error("Attempt to play finish animation on idle player. The finish animation requires the current \
      target_inserter as well as its cache and it reuses some of the rendering objects."
    )
  end
  local drop_position = calculate_visualized_drop_position(player, player.target_inserter.drop_position)
  play_drop_highlight_animation(player, drop_position)
  play_line_to_drop_highlight_animation(player, drop_position)
  play_circle_on_inserter_animation(player)
  play_pickup_highlight_animation(player)
  play_line_to_pickup_highlight_animation(player)
end

---This appears to match the game's snapping logic perfectly.
---And we must do this here in order for find_entity to actually find the inserter we just placed, because
---find_entity goes by collision boxes and inserters do not take up entire tiles. Basically nothing does.
---Note that if it went by position we'd also have to do this. So that detail doesn't really matter.
---@param position MapPosition @ Gets modified.
---@param direction defines.direction
---@param cache InserterCacheQAI
local function snap_build_position(position, direction, cache)
  if cache.placeable_off_grid then return end
  local is_north_south = direction == defines.direction.north or direction == defines.direction.south
  local width = is_north_south and cache.raw_tile_width or cache.raw_tile_height
  local height = is_north_south and cache.raw_tile_height or cache.raw_tile_width
  position.x = (width % 2) == 0
    and math.floor(position.x + 0.5) -- even
    or math.floor(position.x) + 0.5 -- odd
  position.y = (height % 2) == 0
    and math.floor(position.y + 0.5) -- even
    or math.floor(position.y) + 0.5 -- odd
end

---@param actual_player LuaPlayer
---@param args LuaPlayer.build_from_cursor_param
---@param inserter_name string
---@return LuaEntity? built_entity
local function brute_force_it(actual_player, args, inserter_name)
  return actual_player.surface.create_entity{
    name = "entity-ghost",
    inner_name = inserter_name,
    position = args.position,
    direction = args.direction,
    player = actual_player,
    force = actual_player.force,
    raise_built = true,
  }
end

---@param actual_player LuaPlayer
---@param item_prototype LuaItemPrototype
local function try_reset_cursor(actual_player, item_prototype)
  local cursor = actual_player.cursor_stack
  if not cursor then return end
  if cursor.valid_for_read and cursor.name == item_prototype.name then
    -- Best guesses to delete the previously spawned in item, could actually be deleting an item it shouldn't.
    -- But at that point the other mod is likely doing some weird stuff.
    if cursor.count == 1 then
      cursor.clear()
    else
      cursor.count = cursor.count - 1
    end
  end
  -- clear() or `count=` most likely do not raise any events instantly so these rechecks are likely pointless.
  cursor = actual_player.cursor_stack
  if cursor and not cursor.valid_for_read then
    actual_player.cursor_ghost = item_prototype
  end
end

---@param actual_player LuaPlayer
---@param args LuaPlayer.build_from_cursor_param
---@param inserter_name string
---@return LuaEntity? built_entity @ Guaranteed to be valid (when not `nil` of course).
local function build_from_cursor_ghost(actual_player, args, inserter_name)
  local item_prototype = actual_player.cursor_ghost--[[@as LuaItemPrototype]]
  local surface = actual_player.surface

  -- Initial validation (do nothing if it is a spectator).
  local cursor = actual_player.cursor_stack
  if not cursor then return nil end

  cursor.set_stack{name = item_prototype.name, count = 1}

  do -- set_stack most likely does not raise any event instantly, so the next code block is likely pointless.
    if not surface.valid or actual_player.surface_index ~= surface.index then
      try_reset_cursor(actual_player, item_prototype)
      return nil
    end
    cursor = actual_player.cursor_stack -- Refetch just in case the controller changed multiple times in between.
  end

  -- This entire block is likely just as pointless.
  if not cursor or not cursor.valid_for_read or cursor.name ~= item_prototype.name then
    local built_entity = brute_force_it(actual_player, args, inserter_name)
    try_reset_cursor(actual_player, item_prototype)
    return built_entity and built_entity.valid and built_entity or nil
  end

  -- Validation passed, build ghost from cursor.
  actual_player.build_from_cursor(args)
  local built_entity = surface.valid and find_ghost_entity(surface, inserter_name, args.position) or nil
  try_reset_cursor(actual_player, item_prototype)
  -- The built_entity valid check here is likely also pointless.
  return built_entity and built_entity.valid and built_entity or nil
end

---This logic deciding between real or ghost building does not match the game's logic. There are several
---cases where this will choose to build a ghost sooner than the game would consider it out of range,
---especially on diagonals. However for simplicity this is good enough, and it does take the collision box
---of the inserter into account at least a little bit. And it never causes a "cannot reach" floating text.
---@param player PlayerDataQAI
---@param position MapPosition
---@param cache InserterCacheQAI
---@return boolean
local function is_within_build_range(player, position, cache)
  local actual_player = player.player
  -- + 1/256 just to make sure there are no rare edge cases where it ends up being off by 1.
  local distance = vec.get_length(vec.sub(actual_player.position, position)) + 1/256
  -- And greater _equals_ for the same potential edge cases.
  return distance >= actual_player.build_distance + cache.min_extra_build_distance
end

---@param player PlayerDataQAI
---@param position MapPosition
---@param inserter_name string @ Must be a valid LuaEntityPrototype name.
---@param cache InserterCacheQAI
---@param is_cursor_ghost boolean?
---@return LuaEntity? inserter @ The placed inserter if successful.
local function try_place_held_inserter_and_adjust_it(player, position, inserter_name, cache, is_cursor_ghost)
  if cache.disabled_because_of_tech_level then
    show_error(player, {"qai.cant-adjust-due-to-lack-of-tech"})
    return
  end

  ---@type LuaPlayer.can_build_from_cursor_param
  local args = {
    position = position,
    direction = cache.not_rotatable
      and defines.direction.north
      or cursor_direction.get_cursor_direction_four_way(player)
    -- `alt` is evaluated later.
  }
  local actual_player = player.player
  if not is_cursor_ghost and not actual_player.can_build_from_cursor(args) then return end

  ---@cast args LuaPlayer.build_from_cursor_param
  snap_build_position(position, args.direction, cache)
  local surface = actual_player.surface
  local inserter
  if is_cursor_ghost then
    args.alt = true
    inserter = build_from_cursor_ghost(actual_player, args, inserter_name)
  else
    args.alt = is_within_build_range(player, position, cache)
    actual_player.build_from_cursor(args)
    if args.alt then
      inserter = surface.valid and find_ghost_entity(surface, inserter_name, position)
    else
      inserter = surface.valid and surface.find_entity(inserter_name, position)
    end
  end

  -- If the player changed surface, do not switch to selecting pickup.
  if not surface.valid or actual_player.surface_index ~= surface.index then return end
  if not inserter then return end
  if not actual_player.clear_cursor() then return end
  -- Docs say clear_cursor raises an event in the current tick, not instantly, but a valid check does not hurt.
  if not inserter.valid then return end
  advance_to_selecting_pickup(player, inserter)
  -- Accept both selecting pickup and selecting drop as states after the call above, because skipping
  -- selecting pickup is possible.
  if player.state ~= "idle" and player.target_inserter == inserter then
    player.pipette_when_done = true
    return inserter.valid and inserter or nil
  end
end

---@param entity LuaEntity
---@param selectable_name string
---@param player PlayerDataQAI
---@return boolean
local function is_selectable_for_player(entity, selectable_name, player)
  return entity.name == selectable_name
    and global.selectable_entities_to_player_lut[entity.unit_number] == player
end

---@type table<string, fun(player: PlayerDataQAI, selected: LuaEntity)>
local on_adjust_handler_lut = {
  ["idle"] = function(player, selected)
    if not is_real_or_ghost_inserter(selected) then return end
    advance_to_selecting_pickup(player, selected, true)
  end,

  ["selecting-pickup"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if is_real_or_ghost_inserter(selected) then
      if selected == player.target_inserter then
        advance_to_selecting_drop(player, player.target_inserter)
      else
        advance_to_selecting_pickup(player, selected, true)
      end
      return
    end
    if is_selectable_for_player(selected, consts.square_entity_name, player) then
      set_pickup_position(player, selected.position)
      advance_to_selecting_drop(player, player.target_inserter)
      return
    end
    if is_selectable_for_player(selected, consts.rect_entity_name, player) then
      set_direction_and_update_arrow(player, selected.direction)
      return
    end
    switch_to_idle(player)
  end,

  ["selecting-drop"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if is_real_or_ghost_inserter(selected) then
      if selected == player.target_inserter then
        play_finish_animation(player) -- Before switching to idle because some rendering objects get reused.
        switch_to_idle(player)
      else
        advance_to_selecting_pickup(player, selected, true)
      end
      return
    end
    if is_selectable_for_player(selected, consts.square_entity_name, player)
      or is_selectable_for_player(selected, consts.ninth_entity_name, player)
    then
      set_drop_position(player, selected.position)
      play_finish_animation(player) -- Before switching to idle because some rendering objects get reused.
      switch_to_idle(player)
      return
    end
    if is_selectable_for_player(selected, consts.rect_entity_name, player) then
      set_direction_and_update_arrow(player, selected.direction)
      return
    end
    switch_to_idle(player)
  end,
}

---@param player PlayerDataQAI
---@param selected_entity LuaEntity?
local function adjust(player, selected_entity)
  if not selected_entity then
    switch_to_idle(player)
    return
  end
  on_adjust_handler_lut[player.state](player, selected_entity)
end

---@param force ForceDataQAI
local function update_inserter_cache(force)
  force.inserter_cache_lut = {}
  for _, inserter in pairs(game.get_filtered_entity_prototypes{{filter = "type", type = "inserter"}}) do
    -- No matter what other flags the inserter has set (in other words no matter what crazy things other mods
    -- might be doing), generate cache for it if it has `allow_custom_vectors` set, allowing this mod to
    -- adjust it. Even if it isn't selectable or if it is rotatable 8 way, both of which make little sense for
    -- this mod, the remote interface exists, and the 8 directions won't break this mod.
    if inserter.allow_custom_vectors then
      force.inserter_cache_lut[inserter.name] = generate_cache_for_inserter(inserter, force.tech_level)
    end
  end
  for _, player in ipairs(force.force.players) do
    local player_data = global.players[player.index]
    if player_data then
      switch_to_idle_and_back(player_data)
    end
  end
end

local update_tech_level_for_force
do
  ---@generic T
  ---@param name string
  ---@param default_value T
  ---@return T
  local function get_startup_setting_value(name, default_value)
    local setting = settings.startup[name]
    -- A setting from another mod, we cannot trust it actually existing.
    -- There's an argument to be made that this should throw an error if the setting does not exist, and yea
    -- I'm considering it. But also :shrug:.
    if setting then
      return setting.value
    else
      return default_value
    end
  end

  ---@param tech_level TechnologyLevelQAI
  ---@param techs LuaCustomTable<string, LuaTechnology>
  local function evaluate_near(tech_level, techs)
    if consts.use_smart_inserters and not get_startup_setting_value("si-offset-technologies", false) then
      tech_level.drop_offset = true
      return
    end
    local near_inserters = techs[consts.near_inserters_name]
    tech_level.drop_offset = near_inserters and near_inserters.researched or false
  end

  ---@param tech_level TechnologyLevelQAI
  ---@param techs LuaCustomTable<string, LuaTechnology>
  local function evaluate_tiles(tech_level, techs)
    if consts.use_smart_inserters and not get_startup_setting_value("si-diagonal-technologies", false) then
      tech_level.all_tiles = true
      tech_level.cardinal = true
      tech_level.diagonal = true
      return
    end
    local cardinal_inserters = consts.cardinal_inserters_name and techs[consts.cardinal_inserters_name]
    local more_inserters_1 = techs[consts.more_inserters_1_name]
    local more_inserters_2 = techs[consts.more_inserters_2_name]
    tech_level.all_tiles = more_inserters_2 and more_inserters_2.researched or false
    tech_level.cardinal = tech_level.all_tiles or (cardinal_inserters == nil and true or cardinal_inserters.researched)
    tech_level.diagonal = tech_level.all_tiles or more_inserters_1 and more_inserters_1.researched or false
  end

  ---@param techs LuaCustomTable<string, LuaTechnology>
  ---@return integer
  local function get_range_from_technologies(techs)
    local range = 1
    for level = 1, 1/0 do -- No artificial limit, the practical limit will be hit pretty quickly anyway.
      local tech = techs[string.format(consts.range_technology_format, level)]
      if not tech then break end -- Gaps in technologies are not accepted.
      if tech.researched then
        range = level + 1 -- "long-inserters-1" equates to having 2 range.
      end
      -- Continue even if a technology isn't researched to find the highest technology which has been researched.
      -- The highest technology is unknown, so it's just a loop from the bottom up.
    end
    return range
  end

  ---@param tech_level TechnologyLevelQAI
  ---@param techs LuaCustomTable<string, LuaTechnology>
  local function evaluate_range(tech_level, techs)
    if consts.use_smart_inserters and not get_startup_setting_value("si-range-technologies", false) then
      -- Using math.max because this is the setting from another mod therefore we cannot trust it.
      tech_level.range = math.max(1, get_startup_setting_value("si-max-inserters-range", 3))
      return
    end
    tech_level.range = get_range_from_technologies(techs)
  end

  ---@param force ForceDataQAI
  function update_tech_level_for_force(force)
    local tech_level = force.tech_level
    local techs = force.force.technologies
    evaluate_near(tech_level, techs)
    evaluate_tiles(tech_level, techs)
    evaluate_range(tech_level, techs)
    update_inserter_cache(force)
  end
end

---@param force LuaForce
---@return ForceDataQAI
function init_force(force)
  local force_index = force.index
  ---@type ForceDataQAI
  local force_data = {
    force = force,
    force_index = force_index,
    tech_level = {},
    inserter_cache_lut = (nil)--[[@as any]], -- Set in `update_inserter_cache`.
  }
  global.forces[force_index] = force_data
  update_tech_level_for_force(force_data)
  return force_data
end

---@param player PlayerDataQAI
---@param setting_name string
---@param field_name string
local function update_show_throughput_on_player(player, setting_name, field_name)
  local new_value = settings.get_player_settings(player.player_index)[setting_name].value--[[@as boolean]]
  if new_value == player[field_name] then return end
  player[field_name] = new_value
  update_inserter_speed_text(player)
end

---@param player PlayerDataQAI
local function clear_pipetted_inserter_data(player)
  player.pipetted_inserter_name = nil
  player.pipetted_pickup_vector = nil
  player.pipetted_drop_vector = nil
end

---Since on_player_cursor_stack_changed gets raised at the end of the tick, make sure to validate associated
---data every time any of said data gets used, since the cursor could have changed already in this tick.
---@param player PlayerDataQAI
function validate_cursor_stack_associated_data(player)
  local cursor_item = get_cursor_item_prototype(player)
  if cursor_item then
    player.pipette_when_done = nil
  end
  if not cursor_item or cursor_item.name ~= player.pipetted_inserter_name then
    clear_pipetted_inserter_data(player)
  end
end

---@type table<string, fun(player: PlayerDataQAI)>
local update_setting_lut = {
  ["qai-show-throughput-on-inserter"] = function(player)
    update_show_throughput_on_player(player, "qai-show-throughput-on-inserter", "show_throughput_on_inserter")
  end,
  ["qai-show-throughput-on-pickup"] = function(player)
    update_show_throughput_on_player(player, "qai-show-throughput-on-pickup", "show_throughput_on_pickup")
  end,
  ["qai-show-throughput-on-drop"] = function(player)
    update_show_throughput_on_player(player, "qai-show-throughput-on-drop", "show_throughput_on_drop")
  end,
  ["qai-highlight-default-drop-offset"] = function(player)
    local new_value = settings.get_player_settings(player.player_index)["qai-highlight-default-drop-offset"].value--[[@as boolean]]
    if new_value == player.highlight_default_drop_offset then return end
    player.highlight_default_drop_offset = new_value
    if player.highlight_default_drop_offset then
      update_default_drop_highlight(player)
    else
      destroy_default_drop_highlight(player)
    end
  end,
  ["qai-pipette-after-place-and-adjust"] = function(player)
    local new_value = settings.get_player_settings(player.player_index)["qai-pipette-after-place-and-adjust"].value--[[@as boolean]]
    player.pipette_after_place_and_adjust = new_value
  end,
  ["qai-pipette-copies-vectors"] = function(player)
    local new_value = settings.get_player_settings(player.player_index)["qai-pipette-copies-vectors"].value--[[@as boolean]]
    if new_value == player.pipette_copies_vectors then return end
    player.pipette_copies_vectors = new_value
    if not player.pipette_copies_vectors then
      clear_pipetted_inserter_data(player)
    end
  end,
}

local function update_only_allow_mirrored_setting()
  global.only_allow_mirrored = settings.global["qai-mirrored-inserters-only"].value--[[@as boolean]]
  for _, player in safer_pairs(global.players) do
    if validate_player(player) then
      switch_to_idle_and_back(player)
    end
  end
end

---@param player LuaPlayer
---@return PlayerDataQAI
local function init_player(player)
  local player_settings = settings.get_player_settings(player)
  ---@type PlayerDataQAI
  local player_data = {
    player = player,
    player_index = player.index,
    force_index = player.force_index--[[@as uint8]],
    state = "idle",
    used_squares = {},
    used_ninths = {},
    used_rects = {},
    line_ids = {},
    direction_arrows_indicator_line_ids = {},
    show_throughput_on_inserter = player_settings["qai-show-throughput-on-inserter"].value--[[@as boolean]],
    show_throughput_on_pickup = player_settings["qai-show-throughput-on-pickup"].value--[[@as boolean]],
    show_throughput_on_drop = player_settings["qai-show-throughput-on-drop"].value--[[@as boolean]],
    highlight_default_drop_offset = player_settings["qai-highlight-default-drop-offset"].value--[[@as boolean]],
    pipette_after_place_and_adjust = player_settings["qai-pipette-after-place-and-adjust"].value--[[@as boolean]],
    pipette_copies_vectors = player_settings["qai-pipette-copies-vectors"].value--[[@as boolean]],
  }
  cursor_direction.init_player(player_data)
  global.players[player_data.player_index] = player_data
  return player_data
end

---@param player PlayerDataQAI
function remove_player(player)
  switch_to_idle(player)
  global.players[player.player_index] = nil
end

---Can be called if the given `player_index` actually no longer exists at this point in time.
---@param player_index integer
---@return PlayerDataQAI?
local function get_or_init_player(player_index)
  local player_data = get_player_raw(player_index)
  if player_data then return player_data end
  local player = game.get_player(player_index)
  return player and init_player(player) or nil
end

---@param player PlayerDataQAI
local function update_active_inserter_speed_text(player)
  local inserter = player.inserter_speed_reference_inserter
  if not inserter.valid then return end

  local current_stack_size = inserter.inserter_target_pickup_count
  if current_stack_size ~= player.inserter_speed_stack_size then
    -- `inserter_speed_stack_size` gets updated by `update_inserter_speed_text`.
    update_inserter_speed_text(player)
    return
  end

  if player.state ~= "idle" and player.target_inserter == inserter then
    return -- Pickup and drop positions get compared by regular active player update in this case.
  end

  if not vec.vec_equals(inserter.pickup_position, player.inserter_speed_pickup_position)
    or not vec.vec_equals(inserter.drop_position, player.inserter_speed_drop_position)
  then
    update_inserter_speed_text(player)
    return
  end
end

---@param player PlayerDataQAI
local function update_active_player(player)
  if not validate_player(player) then return end

  if player.has_active_inserter_speed_text then
    update_active_inserter_speed_text(player)
  end

  if not validate_target_inserter(player) then return end -- Returns when player is idle.

  local inserter = player.target_inserter
  deactivate_inserter(player, inserter)

  if dirs.collapse_direction_lut[inserter.direction] ~= player.target_inserter_direction
    or inserter.force_index ~= player.target_inserter_force_index
    or not vec.vec_equals(inserter.position, player.target_inserter_position)
  then
    switch_to_idle_and_back(player, true)
    update_inserter_speed_text(player)
    return
  end

  if not vec.vec_equals(inserter.pickup_position, player.target_inserter_pickup_position)
    or not vec.vec_equals(inserter.drop_position, player.target_inserter_drop_position)
  then
    switch_to_idle_and_back(player) -- Don't do reach checks.
    update_inserter_speed_text(player)
    return
  end

  if should_be_rotatable(player) ~= player.is_rotatable then
    switch_to_idle_and_back(player) -- Don't do reach checks.
    -- And don't update inserter speed text.
    return
  end
end

---@type table<AnimationTypeQAI, fun(animation: AnimationQAI)>
local update_animation_lut
do
  local set_color = rendering.set_color
  local set_radius = rendering.set_radius
  local set_left_top = rendering.set_left_top
  local set_right_bottom = rendering.set_right_bottom
  local set_from = rendering.set_from
  local set_to = rendering.set_to

  update_animation_lut = {
    ---@param animation AnimatedCircleQAI
    [animation_type.circle] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)

      local radius = animation.radius + animation.radius_step
      animation.radius = radius
      set_radius(id, radius)
    end,
    ---@param animation AnimatedRectangleQAI
    [animation_type.rectangle] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)

      local left_top = animation.left_top
      local left_top_step = animation.left_top_step
      left_top.x = left_top.x + left_top_step.x
      left_top.y = left_top.y + left_top_step.y
      set_left_top(id, left_top)

      local right_bottom = animation.right_bottom
      local right_bottom_step = animation.right_bottom_step
      right_bottom.x = right_bottom.x + right_bottom_step.x
      right_bottom.y = right_bottom.y + right_bottom_step.y
      set_right_bottom(id, right_bottom)
    end,
    ---@param animation AnimatedLineQAI
    [animation_type.line] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)

      local from = animation.from
      local from_step = animation.from_step
      from.x = from.x + from_step.x
      from.y = from.y + from_step.y
      set_from(id, from)

      local to = animation.to
      local to_step = animation.to_step
      to.x = to.x + to_step.x
      to.y = to.y + to_step.y
      set_to(id, to)
    end,
    ---@param animation AnimatedColorQAI
    [animation_type.color] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)
    end,
  }
end

local rendering_is_valid = rendering.is_valid

script.on_event(ev.on_tick, function(event)
  local global = global -- Premature micro optimizations are bad for your health...

  local active_players = global.active_players
  local next_index = active_players.next_index
  local player = active_players[next_index]
  if player then
    update_active_player(player)
    active_players.next_index = next_index + 1
  else
    active_players.next_index = 1
  end

  local active_animations = global.active_animations
  local count = active_animations.count
  for i = count, 1, -1 do
    local animation = active_animations[i]
    local remaining_updates = animation.remaining_updates
    if remaining_updates > 0 and rendering_is_valid(animation.id) then
      animation.remaining_updates = remaining_updates - 1
      local update_animation = update_animation_lut[animation.type]
      update_animation(animation)
    else
      if animation.destroy_on_finish then
        rendering.destroy(animation.id) -- Destroy accepts already invalid ids.
      end
      active_animations[i] = active_animations[count]
      active_animations[count] = nil
      count = count - 1
      active_animations.count = count
    end
  end
end)

script.on_event("qai-adjust", function(event)
  local player = get_player(event)
  if not player then return end
  local place_result, is_cursor_ghost = get_cursor_item_place_result(player)
  if place_result and place_result.type == "inserter" then
    local force = get_or_init_force(player.player.force_index)
    local name = place_result.name
    local cache = force and force.inserter_cache_lut[name]
    if cache then
      try_place_held_inserter_and_adjust_it(player, event.cursor_position, name, cache, is_cursor_ghost)
      return
    end
  end

  adjust(player, get_redirected_selected_entity(player.player.selected))
end)

script.on_event("qai-rotate", function(event)
  local player = get_player(event)
  if not player then return end
  cursor_direction.handle_rotation(player, false)
end)

script.on_event("qai-reverse-rotate", function(event)
  local player = get_player(event)
  if not player then return end
  cursor_direction.handle_rotation(player, true)
end)

script.on_event(ev.on_player_pipette, function(event)
  local player = get_player(event)
  if not player then return end
  -- If a mod called player.pipette_entity then this will likely be wrong, however the event does not tell us
  -- the entity that was pipetted, so this is the best guess.
  local selected = player.player.selected
  if not selected then return end
  cursor_direction.handle_pipette_direction(player, selected)

  if not player.pipette_copies_vectors or not is_real_or_ghost_inserter(selected) then return end
  local force = get_or_init_force(player.force_index)
  if not force then return end
  local name = get_real_or_ghost_name(selected)
  local cache = force.inserter_cache_lut[name]
  if not cache or cache.disabled_because_of_tech_level then return end
  save_pipetted_vectors(player, name, selected)
end)

script.on_event(ev.on_player_cursor_stack_changed, function(event)
  local player = get_player(event)
  if not player then return end
  validate_cursor_stack_associated_data(player)
end)

script.on_event(ev.on_selected_entity_changed, function(event)
  local player = get_player(event)
  if not player then return end
  update_default_drop_highlight(player)
  update_mirrored_highlight(player)
  update_inserter_speed_text(player)
end)

script.on_event(ev.on_entity_settings_pasted, function(event)
  local player = get_player(event)
  if player then
    -- It won't update for other players hovering the inserter. It is not worth adding logic for that.
    update_inserter_speed_text(player)
  end
  local destination = event.destination
  if destination.type ~= "inserter" then return end
  player = validate_player(global.inserters_in_use[get_id(destination)])
  if not player then return end
  switch_to_idle_and_back(player)
  update_inserter_speed_text(player)
end)

script.on_event(ev.on_runtime_mod_setting_changed, function(event)
  if event.setting == "qai-mirrored-inserters-only" then
    update_only_allow_mirrored_setting()
    return
  end
  -- Per player settings.
  local update_setting = update_setting_lut[event.setting]
  if not update_setting then return end
  local player = get_player(event)
  if not player then return end
  update_setting(player)
end)

script.on_event(ev.on_player_changed_position, function(event)
  local player = get_player(event)
  if not player then return end
  if player.state ~= "idle" then
    local inserter = player.target_inserter
    if not inserter.valid
      or (not player.no_reach_checks and not can_reach_entity(player, inserter))
    then
      switch_to_idle(player)
    end
  end
end)

for _, data in ipairs{
  {event_name = ev.on_player_rotated_entity, do_check_reach = false},
  {event_name = ev.script_raised_teleported, do_check_reach = true},
}
do
  local do_check_reach = data.do_check_reach
  ---@param event EventData.on_player_rotated_entity|EventData.script_raised_teleported
  script.on_event(data.event_name, function(event)
    local player = get_player(event)
    if player then
      -- If this is an inserter and another player also has that inserter selected, the text won't update for
      -- them. Making it update for them is not worth the performance cost or complexity.
      update_inserter_speed_text(player)
    end
    player = validate_player(global.inserters_in_use[get_id(event.entity)])
    if player then
      switch_to_idle_and_back(player, do_check_reach)
    end
  end)
end

for _, destroy_event in ipairs{
  ev.on_robot_mined_entity,
  ev.on_player_mined_entity,
  ev.script_raised_destroy,
}
do
  ---@param event EventData.on_robot_mined_entity|EventData.on_player_mined_entity|EventData.script_raised_destroy
  script.on_event(destroy_event, function(event)
    local player = validate_player(global.inserters_in_use[get_id(event.entity)])
    if not player then return end
    switch_to_idle(player)
  end, {
    {filter = "type", type = "inserter"},
    {mode = "or", filter = "ghost_type", type = "inserter"},
  })
end

script.on_event(ev.on_post_entity_died, function(event)
  local ghost = event.ghost
  if not ghost then return end
  local player = validate_player(global.inserters_in_use[event.unit_number])
  if not player then return end
  switch_to_idle_and_back(player, false, ghost)
end, {{filter = "type", type = "inserter"}})

---@param entity LuaEntity
---@return boolean
local function potential_revive(entity)
  local player = validate_player(
    global.inserters_in_use[entity.unit_number] or global.inserters_in_use[get_ghost_id(entity)]
  )
  if not player then return false end
  switch_to_idle_and_back(player, false, entity)
  return true
end

script.on_event(ev.script_raised_revive, function(event)
  potential_revive(event.entity)
end, {{filter = "type", type = "inserter"}})

script.on_event(ev.on_robot_built_entity, function(event)
  potential_revive(event.created_entity)
end, {{filter = "type", type = "inserter"}})

script.on_event(ev.on_built_entity, function(event)
  local entity = event.created_entity
  local entity_type = inserter_throughput.get_real_or_ghost_entity_type(entity)
  if entity_type ~= "inserter" then
    local player = get_player(event)
    if not player then return end
    cursor_direction.handle_built_rail_connectable_or_offshore_pump(player, entity, entity_type)
    return
  end

  if not is_ghost[entity] and potential_revive(event.created_entity) then return end
  local player = get_player(event)
  if not player then return end
  validate_cursor_stack_associated_data(player)
  local expected_name = player.pipetted_inserter_name
  if not expected_name then return end
  if get_real_or_ghost_name(entity) ~= expected_name then return end
  local direction = entity.direction -- Supports all directions, not just 4.
  local position = entity.position
  local pickup_vector = vec.rotate_by_direction(vec.copy(player.pipetted_pickup_vector), direction)
  local drop_vector = vec.rotate_by_direction(vec.copy(player.pipetted_drop_vector), direction)
  entity.pickup_position = vec.add(pickup_vector, position)
  entity.drop_position = vec.add(drop_vector, position)
end, { -- Is this even worth it at this point? I have no idea. Maybe.
  {--[[      ]] filter = "type", type = "inserter"},
  {mode = "or", filter = "type", type = "offshore-pump"},
  {mode = "or", filter = "type", type = "rail-signal"},
  {mode = "or", filter = "type", type = "rail-chain-signal"},
  {mode = "or", filter = "type", type = "train-stop"},
  {mode = "or", filter = "ghost_type", type = "inserter"},
  {mode = "or", filter = "ghost_type", type = "offshore-pump"},
  {mode = "or", filter = "ghost_type", type = "rail-signal"},
  {mode = "or", filter = "ghost_type", type = "rail-chain-signal"},
  {mode = "or", filter = "ghost_type", type = "train-stop"},
})

script.on_event({ev.on_research_finished, ev.on_research_reversed}, function(event)
  local research = event.research
  if not do_we_care_about_this_technology(research.name) then return end
  local force = get_force(research.force.index)
  if not force then return end
  update_tech_level_for_force(force)
end)

script.on_event(ev.on_force_reset, function(event)
  local force = get_force(event.force.index)
  if not force then return end
  update_tech_level_for_force(force)
end)

---@param force LuaForce
local function recheck_players_in_force(force)
  for _, player in ipairs(force.players) do
    local player_data = get_player_raw(player.index)
    if player_data then
      switch_to_idle_and_back(player_data)
    end
  end
end

script.on_event(ev.on_force_friends_changed, function(event)
  recheck_players_in_force(event.force)
  recheck_players_in_force(event.other_force)
end)

script.on_event(ev.on_player_changed_force, function(event)
  local player = get_player(event)
  if not player then return end
  player.force_index = player.player.force_index--[[@as uint8]]
  switch_to_idle_and_back(player)
  update_inserter_speed_text(player)
end)

script.on_event(ev.on_player_display_scale_changed, function(event)
  local player = get_player(event)
  if not player then return end
  update_inserter_speed_text_scale(player)
end)

script.on_configuration_changed(function(event)
  -- Ignore the event if this mod has just been added, since on_init ran already anyway.
  local mod_changes = event.mod_changes["quick-adjustable-inserters"]
  if mod_changes and not mod_changes.old_version then return end

  -- Do this before updating forces, because updating forces potentially involves changing player states.
  for _, player in safer_pairs(global.players) do
    if validate_player(player)then
      player.pipette_when_done = nil
      clear_pipetted_inserter_data(player)
    end
  end

  for _, force in safer_pairs(global.forces) do
    if validate_force(force) then
      update_tech_level_for_force(force)
    end
  end
end)

script.on_event(ev.on_force_created, function(event)
  init_force(event.force) -- This can unfortunately cause a little lag spike.
end)

script.on_event(ev.on_forces_merged, function(event)
  -- Merging forces raises the player changed force event, so nothing else to do here.
  global.forces[event.source_index] = nil
end)

script.on_event(ev.on_player_left_game, function(event)
  local player = get_player(event)
  if not player then return end
  switch_to_idle(player)
end)

script.on_event(ev.on_player_created, function(event)
  init_player(game.get_player(event.player_index)--[[@as LuaPlayer]])
end)

script.on_event(ev.on_player_removed, function(event)
  -- It might legitimately already have been removed through another mod raising an event which causes this
  -- mod to call get_player, which checks player validity and then removes the player. Said other mod would
  -- have to do so in its on_player_removed handler and come before this mod in mod load order.
  local player = global.players[event.player_index]
  if not player then return end
  remove_player(player)
end)

script.on_load(function()
  try_override_can_reach_entity()
end)

script.on_init(function()
  try_override_can_reach_entity()
  ---@type GlobalDataQAI
  global = {
    players = {},
    forces = {},
    inserters_in_use = {},
    active_players = {count = 0, next_index = 1},
    active_animations = {count = 0},
    selectable_entities_to_player_lut = {},
    selectable_entities_by_unit_number = {},
    selectable_dummy_redirects = {},
    ghost_ids = {},
    only_allow_mirrored = settings.global["qai-mirrored-inserters-only"].value--[[@as boolean]],
  }
  for _, force in pairs(game.forces) do
    init_force(force)
  end
  for _, player in pairs(game.players) do
    init_player(player)
  end
end)

remote.add_interface("qai", {
  ---The mod and the entire world could be in any state after this call.
  ---@param player_index integer
  switch_to_idle = function(player_index)
    local player = get_or_init_player(player_index)
    if not player then return end
    switch_to_idle(player)
  end,
  ---Effectively refreshes the current state using all new values. The mod already catches most things through
  ---events, and things it cannot catch through events it gradually checks in an on_tick handler, but this can
  ---instantly notify the mod about changes that require a state refresh.
  ---
  ---The mod and the entire world could be in any state after this call.
  ---@param player_index integer
  ---@param do_check_reach boolean? @ Default: `false`.
  switch_to_idle_and_back = function(player_index, do_check_reach)
    local player = get_or_init_player(player_index)
    if not player then return end
    switch_to_idle_and_back(player, do_check_reach)
  end,
  ---The mod and the entire world could be in any state after this call.
  ---@param player_index integer
  ---@param selected_entity LuaEntity?
  adjust = function(player_index, selected_entity)
    local player = get_or_init_player(player_index)
    if not player then return end
    adjust(player, selected_entity)
  end,
  ---Tries to use the inserter in the `player.cursor_stack` to place and adjust it at a given position.\
  ---Finishing adjusting will restore the cursor, unless the cursor changed in the meantime.
  ---
  ---The mod and the entire world could be in any state after this call. Including the cursor, even when
  ---successful.
  ---@param player_index integer
  ---@param position MapPosition
  ---@return LuaEntity? inserter @ The placed inserter if successful. Never invalid.
  try_place_and_adjust = function(player_index, position)
    local player = get_or_init_player(player_index)
    if not player then return end
    local place_result, is_cursor_ghost = get_cursor_item_place_result(player)
    if place_result and place_result.type == "inserter" then
      local force = get_or_init_force(player.player.force_index)
      local name = place_result.name
      local cache = force and force.inserter_cache_lut[name]
      if cache then
        return try_place_held_inserter_and_adjust_it(player, position, name, cache, is_cursor_ghost)
      end
    end
  end,
  ---Get the current best guess for what the given player's cursor/hand direction might be.\
  ---This being in quick-adjustable-inserter's remote interface makes little sense, but the rotation state
  ---tracking exists in the mod, so might as well expose it.
  ---@param player_index integer
  ---@return defines.direction @ north, east, south or west.
  get_cursor_direction_four_way = function(player_index)
    local player = get_or_init_player(player_index)
    if not player then return defines.direction.north end
    return cursor_direction.get_cursor_direction_four_way(player)
  end,
  ---Get the current best guess for what the given player's cursor/hand direction might be.\
  ---This being in quick-adjustable-inserter's remote interface makes little sense, but the rotation state
  ---tracking exists in the mod, so might as well expose it.
  ---@param player_index integer
  ---@return defines.direction @ Any of the 8 possible directions.
  get_cursor_direction_eight_way = function(player_index)
    local player = get_or_init_player(player_index)
    if not player then return defines.direction.north end
    return cursor_direction.get_cursor_direction_eight_way(player)
  end,
})
