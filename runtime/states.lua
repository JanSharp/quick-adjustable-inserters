
local animations = require("__quick-adjustable-inserters__.runtime.animations")
local consts = require("__quick-adjustable-inserters__.runtime.consts")
local force_data = require("__quick-adjustable-inserters__.runtime.force_data")
local inserter_speed = require("__quick-adjustable-inserters__.runtime.inserter_speed")
local player_activity = require("__quick-adjustable-inserters__.runtime.player_activity")
local player_data = require("__quick-adjustable-inserters__.runtime.player_data")
local selectables = require("__quick-adjustable-inserters__.runtime.selectables")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

---@param player PlayerDataQAI
local function destroy_default_drop_highlight(player)
  local entity = player.default_drop_highlight
  player.default_drop_highlight = nil
  utils.destroy_entity_safe(entity)
end

---@param player PlayerDataQAI
local function destroy_mirrored_highlight(player)
  local entity = player.mirrored_highlight
  player.mirrored_highlight = nil
  utils.destroy_entity_safe(entity)
end

---@param player PlayerDataQAI
local function confirm_rendering_was_kept_successfully(player)
  player.rendering_is_floating_while_idle = nil
end

---@param player PlayerDataQAI
---@param inserter LuaEntity
local function deactivate_inserter(player, inserter)
  if utils.is_ghost[inserter] then return end -- Ghosts are always inactive.
  if inserter.active then -- If another mod already deactivated it then this mod shall not reactivate it.
    inserter.active = false
    player.reactivate_inserter_when_done = true
  end
end

---@param inserter LuaEntity
local function reactivate_inserter(inserter)
  if utils.is_ghost[inserter] then return end -- Ghosts are always inactive.
  if inserter.valid then
    inserter.active = true
  end
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
local function forget_about_restoring(player, target_inserter)
  player.reactivate_inserter_when_done = nil
  reactivate_inserter(target_inserter)
  player.pipette_when_done = nil
end

---Can raise an event.
---@param player PlayerDataQAI
---@param target_inserter LuaEntity @ Can be invalid.
---@param surface LuaSurface @ Can be invalid.
---@param inserter_position MapPosition
local function restore_after_adjustment(player, target_inserter, surface, inserter_position)
  if player.reactivate_inserter_when_done then
    player.reactivate_inserter_when_done = nil
    reactivate_inserter(target_inserter)
  end

  player_data.validate_cursor_stack_associated_data(player)
  if player.pipette_when_done then
    player.pipette_when_done = nil
    if not player.pipette_after_place_and_adjust or not target_inserter.valid then goto leave_pipette end
    local name = utils.get_real_or_ghost_name(target_inserter)
    player.player.pipette_entity(utils.is_ghost[target_inserter] and name or target_inserter)
    -- Manually set the cursor_ghost for 2 reasons:
    -- 1) pipette_entity does not set a ghost cursor even though the "Pick ghost item if no items are available"
    --    setting is enabled.
    -- 2) the pipette_when_done feature works in cohesion with place and adjust feature. Therefore the point
    --    is for the player to be able to place an inserter ghost, adjust it immediately, and then continue
    --    placing ghosts. So basically this doesn't care about the setting mentioned above.
    -- There is the issue that the game plays the error sound in the pipette_entity call when the player does
    -- not have any items to build that inserter anymore. That is how it is.
    local cursor = player.player.cursor_stack
    if cursor and not cursor.valid_for_read and not player.player.cursor_ghost then
      local items = (game.entity_prototypes[name]--[[@as LuaEntityPrototype]]).items_to_place_this
      local item = items and items[1]
      player.player.cursor_ghost = item and item.name
    end

    if not surface.valid then goto leave_pipette end
    ---@diagnostic disable-next-line: cast-local-type
    target_inserter = target_inserter.valid
      and target_inserter
      or utils.find_real_or_ghost_entity(surface, name, inserter_position)
    if not player.pipette_copies_vectors or not target_inserter then goto leave_pipette end
    local place_result = utils.get_cursor_item_place_result(player)
    if place_result and place_result.name == name then
      player_data.save_pipetted_vectors(player, name--[[@as string]], target_inserter)
    end
  end
  ::leave_pipette::
