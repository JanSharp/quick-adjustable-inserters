
---cSpell:ignore rects

---@class GlobalDataQAI
---@field players table<int, PlayerDataQAI>
---@field forces table<uint8, ForceDataQAI>
---@field inserters_in_use table<uint32, PlayerDataQAI> @ Indexed by inserter unit_number.
---@field active_players PlayerDataQAI[]|{count: integer, next_index: integer}
---@field pooled_entities_to_player_lut table<uint32, PlayerDataQAI> @ pooled entity unit number => player index.
---@field square_pool EntityPoolQAI
---@field ninth_pool EntityPoolQAI
---@field rect_pool EntityPoolQAI
global = {}

---@class ForceDataQAI
---@field force_index uint32
---@field force LuaForce
---@field inserter_cache_lut table<string, InserterCacheQAI>
---@field tech_level TechnologyLevelQAI

---@class EntityPoolQAI
---@field entity_name string
---@field surface_pools table<uint, EntityPoolSurfaceQAI> @ surface_index => surface pool.

---@class EntityPoolSurfaceQAI
---@field free_count int
---@field used_count int
---@field free_entities table<uint, LuaEntity> @ unit_number => entity.
---@field used_entities table<uint, LuaEntity> @ unit_number => entity.

---@class LineDefinitionQAI
---@field from MapPosition
---@field to MapPosition

---@class DirectionArrowDefinitionQAI
---@field position MapPosition
---@field direction defines.direction

---@class InserterCacheQAI
---@field prototype LuaEntityPrototype
---@field tech_level TechnologyLevelQAI
---Defines how to calculate the left top position of the grid when given an inserter entity. By adding
---this value to the inserter's position, the left top position - the grid origin - has been found. All
---other positions in this definition are then relative to this calculated position.\
---For inserters placable off grid, the tiles, lines and simply everything from this mod will also be off
---grid.
---@field is_square boolean @ When false, `vertical_offset_from_inserter ~= horizontal_offset_from_inserter`.
---@field base_range integer
---@field range_gap_from_center integer
---@field offset_from_inserter MapPosition @ For north and south. For east and west, flip x and y.
---@field tile_width integer
---@field tile_height integer
---@field tiles MapPosition[]
---@field lines LineDefinitionQAI[]
---@field direction_arrows DirectionArrowDefinitionQAI[] @ Always 4.
---@field direction_arrow_position MapPosition
---@field direction_arrow_vertices ScriptRenderVertexTarget[]

---@class TechnologyLevelQAI
---@field range integer
---@field drop_offset boolean
---@field perpendicular boolean @ Meaning horizontal and vertical. Couldn't find a better term.
---@field diagonal boolean
---@field all_tiles boolean @ When true, `perpendicular` and `diagonal` are implied to also be true.

---@alias PlayerStateQAI
---| "idle"
---| "selecting-pickup"
---| "selecting-drop"

---@class PlayerDataQAI
---@field player LuaPlayer
---@field player_index uint
---@field force_index uint8
---@field force LuaForce
---@field state PlayerStateQAI
---@field index_in_active_players integer @ `nil` when idle.
---`nil` when idle. Must be stored, because we can switch to idle _after_ an entity has been invalidated.
---@field target_inserter_unit_number uint32
---@field target_inserter LuaEntity @ `nil` when idle.
---@field target_inserter_cache InserterCacheQAI @ `nil` when idle.
---@field target_inserter_position MapPosition @ `nil` when idle.
---@field target_inserter_direction defines.direction @ `nil` when idle.
---@field target_inserter_force_index uint32 @ `nil` when idle.
---`nil` when idle.\
---`true` for non square inserters facing west or east.
---Those end up pretending to be north and south, but flipped diagonally.
---@field should_flip boolean
---@field current_surface_index uint @  `nil` when idle.
---@field used_squares uint[]
---@field used_ninths uint[]
---@field used_rects uint[]
---@field line_ids uint64[]
---@field background_ids uint64[]
---@field inserter_circle_id uint64 @ `nil` when idle.
---@field direction_arrow_id uint64 @ `nil` when idle.
---@field pickup_highlight LuaEntity? @ Can be `nil` even when not idle.

local ev = defines.events
local square_entity_name = "QAI-selectable-square"
local ninth_entity_name = "QAI-selectable-ninth"
local rect_entity_name = "QAI-selectable-rect"

local entity_name_lut = {
  [square_entity_name] = true,
  [ninth_entity_name] = true,
  [rect_entity_name] = true,
}

local techs_we_care_about = {
  ["long-inserters-1"] = true,
  ["long-inserters-2"] = true,
  ["near-inserters"] = true,
  ["more-inserters-1"] = true,
  ["more-inserters-2"] = true,
}

local inverse_direction_lut = {
  [defines.direction.north] = defines.direction.south,
  [defines.direction.east] = defines.direction.west,
  [defines.direction.south] = defines.direction.north,
  [defines.direction.west] = defines.direction.east,
}

---@param event EventData|{player_index: uint}
---@return PlayerDataQAI?
local function get_player(event)
  return global.players[event.player_index]
end

