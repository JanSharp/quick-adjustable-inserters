
local vec = require("__inserter-throughput-lib__.vector")
local consts = require("__quick-adjustable-inserters__.runtime.consts")
local long_inserter_range_type = consts.long_inserter_range_type

---Require `cache.base_range` to be set.
---@type table<LongInserterRangeTypeQAI, fun(cache: InserterCacheQAI)>
local generate_range_cache_lut = {
  [long_inserter_range_type.retract_then_extend] = function(cache)
    cache.range = cache.tech_level.range
    cache.range_gap_from_center = math.max(0, cache.base_range - cache.range)
  end,
  [long_inserter_range_type.extend_only] = function(cache)
    cache.range = cache.tech_level.range
    cache.range_gap_from_center = cache.base_range - 1
  end,
  [long_inserter_range_type.extend_only_without_gap] = function(cache)
    cache.range = cache.base_range + cache.tech_level.range - 1
    cache.range_gap_from_center = 0
  end,
  [long_inserter_range_type.extend_only_starting_at_inner] = function(cache)
    cache.range = cache.tech_level.range
    cache.range_gap_from_center = 0
  end,
  [long_inserter_range_type.extend_only_starting_at_inner_intersect_with_gap] = function(cache)
    cache.range = math.max(0, cache.tech_level.range - cache.base_range + 1)
    cache.range_gap_from_center = cache.base_range - 1
  end,
  [long_inserter_range_type.retract_only] = function(cache)
    cache.range = math.min(cache.base_range, cache.tech_level.range)
    cache.range_gap_from_center = cache.base_range - cache.range
  end,
  [long_inserter_range_type.retract_only_inverse] = function(cache)
    cache.range = math.min(cache.base_range, cache.tech_level.range)
    cache.range_gap_from_center = 0
  end,
  [long_inserter_range_type.unlock_when_range_tech_reaches_inserter_range] = function(cache)
    cache.range = cache.tech_level.range >= cache.base_range and 1 or 0
    cache.range_gap_from_center = cache.base_range - 1
  end,
}

---@param cache InserterCacheQAI
local function generate_pickup_and_drop_position_related_cache(cache)
  local inserter = cache.prototype
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
  local generate_range_cache = generate_range_cache_lut[storage.range_for_long_inserters]
  generate_range_cache(cache)

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
    vertices[count] = {x = x, y = y}
    vertices_flipped[count] = {x = y, y = x}
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
    {x = -1.3, y = max_range + tile_height / 2 + 0.35},
    {x = 0, y = max_range + tile_height / 2 + 0.35 + 1.3},
    {x = 1.3, y = max_range + tile_height / 2 + 0.35},
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
local function generate_collision_box_related_cache(cache)
  local inserter = cache.prototype
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
local function generate_cache_for_inserter(inserter, tech_level)
  if not tech_level.cardinal and not tech_level.diagonal and not tech_level.drop_offset then
    -- If both cardinal and diagonal are false then all_tiles is also false.
    return {disabled = true, disabled_because_no_tech = true}
  end

  local only_drop_offset = not tech_level.cardinal and not tech_level.diagonal and tech_level.drop_offset
  local not_rotatable = inserter.has_flag("not-rotatable")

  ---@type InserterCacheQAI
  local cache = {
    prototype = inserter,
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
    chases_belt_items = inserter.inserter_chases_belt_items,
  }

  generate_collision_box_related_cache(cache)
  generate_pickup_and_drop_position_related_cache(cache)
  if cache.range == 0 then
    return {disabled = true, disabled_because_not_enough_tech = true}
  end
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

return generate_cache_for_inserter
