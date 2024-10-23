
local inserter_throughput = require("__inserter-throughput-lib__.inserter_throughput")
local vec = require("__inserter-throughput-lib__.vector")
local consts = require("__quick-adjustable-inserters__.runtime.consts")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

---@type StatesFileQAI
local states
---@type PlayerActivityFileQAI
local player_activity

---@param refs {states: StatesFileQAI, player_activity: PlayerActivityFileQAI}
local function set_circular_references(refs)
  states = refs.states
  player_activity = refs.player_activity
end

---@param player PlayerDataQAI
local function hide_inserter_speed_text(player)
  local obj = player.inserter_speed_text_obj
  if obj and obj.valid then
    obj.visible = false
  end
  player.has_active_inserter_speed_text = false
  player.inserter_speed_reference_inserter = nil
  player.inserter_speed_stack_size = nil
  player.inserter_speed_pickup_position = nil
  player.inserter_speed_drop_position = nil
  player_activity.update_player_active_state(player)
end

---@param player PlayerDataQAI
local function destroy_inserter_speed_text(player)
  if player.inserter_speed_text_obj then
    player.inserter_speed_text_obj.destroy()
    player.inserter_speed_text_obj = nil
    player.inserter_speed_text_surface_index = nil
  end
end

local function format_inserter_speed(items_per_second, is_estimate)
  return string.format((is_estimate and "~ " or "").."%.3f/s", items_per_second)
end

---Using `display_scale` for better support for large displays. Not going directly off of `display_resolution`
---because the pixel density is unknown, however players will adjust the scale to make the GUI look good,
---which is basically them adjusting based on pixel density.
---@param player PlayerDataQAI
---@return number
local function get_scale_for_inserter_speed_text(player)
  return 1.5 * player.player.display_scale
end

---@param player PlayerDataQAI
---@param position MapPosition
---@param items_per_second number
---@param is_estimate boolean
---@param reference_inserter LuaEntity
local function set_inserter_speed_text(player, position, items_per_second, is_estimate, reference_inserter)
  player.has_active_inserter_speed_text = true
  player.inserter_speed_reference_inserter = reference_inserter
  player.inserter_speed_stack_size = reference_inserter.inserter_target_pickup_count
  player.inserter_speed_pickup_position = reference_inserter.pickup_position
  player.inserter_speed_drop_position = reference_inserter.drop_position
  player_activity.update_player_active_state(player)

  local obj = player.inserter_speed_text_obj
  local surface_index = reference_inserter.surface_index
  if not obj or not obj.valid or player.inserter_speed_text_surface_index ~= surface_index then
    if obj then obj.destroy() end -- Was on a different surface.
    player.inserter_speed_text_surface_index = surface_index
    player.inserter_speed_text_obj = rendering.draw_text{
      -- Can't use `player.current_surface_index` because that's nil when idle.
      surface = surface_index,
      players = {player.player_index},
      color = {1, 1, 1},
      target = position,
      text = format_inserter_speed(items_per_second, is_estimate),
      scale = get_scale_for_inserter_speed_text(player),
      scale_with_zoom = true,
      vertical_alignment = "middle",
    }
    return
  end
  obj.text = format_inserter_speed(items_per_second, is_estimate)
  obj.target = position
  obj.visible = true
  obj.bring_to_front()
end

---@param player PlayerDataQAI
local function update_inserter_speed_text_scale(player)
  local obj = player.inserter_speed_text_obj
  if not obj or not obj.valid then return end
  obj.scale = get_scale_for_inserter_speed_text(player)
end

---@param player PlayerDataQAI
---@param selected_position MapPosition @ Position of the selected square or ninth.
---@return number items_per_second
---@return boolean is_estimate
local function estimate_inserter_speed(player, selected_position)
  local cache = player.target_inserter_cache
  local target_inserter = player.target_inserter
  local target_inserter_position = player.target_inserter_position
  local quality = target_inserter.quality
  ---@type InserterThroughputDefinition
  local def = {
    inserter = {
      extension_speed = cache.prototype.get_inserter_extension_speed(quality)--[[@as number]],
      rotation_speed = cache.prototype.get_inserter_rotation_speed(quality)--[[@as number]],
      chases_belt_items = cache.chases_belt_items,
      stack_size = inserter_throughput.get_stack_size(target_inserter),
      direction = target_inserter.direction,
      inserter_position_in_tile = inserter_throughput.get_position_in_tile(target_inserter_position),
    },
  }

  if player.state == "selecting-pickup" then
    inserter_throughput.pickup_from_position_and_set_pickup_vector(
      def,
      player.current_surface,
      selected_position,
      target_inserter,
      target_inserter_position
    )
    if not storage.only_allow_mirrored then
      inserter_throughput.drop_to_drop_target_of_inserter_and_set_drop_vector(def, target_inserter)
    else
      local drop_position = vec.copy(selected_position)
      utils.mirror_position(player, drop_position)
      inserter_throughput.drop_to_position_and_set_drop_vector(
        def,
        player.current_surface,
        utils.calculate_actual_drop_position(player, drop_position, true),
        target_inserter,
        target_inserter_position
      )
    end
  else
    inserter_throughput.pickup_from_pickup_target_of_inserter_and_set_pickup_vector(def, target_inserter)
    inserter_throughput.drop_to_position_and_set_drop_vector(
      def,
      player.current_surface,
      utils.calculate_actual_drop_position(player, selected_position),
      target_inserter,
      target_inserter_position
    )
  end

  return inserter_throughput.estimate_inserter_speed(def), inserter_throughput.is_estimate(def)