end

---This function can raise an event, so make sure to expect the world to be in any state after calling it.
---This includes the state of this mod. Calling switch_to_idle does not mean that the player's state will
---actually be idle afterwards.
---@param player PlayerDataQAI
---@param keep_rendering boolean? @ When true, no rendering objects will get destroyed.
---@param do_not_restore boolean? @ When true, do not script enable the inserter and do not pipette it.
local function switch_to_idle(player, keep_rendering, do_not_restore)
  if player.state == "idle" then return end
  local target_inserter = player.target_inserter
  local surface = player.current_surface
  local position = player.target_inserter_position

  player.current_surface_index = nil
  player.current_surface = nil
  selectables.destroy_entities(player.used_squares)
  selectables.destroy_entities(player.used_ninths)
  selectables.destroy_entities(player.used_rects)
  selectables.destroy_dummy_pickup_square(player)
  destroy_default_drop_highlight(player)
  destroy_mirrored_highlight(player)
  player.rendering_is_floating_while_idle = keep_rendering
  if not keep_rendering or global.only_allow_mirrored then
    animations.destroy_grid_lines_and_background(player)
  end
  if not keep_rendering then
    animations.destroy_everything_but_grid_lines_and_background(player)
  end
  utils.remove_id(player.target_inserter_id)
  global.inserters_in_use[player.target_inserter_id] = nil
  player_activity.update_player_active_state(player, false)
  player.target_inserter_id = nil
  player.target_inserter = nil
  player.target_inserter_cache = nil
  player.target_inserter_position = nil
  player.target_inserter_pickup_position = nil
  player.target_inserter_drop_position = nil
  player.target_inserter_direction = nil
  player.target_inserter_force_index = nil
  player.should_flip = nil
  player.is_rotatable = nil
  player.no_reach_checks = nil
  player.state = "idle"

  local actual_player = player.player
  if not actual_player.valid then -- Only happens when coming from `remove_player()`.
    player_data.extra_clean_up_for_removed_player(player, target_inserter)
    return
  end

  inserter_speed.update_inserter_speed_text(player)

  if not do_not_restore then
    restore_after_adjustment(player, target_inserter, surface, position)
  end
end

---@param player PlayerDataQAI
local function update_direction_arrow(player)
  rendering.set_orientation(player.direction_arrow_id, player.target_inserter.orientation)
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
  local actual_direction = consts.inverse_direction_lut[new_direction]
  inserter.direction = actual_direction
  inserter.pickup_position = pickup_position
  inserter.drop_position = drop_position
  player.target_inserter_direction = actual_direction
end

local switch_to_idle_and_back

---@param player PlayerDataQAI
---@param new_direction defines.direction @
---If you look at the feet of the inserter, the forwards pointing feet should be the direction this variable
---is defining.\
---Only accepts 4 directions. If the direction is obtained from "simple-entity-with-owner" then nothing needs
---to be done because those can only have 4 directions anyway.
local function set_direction_and_update_arrow(player, new_direction)
  -- Recheck if the inserter is rotatable. Don't recheck the cache, because that's a static prototype flag.
  if not player.target_inserter.rotatable then
    switch_to_idle_and_back(player)
    return
  end
  set_direction(player, new_direction)
  update_direction_arrow(player)
end

