
-- NOTE: Every file has a class annotation on the return value to make the language server emit warnings when
-- trying to use functions or fields that do not exist in the return value of the file.
-- It also allows referencing the class for circular references.

local inserter_throughput = require("__inserter-throughput-lib__.inserter_throughput")
local vec = require("__inserter-throughput-lib__.vector")
local animations = require("__quick-adjustable-inserters__.runtime.animations")
local cursor_direction = require("__quick-adjustable-inserters__.runtime.cursor_direction")
local force_data = require("__quick-adjustable-inserters__.runtime.force_data")
local inserter_speed = require("__quick-adjustable-inserters__.runtime.inserter_speed")
local player_activity = require("__quick-adjustable-inserters__.runtime.player_activity")
local player_data = require("__quick-adjustable-inserters__.runtime.player_data")
local states = require("__quick-adjustable-inserters__.runtime.states")
local try_place_held_inserter_and_adjust_it = require("__quick-adjustable-inserters__.runtime.place_and_adjust")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

utils.set_circular_references{force_data = force_data}
inserter_speed.set_circular_references{states = states, player_activity = player_activity}
player_activity.set_circular_references{states = states}
player_data.set_circular_references{states = states}
force_data.set_circular_references{states = states}

local ev = defines.events

local get_player = player_data.get_player
local get_or_init_player = player_data.get_or_init_player

script.on_event(ev.on_tick, function(event)
  player_activity.update_active_players()
  animations.update_animations()
end)

if script.active_mods["RenaiTransportation"] then
  -- Throwers are managed and scripted using an on_nth_tick handler every 3 ticks. This logic also manages the
  -- active states of the inserter, however while adjusting an inserter it should stay inactive. on_tick in
  -- qai is already doing that, however on_nth_tick seems to run after on_tick, so the inserter ends up being
  -- active for 1 tick and then inactive for 2 ticks. With the hidden optional dependency and also handling
  -- on_nth_tick 3 in here this flashing no longer happens.
  script.on_nth_tick(3, function(event)
    player_activity.ensure_all_active_players_inserters_are_inactive()
  end)
end

script.on_event("qai-adjust", function(event)
  local player = get_player(event)
  if not player then return end
  local place_result, is_cursor_ghost = utils.get_cursor_item_place_result(player)
  if place_result and place_result.type == "inserter" then
    local force = force_data.get_or_init_force(player.player.force_index)
    local name = place_result.name
    local cache = force and force.inserter_cache_lut[name]
    if cache then
      try_place_held_inserter_and_adjust_it(player, event.cursor_position, name, cache, is_cursor_ghost)
      return
    end
  end

  states.adjust(player, utils.get_redirected_selected_entity(player.player.selected))
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

  if not player.pipette_copies_vectors or not utils.is_real_or_ghost_inserter(selected) then return end
  local force = force_data.get_or_init_force(player.force_index)
  if not force then return end
  local name = utils.get_real_or_ghost_name(selected)
  local cache = force.inserter_cache_lut[name]
  if not cache or cache.disabled_because_of_tech_level then return end
  player_data.save_pipetted_vectors(player, name, selected)
end)

script.on_event(ev.on_player_cursor_stack_changed, function(event)
  local player = get_player(event)
  if not player then return end
  player_data.validate_cursor_stack_associated_data(player)
end)

script.on_event(ev.on_selected_entity_changed, function(event)
  local player = get_player(event)
  if not player then return end
  states.update_default_drop_highlight(player)
  states.update_mirrored_highlight(player)
  inserter_speed.update_inserter_speed_text(player)
end)

script.on_event(ev.on_entity_settings_pasted, function(event)
  local player = get_player(event)
  if player then
    -- It won't update for other players hovering the inserter. It is not worth adding logic for that.
    inserter_speed.update_inserter_speed_text(player)
  end
  local destination = event.destination
  if destination.type ~= "inserter" then return end
  player = player_data.validate_player(storage.inserters_in_use[utils.get_id(destination)])
  if not player then return end
  states.switch_to_idle_and_back(player)
  inserter_speed.update_inserter_speed_text(player)
end)

script.on_event(ev.on_runtime_mod_setting_changed, function(event)
  if event.setting == "qai-mirrored-inserters-only" then
    force_data.update_only_allow_mirrored_setting()
    return
  end
  if event.setting == "qai-range-for-long-inserters" then
    force_data.update_range_for_long_inserters_setting()
    return
  end
  -- Per player settings.
  local update_setting = player_data.update_setting_lut[event.setting]
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
      or (not player.no_reach_checks and not utils.can_reach_entity(player, inserter))
    then
      states.switch_to_idle(player)
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
      inserter_speed.update_inserter_speed_text(player)
    end
    player = player_data.validate_player(storage.inserters_in_use[utils.get_id(event.entity)])
    if player then
      states.switch_to_idle_and_back(player, do_check_reach)
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
    local player = player_data.validate_player(storage.inserters_in_use[utils.get_id(event.entity)])
    if not player then return end
    states.switch_to_idle(player)
  end, {
    {filter = "type", type = "inserter"},
    {mode = "or", filter = "ghost_type", type = "inserter"},
  })
end

script.on_event(ev.on_post_entity_died, function(event)
  local ghost = event.ghost
  if not ghost then return end
  local player = player_data.validate_player(storage.inserters_in_use[event.unit_number])
  if not player then return end
  states.switch_to_idle_and_back(player, false, ghost)
end, {{filter = "type", type = "inserter"}})

---@param entity LuaEntity
---@return boolean
local function potential_revive(entity)
  local player = player_data.validate_player(
    storage.inserters_in_use[entity.unit_number] or storage.inserters_in_use[utils.get_ghost_id(entity)]
  )
  if not player then return false end
  states.switch_to_idle_and_back(player, false, entity)
  return true
