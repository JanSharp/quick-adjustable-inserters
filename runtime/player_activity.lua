
local vec = require("__inserter-throughput-lib__.vector")
local consts = require("__quick-adjustable-inserters__.runtime.consts")
local inserter_speed = require("__quick-adjustable-inserters__.runtime.inserter_speed")
local player_data = require("__quick-adjustable-inserters__.runtime.player_data")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

---@type StatesFileQAI
local states

---@param refs {states: StatesFileQAI}
local function set_circular_references(refs)
  states = refs.states
end

local update_player_active_state
do
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
  ---@param is_not_idle boolean? @ When `nil` will be evaluated using the current `player.state`.
  function update_player_active_state(player, is_not_idle)
    is_not_idle = is_not_idle == nil and (player.state ~= "idle") or is_not_idle
    local should_be_active = is_not_idle or player.has_active_inserter_speed_text
    if (player.index_in_active_players ~= nil) == should_be_active then return end
    if should_be_active then
      add_active_player(player)
    else
      remove_active_player(player)
    end
  end
end

---@param player PlayerDataQAI
local function update_active_player(player)
  if not player_data.validate_player(player) then return end

  if player.has_active_inserter_speed_text then
    inserter_speed.update_active_inserter_speed_text(player)
  end

  if not states.validate_target_inserter(player) then return end -- Returns when player is idle.

  local inserter = player.target_inserter
  states.deactivate_inserter(player, inserter)

  if consts.collapse_direction_lut[inserter.direction] ~= player.target_inserter_direction
    or inserter.force_index ~= player.target_inserter_force_index
    or not vec.vec_equals(inserter.position, player.target_inserter_position)
  then
    states.switch_to_idle_and_back(player, true)
    inserter_speed.update_inserter_speed_text(player)
    return
  end

  if not vec.vec_equals(inserter.pickup_position, player.target_inserter_pickup_position)
    or not vec.vec_equals(inserter.drop_position, player.target_inserter_drop_position)
  then
    states.switch_to_idle_and_back(player) -- Don't do reach checks.
    inserter_speed.update_inserter_speed_text(player)
    return
  end

  if utils.should_be_rotatable(player) ~= player.is_rotatable then
    states.switch_to_idle_and_back(player) -- Don't do reach checks.
    -- And don't update inserter speed text.
    return
  end
end

local function update_active_players()
  local active_players = global.active_players
  local next_index = active_players.next_index
  local player = active_players[next_index]
  if player then
    update_active_player(player)
    active_players.next_index = next_index + 1
  else
    active_players.next_index = 1
  end
end

---@class PlayerActivityFileQAI
local player_activity = {
  set_circular_references = set_circular_references,
  update_player_active_state = update_player_active_state,
  update_active_players = update_active_players,
}
return player_activity