local validate_target_inserter

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---It should only perform reach checks when the player is selecting a new inserter. Any other state switching
---should not care about being out of reach. Going out of reach while adjusting an inserter is handled in the
---player position changed event, which is raised for each tile the player moves.
---@param do_check_reach boolean?
---@param carry_over_no_reach_checks boolean?
---@return boolean
local function try_set_target_inserter(player, target_inserter, do_check_reach, carry_over_no_reach_checks)
  local force = force_data.get_or_init_force(player.force_index)
  if not force then return false end
  -- Can't use get_cache_for_inserter because the force not existing is handled differently here.

  local cache = force.inserter_cache_lut[utils.get_real_or_ghost_name(target_inserter)]
  if not cache then
    return utils.show_error(player, {"qai.cant-change-inserter-at-runtime"})
  end

  if cache.disabled_because_of_tech_level then
    return utils.show_error(player, {"qai.cant-adjust-due-to-lack-of-tech"})
  end

  -- Specifically check if the force of the inserter is friends with the player. Friendship is one directional.
  if not target_inserter.force.is_friend(player.force_index) then
    return utils.show_error(player, {"qai.cant-adjust-enemy-inserters"})
  end

  if not target_inserter.operable then
    return utils.show_error(player, {"not-operable"})
  end

  if do_check_reach
    and not carry_over_no_reach_checks
    and not utils.can_reach_entity(player, target_inserter)
  then
    return utils.show_error(player, {"cant-reach"})
  end

  local id = utils.get_or_create_id(target_inserter)
  if player_data.validate_player(global.inserters_in_use[id]) then
    return utils.show_error(player, {"qai.only-one-player-can-adjust"})
  end

  global.inserters_in_use[id] = player
  player_activity.update_player_active_state(player, true)
  player.target_inserter_id = id
  player.target_inserter = target_inserter
  player.target_inserter_cache = cache
  player.target_inserter_position = target_inserter.position
  player.target_inserter_pickup_position = target_inserter.pickup_position
  player.target_inserter_drop_position = target_inserter.drop_position
  local direction = consts.collapse_direction_lut[target_inserter.direction]
  player.target_inserter_direction = direction
  player.target_inserter_force_index = target_inserter.force_index
  player.should_flip = not player.target_inserter_cache.is_square
    and consts.is_east_or_west_lut[direction]
  player.is_rotatable = utils.should_be_rotatable(player)
  player.current_surface_index = target_inserter.surface_index
  player.current_surface = target_inserter.surface
  player.no_reach_checks = carry_over_no_reach_checks or utils.is_ghost[target_inserter]
  return true
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
---@return boolean success
local function ensure_is_idle_and_try_set_target_inserter(player, target_inserter, do_check_reach)
  -- If we are in here because of a raised event during another switch_to_idle call, we must first clean up
  -- the rendering objects for that were potentially kept alive in that call.
  animations.destroy_all_rendering_objects_if_kept_rendering(player)
  local prev_target_inserter = player.target_inserter
  local prev_surface = player.current_surface
  local prev_position = player.target_inserter_position
  local carry_over_no_reach_checks = player.no_reach_checks and prev_target_inserter == target_inserter
  if player.state ~= "idle" then
    local is_same_inserter = prev_target_inserter == target_inserter
    if not is_same_inserter then
      forget_about_restoring(player, prev_target_inserter)
    end
    switch_to_idle(player, is_same_inserter, true)
    if not target_inserter.valid or player.state ~= "idle" then return false end
  end
  if not try_set_target_inserter(player, target_inserter, do_check_reach, carry_over_no_reach_checks) then
    animations.destroy_all_rendering_objects_if_kept_rendering(player)
    if prev_target_inserter then
      restore_after_adjustment(player, prev_target_inserter, prev_surface, prev_position)
    end
    return false
  end
  confirm_rendering_was_kept_successfully(player)
  deactivate_inserter(player, target_inserter)
  return true
end

---Similar to switch_to_idle, this function can raise an event, so make sure to expect the world and the mod
---to be in any state after calling it.
---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function switch_to_selecting_pickup(player, target_inserter, do_check_reach)
  if player.state == "selecting-pickup" and player.target_inserter == target_inserter then return end
  if not ensure_is_idle_and_try_set_target_inserter(player, target_inserter, do_check_reach) then return end

  -- When only_drop_offset is true, selecting pickup makes no sense. However if the validations above pass,
  -- then it is no longer valid to say "nope, not switching into this state". By allowing switching to
  -- selecting pickup even when only_drop_offset is true, it's handling potential edge cases, and if this
  -- function were to be exposed through the remote interface then mods could do crazy things.
  if not player.target_inserter_cache.only_drop_offset then
    selectables.place_squares(player)
    selectables.place_rects(player)
    animations.draw_grid_lines_and_background(player)
  end
  animations.draw_grid_everything_but_lines_and_background(player)
  animations.draw_white_drop_highlight(player) -- Below pickup highlight.
  animations.draw_white_pickup_highlight(player)
  player.state = "selecting-pickup"
  inserter_speed.update_inserter_speed_text(player)
