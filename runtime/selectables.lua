
local vec = require("__inserter-throughput-lib__.vector")
local consts = require("__quick-adjustable-inserters__.runtime.consts")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

---@param entities uint32[]
local function destroy_entities(entities)
  local selectable_entities_to_player_lut = storage.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = storage.selectable_entities_by_unit_number
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

---@param player PlayerDataQAI
local function destroy_dummy_pickup_square(player)
  local entity = player.dummy_pickup_square
  if not entity then return end
  storage.selectable_dummy_redirects[player.dummy_pickup_square_unit_number] = nil
  player.dummy_pickup_square = nil
  player.dummy_pickup_square_unit_number = nil
  utils.destroy_entity_safe(entity)
end

---@param player PlayerDataQAI
---@param single_drop_tile MapPosition
local function place_dummy_square_at_pickup(player, single_drop_tile)
  local drop_tile_position = vec.add(utils.get_current_grid_left_top(player), single_drop_tile)
  local pickup_position = utils.get_snapped_pickup_position(player)
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
  storage.selectable_dummy_redirects[player.dummy_pickup_square_unit_number] = player.target_inserter
end

---@param player PlayerDataQAI
---@param specific_tiles MapPosition[]? @ Relative to grid left top.
local function place_squares(player, specific_tiles)
  local left_top = utils.get_current_grid_left_top(player)
  local left, top = left_top.x, left_top.y -- Micro optimization.
  local selectable_entities_to_player_lut = storage.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = storage.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = consts.square_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  for i, tile in ipairs(specific_tiles or utils.get_tiles(player)) do
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
  local left_top = utils.get_current_grid_left_top(player)
  local left, top = left_top.x, left_top.y -- Micro optimization.
  local selectable_entities_to_player_lut = storage.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = storage.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = consts.ninth_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  local count = 0
  for _, tile in ipairs(specific_tiles or utils.get_tiles(player)) do
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

---@param player PlayerDataQAI
local function place_rects(player)
  if not player.is_rotatable then return end
  local cache = player.target_inserter_cache
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = cache.offset_from_inserter
  local selectable_entities_to_player_lut = storage.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = storage.selectable_entities_by_unit_number
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
    utils.flip(player, position)
    position.x = position.x + inserter_position.x
    position.y = position.y + inserter_position.y
    arg.direction = player.should_flip and consts.flip_direction_lut[dir_arrow.direction] or dir_arrow.direction
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

---@class SelectablesFileQAI
local selectables = {
  destroy_entities = destroy_entities,
  destroy_dummy_pickup_square = destroy_dummy_pickup_square,
  place_dummy_square_at_pickup = place_dummy_square_at_pickup,
  place_squares = place_squares,
  place_ninths = place_ninths,
  place_rects = place_rects,
}
return selectables
