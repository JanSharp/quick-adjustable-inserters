
---cSpell:ignore rects

---@class GlobalDataQAI
---@field players table<int, PlayerDataQAI>
---@field square_pool EntityPoolQAI
---@field ninth_pool EntityPoolQAI
---@field rect_pool EntityPoolQAI

-- TODO: per surface pools

---@class EntityPoolQAI
---@field entity_name string
---@field free_count int
---@field used_count int
---@field free_entities table<uint, LuaEntity>
---@field used_entities table<uint, LuaEntity>

---@alias PlayerStateQAI
---| "idle"
---| "selecting-pickup"
---| "selecting-drop"

---@class PlayerDataQAI
---@field player LuaPlayer
---@field state PlayerStateQAI
---@field target_inserter LuaEntity @ `nil` when idle.
---@field used_squares uint[]
---@field used_ninths uint[]
---@field used_rects uint[]
---@field line_ids uint64[]
---@field direction_arrow_id uint64 @ `nil` when idle.
---@field pickup_highlight LuaEntity? @ Can be `nil` even when not idle.

local ev = defines.events
local square_entity_name = "QAI-selectable-square"
local ninth_entity_name = "QAI-selectable-ninth"
local rect_entity_name = "QAI-selectable-rect"
local reach_range = 2

local entity_name_lut = {
  [square_entity_name] = true,
  [ninth_entity_name] = true,
  [rect_entity_name] = true,
}

local direction_lut = {
  defines.direction.north,
  defines.direction.east,
  defines.direction.south,
  defines.direction.west,
}
local inverse_direction_lut = {
  [defines.direction.north] = defines.direction.south,
  [defines.direction.east] = defines.direction.west,
  [defines.direction.south] = defines.direction.north,
  [defines.direction.west] = defines.direction.east,
}
local x_direction_multiplier_lut = {0, 1, 0, -1}
local y_direction_multiplier_lut = {-1, 0, 1, 0}

---@return GlobalDataQAI
local function get_global()
  return global
end

---@return PlayerDataQAI?
local function get_player(event)
  return get_global().players[event.player_index]
end

---@param entity_name string
---@return EntityPoolQAI
local function new_entity_pool(entity_name)
  ---@type EntityPoolQAI
  local result = {
    entity_name = entity_name,
    free_count = 0,
    used_count = 0,
    free_entities = {},
    used_entities = {},
  }
  return result
end

---@param player LuaPlayer
---@return PlayerDataQAI
local function init_player(player)
  ---@type PlayerDataQAI
  local player_data = {
    player = player,
    state = "idle",
    used_squares = {},
    used_ninths = {},
    used_rects = {},
    line_ids = {},
  }
  get_global().players[player.index] = player_data
  return player_data
end

script.on_init(function()
  ---@type GlobalDataQAI
  global = {
    players = {},
    square_pool = new_entity_pool(square_entity_name),
    ninth_pool = new_entity_pool(ninth_entity_name),
    rect_pool = new_entity_pool(rect_entity_name),
  }
  for _, player in pairs(game.players) do
    init_player(player)
  end
end)

script.on_event(ev.on_player_created, function(event)
  init_player(game.get_player(event.player_index)--[[@as LuaPlayer]])
end)

script.on_event(ev.on_player_removed, function(event)
  -- TODO: cleanup their entities if they were in that state
  get_global().players[event.player_index] = nil
end)