end

---Similar to switch_to_idle, this function can raise an event, so make sure to expect the world and the mod
---to be in any state after calling it.
---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function switch_to_selecting_drop(player, target_inserter, do_check_reach)
  if player.state == "selecting-drop" and player.target_inserter == target_inserter then return end
  if not ensure_is_idle_and_try_set_target_inserter(player, target_inserter, do_check_reach) then return end

  local is_single_tile = utils.can_only_select_single_drop_tile(player)
  local single_drop_tile = is_single_tile and utils.get_single_drop_tile(player) or nil
  if utils.should_use_auto_drop_offset(player) then
    selectables.place_squares(player, is_single_tile and {single_drop_tile} or nil)
  else
    selectables.place_ninths(player, is_single_tile and {single_drop_tile} or nil)
  end
  if is_single_tile then ---@cast single_drop_tile -nil
    selectables.place_dummy_square_at_pickup(player, single_drop_tile)
  end
  selectables.place_rects(player)

  animations.draw_grid_lines_and_background(player, single_drop_tile)
  animations.draw_grid_everything_but_lines_and_background(player)
  animations.draw_white_drop_highlight(player) -- Below pickup highlight and line to pickup.
  animations.draw_green_pickup_highlight(player)
  animations.draw_line_to_pickup_highlight(player)
  player.state = "selecting-drop"
  inserter_speed.update_inserter_speed_text(player)
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function advance_to_selecting_drop(player, target_inserter, do_check_reach)
  if utils.should_skip_selecting_drop(player) then
    if player.state == "idle" then return end -- Cannot player finish animation on idle player.
    animations.play_finish_animation(player) -- Before switching to idle because some rendering objects get reused.
    switch_to_idle(player)
    return
  end
  switch_to_selecting_drop(player, target_inserter, do_check_reach)
end

---@param player PlayerDataQAI
---@param target_inserter LuaEntity
---@param do_check_reach boolean?
local function advance_to_selecting_pickup(player, target_inserter, do_check_reach)
  if utils.should_skip_selecting_pickup(player, target_inserter) then
    if utils.should_skip_selecting_drop(player) then
      error("There should never be a case where both selecting pickup and selecting drop would be skipped.")
    end
    switch_to_selecting_drop(player, target_inserter, do_check_reach)
  else
    switch_to_selecting_pickup(player, target_inserter, do_check_reach)
  end
end

---@param player PlayerDataQAI
---@param do_check_reach boolean?
---@param new_target_inserter LuaEntity? @ Use this when an inserter changed to/from being real or ghost.
function switch_to_idle_and_back(player, do_check_reach, new_target_inserter)
  if player.state == "idle" then return end
  if new_target_inserter and do_check_reach then
    error("When an inserter gets revived or dies while being adjusted, do not do reach checks.")
  end
  local target_inserter = new_target_inserter or player.target_inserter
  local surface = player.current_surface
  local cache = player.target_inserter_cache
  local position = player.target_inserter_position
  local original_player_state = player.state
  local carry_over_no_reach_checks = player.no_reach_checks
  do_check_reach = do_check_reach and not carry_over_no_reach_checks

  switch_to_idle(player, false, true)
  if player.state ~= "idle" then
    forget_about_restoring(player, target_inserter)
    return
  end
  ---@diagnostic disable-next-line: cast-local-type
  target_inserter = target_inserter.valid and target_inserter
    or surface.valid and utils.find_real_or_ghost_entity_from_prototype(surface, cache.prototype, position)
  if not target_inserter then return end

  if original_player_state == "selecting-pickup" then
    advance_to_selecting_pickup(player, target_inserter, do_check_reach)
  else
    advance_to_selecting_drop(player, target_inserter, do_check_reach)
  end

  -- Carry it over for things like tech level changes, etc. Set it when `new_target_inserter` is non `nil`
  -- because if a robot, another player or a script revived the inserter, moving around should not cause you
  -- to get switched to idle. Especially relevant for the place and adjust feature.
  if (carry_over_no_reach_checks or new_target_inserter)
    and player.state == original_player_state
    and player.target_inserter == target_inserter
  then
    player.no_reach_checks = true
  end
