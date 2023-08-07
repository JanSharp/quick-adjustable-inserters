
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
local function place_pooled_entity(entity_pool, surface, position)
  if entity_pool.free_count ~= 0 then
    local unit_number, entity = next(entity_pool.free_entities)
    entity_pool.free_count = entity_pool.free_count - 1
    entity_pool.used_count = entity_pool.used_count + 1
    entity_pool.free_entities[unit_number] = nil
    entity_pool.used_entities[unit_number] = entity
    entity.teleport(position)
    return unit_number
  end

  local entity = surface.create_entity{
    name = entity_pool.entity_name,
    position = position,
  }
  if not entity then
    error("Creating an internal entity required by Quick Adjustable Inserters failed.")
  end
  local unit_number = entity.unit_number ---@cast unit_number -nil
  entity_pool.used_count = entity_pool.used_count + 1
  entity_pool.used_entities[unit_number] = entity
  return unit_number
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

---@param player PlayerDataQAI
local function switch_to_idle(player)
  if player.state == "idle" then return end
  local global = get_global()
  remove_used_pooled_entities(global.square_pool, player.used_squares)
  remove_used_pooled_entities(global.ninth_pool, player.used_ninths)
  remove_used_pooled_entities(global.rect_pool, player.used_rects)
  player.target_inserter = nil
  player.state = "idle"
  if player.player.selected and entity_name_lut[player.player.selected.name] then
    player.player.selected = nil
  end
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
local function switch_to_selecting_pickup(player, target_inserter)
  if player.state == "selecting-pickup" and player.target_inserter == target_inserter then return end
  if player.state ~= "idle" then
    switch_to_idle(player)
  end
  player.target_inserter = target_inserter
  local global = get_global()
  local surface = target_inserter.surface
  local position = target_inserter.position
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
  local global = get_global()
  local surface = target_inserter.surface
  local position = target_inserter.position
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

---@param player PlayerDataQAI
---@param new_inserter LuaEntity
local function adjusted_an_inserter_while_already_targeting_one(player, new_inserter)
  local prev_target_inserter = player.target_inserter
  switch_to_idle(player)
  if new_inserter ~= prev_target_inserter then
    switch_to_selecting_pickup(player, new_inserter)
  end
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
      adjusted_an_inserter_while_already_targeting_one(player, selected)
      return
    end
    if selected.name == square_entity_name then
      player.target_inserter.pickup_position = selected.position
      switch_to_selecting_drop(player, player.target_inserter)
      return
    end
    if selected.name == rect_entity_name then
      -- TODO: impl
      return
    end
    switch_to_idle(player)
  end,

  ["selecting-drop"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if selected.type == "inserter" then
      adjusted_an_inserter_while_already_targeting_one(player, selected)
      return
    end
    if selected.name == ninth_entity_name then
      player.target_inserter.drop_position = selected.position
      switch_to_idle(player)
      return
    end
    if selected.name == rect_entity_name then
      -- TODO: impl
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