---@param entity_pool EntityPoolQAI
---@param surface LuaSurface
---@param position MapPosition
---@return uint unit_number
---@return LuaEntity
local function place_pooled_entity(entity_pool, surface, position)
  if entity_pool.free_count ~= 0 then
    entity_pool.free_count = entity_pool.free_count - 1
    local unit_number, entity = next(entity_pool.free_entities)
    if not entity.valid then
      entity_pool.free_entities[unit_number] = nil
    else
      entity_pool.used_count = entity_pool.used_count + 1
      entity_pool.free_entities[unit_number] = nil
      entity_pool.used_entities[unit_number] = entity
      entity.teleport(position)
      return unit_number, entity
    end
  end

  local entity = surface.create_entity{
    name = entity_pool.entity_name,
    position = position,
  }
  if not entity then
    error("Creating an internal entity required by Quick Adjustable Inserters failed.")
  end
  entity.destructible = false
  local unit_number = entity.unit_number ---@cast unit_number -nil
  entity_pool.used_count = entity_pool.used_count + 1
  entity_pool.used_entities[unit_number] = entity
  return unit_number, entity
end

---@param entity_pool EntityPoolQAI
---@param unit_number uint
local function remove_pooled_entity(entity_pool, unit_number)
  entity_pool.used_count = entity_pool.used_count - 1
  entity_pool.free_count = entity_pool.free_count + 1
  local entity = entity_pool.used_entities[unit_number]
  entity_pool.used_entities[unit_number] = nil
  entity_pool.free_entities[unit_number] = entity
  entity.teleport{x = 0, y = 0}
end

---@param entity_pool EntityPoolQAI
---@param used_unit_numbers uint[]
local function remove_used_pooled_entities(entity_pool, used_unit_numbers)
  for i = 1, #used_unit_numbers do
    remove_pooled_entity(entity_pool, used_unit_numbers[i])
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
local function switch_to_idle(player)
  if player.state == "idle" then return end
  local global = get_global()
  remove_used_pooled_entities(global.square_pool, player.used_squares)
  remove_used_pooled_entities(global.ninth_pool, player.used_ninths)
  -- TODO: keep rects, arrow and grid when switching between pickup/drop states
  remove_used_pooled_entities(global.rect_pool, player.used_rects)
  destroy_rendering_ids(player.line_ids)
  rendering.destroy(player.direction_arrow_id)
  destroy_pickup_highlight(player)
  player.target_inserter = nil
  player.state = "idle"
  if player.player.selected and entity_name_lut[player.player.selected.name] then
    player.player.selected = nil
  end
end