---@param entity_name string
---@return EntityPoolQAI
local function new_entity_pool(entity_name)
  ---@type EntityPoolQAI
  local result = {
    entity_name = entity_name,
    surface_pools = {},
  }
  return result
end

---@param entity_pool EntityPoolQAI
---@param surface_index uint
local function get_surface_pool(entity_pool, surface_index)
  local surface_pool = entity_pool.surface_pools[surface_index]
  if surface_pool then
    return surface_pool
  end
  ---@type EntityPoolSurfaceQAI
  surface_pool = {
    free_count = 0,
    used_count = 0,
    free_entities = {},
    used_entities = {},
  }
  entity_pool.surface_pools[surface_index] = surface_pool
  return surface_pool
end

---@param player PlayerDataQAI
---@param pos MapPosition
---@param do_copy boolean?
---@return MapPosition
local function flip(player, pos, do_copy)
  if player.should_flip then
    if do_copy then
      pos = {x = pos.y, y = pos.x}
    else
      pos.x, pos.y = pos.y, pos.x
    end
  end
  return pos
end

---@param cache InserterCacheQAI
local function calculate_cached_base_reach(cache)
  local tile_width = cache.tile_width
  local tile_height = cache.tile_height
  local pickup_position = cache.prototype.inserter_pickup_position ---@cast pickup_position -nil
  local drop_position = cache.prototype.inserter_drop_position ---@cast drop_position -nil
  cache.base_range = math.ceil(math.max(
    math.abs(pickup_position[1]) - (tile_width / 2),
    math.abs(pickup_position[2]) - (tile_height / 2),
    math.abs(drop_position[1]) - (tile_width / 2),
    math.abs(drop_position[2]) - (tile_height / 2)
  ))
  cache.range_gap_from_center = math.max(0, cache.base_range - cache.tech_level.range)
end

