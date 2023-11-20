
local inserter_throughput = require("__inserter_throughput_lib__.api")
local vec = require("__inserter_throughput_lib__.vector")

---cSpell:ignore rects

---@class GlobalDataQAI
---@field players table<int, PlayerDataQAI>
---@field forces table<uint8, ForceDataQAI>
---@field inserters_in_use table<uint32, PlayerDataQAI> @ Indexed by inserter unit_number.
---@field active_players PlayerDataQAI[]|{count: integer, next_index: integer}
---@field active_animations AnimationQAI[]|{count: integer}
---@field selectable_entities_to_player_lut table<uint32, PlayerDataQAI> @ pooled entity unit number => player index.
---@field selectable_entities_by_unit_number table<uint32, LuaEntity>
global = {}

---@alias AnimationQAI
---| AnimatedCircleQAI
---| AnimatedRectangleQAI
---| AnimatedLineQAI

---@enum AnimationTypeQAI
local animation_type = {
  circle = 1,
  rectangle = 2,
  line = 3,
}

---@class AnimationBaseQAI
---@field type AnimationTypeQAI
---@field id uint64
---@field remaining_updates integer @ Stays alive when going to 0, finishes the next update.
---@field destroy_on_finish boolean

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
---@field offset_from_inserter MapPosition
---@field offset_from_inserter_flipped MapPosition @ Use when `player.should_flip` is true.
---@field grid_center MapPosition
---@field grid_center_flipped MapPosition
---@field radius_for_circle_on_inserter number
---@field tile_width integer
---@field tile_height integer
---@field tiles MapPosition[]
---@field tiles_flipped MapPosition[]
---@field tiles_background_vertices ScriptRenderVertexTarget[]
---@field tiles_background_vertices_flipped ScriptRenderVertexTarget[]
---@field lines LineDefinitionQAI[]
---@field lines_flipped LineDefinitionQAI[]
---@field direction_arrows DirectionArrowDefinitionQAI[] @ Always 4.
---@field direction_arrow_position MapPosition
---@field direction_arrow_vertices ScriptRenderVertexTarget[]
---@field extension_speed number
---@field rotation_speed number
---@field chases_belt_items boolean

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
---If at any point a mod changes a player's force and some mod causes this mod here to use this force_index
---inside of their on_player_changed_force, before this mod here gets the event, then there will be errors
---I'm guessing. But that's worth the performance improvement of having this cached for all the performance
---critical code paths using it. (Same applies to force merging, probably.)
---@field force_index uint8
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
---@field current_surface_index uint @ `nil` when idle.
---@field current_surface LuaSurface @ `nil` when idle.
---@field used_squares uint[]
---@field used_ninths uint[]
---@field used_rects uint[]
---@field line_ids uint64[]
---@field background_polygon_id uint64 @ `nil` when idle.
---`nil` when idle. Can be `nil` when destroying all rendering objects due to being part of an animation.
---@field inserter_circle_id uint64
---@field direction_arrow_id uint64 @ `nil` when idle.
---@field pickup_highlight_id uint64? @ Can be `nil` even when not idle.
---Can be `nil` even when not idle. Can even be `nil` when `pickup_highlight_id` is not `nil`.
---@field line_to_pickup_highlight_id uint64?
---@field inserter_speed_text_id uint64? @ Only `nil` initially, once it exists, it's never destroyed (by this mod).
---@field show_throughput_on_drop boolean
---@field show_throughput_on_pickup boolean
---@field show_throughput_on_inserter boolean

local ev = defines.events
local square_entity_name = "QAI-selectable-square"
local ninth_entity_name = "QAI-selectable-ninth"
local rect_entity_name = "QAI-selectable-rect"

local finish_animation_frames = 16
local finish_animation_expansion = 3/16
local finish_animation_highlight_box_step = (finish_animation_expansion / 2) / finish_animation_frames

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