end

---@param player PlayerDataQAI
---@return boolean @ `true` if the player results in a non idle state with a valid inserter.
function validate_target_inserter(player)
  if player.state == "idle" then return false end
  local inserter = player.target_inserter
  if inserter.valid then
    if inserter.operable then return true end
    switch_to_idle(player)
    return false
  end
  ---@diagnostic disable-next-line: cast-local-type
  inserter = player.current_surface.valid and utils.find_real_or_ghost_entity_from_prototype(
    player.current_surface,
    player.target_inserter_cache.prototype,
    player.target_inserter_position
  )
  if not inserter then
    switch_to_idle(player)
    return false
  end
  local expected_state = player.state
  switch_to_idle_and_back(player, false, inserter)
  if player.state ~= expected_state or player.target_inserter ~= inserter then return false end
  if not inserter.valid then
    -- A switch_to_idle_and_back attempt was made, the inserter is once again invalid, so now just give up.
    switch_to_idle(player)
    return false
  end
  return true
end

local update_default_drop_highlight
local update_mirrored_highlight
do
  local left_top = {x = 0, y = 0}
  local right_bottom = {x = 0, y = 0}
  ---@type LuaSurface.create_entity_param
  local create_entity_arg = {
    name = "highlight-box",
    render_player_index = 0, -- Set in the actual function.
    position = {x = 0, y = 0}, -- Required but not used since bounding_box is set.
    bounding_box = {
      left_top = left_top,
      right_bottom = right_bottom,
    },
    box_type = nil, -- Set in the actual function.
  }

  ---@param player PlayerDataQAI
  ---@return LuaEntity?
  local function get_and_validate_selected(player)
    local selected = player.player.selected
    if selected
      and (selected.name == consts.ninth_entity_name or selected.name == consts.square_entity_name)
      and global.selectable_entities_to_player_lut[selected.unit_number] == player
    then
      return selected
    end
  end

  ---@param player PlayerDataQAI
  ---@param position MapPosition
  ---@param existing_highlight LuaEntity?
  ---@param size number
  ---@param box_type CursorBoxRenderType
  ---@return LuaEntity? highlight
  local function place_highlight(player, position, existing_highlight, size, box_type)
    if existing_highlight and existing_highlight.valid then -- Guaranteed to be on the surface of the inserter.
      local existing_position = existing_highlight.position
      if existing_position.x == position.x and existing_position.y == position.y then
        return existing_highlight
      end
    end

    -- "highlight-box"es cannot be teleported, so they have to be destroyed and recreated.
    utils.destroy_entity_safe(existing_highlight)
    if not player.current_surface.valid then return end

    create_entity_arg.render_player_index = player.player_index
    create_entity_arg.box_type = box_type
    local radius = size / 2
    left_top.x = position.x - radius
    left_top.y = position.y - radius
    right_bottom.x = position.x + radius
    right_bottom.y = position.y + radius
    return player.current_surface.create_entity(create_entity_arg)
  end

  ---@param player PlayerDataQAI
  function update_default_drop_highlight(player)
    if not player.highlight_default_drop_offset then return end
    if player.state ~= "selecting-drop"
      and not (player.state == "selecting-pickup" and utils.should_skip_selecting_drop(player))
    then
      return
    end

    local selected = get_and_validate_selected(player)
    if not selected then
      destroy_default_drop_highlight(player)
      return
    end

    local position = selected.position
    if player.state == "selecting-pickup" then -- only_allow_mirrored is true.
      utils.mirror_position(player, position)
    end
    position = utils.calculate_visualized_default_drop_position(player, position)

    player.default_drop_highlight
      = place_highlight(player, position, player.default_drop_highlight, 6/32, "electricity")
  end

  ---@param player PlayerDataQAI
  function update_mirrored_highlight(player)
    if not global.only_allow_mirrored then return end
    if player.state ~= "selecting-pickup" then return end

    local selected = get_and_validate_selected(player)
    if not selected then
      destroy_mirrored_highlight(player)
      return
    end

    local position = selected.position
    utils.mirror_position(player, position)
    -- No snapping required, the pickup position (the square entity position) is already centered.

    player.mirrored_highlight = place_highlight(player, position, player.mirrored_highlight, 1, "entity")
  end