end

---@param inserter LuaEntity
---@return number items_per_second
---@return boolean is_estimate
local function estimate_inserter_speed_for_inserter(inserter)
  local def = inserter_throughput.make_full_definition_for_inserter(inserter)
  return inserter_throughput.estimate_inserter_speed(def), inserter_throughput.is_estimate(def)
end

---@param inserter LuaEntity
local function get_inserter_speed_position_next_to_inserter(inserter)
  local prototype = utils.get_real_or_ghost_prototype(inserter)
  local box = prototype.selection_box
  local offset = math.max(-box.left_top.x, -box.left_top.y, box.right_bottom.x, box.right_bottom.y)
  local position = inserter.position
  position.x = position.x + offset + 0.15
  return position
end

---@param player PlayerDataQAI
---@param inserter LuaEntity
---@param position MapPosition
local function update_inserter_speed_text_using_inserter(player, inserter, position)
  local items_per_second, is_estimate = estimate_inserter_speed_for_inserter(inserter)
  set_inserter_speed_text(player, position, items_per_second, is_estimate, inserter)
end

---@param player PlayerDataQAI
---@param selectable LuaEntity
local function get_inserter_speed_position_next_to_selectable(player, selectable)
  local position = selectable.position
  if selectable.name == consts.ninth_entity_name then
    utils.snap_position_to_tile_center_relative_to_inserter(player, position)
  end
  position.x = position.x + 0.6
  return position
end

---@param player PlayerDataQAI
local function update_inserter_speed_text(player)
  -- There are a few cases where this function gets called where the target inserter is already guaranteed to
  -- be valid, however a lot of the time that is not the case. So just always validate.
  states.validate_target_inserter(player)

  local actual_selected = player.player.selected
  local selected = utils.get_redirected_selected_entity(actual_selected)
  if not selected then
    hide_inserter_speed_text(player)
    return
  end
  ---@cast actual_selected -nil

  local show_due_to_state = player.state == "selecting-drop" and player.show_throughput_on_drop
    or player.state == "selecting-pickup" and (
      player.show_throughput_on_pickup
        or utils.should_skip_selecting_drop(player) and player.show_throughput_on_drop
    )

  if (show_due_to_state
      and selected == player.target_inserter
    )
    or (player.show_throughput_on_inserter
      and utils.is_real_or_ghost_inserter(selected)
      and selected.force.is_friend(player.force_index)
    )
  then
    local position = utils.is_real_or_ghost_inserter(actual_selected)
      and get_inserter_speed_position_next_to_inserter(actual_selected)
      or get_inserter_speed_position_next_to_selectable(player, actual_selected)
    update_inserter_speed_text_using_inserter(player, selected, position)
    return
  end

  if not show_due_to_state then
    hide_inserter_speed_text(player)
    return
  end

  local name = selected.name
  if not (name == consts.square_entity_name or name == consts.ninth_entity_name) ---@cast selected -nil
    or storage.selectable_entities_to_player_lut[selected.unit_number] ~= player
  then
    hide_inserter_speed_text(player)
    return
  end

  local position = selected.position
  local items_per_second, is_estimate = estimate_inserter_speed(player, position)
  if name == consts.ninth_entity_name then
    utils.snap_position_to_tile_center_relative_to_inserter(player, position)
  end
  position.x = position.x + 0.6
  set_inserter_speed_text(player, position, items_per_second, is_estimate, player.target_inserter)
end

---@param player PlayerDataQAI
local function update_active_inserter_speed_text(player)
  local inserter = player.inserter_speed_reference_inserter
  if not inserter.valid then return end

  local current_stack_size = inserter.inserter_target_pickup_count
  if current_stack_size ~= player.inserter_speed_stack_size then
    -- `inserter_speed_stack_size` gets updated by `update_inserter_speed_text`.
    update_inserter_speed_text(player)
    return
  end

  if player.state ~= "idle" and player.target_inserter == inserter then
    return -- Pickup and drop positions get compared by regular active player update in this case.
  end

  if not vec.vec_equals(inserter.pickup_position, player.inserter_speed_pickup_position)
    or not vec.vec_equals(inserter.drop_position, player.inserter_speed_drop_position)
  then
    update_inserter_speed_text(player)
    return
  end
end

---@class InserterSpeedFileQAI
local inserter_speed = {
  set_circular_references = set_circular_references,
  destroy_inserter_speed_text = destroy_inserter_speed_text,
  update_inserter_speed_text_scale = update_inserter_speed_text_scale,
  update_inserter_speed_text = update_inserter_speed_text,
  update_active_inserter_speed_text = update_active_inserter_speed_text,
}
return inserter_speed
