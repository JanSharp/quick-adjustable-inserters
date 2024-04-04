
local vec = require("__inserter-throughput-lib__.vector")
local consts = require("__quick-adjustable-inserters__.runtime.consts")

---@type ForceDataUtilQAI
local force_data

---@param refs {force_data: ForceDataUtilQAI}
local function set_circular_references(refs)
  force_data = refs.force_data
end

---cSpell:ignore IDQAI

---@param name string
local function do_we_care_about_this_technology(name)
  return consts.techs_we_care_about[name]
    or string.find(name, consts.range_technology_pattern)
end

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

---@param player PlayerDataQAI
---@param pos MapPosition
---@return MapPosition
local function flip(player, pos)
  if player.should_flip then
    pos.x, pos.y = pos.y, pos.x
  end
  return pos
end

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
---@return LuaItemPrototype?
---@return boolean is_cursor_ghost
local function get_cursor_item_prototype(player)
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
---@param position MapPosition @ Gets modified.
local function mirror_position(player, position)
  local grid_center_position = get_current_grid_center_position(player)
  vec.add(vec.mul_scalar(vec.sub(position, grid_center_position), -1), grid_center_position)
end

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
  local force = force_data.get_or_init_force(player.force_index)
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
---@param target_inserter LuaEntity? @ Must be provided if the player state is (or can be) "idle".
---@return boolean
local function should_use_auto_drop_offset(player, target_inserter)
  local cache = player.target_inserter_cache or get_cache_for_inserter(player, target_inserter--[[@as LuaEntity]])
  return player.always_use_default_drop_offset
    or (cache and cache.tech_level.drop_offset)
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@return boolean
local function should_skip_selecting_pickup(player, target_inserter)
  local cache = get_cache_for_inserter(player, target_inserter)
  return cache and cache.only_drop_offset or false
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity? @ Must be provided if the player state is (or can be) "idle".
---@return boolean
local function should_skip_selecting_drop(player, target_inserter)
  return global.only_allow_mirrored and should_use_auto_drop_offset(player, target_inserter)
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
local function calculate_actual_drop_position(player, position, auto_determine_drop_offset_no_matter_what)
  local auto_drop_offset = auto_determine_drop_offset_no_matter_what or should_use_auto_drop_offset(player)
  -- 51 / 256 = 0.19921875. Vanilla inserter drop positions are offset by 0.2 away from the center, however
  -- it ultimately gets rounded to 51 / 256, because of map positions. In other words, this matches vanilla.
  return snap_drop_position(player, position, 51/256, auto_drop_offset)
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

---@param entity LuaEntity
---@param selectable_name string
---@param player PlayerDataQAI
---@return boolean
local function is_selectable_for_player(entity, selectable_name, player)
  return entity.name == selectable_name
    and global.selectable_entities_to_player_lut[entity.unit_number] == player
end

---@class UtilsFileQAI
local utils = {
  set_circular_references = set_circular_references,
  do_we_care_about_this_technology = do_we_care_about_this_technology,
  safer_pairs = safer_pairs,
  flip = flip,
  is_ghost = is_ghost,
  is_real_or_ghost_inserter = is_real_or_ghost_inserter,
  get_real_or_ghost_name = get_real_or_ghost_name,
  get_real_or_ghost_prototype = get_real_or_ghost_prototype,
  find_ghost_entity = find_ghost_entity,
  find_real_or_ghost_entity = find_real_or_ghost_entity,
  find_real_or_ghost_entity_from_prototype = find_real_or_ghost_entity_from_prototype,
  get_ghost_id = get_ghost_id,
  get_id = get_id,
  get_or_create_id = get_or_create_id,
  remove_id = remove_id,
  destroy_entity_safe = destroy_entity_safe,
  get_cursor_item_prototype = get_cursor_item_prototype,
  get_cursor_item_place_result = get_cursor_item_place_result,
  get_offset_from_inserter = get_offset_from_inserter,
  get_current_grid_left_top = get_current_grid_left_top,
  get_current_grid_center_position = get_current_grid_center_position,
  get_tiles = get_tiles,
  get_lines = get_lines,
  get_direction_arrows_indicator_lines = get_direction_arrows_indicator_lines,
  get_tiles_background_vertices = get_tiles_background_vertices,
  get_snapped_pickup_position = get_snapped_pickup_position,
  mirror_position = mirror_position,
  snap_position_to_tile_center_relative_to_inserter = snap_position_to_tile_center_relative_to_inserter,
  get_redirected_selected_entity = get_redirected_selected_entity,
  get_pickup_box = get_pickup_box,
  rectangle_positions_equal = rectangle_positions_equal,
  show_error = show_error,
  should_be_rotatable = should_be_rotatable,
  can_reach_entity = can_reach_entity,
  try_override_can_reach_entity = try_override_can_reach_entity,
  can_only_select_single_drop_tile = can_only_select_single_drop_tile,
  get_single_drop_tile = get_single_drop_tile,
  should_use_auto_drop_offset = should_use_auto_drop_offset,
  should_skip_selecting_pickup = should_skip_selecting_pickup,
  should_skip_selecting_drop = should_skip_selecting_drop,
  calculate_visualized_drop_position = calculate_visualized_drop_position,
  calculate_visualized_default_drop_position = calculate_visualized_default_drop_position,
  calculate_actual_drop_position = calculate_actual_drop_position,
  get_drop_box = get_drop_box,
  snap_build_position = snap_build_position,
  is_within_build_range = is_within_build_range,
  is_selectable_for_player = is_selectable_for_player,
}
return utils
