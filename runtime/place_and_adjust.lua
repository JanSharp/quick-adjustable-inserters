
local cursor_direction = require("__quick-adjustable-inserters__.runtime.cursor_direction")
local states = require("__quick-adjustable-inserters__.runtime.states")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

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
  local built_entity = surface.valid and utils.find_ghost_entity(surface, inserter_name, args.position) or nil
  try_reset_cursor(actual_player, item_prototype)
  -- The built_entity valid check here is likely also pointless.
  return built_entity and built_entity.valid and built_entity or nil
end

---@param player PlayerDataQAI
---@param position MapPosition
---@param inserter_name string @ Must be a valid LuaEntityPrototype name.
---@param cache InserterCacheQAI
---@param is_cursor_ghost boolean?
---@return LuaEntity? inserter @ The placed inserter if successful.
local function try_place_held_inserter_and_adjust_it(player, position, inserter_name, cache, is_cursor_ghost)
  if cache.disabled_because_of_tech_level then
    utils.show_error(player, {"qai.cant-adjust-due-to-lack-of-tech"})
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
  utils.snap_build_position(position, args.direction, cache)
  local surface = actual_player.surface
  local inserter
  if is_cursor_ghost then
    args.alt = true
    inserter = build_from_cursor_ghost(actual_player, args, inserter_name)
  else
    -- TODO: build_from_cursor_param.alt was used to make it place a ghost... but that's not a thing anymore?
    args.alt = utils.is_within_build_range(player, position, cache)
    actual_player.build_from_cursor(args)
    if args.alt then
      inserter = surface.valid and utils.find_ghost_entity(surface, inserter_name, position)
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
  states.advance_to_selecting_pickup(player, inserter)
  -- Accept both selecting pickup and selecting drop as states after the call above, because skipping
  -- selecting pickup is possible.
  if player.state ~= "idle" and player.target_inserter == inserter then
    player.pipette_when_done = true
    return inserter.valid and inserter or nil
  end
end

return try_place_held_inserter_and_adjust_it