---@param cache InserterCacheQAI
local function generate_tiles_cache(cache)
  -- Positions are integers, top left is 0, 0.
  local tile_width = cache.tile_width
  local tile_height = cache.tile_height
  local gap = cache.range_gap_from_center
  local tech_level = cache.tech_level
  local max_range = tech_level.range + gap
  local grid_width = tile_width + max_range * 2
  local grid_height = tile_height + max_range * 2
  local tiles = cache.tiles

  if tech_level.all_tiles then
    for y = 1, grid_height do
      for x = 1, grid_width do
        if not (tech_level.range < x and x <= tech_level.range + tile_width + gap * 2
          and tech_level.range < y and y <= tech_level.range + tile_height + gap * 2)
        then
          tiles[#tiles+1] = {x = x - 1, y = y - 1}
        end
      end
    end
    return
  end

  assert(tech_level.perpendicular or tech_level.diagonal, "Having both perpendicular and diagonal be \z
    disabled means there nowhere for an inserter to pickup from or drop to, which makes no sense."
  )

  if tech_level.perpendicular then
    for y = max_range + 1, max_range + tile_height do
      for x = 1, tech_level.range * 2 do
        if x > tech_level.range then
          x = x + tile_width + gap * 2
        end
        tiles[#tiles+1] = {x = x - 1, y = y - 1}
      end
    end
    for x = max_range + 1, max_range + tile_width do
      for y = 1, tech_level.range * 2 do
        if y > tech_level.range then
          y = y + tile_height + gap * 2
        end
        tiles[#tiles+1] = {x = x - 1, y = y - 1}
      end
    end
  end

  if tech_level.diagonal then
    for i = 1, tech_level.range * 2 do
      tiles[#tiles+1] = {
        x = (i > tech_level.range and (i + tile_width + gap * 2) or i) - 1,
        y = (i > tech_level.range and (i + tile_height + gap * 2) or i) - 1,
      }
      local x = tech_level.range * 2 - i + 1
      tiles[#tiles+1] = {
        x = (x > tech_level.range and (x + tile_width + gap * 2) or x) - 1,
        y = (i > tech_level.range and (i + tile_height + gap * 2) or i) - 1,
      }
    end
  end
end

---@param cache InserterCacheQAI
local function generate_lines_cache(cache)
  local lines = cache.lines

  -- The final lines are represented as points in these grids.
  -- 0, 0 in horizontal_grid is the line going from the top left corner 1 tile to the right.
  -- 0, 0 in vertical_grid is the line going from the top left corner 1 tile downwards.
  local horizontal_grid = {}
  local vertical_grid = {}
  local function get_point(x, y)
    return x * 2^16 + y
  end
  local function get_xy(point)
    -- Not using bit32 because math is faster than those function calls.
    local y = point % 2^16 -- Basically bitwise AND on lower 16 bits.
    return (point - y) / 2^16, y -- Basically right shift by 16 for x.
  end
  for _, tile in pairs(cache.tiles) do
    horizontal_grid[get_point(tile.x, tile.y)] = true
    horizontal_grid[get_point(tile.x, tile.y + 1)] = true
    vertical_grid[get_point(tile.x, tile.y)] = true
    vertical_grid[get_point(tile.x + 1, tile.y)] = true
  end

  ---@return boolean @ Returns true if the point existed.
  local function check_and_remove_point(grid, point)
    local exists = grid[point]
    grid[point] = nil
    return exists
  end

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
    lines[#lines+1] = {
      from = {x = from_x, y = y},
      to = {x = to_x + 1, y = y},
    }
  end

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
    lines[#lines+1] = {
      from = {x = x, y = from_y},
      to = {x = x, y = to_y + 1},
    }
  end
end

---@param cache InserterCacheQAI
local function generate_direction_arrow_cache(cache)
  local tile_width = cache.tile_width
  local tile_height = cache.tile_height
  local max_range = cache.tech_level.range + cache.range_gap_from_center
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
    {
      direction = defines.direction.west,
      position = {
        x = -1,
        y = max_range + tile_height / 2,
      },
    },
    {
      direction = defines.direction.east,
      position = {
        x = max_range * 2 + tile_width + 1,
        y = max_range + tile_height / 2,
      },
    },
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

---Centers the collision box both horizontally and vertically, by taking the distance from the center and
---making both left and right have the same - higher - distance. Same goes for top and bottom.
---@param col_box BoundingBox
local function normalize_collision_box(col_box)
  local x_distance = math.max(-col_box.left_top.x, col_box.right_bottom.x)
  local y_distance = math.max(-col_box.left_top.y, col_box.right_bottom.y)
  col_box.left_top.x = -x_distance
  col_box.left_top.y = -y_distance
  col_box.right_bottom.x = x_distance
  col_box.right_bottom.y = y_distance
end

---@param inserter LuaEntityPrototype
---@param tech_level TechnologyLevelQAI
---@return InserterCacheQAI
local function generate_cache_for_inserter(inserter, tech_level)
  local range = tech_level.range
  local col_box = inserter.collision_box
  normalize_collision_box(col_box)

  -- These do not match the values from the prototype, because it seems that changing the pickup and drop
  -- positions does not care about being inside of the tile width/height of the inserter itself. It even
  -- allows them being inside of the collision box of the inserter itself.
  -- However, I do not wish to put the pickup or drop position inside of the collision box and the tiles said
  -- box is touching, therefore the width and height is evaluated manually, with snapping in mind.
  local tile_width
  local tile_height
  local offset_from_inserter
  if inserter.flags["placeable-off-grid"] then
    local col_width = col_box.right_bottom.x - col_box.left_top.x
    local col_height = col_box.right_bottom.y - col_box.left_top.y
    tile_width = math.ceil(col_width)
    tile_height = math.ceil(col_height)
    offset_from_inserter = {
      x = col_box.left_top.x - ((tile_width - col_width) / 2) - range,
      y = col_box.left_top.y - ((tile_height - col_height) / 2) - range,
    }
  else
    local odd_width = (inserter.tile_width % 2) == 1
    local odd_height = (inserter.tile_height % 2) == 1
    local shifted_left_top = {
      x = col_box.left_top.x + (odd_width and 0.5 or 0),
      y = col_box.left_top.y + (odd_height and 0.5 or 0),
    }
    local snapped_left_top = {
      x = math.floor(shifted_left_top.x),
      y = math.floor(shifted_left_top.y),
    }
    local snapped_right_bottom = {
      x = math.ceil(col_box.right_bottom.x + (odd_width and 0.5 or 0)),
      y = math.ceil(col_box.right_bottom.y + (odd_height and 0.5 or 0)),
    }
    tile_width = snapped_right_bottom.x - snapped_left_top.x
    tile_height = snapped_right_bottom.y - snapped_left_top.y
    offset_from_inserter = {
      x = col_box.left_top.x - (shifted_left_top.x - snapped_left_top.x) - range,
      y = col_box.left_top.y - (shifted_left_top.y - snapped_left_top.y) - range,
    }
  end

  ---@type InserterCacheQAI
  local cache = {
    prototype = inserter,
    tech_level = tech_level,
    is_square = tile_width == tile_height,
    offset_from_inserter = offset_from_inserter,
    tile_width = tile_width,
    tile_height = tile_height,
    tiles = {},
    lines = {},
    direction_arrows = {},
    direction_arrow_vertices = {},
  }
  calculate_cached_base_reach(cache)
  offset_from_inserter.x = offset_from_inserter.x - cache.range_gap_from_center
  offset_from_inserter.y = offset_from_inserter.y - cache.range_gap_from_center
  generate_tiles_cache(cache)
  generate_lines_cache(cache)
  generate_direction_arrow_cache(cache)
  return cache
end

---@param entity_pool EntityPoolQAI
---@param surface LuaSurface
---@param position MapPosition
---@param player PlayerDataQAI @ Only this player should be able to interact with this pooled entity.
---@return uint unit_number
---@return LuaEntity
local function place_pooled_entity(entity_pool, surface, position, player)
  local surface_pool = get_surface_pool(entity_pool, surface.index)

  if surface_pool.free_count ~= 0 then
    surface_pool.free_count = surface_pool.free_count - 1
    local unit_number, entity = next(surface_pool.free_entities)
    if not entity.valid then
      surface_pool.free_entities[unit_number] = nil
    else
      surface_pool.used_count = surface_pool.used_count + 1
      surface_pool.free_entities[unit_number] = nil
      surface_pool.used_entities[unit_number] = entity
      entity.teleport(position)
      entity.force = player.force_index
      global.pooled_entities_to_player_lut[unit_number] = player
      return unit_number, entity
    end
  end

  local entity = surface.create_entity{
    name = entity_pool.entity_name,
    position = position,
    force = player.force_index,
  }
  if not entity then
    error("Creating an internal entity required by Quick Adjustable Inserters failed.")
  end
  entity.destructible = false
  local unit_number = entity.unit_number ---@cast unit_number -nil
  surface_pool.used_count = surface_pool.used_count + 1
  surface_pool.used_entities[unit_number] = entity
  global.pooled_entities_to_player_lut[unit_number] = player
  return unit_number, entity
end

---@param entity_pool EntityPoolQAI
---@param surface_index uint
---@param unit_number uint
local function remove_pooled_entity(entity_pool, surface_index, unit_number)
  local surface_pool = entity_pool.surface_pools[surface_index]
  global.pooled_entities_to_player_lut[unit_number] = nil
  if not surface_pool then return end -- Surface has been deleted already, nothing to do.
  surface_pool.used_count = surface_pool.used_count - 1
  local entity = surface_pool.used_entities[unit_number]
  surface_pool.used_entities[unit_number] = nil
  if not entity then return end
  surface_pool.free_count = surface_pool.free_count + 1
  surface_pool.free_entities[unit_number] = entity
  entity.teleport{x = 0, y = 0}
  entity.force = "neutral"
end

---Call this after a surface has been deleted.
---@param entity_pool EntityPoolQAI
---@param surface_index uint
local function cleanup_deleted_surface_pool(entity_pool, surface_index)
  local surface_pool = entity_pool.surface_pools[surface_index]
  if not surface_pool then return end
  for unit_number in pairs(surface_pool.used_entities) do
    global.pooled_entities_to_player_lut[unit_number] = nil
  end
  entity_pool.surface_pools[surface_index] = nil
end

---@param entity_pool EntityPoolQAI
---@param surface_index uint
---@param used_unit_numbers uint[]
local function remove_used_pooled_entities(entity_pool, surface_index, used_unit_numbers)
  for i = 1, #used_unit_numbers do
    remove_pooled_entity(entity_pool, surface_index, used_unit_numbers[i])
    used_unit_numbers[i] = nil
  end
end

---@param ids uint64[]
local function destroy_rendering_ids(ids)
  for _, id in pairs(ids) do
    rendering.destroy(id)
  end
end

---@param player PlayerDataQAI
local function destroy_pickup_highlight(player)
  if player.pickup_highlight then
    player.pickup_highlight.destroy()
  end
end

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
local function switch_to_idle(player)
  if player.state == "idle" then return end
  local surface_index = player.current_surface_index
  player.current_surface_index = nil
  remove_used_pooled_entities(global.square_pool, surface_index, player.used_squares)
  remove_used_pooled_entities(global.ninth_pool, surface_index, player.used_ninths)
  -- TODO: keep rects, arrow and grid when switching between pickup/drop states
  remove_used_pooled_entities(global.rect_pool, surface_index, player.used_rects)
  destroy_rendering_ids(player.line_ids)
  destroy_rendering_ids(player.background_ids)
  rendering.destroy(player.inserter_circle_id)
  rendering.destroy(player.direction_arrow_id)
  player.inserter_circle_id = nil
  player.direction_arrow_id = nil
  destroy_pickup_highlight(player)
  global.inserters_in_use[player.target_inserter_unit_number] = nil
  remove_active_player(player)
  player.target_inserter_unit_number = nil
  player.target_inserter = nil
  player.target_inserter_cache = nil
  player.target_inserter_position = nil
  player.target_inserter_direction = nil
  player.target_inserter_force_index = nil
  player.should_flip = nil
  player.state = "idle"
  if player.player.selected and entity_name_lut[player.player.selected.name] then
    player.player.selected = nil
  end
end

---@param player PlayerDataQAI
local function place_squares(player)
  local surface = player.target_inserter.surface
  local inserter_position = player.target_inserter.position
  local offset_from_inserter = player.target_inserter_cache.offset_from_inserter
  local position = {}
  for _, tile in pairs(player.target_inserter_cache.tiles) do
    position.x = offset_from_inserter.x + tile.x + 0.5
    position.y = offset_from_inserter.y + tile.y + 0.5
    flip(player, position)
    position.x = position.x + inserter_position.x
    position.y = position.y + inserter_position.y
    local unit_number = place_pooled_entity(global.square_pool, surface, position, player)
    player.used_squares[#player.used_squares+1] = unit_number
  end
end

---@param player PlayerDataQAI
local function place_ninths(player)
  local surface = player.target_inserter.surface
  local inserter_position = player.target_inserter.position
  local offset_from_inserter = player.target_inserter_cache.offset_from_inserter
  local position = {}
  for _, tile in pairs(player.target_inserter_cache.tiles) do
    for inner_x = 0, 2 do
      for inner_y = 0, 2 do
        position.x = offset_from_inserter.x + tile.x + inner_x / 3 + 1 / 6
        position.y = offset_from_inserter.y + tile.y + inner_y / 3 + 1 / 6
        flip(player, position)
        position.x = position.x + inserter_position.x
        position.y = position.y + inserter_position.y
        local unit_number = place_pooled_entity(global.ninth_pool, surface, position, player)
        player.used_ninths[#player.used_ninths+1] = unit_number
      end
    end
  end
end

---@param player PlayerDataQAI
local function draw_direction_arrow(player)
  local inserter = player.target_inserter
  local inserter_position = inserter.position
  local cache = player.target_inserter_cache
  inserter_position.x = inserter_position.x + cache.offset_from_inserter.x + cache.direction_arrow_position.x
  inserter_position.y = inserter_position.y + cache.offset_from_inserter.y + cache.direction_arrow_position.y
  local opacity = 0.6
  player.direction_arrow_id = rendering.draw_polygon{
    surface = inserter.surface,
    forces = {player.force_index},
    color = {opacity, opacity, opacity, opacity},
    vertices = player.target_inserter_cache.direction_arrow_vertices,
    orientation = inserter.orientation,
    target = inserter_position,
  }
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
  local cache = player.target_inserter_cache
  local surface = player.target_inserter.surface
  local inserter_position = player.target_inserter.position
  local offset_from_inserter = cache.offset_from_inserter
  local position = {}
  for _, dir_arrow in pairs(cache.direction_arrows) do
    if not cache.is_square and is_east_or_west_lut[dir_arrow.direction] then goto continue end
    position.x = offset_from_inserter.x + dir_arrow.position.x
    position.y = offset_from_inserter.y + dir_arrow.position.y
    flip(player, position)
    position.x = position.x + inserter_position.x
    position.y = position.y + inserter_position.y
    local unit_number, entity = place_pooled_entity(global.rect_pool, surface, position, player)
    entity.direction = player.should_flip and flip_direction_lut[dir_arrow.direction] or dir_arrow.direction
    player.used_rects[#player.used_rects+1] = unit_number
    ::continue::
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
  inserter.direction = inverse_direction_lut[new_direction]
  inserter.pickup_position = pickup_position
  inserter.drop_position = drop_position
end

---@param player PlayerDataQAI
---@param new_direction defines.direction @
---If you look at the feet of the inserter, the forwards pointing feet should be the direction this variable
---is defining.
local function set_direction_and_update_arrow(player, new_direction)
  set_direction(player, new_direction)
  update_direction_arrow(player)
end

---@param player PlayerDataQAI
local function draw_circle_on_inserter(player)
  local cache = player.target_inserter_cache
  local offset_from_inserter = cache.offset_from_inserter

  local max_range = cache.tech_level.range + cache.range_gap_from_center
  player.inserter_circle_id = rendering.draw_circle{
    surface = player.target_inserter.surface,
    forces = {player.force_index},
    color = {1, 1, 1},
    radius = math.min(cache.tile_width, cache.tile_height) / 2 - 0.25,
    width = 2,
    target = player.target_inserter,
    target_offset = {
      x = offset_from_inserter.x + max_range + cache.tile_width / 2,
      y = offset_from_inserter.y + max_range + cache.tile_height / 2,
    },
  }
end

---@param player PlayerDataQAI
local function draw_grid_lines(player)
  local cache = player.target_inserter_cache
  local offset_from_inserter = cache.offset_from_inserter

  local from = {}
  local to = {}
  ---@type LuaRendering.draw_line_param
  local line_param = {
    surface = player.target_inserter.surface,
    forces = {player.force_index},
    color = {1, 1, 1},
    width = 1,
    from = player.target_inserter,
    from_offset = from,
    to = player.target_inserter,
    to_offset = to,
  }

  for _, line in pairs(cache.lines) do
    from.x = offset_from_inserter.x + line.from.x
    from.y = offset_from_inserter.y + line.from.y
    to.x = offset_from_inserter.x + line.to.x
    to.y = offset_from_inserter.y + line.to.y
    flip(player, from)
    flip(player, to)
    player.line_ids[#player.line_ids+1] = rendering.draw_line(line_param)
  end
end

---@param player PlayerDataQAI
local function draw_grid_background(player)
  local cache = player.target_inserter_cache
  local offset_from_inserter = cache.offset_from_inserter

  local left_top = {}
  local right_bottom = {}
  local opacity = 0.2
  ---@type LuaRendering.draw_rectangle_param
  local rectangle_param = {
    surface = player.target_inserter.surface,
    forces = {player.force_index},
    color = {opacity, opacity, opacity, opacity},
    filled = true,
    left_top = player.target_inserter,
    left_top_offset = left_top,
    right_bottom = player.target_inserter,
    right_bottom_offset = right_bottom,
  }

  for _, tile in pairs(cache.tiles) do
    left_top.x = offset_from_inserter.x + tile.x
    left_top.y = offset_from_inserter.y + tile.y
    right_bottom.x = offset_from_inserter.x + tile.x + 1
    right_bottom.y = offset_from_inserter.y + tile.y + 1
    flip(player, left_top)
    flip(player, right_bottom)
    player.background_ids[#player.background_ids+1] = rendering.draw_rectangle(rectangle_param)
  end
end

---@param player PlayerDataQAI
local function draw_all_rendering_objects(player)
  draw_direction_arrow(player)
  draw_circle_on_inserter(player)
  draw_grid_lines(player)
  draw_grid_background(player)
end

---@param player PlayerDataQAI
local function create_pickup_highlight(player)
  local inserter = player.target_inserter
  local pickup_pos = inserter.pickup_position
  local surface = inserter.surface
  player.pickup_highlight = surface.create_entity{
    name = "highlight-box",
    position = {x = 0, y = 0},
    bounding_box = {
      left_top = {x = pickup_pos.x - 0.5, y = pickup_pos.y - 0.5},
      right_bottom = {x = pickup_pos.x + 0.5, y = pickup_pos.y + 0.5},
    },
    box_type = "copy",
    render_player_index = player.player_index,
  }
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param message LocalisedString
---@return false
local function show_error(player, target_inserter, message)
  target_inserter.surface.create_entity{
    name = "flying-text",
    text = message,
    position = target_inserter.position,
    render_player_index = player.player_index,
  }
  player.player.play_sound{path = "utility/cannot_build"}
  return false
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---It should only perform reach checks when the player is selecting a new inserter. Any other state switching
---should not care about being out of reach. Going out of reach while adjusting an inserter is handled in the
---player position changed event, which is raised for each tile the player moves.
---@param do_check_reach boolean?
---@return boolean
local function try_set_target_inserter(player, target_inserter, do_check_reach)
  local force = global.forces[player.force_index]
  if not force or not player.force.valid then return false end

  local cache = force.inserter_cache_lut[target_inserter.name]
  if not cache then
    return show_error(player, target_inserter, {"qai.cant-change-inserter-at-runtime"})
  end

  -- Specifically check if the force of the inserter is friends with the player. Friendship is one directional.
  if not target_inserter.force.is_friend(player.force_index) then
    return show_error(player, target_inserter, {"cant-rotate-enemy-structures"})
  end

  if do_check_reach and not player.player.can_reach_entity(target_inserter) then
    return show_error(player, target_inserter, {"cant-reach"})
  end

  local unit_number = target_inserter.unit_number ---@cast unit_number -nil
  if global.inserters_in_use[unit_number] then
    return show_error(player, target_inserter, {"qai.only-one-player-can-adjust"})
  end

  global.inserters_in_use[unit_number] = player
  add_active_player(player)
  player.target_inserter_unit_number = unit_number
  player.target_inserter = target_inserter
  player.target_inserter_cache = cache
  player.target_inserter_position = target_inserter.position
  player.target_inserter_direction = target_inserter.direction
  player.target_inserter_force_index = target_inserter.force_index
  player.should_flip = not player.target_inserter_cache.is_square
    and is_east_or_west_lut[target_inserter.direction]
  player.current_surface_index = target_inserter.surface_index
  return true
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function switch_to_selecting_pickup(player, target_inserter, do_check_reach)
  if player.state == "selecting-pickup" and player.target_inserter == target_inserter then return end
  if player.state ~= "idle" then
    switch_to_idle(player)
  end
  if not try_set_target_inserter(player, target_inserter, do_check_reach) then return end
  place_squares(player)
  place_rects(player)
  draw_all_rendering_objects(player)
  player.state = "selecting-pickup"
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function switch_to_selecting_drop(player, target_inserter, do_check_reach)
  if player.state == "selecting-drop" and player.target_inserter == target_inserter then return end
  if player.state ~= "idle" then
    switch_to_idle(player)
  end
  if not try_set_target_inserter(player, target_inserter, do_check_reach) then return end
  if player.target_inserter_cache.tech_level.drop_offset then
    place_ninths(player)
  else
    place_squares(player)
  end
  place_rects(player)
  draw_all_rendering_objects(player)
  create_pickup_highlight(player)
  player.state = "selecting-drop"
end

---@param player PlayerDataQAI
---@param do_check_reach boolean?
local function switch_to_idle_and_back(player, do_check_reach)
  if player.state == "idle" then return end
  local target_inserter = player.target_inserter
  local selecting_pickup = player.state == "selecting-pickup"
  switch_to_idle(player)
  if selecting_pickup then
    switch_to_selecting_pickup(player, target_inserter, do_check_reach)
  else
    switch_to_selecting_drop(player, target_inserter, do_check_reach)
  end
end

---@param player PlayerDataQAI
---@return boolean
local function validate_target_inserter(player)
  local is_valid = player.target_inserter.valid
  if not is_valid then
    switch_to_idle(player)
  end
  return is_valid
end

---@param player PlayerDataQAI
---@param position MapPosition
local function set_drop_position(player, position)
  local cache = player.target_inserter_cache
  local tech_level = cache.tech_level
  local auto_determine_drop_offset = not tech_level.drop_offset
  local inserter_position = player.target_inserter.position
  local offset_from_inserter = cache.offset_from_inserter
  local left_top_x = inserter_position.x + offset_from_inserter.x
  local left_top_y = inserter_position.y + offset_from_inserter.y
  local relative_x = position.x - left_top_x
  local relative_y = position.y - left_top_y
  local x_offset
  local y_offset
  if auto_determine_drop_offset then
    local max_range = tech_level.range + cache.range_gap_from_center
    x_offset = relative_x < max_range and -51/256
      or (max_range + cache.tile_width) < relative_x and 51/256
      or 0
    y_offset = relative_y < max_range and -51/256
      or (max_range + cache.tile_height) < relative_y and 51/256
      or 0
  else
    -- Modulo always returns a positive number.
    local x_from_tile_center = (relative_x % 1) - 0.5
    local y_from_tile_center = (relative_y % 1) - 0.5
    -- 51 / 256 = 0.19921875. Vanilla inserter drop positions are offset by 0.2 away from the center, however
    -- it ultimately gets rounded to 51 / 256, because of map positions. In other words, this matches vanilla.
    x_offset = x_from_tile_center == 0 and 0
      or x_from_tile_center < 0 and -51/256
      or 51/256
    y_offset = y_from_tile_center == 0 and 0
      or y_from_tile_center < 0 and -51/256
      or 51/256
  end
  player.target_inserter.drop_position = {
    x = left_top_x + math.floor(relative_x) + 0.5 + x_offset,
    y = left_top_y + math.floor(relative_y) + 0.5 + y_offset,
  }
end

---@param entity LuaEntity
---@param selectable_name string
---@param player PlayerDataQAI
---@return boolean
local function is_selectable_for_player(entity, selectable_name, player)
  return entity.name == selectable_name
    and global.pooled_entities_to_player_lut[entity.unit_number] == player
end

---@type table<string, fun(player: PlayerDataQAI, selected: LuaEntity)>
local on_adjust_handler_lut = {
  ["idle"] = function(player, selected)
    if selected.type ~= "inserter" then return end
    switch_to_selecting_pickup(player, selected, true)
  end,

  ["selecting-pickup"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if selected.type == "inserter" then
      if selected == player.target_inserter then
        switch_to_selecting_drop(player, selected)
      else
        switch_to_selecting_pickup(player, selected, true)
      end
      return
    end
    if is_selectable_for_player(selected, square_entity_name, player) then
      player.target_inserter.pickup_position = selected.position
      switch_to_selecting_drop(player, player.target_inserter)
      return
    end
    if is_selectable_for_player(selected, rect_entity_name, player) then
      set_direction_and_update_arrow(player, selected.direction)
      return
    end
    switch_to_idle(player)
  end,

  ["selecting-drop"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if selected.type == "inserter" then
      if selected == player.target_inserter then
        switch_to_idle(player)
      else
        switch_to_selecting_pickup(player, selected, true)
      end
      return
    end
    if is_selectable_for_player(selected, square_entity_name, player)
      or is_selectable_for_player(selected, ninth_entity_name, player)
    then
      set_drop_position(player, selected.position)
      switch_to_idle(player)
      return
    end
    if is_selectable_for_player(selected, rect_entity_name, player) then
      set_direction_and_update_arrow(player, selected.direction)
      return
    end
    switch_to_idle(player)
  end,
}

---@param force ForceDataQAI
local function update_inserter_cache(force)
  force.inserter_cache_lut = {}
  for _, inserter in pairs(game.get_filtered_entity_prototypes{{filter = "type", type = "inserter"}}) do
    if inserter.allow_custom_vectors then
      force.inserter_cache_lut[inserter.name] = generate_cache_for_inserter(inserter, force.tech_level)
    end
  end
  for _, player in pairs(force.force.players) do
    local player_data = global.players[player.index]
    if player_data then
      switch_to_idle_and_back(player_data)
    end
  end
end

---@param force ForceDataQAI
local function update_tech_level_for_force(force)
  local tech_level = force.tech_level
  local techs = force.force.technologies
  local long_inserters_1 = techs["long-inserters-1"]
  local long_inserters_2 = techs["long-inserters-2"]
  local near_inserters = techs["near-inserters"]
  local more_inserters_1 = techs["more-inserters-1"]
  local more_inserters_2 = techs["more-inserters-2"]
  tech_level.range = long_inserters_2 and long_inserters_2.researched and 3
    or long_inserters_1 and long_inserters_1.researched and 2
    or 1
  tech_level.drop_offset = near_inserters and near_inserters.researched or false
  tech_level.perpendicular = true
  tech_level.all_tiles = more_inserters_2 and more_inserters_2.researched or false
  tech_level.diagonal = tech_level.all_tiles or more_inserters_1 and more_inserters_1.researched or false
  update_inserter_cache(force)
end

---@param force LuaForce
---@return ForceDataQAI
local function init_force(force)
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

---@param player LuaPlayer
---@return PlayerDataQAI
local function init_player(player)
  ---@type PlayerDataQAI
  local player_data = {
    player = player,
    player_index = player.index,
    force_index = player.force_index--[[@as uint8]],
    force = player.force--[[@as LuaForce]],
    state = "idle",
    used_squares = {},
    used_ninths = {},
    used_rects = {},
    line_ids = {},
    background_ids = {},
  }
  global.players[player.index] = player_data
  return player_data
end

---@param player PlayerDataQAI
local function update_active_player(player)
  local inserter = player.target_inserter
  if not inserter.valid then
    switch_to_idle(player)
    return
  end
  local position = inserter.position
  local prev_position = player.target_inserter_position
  if inserter.direction ~= player.target_inserter_direction
    or inserter.force_index ~= player.target_inserter_force_index
    or position.x ~= prev_position.x
    or position.y ~= prev_position.y
  then
    switch_to_idle_and_back(player, true)
  end
end

script.on_event(ev.on_tick, function(event)
  local active_players = global.active_players
  local next_index = active_players.next_index
  local player = active_players[next_index]
  if player then
    update_active_player(player)
  else
    active_players.next_index = 1
  end
end)

script.on_event("QAI-adjust", function(event)
  local player = get_player(event)
  if not player then return end
  local selected = player.player.selected
  if not selected then
    switch_to_idle(player)
    return
  end
  on_adjust_handler_lut[player.state](player, selected)
end)

script.on_event(ev.on_player_changed_position, function(event)
  local player = get_player(event)
  if not player then return end
  if player.state ~= "idle" then
    local inserter = player.target_inserter
    if not inserter.valid or not player.player.can_reach_entity(inserter) then
      switch_to_idle(player)
    end
  end
end)

script.on_event(ev.on_player_rotated_entity, function(event)
  local player = global.inserters_in_use[event.entity.unit_number] ---@cast player PlayerDataQAI
  if not player then return end
  switch_to_idle_and_back(player)
end)

script.on_event(ev.script_raised_teleported, function(event)
  local player = global.inserters_in_use[event.entity.unit_number] ---@cast player PlayerDataQAI
  if not player then return end
  switch_to_idle_and_back(player, true)
end)

for _, destroy_event in pairs{
  ev.on_entity_died,
  ev.on_robot_mined_entity,
  ev.on_player_mined_entity,
  ev.script_raised_destroy,
}
do
  ---@param event EventData.on_entity_died|EventData.on_robot_mined_entity|EventData.on_player_mined_entity|EventData.script_raised_destroy
  script.on_event(destroy_event, function(event)
    local player = global.inserters_in_use[event.entity.unit_number]
    if not player then return end
    switch_to_idle(player)
  end, {
    {filter = "type", type = "inserter"},
  })
end

script.on_event({ev.on_research_finished, ev.on_research_reversed}, function(event)
  local research = event.research
  if not techs_we_care_about[research.name] then return end
  local force = global.forces[research.force.index]
  if not force then return end
  update_tech_level_for_force(force)
end)

script.on_event(ev.on_force_reset, function(event)
  local force = global.forces[event.force.index]
  if not force then return end
  update_tech_level_for_force(force)
end)

---@param force LuaForce
local function recheck_players_in_force(force)
  for _, player in pairs(force.players) do
    local player_data = global.players[player.index]
    if player_data then
      switch_to_idle_and_back(player_data)
    end
  end
end

script.on_event(ev.on_force_friends_changed, function(event)
  recheck_players_in_force(event.force)
  recheck_players_in_force(event.other_force)
end)

script.on_event(ev.on_surface_deleted, function(event)
  cleanup_deleted_surface_pool(global.square_pool, event.surface_index)
  cleanup_deleted_surface_pool(global.ninth_pool, event.surface_index)
  cleanup_deleted_surface_pool(global.rect_pool, event.surface_index)
end)

script.on_event(ev.on_player_changed_force, function(event)
  local player = get_player(event)
  if not player then return end
  player.force_index = player.player.force_index--[[@as uint8]]
  player.force = player.player.force--[[@as LuaForce]]
  switch_to_idle_and_back(player)
end)

script.on_configuration_changed(function(event)
  -- Ignore the event if this mod has just been added, since on_init ran already anyway.
  if not event.mod_changes["quick_adjustable_inserters"]
    or event.mod_changes["quick_adjustable_inserters"].old_version
  then
    for _, force in pairs(global.forces) do
      update_tech_level_for_force(force)
    end
  end
end)

script.on_event(ev.on_force_created, function(event)
  init_force(event.force)
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
  local player = get_player(event) ---@cast player -nil
  switch_to_idle(player)
  global.players[event.player_index] = nil
end)

script.on_init(function()
  ---@type GlobalDataQAI
  global = {
    players = {},
    forces = {},
    inserters_in_use = {},
    active_players = {count = 0, next_index = 1},
    pooled_entities_to_player_lut = {},
    square_pool = new_entity_pool(square_entity_name),
    ninth_pool = new_entity_pool(ninth_entity_name),
    rect_pool = new_entity_pool(rect_entity_name),
  }
  for _, force in pairs(game.forces) do
    init_force(force)
  end
  for _, player in pairs(game.players) do
    init_player(player)
  end
end)
