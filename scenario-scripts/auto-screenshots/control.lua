
local util = require("__core__.lualib.util")
local vec = require("__inserter-throughput-lib__.vector")

local ev = defines.events

---@param surface LuaSurface
---@param tile_name string
local function fill_chunk_with_tile(surface, tile_name)
  ---@type Tile[]
  local tiles = {}
  for y = 0, 31 do
    for x = 0, 31 do
      tiles[#tiles+1] = {
        name = tile_name,
        position = {x = x, y = y},
      }
    end
  end
  surface.set_tiles(tiles)
  surface.set_chunk_generated_status({x = 0, y = 0}, defines.chunk_generated_status.entities)
end

---@param force LuaForce
---@param tech_level TechnologyLevelQAI
local function set_tech_level(force, tech_level)
  local techs = force.technologies
  techs["long-inserters-1"].researched = tech_level.range >= 2
  techs["long-inserters-2"].researched = tech_level.range >= 3
  techs["near-inserters"].researched = tech_level.drop_offset
  techs["more-inserters-1"].researched = tech_level.diagonal
  techs["more-inserters-2"].researched = tech_level.all_tiles
end

---@param range integer
---@return integer
local function get_actual_range(range)
  return 3 -- NOTE: always overwrite to 3, making screenshots always have the same zoom and size.
end

---@param range integer
local function get_inserter_position(range)
  range = get_actual_range(range)
  return {
    x = range + 1.5,
    y = range + 1.5,
  }
end

---@param surface LuaSurface
---@param player LuaPlayer
---@param range integer
local function place_inserter(surface, player, range)
  local position = get_inserter_position(range)
  storage.inserter = surface.create_entity{
    name = "qai-inserter-for-screenshots",
    position = position,
    direction = defines.direction.south,
    force = "player",
  }
  remote.call("qai", "adjust", player.index, storage.inserter)
end

---@param surface LuaSurface
---@param player LuaPlayer
---@param range integer
---@param relative_position MapPosition
local function adjust_at(surface, player, range, relative_position)
  local position = vec.add(get_inserter_position(range), relative_position)
  local entities = surface.find_entities_filtered{position = position}
  if not entities[1] then error("No entities here.") end
  if entities[2] then error("Too many entities here.") end
  local entity = entities[1]
  remote.call("qai", "adjust", player.index, entity)
end

---@param obj LuaRenderObject @ A polygon.
local function delete_direction_arrow(obj)
  local vertices = obj.vertices
  if vertices[3] and not vertices[4] then
    obj.destroy()
  end
end

---@param color Color
local function is_grey_scale(color)
  return color.r == color.g and color.r == color.b
end

---@param obj LuaRenderObject @ A line.
local function delete_direction_arrow_outline(obj)
  local color = obj.color
  if not is_grey_scale(color) then return end
  local from = obj.from.position--[[@as MapPosition]]
  local to = obj.to.position--[[@as MapPosition]]
  if vec.get_length(vec.sub(from, to)) > 0.75 then return end
  obj.destroy()
end

local function delete_unwanted_rendering_objects()
  for _, obj in pairs(rendering.get_all_objects()) do
    local obj_type = obj.type
    if obj_type == "polygon" then
      delete_direction_arrow(obj)
    elseif obj_type == "line" then
      delete_direction_arrow_outline(obj)
    end
  end
end

local function make_grid_dark()
  for _, obj in pairs(rendering.get_all_objects()) do
    local color = obj.color
    if not is_grey_scale(color) then goto continue end
    color.r = color.r * 0.4
    color.g = color.g * 0.4
    color.b = color.b * 0.4
    obj.color = color
    ::continue::
  end
end

local function un_pre_multiply_colors()
  for _, obj in pairs(rendering.get_all_objects()) do
    local color = obj.color
    color.r = color.r / color.a
    color.g = color.g / color.a
    color.b = color.b / color.a
    obj.color = color
  end
end

local function make_lines_thicker()
  for _, obj in pairs(rendering.get_all_objects()) do
    local obj_type = obj.type
    if obj_type == "line" or obj_type == "rectangle" then
      obj.width = obj.width + 1.99
    end
  end
end

local function make_background_more_opaque()
  for _, obj in pairs(rendering.get_all_objects()) do
    local color = obj.color
    if color.a == 1 then goto continue end
    color.a = 0.4
    obj.color = color
    ::continue::
  end
end

local function turn_green_into_yellow()
  for _, obj in pairs(rendering.get_all_objects()) do
    local color = obj.color
    if is_grey_scale(color) then goto continue end
    obj.color = util.color("#222222")
    -- obj.color = util.color("#FFFF00")
    -- obj.color = util.color("#F59501")
    ::continue::
  end
end

---@param surface LuaSurface
---@param range integer
---@param name string
---@param resolution integer? @ Default: 256
---@param pixels_per_tile number? @ Default: evaluated based on range and resolution
---@param anti_alias boolean?
local function take_screenshot(surface, range, name, resolution, pixels_per_tile, anti_alias)
  resolution = resolution or 256
  pixels_per_tile = pixels_per_tile or (resolution / (get_actual_range(range) * 2 + 1 + 1))
  game.take_screenshot{
    surface = surface,
    position = get_inserter_position(range),
    daytime = 0,
    path = "qai/"..name,
    anti_alias = anti_alias,
    resolution = {resolution, resolution},
    zoom = pixels_per_tile / 32,
    force_render = true,
  }