end

---@param player PlayerDataQAI
---@param position MapPosition @ Gets modified if `only_allow_mirrored` is true.
local function set_pickup_position(player, position)
  player.target_inserter.pickup_position = position
  if not global.only_allow_mirrored then return end
  utils.mirror_position(player, position)
  player.target_inserter.drop_position = utils.calculate_actual_drop_position(player, position, true)
end

---@param player PlayerDataQAI
---@param position MapPosition
local function set_drop_position(player, position)
  player.target_inserter.drop_position = utils.calculate_actual_drop_position(player, position)
end

---@type table<string, fun(player: PlayerDataQAI, selected: LuaEntity)>
local on_adjust_handler_lut = {
  ["idle"] = function(player, selected)
    if not utils.is_real_or_ghost_inserter(selected) then return end
    advance_to_selecting_pickup(player, selected, true)
  end,

  ["selecting-pickup"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if utils.is_real_or_ghost_inserter(selected) then
      if selected == player.target_inserter then
        advance_to_selecting_drop(player, player.target_inserter)
      else
        advance_to_selecting_pickup(player, selected, true)
      end
      return
    end
    if utils.is_selectable_for_player(selected, consts.square_entity_name, player) then
      set_pickup_position(player, selected.position)
      advance_to_selecting_drop(player, player.target_inserter)
      return
    end
    if utils.is_selectable_for_player(selected, consts.rect_entity_name, player) then
      set_direction_and_update_arrow(player, selected.direction)
      return
    end
    switch_to_idle(player)
  end,

  ["selecting-drop"] = function(player, selected)
    if not validate_target_inserter(player) then return end
    if utils.is_real_or_ghost_inserter(selected) then
      if selected == player.target_inserter then
        animations.play_finish_animation(player) -- Before switching to idle because some rendering objects get reused.
        switch_to_idle(player)
      else
        advance_to_selecting_pickup(player, selected, true)
      end
      return
    end
    if utils.is_selectable_for_player(selected, consts.square_entity_name, player)
      or utils.is_selectable_for_player(selected, consts.ninth_entity_name, player)
    then
      set_drop_position(player, selected.position)
      animations.play_finish_animation(player) -- Before switching to idle because some rendering objects get reused.
      switch_to_idle(player)
      return
    end
    if utils.is_selectable_for_player(selected, consts.rect_entity_name, player) then
      set_direction_and_update_arrow(player, selected.direction)
      return
    end
    switch_to_idle(player)
  end,
}

---@param player PlayerDataQAI
---@param selected_entity LuaEntity?
local function adjust(player, selected_entity)
  if not selected_entity then
    switch_to_idle(player)
    return
  end
  on_adjust_handler_lut[player.state](player, selected_entity)
end

---@class StatesFileQAI
local states = {
  destroy_default_drop_highlight = destroy_default_drop_highlight,
  deactivate_inserter = deactivate_inserter,
  forget_about_restoring = forget_about_restoring,
  switch_to_idle = switch_to_idle,
  advance_to_selecting_pickup = advance_to_selecting_pickup,
  switch_to_idle_and_back = switch_to_idle_and_back,
  validate_target_inserter = validate_target_inserter,
  update_default_drop_highlight = update_default_drop_highlight,
  update_mirrored_highlight = update_mirrored_highlight,
  adjust = adjust,
}
return states