---@param player PlayerDataQAI
---@param pos MapPosition
---@return MapPosition
local function flip(player, pos)
  if player.should_flip then
    pos.x, pos.y = pos.y, pos.x
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
        if not (tech_level.range < x and x <= tech_level.range + tile_width + gap * 2
          and tech_level.range < y and y <= tech_level.range + tile_height + gap * 2)
        then
          add(x, y)
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
        add(x, y)
      end
    end
    for x = max_range + 1, max_range + tile_width do
      for y = 1, tech_level.range * 2 do
        if y > tech_level.range then
          y = y + tile_height + gap * 2
        end
        add(x, y)
      end
    end
  end

  if tech_level.diagonal then
    for i = 1, tech_level.range * 2 do
      add(
        i > tech_level.range and (i + tile_width + gap * 2) or i,
        i > tech_level.range and (i + tile_height + gap * 2) or i
      )
      local x = tech_level.range * 2 - i + 1
      add(
        x > tech_level.range and (x + tile_width + gap * 2) or x,
        i > tech_level.range and (i + tile_height + gap * 2) or i
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

  for _, tile in pairs(cache.tiles) do
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

---@param cache InserterCacheQAI
local function generate_lines_cache(cache)
  local count = 0
  local lines = cache.lines
  local lines_flipped = cache.lines_flipped
  ---@param line LineDefinitionQAI
  local function add(line)
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

  -- The final lines are represented as points in these grids.
  -- 0, 0 in horizontal_grid is the line going from the top left corner 1 tile to the right.
  -- 0, 0 in vertical_grid is the line going from the top left corner 1 tile downwards.
  ---@type table<uint32, true>
  local horizontal_grid = {}
  ---@type table<uint32, true>
  local vertical_grid = {}

  for _, tile in pairs(cache.tiles) do
    horizontal_grid[get_point(tile.x, tile.y)] = true
    horizontal_grid[get_point(tile.x, tile.y + 1)] = true
    vertical_grid[get_point(tile.x, tile.y)] = true
    vertical_grid[get_point(tile.x + 1, tile.y)] = true
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
    add{
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
    add{
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
    offset_from_inserter_flipped = (nil)--[[@as any]], -- Set after the `calculate_cached_base_reach` call.
    tile_width = tile_width,
    tile_height = tile_height,
    radius_for_circle_on_inserter = math.min(tile_width, tile_height) / 2 - 0.25,
    tiles = {},
    tiles_flipped = {},
    tiles_background_vertices = {},
    tiles_background_vertices_flipped = {},
    lines = {},
    lines_flipped = {},
    direction_arrows = {},
    direction_arrow_vertices = {},
    extension_speed = inserter.inserter_extension_speed,
    rotation_speed = inserter.inserter_rotation_speed,
    chases_belt_items = inserter.inserter_chases_belt_items,
  }
  calculate_cached_base_reach(cache)
  offset_from_inserter.x = offset_from_inserter.x - cache.range_gap_from_center
  offset_from_inserter.y = offset_from_inserter.y - cache.range_gap_from_center
  cache.offset_from_inserter_flipped = {
    x = offset_from_inserter.y,
    y = offset_from_inserter.x,
  }
  cache.grid_center = {
    x = range + cache.range_gap_from_center + (tile_width / 2),
    y = range + cache.range_gap_from_center + (tile_height / 2),
  }
  cache.grid_center_flipped = {
    x = cache.grid_center.y,
    y = cache.grid_center.x,
  }

  generate_tiles_cache(cache)
  generate_tiles_background_cache(cache)
  generate_lines_cache(cache)
  generate_direction_arrow_cache(cache)
  return cache
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

---@param ids uint64[]
local function destroy_and_clear_rendering_ids(ids)
  local destroy = rendering.destroy
  for i = #ids, 1, -1 do
    destroy(ids[i])
    ids[i] = nil
  end
end

---@param player PlayerDataQAI
local function destroy_all_rendering_objects(player)
  -- For simplicity in other parts of the code, accept this function getting called no matter what.
  if not player.background_polygon_id then return end
  destroy_and_clear_rendering_ids(player.line_ids)
  local destroy = rendering.destroy
  destroy(player.background_polygon_id)
  if player.inserter_circle_id then destroy(player.inserter_circle_id) end
  destroy(player.direction_arrow_id)
  if player.pickup_highlight_id then destroy(player.pickup_highlight_id) end
  if player.line_to_pickup_highlight_id then destroy(player.line_to_pickup_highlight_id) end
  player.background_polygon_id = nil
  player.inserter_circle_id = nil
  player.direction_arrow_id = nil
  player.pickup_highlight_id = nil
  player.line_to_pickup_highlight_id = nil
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
local function hide_inserter_speed_text(player)
  local id = player.inserter_speed_text_id
  if id and rendering.is_valid(id) then
    rendering.set_visible(id, false)
  end
end

---@param player PlayerDataQAI
---@param keep_rendering boolean? @ When true, no rendering objects will get destroyed.
local function switch_to_idle(player, keep_rendering)
  if player.state == "idle" then return end
  player.current_surface_index = nil
  player.current_surface = nil
  destroy_entities(player.used_squares)
  destroy_entities(player.used_ninths)
  destroy_entities(player.used_rects)
  if not keep_rendering then
    destroy_all_rendering_objects(player)
  end
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
---@return MapPosition
local function get_offset_from_inserter(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.offset_from_inserter_flipped
    or cache.offset_from_inserter
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
---@return ScriptRenderVertexTarget[]
local function get_tiles_background_vertices(player)
  local cache = player.target_inserter_cache
  return player.should_flip
    and cache.tiles_background_vertices_flipped
    or cache.tiles_background_vertices
end

---@param player PlayerDataQAI
local function place_squares(player)
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = get_offset_from_inserter(player)
  local left = inserter_position.x + offset_from_inserter.x
  local top = inserter_position.y + offset_from_inserter.y
  local selectable_entities_to_player_lut = global.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = global.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = square_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  for i, tile in pairs(get_tiles(player)) do
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
local function place_ninths(player)
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = get_offset_from_inserter(player)
  local left = inserter_position.x + offset_from_inserter.x
  local top = inserter_position.y + offset_from_inserter.y
  local selectable_entities_to_player_lut = global.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = global.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = ninth_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  local count = 0
  for _, tile in pairs(get_tiles(player)) do
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
local function draw_direction_arrow(player)
  local inserter = player.target_inserter
  local inserter_position = inserter.position
  local cache = player.target_inserter_cache
  inserter_position.x = inserter_position.x + cache.offset_from_inserter.x + cache.direction_arrow_position.x
  inserter_position.y = inserter_position.y + cache.offset_from_inserter.y + cache.direction_arrow_position.y
  local opacity = 0.6
  player.direction_arrow_id = rendering.draw_polygon{
    surface = player.current_surface_index,
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
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = cache.offset_from_inserter
  local selectable_entities_to_player_lut = global.selectable_entities_to_player_lut
  local selectable_entities_by_unit_number = global.selectable_entities_by_unit_number
  local position = {}
  ---@type LuaSurface.create_entity_param
  local arg = {
    name = rect_entity_name,
    force = player.force_index,
    position = position,
  }
  local create_entity = player.current_surface.create_entity
  for _, dir_arrow in pairs(cache.direction_arrows) do
    if not cache.is_square and is_east_or_west_lut[dir_arrow.direction] then goto continue end
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
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = get_offset_from_inserter(player)
  local grid_center = get_grid_center(player)
  player.inserter_circle_id = rendering.draw_circle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = {1, 1, 1},
    radius = cache.radius_for_circle_on_inserter,
    width = 2,
    target = {
      x = inserter_position.x + offset_from_inserter.x + grid_center.x,
      y = inserter_position.y + offset_from_inserter.y + grid_center.y,
    },
  }
end

---@param player PlayerDataQAI
local function draw_grid_lines(player)
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = get_offset_from_inserter(player)
  local left = inserter_position.x + offset_from_inserter.x
  local top = inserter_position.y + offset_from_inserter.y
  local from = {}
  local to = {}
  ---@type LuaRendering.draw_line_param
  local line_param = {
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = {1, 1, 1},
    width = 1,
    from = from,
    to = to,
  }

  for _, line in pairs(get_lines(player)) do
    from.x = left + line.from.x
    from.y = top + line.from.y
    to.x = left + line.to.x
    to.y = top + line.to.y
    player.line_ids[#player.line_ids+1] = rendering.draw_line(line_param)
  end
end

---@param player PlayerDataQAI
local function draw_grid_background(player)
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = get_offset_from_inserter(player)
  local opacity = 0.2
  player.background_polygon_id = rendering.draw_polygon{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = {opacity, opacity, opacity, opacity},
    vertices = get_tiles_background_vertices(player),
    target = {
      x = inserter_position.x + offset_from_inserter.x,
      y = inserter_position.y + offset_from_inserter.y,
    },
  }
end

---@param player PlayerDataQAI
local function draw_all_rendering_objects(player)
  -- When rendering objects were kept alive when switching to idle previously, don't create another set.
  if player.inserter_circle_id then return end
  draw_direction_arrow(player)
  draw_circle_on_inserter(player)
  draw_grid_lines(player)
  draw_grid_background(player)
end

---@param player PlayerDataQAI
---@param position MapPosition
---@param text string
local function set_inserter_speed_text(player, position, text)
  local id = player.inserter_speed_text_id
  if not id or not rendering.is_valid(id) then
    player.inserter_speed_text_id = rendering.draw_text{
      -- Can't use `player.current_surface_index` because that's nil when idle.
      surface = player.player.surface_index,
      players = {player.player_index},
      color = {1, 1, 1},
      target = position,
      text = text,
    }
    return
  end
  rendering.set_text(id, text)
  rendering.set_target(id, position)
  rendering.set_visible(id, true)
  rendering.bring_to_front(id)
end

local calculate_actual_drop_position

---@param player PlayerDataQAI
---@param selected_position MapPosition @ Position of the selected square or ninth.
---@return number items_per_second
local function estimate_inserter_speed(player, selected_position)
  local cache = player.target_inserter_cache
  local target_inserter = player.target_inserter
  ---@type InserterThroughputDefinition
  local def = {
    extension_speed = cache.extension_speed,
    rotation_speed = cache.rotation_speed,
    chases_belt_items = cache.chases_belt_items,
    stack_size = target_inserter.inserter_target_pickup_count,
  }

  if player.state == "selecting-pickup" then
    inserter_throughput.set_from_based_on_position(
      def,
      target_inserter.surface,
      player.target_inserter_position,
      selected_position
    )
    inserter_throughput.set_to_based_on_inserter(def, target_inserter)
  else
    inserter_throughput.set_from_based_on_inserter(def, target_inserter)
    inserter_throughput.set_to_based_on_position(
      def,
      target_inserter.surface,
      player.target_inserter_position,
      calculate_actual_drop_position(player, selected_position)
    )
  end

  return inserter_throughput.estimate_inserter_speed(def)
end

---@param inserter LuaEntity
local function estimate_inserter_speed_for_inserter(inserter)
  local prototype = inserter.prototype
  ---@type InserterThroughputDefinition
  local def = {
    extension_speed = prototype.inserter_extension_speed,
    rotation_speed = prototype.inserter_rotation_speed,
    chases_belt_items = prototype.inserter_chases_belt_items,
    stack_size = inserter.inserter_target_pickup_count,
  }
  inserter_throughput.set_from_based_on_inserter(def, inserter)
  inserter_throughput.set_to_based_on_inserter(def, inserter)
  return inserter_throughput.estimate_inserter_speed(def)
end

---@param player PlayerDataQAI
---@param inserter LuaEntity
local function update_inserter_speed_text_using_inserter(player, inserter)
  local items_per_second = estimate_inserter_speed_for_inserter(inserter)
  local selection_box = inserter.selection_box
  local position = {
    x = selection_box.right_bottom.x + 0.15,
    y = (selection_box.left_top.y + selection_box.right_bottom.y) / 2 - 0.31,
  }
  set_inserter_speed_text(player, position, string.format("%.3f/s", items_per_second))
  return
end

---@param player PlayerDataQAI
local function update_inserter_speed_text(player)
  local selected = player.player.selected
  if not selected then
    hide_inserter_speed_text(player)
    return
  end

  if player.show_throughput_on_inserter
    and selected.type == "inserter"
    and selected.force.is_friend(player.force_index)
  then
    update_inserter_speed_text_using_inserter(player, selected)
    return
  end

  if player.state == "idle"
    or player.state == "selecting-pickup" and not player.show_throughput_on_pickup
    or player.state == "selecting-drop" and not player.show_throughput_on_drop
  then
    hide_inserter_speed_text(player)
    return
  end

  local name = selected.name
  if not (name == square_entity_name or name == ninth_entity_name) ---@cast selected -nil
    or global.selectable_entities_to_player_lut[selected.unit_number] ~= player
  then
    hide_inserter_speed_text(player)
    return
  end

  local position = selected.position
  local items_per_second = estimate_inserter_speed(player, position)
  position.x = position.x + (name == ninth_entity_name and 0.35 or 0.6)
  position.y = position.y - 0.31
  set_inserter_speed_text(player, position, string.format("%.3f/s", items_per_second))
end

---@param player PlayerDataQAI
---@return MapPosition left_top
---@return MapPosition right_bottom
local function get_pickup_box(player)
  local pickup_pos = player.target_inserter.pickup_position
  return {x = pickup_pos.x - 0.5, y = pickup_pos.y - 0.5},
    {x = pickup_pos.x + 0.5, y = pickup_pos.y + 0.5}
end

---@param player PlayerDataQAI
local function draw_pickup_highlight(player)
  local left_top, right_bottom = get_pickup_box(player)
  player.pickup_highlight_id = rendering.draw_rectangle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = {0, 1, 0},
    width = 3,
    left_top = left_top,
    right_bottom = right_bottom,
  }
end

---@param player PlayerDataQAI
---@param square_position MapPosition @ Gets modified.
---@param square_radius number @ Half of the length of the sides of the square.
---@return MapPosition? from
---@return MapPosition? to
---@return number length
local function get_from_and_to_for_line_from_center(player, square_position, square_radius)
  local grid_center_position = vec.add(
    vec.add(
      vec.copy(player.target_inserter_position),
      get_offset_from_inserter(player)
    ),
    get_grid_center(player)
  )
  local pickup_vector = vec.sub(square_position, grid_center_position)
  local distance_from_pickup = (3/32) + vec.get_length(vec.div_scalar(
    vec.copy(pickup_vector),
    math.max(math.abs(pickup_vector.x), math.abs(pickup_vector.y)) / square_radius
  ))
  local distance_from_center = (2/32) + player.target_inserter_cache.radius_for_circle_on_inserter
  local length = vec.get_length(pickup_vector) - distance_from_pickup - distance_from_center
  if length <= 0 then return nil, nil, length end

  local from = vec.add(
    vec.copy(grid_center_position),
    vec.set_length(pickup_vector, distance_from_center)
  )
  local to = vec.add(
    grid_center_position, -- No need to copy here too.
    vec.set_length(pickup_vector, distance_from_center + length)
  )
  return from--[[@as MapPosition]], to--[[@as MapPosition]], length
end

---@param player PlayerDataQAI
local function draw_line_to_pickup_highlight(player)
  local from, to = get_from_and_to_for_line_from_center(player, player.target_inserter.pickup_position, 0.5)
  if not from then return end ---@cast to -nil
  player.line_to_pickup_highlight_id = rendering.draw_line{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = {0, 1, 0},
    width = 2,
    from = from,
    to = to,
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
  if not force then return false end

  local cache = force.inserter_cache_lut[target_inserter.name]
  if not cache then
    return show_error(player, target_inserter, {"QAI.cant-change-inserter-at-runtime"})
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
    return show_error(player, target_inserter, {"QAI.only-one-player-can-adjust"})
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
  player.current_surface = target_inserter.surface
  return true
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function switch_to_selecting_pickup(player, target_inserter, do_check_reach)
  if player.state == "selecting-pickup" and player.target_inserter == target_inserter then return end
  if player.state ~= "idle" then
    switch_to_idle(player, player.target_inserter == target_inserter)
  end
  if not try_set_target_inserter(player, target_inserter, do_check_reach) then
    destroy_all_rendering_objects(player)
    return
  end

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
    switch_to_idle(player, player.target_inserter == target_inserter)
  end
  if not try_set_target_inserter(player, target_inserter, do_check_reach) then
    destroy_all_rendering_objects(player)
    return
  end

  if player.target_inserter_cache.tech_level.drop_offset then
    place_ninths(player)
  else
    place_squares(player)
  end
  place_rects(player)
  draw_all_rendering_objects(player)
  draw_pickup_highlight(player)
  draw_line_to_pickup_highlight(player)
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
---@param offset_from_tile_center number
---@param auto_determine_drop_offset boolean? @ Should it move the drop offset away from the inserter?
local function snap_drop_position(player, position, offset_from_tile_center, auto_determine_drop_offset)
  local cache = player.target_inserter_cache
  local tech_level = cache.tech_level
  local inserter_position = player.target_inserter_position
  local offset_from_inserter = cache.offset_from_inserter
  local left_top_x = inserter_position.x + offset_from_inserter.x
  local left_top_y = inserter_position.y + offset_from_inserter.y
  local relative_x = position.x - left_top_x
  local relative_y = position.y - left_top_y
  local x_offset
  local y_offset
  if auto_determine_drop_offset then
    local max_range = tech_level.range + cache.range_gap_from_center
    x_offset = relative_x < max_range and -offset_from_tile_center
      or (max_range + cache.tile_width) < relative_x and offset_from_tile_center
      or 0
    y_offset = relative_y < max_range and -offset_from_tile_center
      or (max_range + cache.tile_height) < relative_y and offset_from_tile_center
      or 0
  else
    -- Modulo always returns a positive number.
    local x_from_tile_center = (relative_x % 1) - 0.5
    local y_from_tile_center = (relative_y % 1) - 0.5
    -- 51 / 256 = 0.19921875. Vanilla inserter drop positions are offset by 0.2 away from the center, however
    -- it ultimately gets rounded to 51 / 256, because of map positions. In other words, this matches vanilla.
    x_offset = x_from_tile_center == 0 and 0
      or x_from_tile_center < 0 and -offset_from_tile_center
      or offset_from_tile_center
    y_offset = y_from_tile_center == 0 and 0
      or y_from_tile_center < 0 and -offset_from_tile_center
      or offset_from_tile_center
  end
  return {
    x = left_top_x + math.floor(relative_x) + 0.5 + x_offset,
    y = left_top_y + math.floor(relative_y) + 0.5 + y_offset,
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
function calculate_actual_drop_position(player, position)
  local auto_determine_drop_offset = not player.target_inserter_cache.tech_level.drop_offset
  return snap_drop_position(player, position, 51/256, auto_determine_drop_offset)
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
  return {r = 0, g = -1 / finish_animation_frames, b = 0, a = -1 / finish_animation_frames}
end

---@param player PlayerDataQAI
---@param position MapPosition
local function play_drop_highlight_animation(player, position)
  local color = get_finish_animation_color()
  local left_top = {x = position.x - 43/256, y = position.y - 43/256} -- 43/256 ~= 1/6
  local right_bottom = {x = position.x + 43/256, y = position.y + 43/256}
  local id = rendering.draw_rectangle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color,
    width = 3,
    left_top = left_top,
    right_bottom = right_bottom,
  }

  local step = finish_animation_highlight_box_step
  add_animated_rectangle{
    id = id,
    remaining_updates = finish_animation_frames - 1,
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
  local final_length = length - finish_animation_expansion
  local length_step = finish_animation_expansion / finish_animation_frames
  local frames = math.max(1, finish_animation_frames - math.floor(math.max(0, -final_length) / length_step))
  local step_vector = vec.set_length(vec.sub(vec.copy(to), from), length_step / 2)
  return frames, step_vector--[[@as MapPosition]]
end

---@param player PlayerDataQAI
---@param position MapPosition
local function play_line_to_drop_highlight_animation(player, position)
  local from, to, length = get_from_and_to_for_line_from_center(
    player,
    vec.copy(position)--[[@as MapPosition]],
    43/256
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
    to_step = vec.mul_scalar(vec.copy(step_vector), -1)--[[@as MapPosition]],
  }
end

---@param player PlayerDataQAI
local function play_circle_on_inserter_animation(player)
  if not rendering.is_valid(player.inserter_circle_id) then return end
  local color = get_finish_animation_color()
  rendering.set_color(player.inserter_circle_id, color)
  add_animated_circle{
    id = player.inserter_circle_id,
    remaining_updates = finish_animation_frames - 1,
    destroy_on_finish = true,
    color = color,
    radius = player.target_inserter_cache.radius_for_circle_on_inserter,
    color_step = get_finish_animation_color_step(),
    radius_step = (finish_animation_expansion / 2) / finish_animation_frames,
  }
  player.inserter_circle_id = nil -- Destroying is now handled by the animation.
end

---@param player PlayerDataQAI
local function play_pickup_highlight_animation(player)
  if not rendering.is_valid(player.pickup_highlight_id) then return end
  local step = (finish_animation_expansion / 2) / finish_animation_frames
  local left_top, right_bottom = get_pickup_box(player)
  add_animated_rectangle{
    id = player.pickup_highlight_id,
    remaining_updates = finish_animation_frames - 1,
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
  if not rendering.is_valid(player.line_to_pickup_highlight_id) then return end
  local from, to, length = get_from_and_to_for_line_from_center(
    player,
    player.target_inserter.pickup_position,
    0.5
  )
  -- The pickup position might have changed since the last time we checked.
  if not from then ---@cast to -nil
    rendering.destroy(player.line_to_pickup_highlight_id)
    player.line_to_pickup_highlight_id = nil
    return
  end

  local frames, step_vector = get_frames_and_step_vector_for_line_to_highlight(from, to, length)
  add_animated_line{
    id = player.line_to_pickup_highlight_id,
    remaining_updates = frames - 1,
    destroy_on_finish = true,
    color = get_finish_animation_color(),
    from = from,
    to = to,
    color_step = get_finish_animation_color_step(),
    from_step = step_vector,
    to_step = vec.mul_scalar(vec.copy(step_vector), -1)--[[@as MapPosition]],
  }
  player.line_to_pickup_highlight_id = nil -- Destroying is now handled by the animation.
end

---@param player PlayerDataQAI
local function play_finish_animation(player)
  if game.tick_paused then return end
  local drop_position = calculate_visualized_drop_position(player, player.target_inserter.drop_position)
  play_drop_highlight_animation(player, drop_position)
  play_line_to_drop_highlight_animation(player, drop_position)
  play_circle_on_inserter_animation(player)
  play_pickup_highlight_animation(player)
  play_line_to_pickup_highlight_animation(player)
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
        play_finish_animation(player)  -- Before switching to idle because some rendering objects get reused.
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
      play_finish_animation(player) -- Before switching to idle because some rendering objects get reused.
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

---@param player PlayerDataQAI
---@param setting_name string
---@param field_name string
local function update_show_throughput_on_player(player, setting_name, field_name)
  local new_value = settings.get_player_settings(player.player_index)[setting_name].value--[[@as boolean]]
  if new_value == player[field_name] then return end
  player[field_name] = new_value
  update_inserter_speed_text(player)
end

---@type table<string, fun(player: PlayerDataQAI)>
local update_setting_lut = {
  ["QAI-show-throughput-on-inserter"] = function(player)
    update_show_throughput_on_player(player, "QAI-show-throughput-on-inserter", "show_throughput_on_inserter")
  end,
  ["QAI-show-throughput-on-pickup"] = function(player)
    update_show_throughput_on_player(player, "QAI-show-throughput-on-pickup", "show_throughput_on_pickup")
  end,
  ["QAI-show-throughput-on-drop"] = function(player)
    update_show_throughput_on_player(player, "QAI-show-throughput-on-drop", "show_throughput_on_drop")
  end,
}

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
    show_throughput_on_inserter = player_settings["QAI-show-throughput-on-inserter"].value--[[@as boolean]],
    show_throughput_on_pickup = player_settings["QAI-show-throughput-on-pickup"].value--[[@as boolean]],
    show_throughput_on_drop = player_settings["QAI-show-throughput-on-drop"].value--[[@as boolean]],
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
    update_inserter_speed_text(player)
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

script.on_event(ev.on_selected_entity_changed, function(event)
  local player = get_player(event)
  if not player then return end
  update_inserter_speed_text(player)
end)

script.on_event(ev.on_runtime_mod_setting_changed, function(event)
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
    if not inserter.valid or not player.player.can_reach_entity(inserter) then
      switch_to_idle(player)
    end
  end
end)

for _, data in pairs{
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
    player = global.inserters_in_use[event.entity.unit_number] ---@cast player PlayerDataQAI
    if player then
      switch_to_idle_and_back(player, do_check_reach)
    end
  end)
end

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

script.on_event(ev.on_player_changed_force, function(event)
  local player = get_player(event)
  if not player then return end
  player.force_index = player.player.force_index--[[@as uint8]]
  switch_to_idle_and_back(player)
  update_inserter_speed_text(player)
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
    active_animations = {count = 0},
    selectable_entities_to_player_lut = {},
    selectable_entities_by_unit_number = {},
  }
  for _, force in pairs(game.forces) do
    init_force(force)
  end
  for _, player in pairs(game.players) do
    init_player(player)
  end
end)