end

local actions = {}
local delayed_actions = {}
local next_free_tick = 0

---@param tick_count integer
local function wait_ticks(tick_count)
  next_free_tick = next_free_tick + tick_count
end

---@param action fun()
local function add_action(action)
  assert(not actions[next_free_tick])
  actions[next_free_tick] = action
end

---@param name string
---@param action fun()
local function add_delayed_action(name, action)
  assert(not delayed_actions[name])
  delayed_actions[name] = action
end

---@param name string
local function run_delayed_action(name)
  game.tick_paused = true
  storage.player.request_translation{"", name}
end

add_delayed_action("unpause", function()
  game.tick_paused = false
end)

add_action(function()
  fill_chunk_with_tile(storage.surface, "lab-dark-2")
  set_tech_level(storage.force, {
    range = 3,
    drop_offset = false,
    cardinal = true,
    diagonal = true,
    all_tiles = false,
  })
  place_inserter(storage.surface, storage.player, 3)
  adjust_at(storage.surface, storage.player, 3, {x = 0, y = 2})
end)
wait_ticks(30)
add_action(function()
  run_delayed_action("thumbnail")
end)
delayed_actions["thumbnail"] = function()
  game.tick_paused = false
  adjust_at(storage.surface, storage.player, 3, {x = 2, y = -2})
  delete_unwanted_rendering_objects()
  make_lines_thicker()
  take_screenshot(storage.surface, 3, "thumbnail.png", 144, 19, true)
  -- NOTE: The current thumbnail has been edited in gimp afterwards to clean up some of the green lines.
  run_delayed_action("unpause")
end
wait_ticks(1)
add_action(function()
  storage.inserter.destroy()
end)
wait_ticks(29)

---@param name string
---@param pickup_tile MapPosition
---@param drop_tile MapPosition
---@param tech_level TechnologyLevelQAI
local function add_actions_for_tech_icon_screenshot(name, pickup_tile, drop_tile, tech_level)
  add_action(function()
    fill_chunk_with_tile(storage.surface, "qai-transparent")
    set_tech_level(storage.force, tech_level)
    place_inserter(storage.surface, storage.player, 2)
    adjust_at(storage.surface, storage.player, 3, pickup_tile)
  end)
  wait_ticks(30)
  add_action(function()
    run_delayed_action(name)
  end)
  delayed_actions[name] = function()
    game.tick_paused = false
    adjust_at(storage.surface, storage.player, 3, drop_tile)
    delete_unwanted_rendering_objects()
    storage.inserter.destroy()
    make_grid_dark()
    make_lines_thicker()
    turn_green_into_yellow()
    un_pre_multiply_colors()
    make_background_more_opaque()
    take_screenshot(storage.surface, 2, name..".png")
    run_delayed_action("unpause")
  end
  wait_ticks(30)
end

add_actions_for_tech_icon_screenshot(
  "near-inserters",
  {x = 0, y = 1},
  {x = 0, y = -1 + 85/256},
  {
    range = 1,
    drop_offset = true,
    cardinal = true,
    diagonal = false,
    all_tiles = false,
  }
)

add_actions_for_tech_icon_screenshot(
  "long-inserters-1",
  {x = 0, y = 2},
  {x = 0, y = -2},
  {
    range = 2,
    drop_offset = false,
    cardinal = true,
    diagonal = false,
    all_tiles = false,
  }
)

add_actions_for_tech_icon_screenshot(
  "long-inserters-2",
  {x = 0, y = 3},
  {x = 0, y = -3},
  {
    range = 3,
    drop_offset = false,
    cardinal = true,
    diagonal = false,
    all_tiles = false,
  }
)

add_actions_for_tech_icon_screenshot(
  "more-inserters-1",
  {x = -3, y = 3},
  {x = 3, y = -3},
  {
    range = 3,
    drop_offset = false,
    cardinal = true,
    diagonal = true,
    all_tiles = false,
  }
)

add_actions_for_tech_icon_screenshot(
  "more-inserters-2",
  {x = -2, y = 3},
  {x = 2, y = -3},
  {
    range = 3,
    drop_offset = false,
    cardinal = true,
    diagonal = true,
    all_tiles = true,
  }
)

script.on_event(ev.on_player_created, function(event)
  local player = game.get_player(event.player_index) ---@cast player -nil
  player.toggle_map_editor()
  game.tick_paused = false
  storage.player = player
end)

script.on_event(ev.on_tick, function(event)
  local relative_tick = event.tick - storage.start_tick
  local action = actions[relative_tick]
  if action and not storage.ran_actions[relative_tick] then
    storage.ran_actions[relative_tick] = true
    action()
  end
end)

script.on_event(ev.on_string_translated, function(event)
  local delayed_action = delayed_actions[event.result]
  if delayed_action then
    delayed_action()
  end
end)

script.on_init(function()
  storage.start_tick = game.tick + 1
  storage.surface = game.surfaces["nauvis"]
  storage.force = game.forces["player"]
  storage.ran_actions = {}
end)