end

script.on_event(ev.script_raised_revive, function(event)
  potential_revive(event.entity)
end, {{filter = "type", type = "inserter"}})

script.on_event(ev.on_robot_built_entity, function(event)
  potential_revive(event.entity)
end, {{filter = "type", type = "inserter"}})

script.on_event(ev.on_built_entity, function(event)
  local entity = event.entity
  local entity_type = inserter_throughput.get_real_or_ghost_entity_type(entity)
  if entity_type ~= "inserter" then
    local player = get_player(event)
    if not player then return end
    cursor_direction.handle_built_rail_connectable_or_offshore_pump(player, entity, entity_type)
    return
  end

  if not utils.is_ghost[entity] and potential_revive(entity) then return end
  local player = get_player(event)
  if not player then return end
  player_data.validate_cursor_stack_associated_data(player)
  local expected_name = player.pipetted_inserter_name
  if not expected_name then return end
  if utils.get_real_or_ghost_name(entity) ~= expected_name then return end
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

---@param event EventData.on_research_finished|EventData.on_research_reversed
script.on_event({ev.on_research_finished, ev.on_research_reversed}, function(event)
  local research = event.research
  if not utils.do_we_care_about_this_technology(research.name) then return end
  local force = force_data.get_force(research.force.index)
  if not force then return end
  force_data.update_tech_level_for_force(force)
end)

script.on_event(ev.on_force_reset, function(event)
  local force = force_data.get_force(event.force.index)
  if not force then return end
  force_data.update_tech_level_for_force(force)
end)

---@param force LuaForce
local function recheck_players_in_force(force)
  for _, actual_player in ipairs(force.players) do
    local player = player_data.get_player_raw(actual_player.index)
    if player then
      states.switch_to_idle_and_back(player)
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
  states.switch_to_idle_and_back(player)
  inserter_speed.update_inserter_speed_text(player)
end)

script.on_event(ev.on_player_display_scale_changed, function(event)
  local player = get_player(event)
  if not player then return end
  inserter_speed.update_inserter_speed_text_scale(player)
end)

script.on_configuration_changed(function(event)
  -- Ignore the event if this mod has just been added, since on_init ran already anyway.
  local mod_changes = event.mod_changes["quick-adjustable-inserters"]
  if mod_changes and not mod_changes.old_version then return end

  -- Technically this only needs to be updated when the mod version is older than 1.1.4, or while smart
  -- inserters is enabled or when smart inserters is removed. But updating the setting is cheap, so adding all
  -- of those checks just isn't worth it.
  force_data.update_range_for_long_inserters_setting(true)

  -- Do this before updating forces, because updating forces potentially involves changing player states.
  for _, player in utils.safer_pairs(storage.players) do
    if player_data.validate_player(player) then
      player.pipette_when_done = nil
      player_data.clear_pipetted_inserter_data(player)
    end
  end

  -- It is expected for on_configuration_changed to switch all players to idle and back. Updating all tech
  -- levels does currently ultimately do that. If at any point that isn't guaranteed anymore, there must be
  -- a loop through all players in here to switch them to idle and back.
  force_data.update_tech_level_for_all_forces()
end)

script.on_event(ev.on_force_created, function(event)
  force_data.init_force(event.force) -- This can unfortunately cause a little lag spike.
end)

script.on_event(ev.on_forces_merged, function(event)
  -- Merging forces raises the player changed force event, so nothing else to do here.
  force_data.remove_force_index(event.source_index)
end)

script.on_event(ev.on_player_joined_game, function(event)
  local player = get_player(event)
  if not player then return end
  cursor_direction.on_player_joined(player)
end)

script.on_event(ev.on_player_left_game, function(event)
  local player = get_player(event)
  if not player then return end
  states.switch_to_idle(player)
end)

script.on_event(ev.on_player_created, function(event)
  player_data.init_player(game.get_player(event.player_index)--[[@as LuaPlayer]])
end)

script.on_event(ev.on_player_removed, function(event)
  -- It might legitimately already have been removed through another mod raising an event which causes this
  -- mod to call get_player, which checks player validity and then removes the player. Said other mod would
  -- have to do so in its on_player_removed handler and come before this mod in mod load order.
  local player = storage.players[event.player_index]
  if not player then return end
  player_data.remove_player(player)
end)

script.on_load(function()
  utils.try_override_can_reach_entity()
end)

script.on_init(function()
  utils.try_override_can_reach_entity()
  ---@type StorageDataQAI
  storage = {
    data_structure_version = 5,
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
  force_data.update_range_for_long_inserters_setting(true)
  for _, force in pairs(game.forces) do
    force_data.init_force(force)
  end
  for _, player in pairs(game.players) do
    player_data.init_player(player)
  end
end)

remote.add_interface("qai", {
  ---The mod and the entire world could be in any state after this call.
  ---@param player_index integer
  switch_to_idle = function(player_index)
    local player = get_or_init_player(player_index)
    if not player then return end
    states.switch_to_idle(player)
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
    states.switch_to_idle_and_back(player, do_check_reach)
  end,
  ---The mod and the entire world could be in any state after this call.
  ---@param player_index integer
  ---@param selected_entity LuaEntity?
  adjust = function(player_index, selected_entity)
    local player = get_or_init_player(player_index)
    if not player then return end
    states.adjust(player, selected_entity)
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
    local place_result, is_cursor_ghost = utils.get_cursor_item_place_result(player)
    if place_result and place_result.type == "inserter" then
      local force = force_data.get_or_init_force(player.player.force_index)
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
