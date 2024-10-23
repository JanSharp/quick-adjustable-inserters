
local vec = require("__inserter-throughput-lib__.vector")
local cursor_direction = require("__quick-adjustable-inserters__.runtime.cursor_direction")
local inserter_speed = require("__quick-adjustable-inserters__.runtime.inserter_speed")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

---@type StatesFileQAI
local states

---@param refs {states: StatesFileQAI}
local function set_circular_references(refs)
  states = refs.states
end

local remove_player

---@param player PlayerDataQAI?
---@return PlayerDataQAI?
local function validate_player(player)
  if not player then return end
  if player.player.valid then return player end
  remove_player(player)
end

---@param player_index uint32
---@return PlayerDataQAI?
local function get_player_raw(player_index)
  return validate_player(storage.players[player_index])
end

---@param event EventData|{player_index: uint32}
---@return PlayerDataQAI?
local function get_player(event)
  return get_player_raw(event.player_index)
end

---Supports all directions, not just 4.
---@param player PlayerDataQAI
---@param inserter_name string
---@param inserter LuaEntity
local function save_pipetted_vectors(player, inserter_name, inserter)
  local direction = inserter.direction
  local position = inserter.position
  player.pipetted_inserter_name = inserter_name
  player.pipetted_pickup_vector = vec.rotate_by_direction(vec.sub(inserter.pickup_position, position), (-direction)--[[@as defines.direction]])
  player.pipetted_drop_vector = vec.rotate_by_direction(vec.sub(inserter.drop_position, position), (-direction)--[[@as defines.direction]])
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
local function extra_clean_up_for_removed_player(player, target_inserter)
  inserter_speed.destroy_inserter_speed_text(player)
  states.forget_about_restoring(player, target_inserter)
end

---@param player PlayerDataQAI
---@param setting_name string
---@param field_name string
local function update_show_throughput_on_player(player, setting_name, field_name)
  local new_value = settings.get_player_settings(player.player_index)[setting_name].value--[[@as boolean]]
  if new_value == player[field_name] then return end
  player[field_name] = new_value
  inserter_speed.update_inserter_speed_text(player)
end

---@param player PlayerDataQAI
local function clear_pipetted_inserter_data(player)
  player.pipetted_inserter_name = nil
  player.pipetted_pickup_vector = nil
  player.pipetted_drop_vector = nil
end

---Since on_player_cursor_stack_changed gets raised at the end of the tick, make sure to validate associated
---data every time any of said data gets used, since the cursor could have changed already in this tick.
---@param player PlayerDataQAI
local function validate_cursor_stack_associated_data(player)
  local cursor_item = utils.get_cursor_item_prototype(player)
  if cursor_item then
    -- pipette_when_done is related to states, but also related to cursor stack. So it's here, I guess.
    player.pipette_when_done = nil
  end
  if not cursor_item or cursor_item.name ~= player.pipetted_inserter_name then
    clear_pipetted_inserter_data(player)
  end
end

---@type table<string, fun(player: PlayerDataQAI)>
local update_setting_lut = {
  ["qai-show-throughput-on-inserter"] = function(player)
    update_show_throughput_on_player(player, "qai-show-throughput-on-inserter", "show_throughput_on_inserter")
  end,
  ["qai-show-throughput-on-pickup"] = function(player)
    update_show_throughput_on_player(player, "qai-show-throughput-on-pickup", "show_throughput_on_pickup")
  end,
  ["qai-show-throughput-on-drop"] = function(player)
    update_show_throughput_on_player(player, "qai-show-throughput-on-drop", "show_throughput_on_drop")
  end,
  ["qai-highlight-default-drop-offset"] = function(player)
    local new_value = settings.get_player_settings(player.player_index)["qai-highlight-default-drop-offset"].value--[[@as boolean]]
    if new_value == player.highlight_default_drop_offset then return end
    player.highlight_default_drop_offset = new_value
    if player.highlight_default_drop_offset then
      states.update_default_drop_highlight(player)
    else
      states.destroy_default_drop_highlight(player)
    end
  end,
  ["qai-always-use-default-drop-offset"] = function(player)
    local new_value = settings.get_player_settings(player.player_index)["qai-always-use-default-drop-offset"].value--[[@as boolean]]
    if new_value == player.always_use_default_drop_offset then return end
    player.always_use_default_drop_offset = new_value
    states.switch_to_idle_and_back(player)
  end,
  ["qai-pipette-after-place-and-adjust"] = function(player)
    local new_value = settings.get_player_settings(player.player_index)["qai-pipette-after-place-and-adjust"].value--[[@as boolean]]
    player.pipette_after_place_and_adjust = new_value
  end,
  ["qai-pipette-copies-vectors"] = function(player)
    local new_value = settings.get_player_settings(player.player_index)["qai-pipette-copies-vectors"].value--[[@as boolean]]
    if new_value == player.pipette_copies_vectors then return end
    player.pipette_copies_vectors = new_value
    if not player.pipette_copies_vectors then
      clear_pipetted_inserter_data(player)
    end
  end,
}

---@param actual_player LuaPlayer
---@return PlayerDataQAI
local function init_player(actual_player)
  local player_settings = settings.get_player_settings(actual_player)
  ---@type PlayerDataQAI
  local player = {
    player = actual_player,
    player_index = actual_player.index,
    force_index = actual_player.force_index--[[@as uint8]],
    state = "idle",
    used_squares = {},
    used_ninths = {},
    used_rects = {},
    line_objs = {},
    direction_arrows_indicator_line_objs = {},
    show_throughput_on_inserter = player_settings["qai-show-throughput-on-inserter"].value--[[@as boolean]],
    show_throughput_on_pickup = player_settings["qai-show-throughput-on-pickup"].value--[[@as boolean]],
    show_throughput_on_drop = player_settings["qai-show-throughput-on-drop"].value--[[@as boolean]],
    highlight_default_drop_offset = player_settings["qai-highlight-default-drop-offset"].value--[[@as boolean]],
    always_use_default_drop_offset = player_settings["qai-always-use-default-drop-offset"].value--[[@as boolean]],
    pipette_after_place_and_adjust = player_settings["qai-pipette-after-place-and-adjust"].value--[[@as boolean]],
    pipette_copies_vectors = player_settings["qai-pipette-copies-vectors"].value--[[@as boolean]],
  }
  cursor_direction.init_player(player)
  storage.players[player.player_index] = player
  return player
end

---@param player PlayerDataQAI
function remove_player(player)
  states.switch_to_idle(player)
  storage.players[player.player_index] = nil
end

---Can be called if the given `player_index` actually no longer exists at this point in time.
---@param player_index integer
---@return PlayerDataQAI?
local function get_or_init_player(player_index)
  local player = get_player_raw(player_index)
  if player then return player end
  local actual_player = game.get_player(player_index)
  return actual_player and init_player(actual_player) or nil
end

---@class PlayerDataFileQAI
local player_data = {
  set_circular_references = set_circular_references,
  validate_player = validate_player,
  get_player_raw = get_player_raw,
  get_player = get_player,
  save_pipetted_vectors = save_pipetted_vectors,
  extra_clean_up_for_removed_player = extra_clean_up_for_removed_player,
  clear_pipetted_inserter_data = clear_pipetted_inserter_data,
  validate_cursor_stack_associated_data = validate_cursor_stack_associated_data,
  update_setting_lut = update_setting_lut,
  init_player = init_player,
  remove_player = remove_player,
  get_or_init_player = get_or_init_player,
}
return player_data