---@param player PlayerDataQAI
local function place_squares(player)
  local global = get_global()
  local surface = player.target_inserter.surface
  local position = player.target_inserter.position
  local top_left_x = math.floor(position.x) - reach_range
  local top_left_y = math.floor(position.y) - reach_range
  local side_length = reach_range * 2 + 1
  -- Zero based loops.
  for x = 0, side_length - 1 do
    for y = 0, side_length - 1 do
      if x == reach_range and y == reach_range then goto continue end
      position.x = top_left_x + x + 0.5
      position.y = top_left_y + y + 0.5
      local unit_number = place_pooled_entity(global.square_pool, surface, position)
      player.used_squares[#player.used_squares+1] = unit_number
      ::continue::
    end
  end
end

---@param player PlayerDataQAI
local function place_ninths(player)
  local global = get_global()
  local surface = player.target_inserter.surface
  local position = player.target_inserter.position
  local top_left_x = math.floor(position.x) - reach_range
  local top_left_y = math.floor(position.y) - reach_range
  local side_length = reach_range * 2 + 1
  -- Zero based loops.
  for x = 0, side_length - 1 do
    for y = 0, side_length - 1 do
      if x == reach_range and y == reach_range then goto continue end
      for inner_x = 0, 2 do
        for inner_y = 0, 2 do
          position.x = top_left_x + x + inner_x / 3 + 1 / 6
          position.y = top_left_y + y + inner_y / 3 + 1 / 6
          local unit_number = place_pooled_entity(global.ninth_pool, surface, position)
          player.used_ninths[#player.used_ninths+1] = unit_number
        end
      end
      ::continue::
    end
  end
end

---@param player PlayerDataQAI
local function draw_direction_arrow(player)
  local inserter = player.target_inserter
  player.direction_arrow_id = rendering.draw_polygon{
    surface = inserter.surface,
    color = {1, 1, 1},
    vertices = {
      {target = {x = -1.3, y = reach_range + 0.85}},
      {target = {x = 0, y = reach_range + 0.85 + 1.3}},
      {target = {x = 1.3, y = reach_range + 0.85}},
    },
    orientation = inserter.orientation,
    target = inserter,
  }
end

---@param player PlayerDataQAI
local function update_direction_arrow(player)
  rendering.set_orientation(player.direction_arrow_id, player.target_inserter.orientation)
end

---@param player PlayerDataQAI
local function place_rects(player)
  local global = get_global()
  local surface = player.target_inserter.surface
  local position = player.target_inserter.position
  local root_x = position.x
  local root_y = position.y
  for i = 1, 4 do
    position.x = root_x + x_direction_multiplier_lut[i] * (reach_range + 1.5)
    position.y = root_y + y_direction_multiplier_lut[i] * (reach_range + 1.5)
    local unit_number, entity = place_pooled_entity(global.rect_pool, surface, position)
    entity.direction = direction_lut[i]
    player.used_rects[#player.used_rects+1] = unit_number
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
local function draw_grid(player)
  local surface = player.target_inserter.surface
  local from = {}
  local to = {}
  ---@type LuaRendering.draw_line_param
  local line_param = {
    surface = surface,
    color = {1, 1, 1},
    width = 1,
    from = from,
    to = to,
  }
  local position = player.target_inserter.position
  local top_left_x = math.floor(position.x) - reach_range
  local top_left_y = math.floor(position.y) - reach_range
  local side_length = reach_range * 2 + 1

  from.y = top_left_y
  to.y = top_left_y + side_length
  for x = top_left_x, top_left_x + side_length do
    from.x = x
    to.x = x
    player.line_ids[#player.line_ids+1] = rendering.draw_line(line_param)
  end

  from.x = top_left_x
  to.x = top_left_x + side_length
  for y = top_left_y, top_left_y + side_length do
    from.y = y
    to.y = y
    player.line_ids[#player.line_ids+1] = rendering.draw_line(line_param)
  end
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
  }
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
local function switch_to_selecting_pickup(player, target_inserter)
  if player.state == "selecting-pickup" and player.target_inserter == target_inserter then return end
  if player.state ~= "idle" then
    switch_to_idle(player)
  end
  player.target_inserter = target_inserter
  place_squares(player)
  place_rects(player)
  draw_direction_arrow(player)
  draw_grid(player)
  player.state = "selecting-pickup"
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
local function switch_to_selecting_drop(player, target_inserter)
  if player.state == "selecting-drop" and player.target_inserter == target_inserter then return end
  if player.state ~= "idle" then
    switch_to_idle(player)
  end
  player.target_inserter = target_inserter
  place_ninths(player)
  place_rects(player)
  draw_direction_arrow(player)
  draw_grid(player)
  create_pickup_highlight(player)
  player.state = "selecting-drop"
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

---@type table<string, fun(player: PlayerDataQAI, selected: LuaEntity)>
local on_adjust_handler_lut = {
  ["idle"] = function(player, selected)
    if selected.type ~= "inserter" then return end
    switch_to_selecting_pickup(player, selected)
  end,

  ["selecting-pickup"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if selected.type == "inserter" then
      if selected == player.target_inserter then
        switch_to_selecting_drop(player, selected)
      else
        switch_to_selecting_pickup(player, selected)
      end
      return
    end
    if selected.name == square_entity_name then
      player.target_inserter.pickup_position = selected.position
      switch_to_selecting_drop(player, player.target_inserter)
      return
    end
    if selected.name == rect_entity_name then
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
        switch_to_selecting_pickup(player, selected)
      end
      return
    end
    if selected.name == ninth_entity_name then
      player.target_inserter.drop_position = selected.position
      switch_to_idle(player)
      return
    end
    if selected.name == rect_entity_name then
      set_direction_and_update_arrow(player, selected.direction)
      return
    end
    switch_to_idle(player)
  end,
}

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
