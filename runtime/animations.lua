
local vec = require("__inserter-throughput-lib__.vector")
local consts = require("__quick-adjustable-inserters__.runtime.consts")
local utils = require("__quick-adjustable-inserters__.runtime.utils")
local animation_type = consts.animation_type

---@param animation AnimationQAI
local function add_animation(animation)
  local active_animations = global.active_animations
  active_animations.count = active_animations.count + 1
  active_animations[active_animations.count] = animation
end

---@param animation AnimatedCircleQAI
local function add_animated_circle(animation)
  animation.type = animation_type.circle
  return add_animation(animation) -- Return to make it a tail call.
end

---@param animation AnimatedRectangleQAI
local function add_animated_rectangle(animation)
  animation.type = animation_type.rectangle
  return add_animation(animation) -- Return to make it a tail call.
end

---@param animation AnimatedLineQAI
local function add_animated_line(animation)
  animation.type = animation_type.line
  return add_animation(animation) -- Return to make it a tail call.
end

---@param animation AnimatedColorQAI
local function add_animated_color(animation)
  animation.type = animation_type.color
  return add_animation(animation) -- Return to make it a tail call.
end

---@param current_color Color @ Gets modified.
---@param final_color Color
---@param frames integer
---@param start_on_first_frame boolean? @ When true `init` will have `step` added to it once already.
---@return Color init @ Same table as `current_color`.
---@return Color step @ New table.
---@return integer remaining_updates
local function get_color_init_and_step(current_color, final_color, frames, start_on_first_frame)
  local step_r = (final_color.r - current_color.r) / frames
  local step_g = (final_color.g - current_color.g) / frames
  local step_b = (final_color.b - current_color.b) / frames
  local step_a = (final_color.a - current_color.a) / frames
  -- Truncate precision which could be lost throughout the [-1,1] range. This means so long as the value
  -- remains within the [-1,1] range it can be modified without any precision lost. It can be multiplied,
  -- added, subtracted, it doesn't matter, so long as the result is is also within [-1,1].
  -- And so long as all input values are properly truncated. And there's more technicalities.
  step_r = step_r - (step_r % (1 / 2^53))
  step_g = step_g - (step_g % (1 / 2^53))
  step_b = step_b - (step_b % (1 / 2^53))
  step_a = step_a - (step_a % (1 / 2^53))
  local step = {
    r = step_r,
    g = step_g,
    b = step_b,
    a = step_a,
  }
  -- Change init color such that adding step to it `frames` times will result in the exact `final_color`.
  local remaining_updates = start_on_first_frame and (frames - 1) or frames
  current_color.r = final_color.r - step_r * remaining_updates
  current_color.g = final_color.g - step_g * remaining_updates
  current_color.b = final_color.b - step_b * remaining_updates
  current_color.a = final_color.a - step_a * remaining_updates
  return current_color, step, remaining_updates
end

---@param id uint64
---@param final_color Color
---@param frames integer
---@param destroy_on_finish boolean?
local function animate_fade_to_color(id, final_color, frames, destroy_on_finish)
  local current_color = rendering.get_color(id) ---@cast current_color -nil
  -- `start_on_first_frame` set to true to have the same animation length as newly created objects.
  -- Basically all animations start on the first frame in this mod, not the initial color/value.
  local color_init, color_step, remaining_updates
    = get_color_init_and_step(current_color, final_color, frames, true)
  add_animated_color{
    id = id,
    destroy_on_finish = destroy_on_finish,
    color = color_init,
    color_step = color_step,
    remaining_updates = remaining_updates,
  }
end

---@return boolean do_animate
local function should_animate()
  return not game.tick_paused
end

---@param id uint64
---@param frames integer
local function fade_out(id, frames)
  animate_fade_to_color(id, {r = 0, g = 0, b = 0, a = 0}, frames, true)
end

---Destroys if `should_animate()` is `false`.
---@param id uint64
---@param frames integer
local function fade_out_or_destroy(id, frames)
  if should_animate() then
    fade_out(id, frames)
  else
    rendering.destroy(id)
  end
end

---@param ids uint64[]
local function animate_lines_disappearing(ids)
  local opacity = 1 / consts.grid_fade_out_frames
  local color_step = {r = -opacity, g = -opacity, b = -opacity, a = -opacity}
  for i = #ids, 1, -1 do
    add_animated_color{
      id = ids[i],
      remaining_updates = consts.grid_fade_out_frames - 1,
      destroy_on_finish = true,
      color = {r = 1, g = 1, b = 1, a = 1},
      color_step = color_step,
    }
    ids[i] = nil
  end
end

---Can only animate the color white.
---@param id uint64
---@param current_opacity number
local function animate_id_disappearing(id, current_opacity)
  local opacity = current_opacity / consts.grid_fade_out_frames
  local color_step = {r = -opacity, g = -opacity, b = -opacity, a = -opacity}
  add_animated_color{
    id = id,
    remaining_updates = consts.grid_fade_out_frames - 1,
    destroy_on_finish = true,
    color = {r = current_opacity, g = current_opacity, b = current_opacity, a = current_opacity},
    color_step = color_step,
  }
end

---Can only animate the color white.
---@param ids uint64[]
local function destroy_and_clear_rendering_ids(ids)
  local destroy = rendering.destroy
  for i = #ids, 1, -1 do
    destroy(ids[i])
    ids[i] = nil
  end
end

---Must only be called when the rendering objects actually exist.
---@param player PlayerDataQAI
local function destroy_grid_lines_and_background(player)
  if should_animate() then
    animate_lines_disappearing(player.line_ids)
    animate_id_disappearing(player.background_polygon_id, consts.grid_background_opacity)
  else
    destroy_and_clear_rendering_ids(player.line_ids)
    rendering.destroy(player.background_polygon_id)
  end
  player.background_polygon_id = nil
end

---Must only be called when the rendering objects actually exist.
---@param player PlayerDataQAI
local function destroy_everything_but_grid_lines_and_background(player)
  local destroy = rendering.destroy
  if should_animate() then
    animate_lines_disappearing(player.direction_arrows_indicator_line_ids)
    if player.direction_arrow_id then animate_id_disappearing(player.direction_arrow_id, consts.direction_arrow_opacity) end
    if player.inserter_circle_id then animate_id_disappearing(player.inserter_circle_id, 1) end
    if player.pickup_highlight_id then fade_out(player.pickup_highlight_id, consts.grid_fade_out_frames) end
    if player.drop_highlight_id then animate_id_disappearing(player.drop_highlight_id, 1) end
    if player.line_to_pickup_highlight_id then fade_out(player.line_to_pickup_highlight_id, consts.grid_fade_out_frames) end
  else
    destroy_and_clear_rendering_ids(player.direction_arrows_indicator_line_ids)
    if player.direction_arrow_id then destroy(player.direction_arrow_id) end
    if player.inserter_circle_id then destroy(player.inserter_circle_id) end
    if player.pickup_highlight_id then destroy(player.pickup_highlight_id) end
    if player.drop_highlight_id then destroy(player.drop_highlight_id) end
    if player.line_to_pickup_highlight_id then destroy(player.line_to_pickup_highlight_id) end
  end
  player.inserter_circle_id = nil
  player.direction_arrow_id = nil
  player.pickup_highlight_id = nil
  player.drop_highlight_id = nil
  player.line_to_pickup_highlight_id = nil
end

---Must only be called when the rendering objects actually exist.
---@param player PlayerDataQAI
local function destroy_all_rendering_objects(player)
  destroy_grid_lines_and_background(player)
  destroy_everything_but_grid_lines_and_background(player)
end

---@param player PlayerDataQAI
local function destroy_all_rendering_objects_if_kept_rendering(player)
  if not player.rendering_is_floating_while_idle then return end
  player.rendering_is_floating_while_idle = nil
  destroy_all_rendering_objects(player)
end

---@param full_opacity number
---@return boolean do_animate
---@return number opacity
---@return Color color_step
local function get_color_for_potential_animation(full_opacity)
  local do_animate = should_animate()
  local opacity = do_animate and (full_opacity / consts.grid_fade_in_frames) or full_opacity
  return do_animate, opacity, {r = opacity, g = opacity, b = opacity, a = opacity}
end

---@param id uint64
---@param opacity number
---@param color_step Color
local function add_grid_fade_in_animation(id, opacity, color_step)
  return add_animated_color{ -- Return to make it a tail call.
    id = id,
    remaining_updates = consts.grid_fade_in_frames - 1,
    color = {r = opacity, g = opacity, b = opacity, a = opacity},
    color_step = color_step,
  }
end

---@param id uint64
---@param opacity number
---@param color_step Color
---@param color Color @ Each component will be multiplied by opacity.
local function add_non_white_grid_fade_in_animation(id, opacity, color_step, color)
  color.r = color.r * opacity
  color.g = color.g * opacity
  color.b = color.b * opacity
  color.a = color.a * opacity
  return add_animated_color{ -- Return to make it a tail call.
    id = id,
    remaining_updates = consts.grid_fade_in_frames - 1,
    color = color,
    color_step = color_step,
  }
end

---@param player PlayerDataQAI
local function draw_direction_arrow(player)
  if not player.is_rotatable then return end
  local inserter_position = player.target_inserter_position
  local cache = player.target_inserter_cache
  inserter_position.x = inserter_position.x + cache.offset_from_inserter.x + cache.direction_arrow_position.x
  inserter_position.y = inserter_position.y + cache.offset_from_inserter.y + cache.direction_arrow_position.y
  local do_animate, opacity, color_step = get_color_for_potential_animation(consts.direction_arrow_opacity)
  player.direction_arrow_id = rendering.draw_polygon{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    vertices = player.target_inserter_cache.direction_arrow_vertices,
    orientation = player.target_inserter.orientation,
    target = inserter_position,
  }
  if do_animate then
    add_grid_fade_in_animation(player.direction_arrow_id, opacity, color_step)
  end
end

---@param player PlayerDataQAI
local function draw_circle_on_inserter(player)
  local cache = player.target_inserter_cache
  local do_animate, opacity, color_step = get_color_for_potential_animation(1)
  player.inserter_circle_id = rendering.draw_circle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    radius = cache.radius_for_circle_on_inserter,
    width = 2,
    target = utils.get_current_grid_center_position(player),
  }
  if do_animate then
    add_grid_fade_in_animation(player.inserter_circle_id, opacity, color_step)
  end
end

---@param player PlayerDataQAI
---@param line_ids int64[]
---@param lines LineDefinitionQAI[]
local function draw_lines_internal(player, line_ids, lines)
  local left_top = utils.get_current_grid_left_top(player)
  local left, top = left_top.x, left_top.y -- Micro optimization.
  local from = {}
  local to = {}
  local do_animate, opacity, color_step = get_color_for_potential_animation(1)
  ---@type LuaRendering.draw_line_param
  local line_param = {
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    width = 1,
    from = from,
    to = to,
  }

  for i, line in ipairs(lines) do
    from.x = left + line.from.x
    from.y = top + line.from.y
    to.x = left + line.to.x
    to.y = top + line.to.y
    local id = rendering.draw_line(line_param)
    line_ids[i] = id
    if do_animate then
      add_grid_fade_in_animation(id, opacity, color_step)
    end
  end
end

---@param player PlayerDataQAI
local function draw_grid_lines(player)
  draw_lines_internal(player, player.line_ids, utils.get_lines(player))
end

---@param player PlayerDataQAI
local function draw_direction_arrows_indicator_lines(player)
  if not player.is_rotatable then return end
  draw_lines_internal(
    player,
    player.direction_arrows_indicator_line_ids,
    utils.get_direction_arrows_indicator_lines(player)
  )
end

---@param player PlayerDataQAI
local function draw_grid_background(player)
  local do_animate, opacity, color_step = get_color_for_potential_animation(consts.grid_background_opacity)
  player.background_polygon_id = rendering.draw_polygon{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    vertices = utils.get_tiles_background_vertices(player),
    target = utils.get_current_grid_left_top(player),
  }
  if do_animate then
    add_grid_fade_in_animation(player.background_polygon_id, opacity, color_step)
  end
end

---@param player PlayerDataQAI
---@param single_tile MapPosition @ Relative to grid left top.
local function draw_single_tile_grid(player, single_tile)
  single_tile = vec.add(vec.copy(single_tile), utils.get_current_grid_left_top(player))
  ---@type LuaRendering.draw_rectangle_param
  local arg = {
    surface = player.current_surface_index,
    forces = {player.force_index},
    left_top = single_tile,
    right_bottom = vec.add_scalar(vec.copy(single_tile), 1),
  }

  local do_animate, opacity, color_step = get_color_for_potential_animation(consts.grid_background_opacity)
  arg.color = color_step
  arg.filled = true
  player.background_polygon_id = rendering.draw_rectangle(arg)
  if do_animate then
    add_grid_fade_in_animation(player.background_polygon_id, opacity, color_step)
  end

  arg.filled = nil
  do_animate, opacity, color_step = get_color_for_potential_animation(1)
  arg.color = color_step
  arg.width = 1
  player.line_ids[1] = rendering.draw_rectangle(arg)
  if do_animate then
    add_grid_fade_in_animation(player.line_ids[1], opacity, color_step)
  end
end

---When rendering objects were kept alive when switching to idle previously, don't create another set.
---@param player PlayerDataQAI
---@return boolean
local function did_keep_rendering(player)
  return player.inserter_circle_id--[[@as boolean]]
end

---@param player PlayerDataQAI
---@param single_tile MapPosition?
local function draw_grid_lines_and_background(player, single_tile)
  if single_tile then
    -- Do not check keep_rendering. This only happens when the grid is not kept.
    draw_single_tile_grid(player, single_tile)
    return
  end
  if did_keep_rendering(player) then return end
  draw_grid_background(player)
  draw_grid_lines(player)
end

---@param player PlayerDataQAI
local function draw_grid_everything_but_lines_and_background(player)
  if did_keep_rendering(player) then return end
  draw_direction_arrow(player)
  draw_direction_arrows_indicator_lines(player)
  draw_circle_on_inserter(player)
end

---@param color Color @ Assumes `r`, `g` and `b` to be the color at full opacity. Current `a` is ignored.
---@param opacity number
local function pre_multiply_and_set_alpha(color, opacity)
  color.r = color.r * opacity
  color.g = color.g * opacity
  color.b = color.b * opacity
  color.a = opacity
end

---@param player PlayerDataQAI
---@param final_opacity number
---@param color Color @ `r`, `b` and `b` must be provided. `a` will be set to `final_opacity`.
---@return boolean
local function try_reuse_existing_pickup_highlight(player, final_opacity, color)
  local id = player.pickup_highlight_id
  if not id or not rendering.is_valid(id) then return false end

  local left_top, right_bottom = utils.get_pickup_box(player)
  if not utils.rectangle_positions_equal(id, left_top, right_bottom) then
    -- Not checking surface or force, because those will trigger switch_to_idle_and_back anyway.
    fade_out_or_destroy(id, consts.grid_fade_in_frames)
    return false
  end

  if not should_animate() then
    rendering.set_color(id, color)
    return true
  end

  pre_multiply_and_set_alpha(color, final_opacity)
  animate_fade_to_color(id, color, consts.grid_fade_in_frames)
  return true
end

---@param player PlayerDataQAI
---@param width number
---@param left_top MapPosition
---@param right_bottom MapPosition
---@param final_opacity number
---@param color Color @ `r`, `b` and `b` must be provided. `a` will be set to `final_opacity`.
---@return uint64 id
local function draw_pickup_or_drop_highlight(player, width, left_top, right_bottom, final_opacity, color)
  local do_animate, opacity, color_step = get_color_for_potential_animation(final_opacity)
  color_step.r = color_step.r * color.r
  color_step.g = color_step.g * color.g
  color_step.b = color_step.b * color.b
  local id = rendering.draw_rectangle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    width = width,
    left_top = left_top,
    right_bottom = right_bottom,
  }
  if do_animate then
    color.a = final_opacity
    add_non_white_grid_fade_in_animation(id, opacity, color_step, color)
  end
  return id
end

---@param player PlayerDataQAI
---@param final_opacity number
---@param color Color @ `r`, `b` and `b` must be provided. `a` will be set to `final_opacity`.
local function draw_pickup_highlight_internal(player, final_opacity, color)
  if try_reuse_existing_pickup_highlight(player, final_opacity, color) then return end
  local left_top, right_bottom = utils.get_pickup_box(player)
  player.pickup_highlight_id
    = draw_pickup_or_drop_highlight(player, 2.999, left_top, right_bottom, final_opacity, color)
end

---@param player PlayerDataQAI
local function draw_green_pickup_highlight(player)
  draw_pickup_highlight_internal(player, 1, {r = 0, g = 1, b = 0})
end

---@param player PlayerDataQAI
local function draw_white_pickup_highlight(player)
  draw_pickup_highlight_internal(player, 1, {r = 1, g = 1, b = 1})
end

---@param player PlayerDataQAI
---@param square_position MapPosition @ Gets modified.
---@param square_radius number @ Half of the length of the sides of the square.
---@return MapPosition? from
---@return MapPosition? to
---@return number length
local function get_from_and_to_for_line_from_center(player, square_position, square_radius)
  local grid_center_position = utils.get_current_grid_center_position(player)
  local vector_to_square = vec.sub(square_position, grid_center_position)
  if vector_to_square.x == 0 and vector_to_square.y == 0 then return nil, nil, 0 end
  local distance_from_pickup = (3/32) + vec.get_length(vec.div_scalar(
    vec.copy(vector_to_square),
    math.max(math.abs(vector_to_square.x), math.abs(vector_to_square.y)) / square_radius
  ))
  local distance_from_center = (2/32) + player.target_inserter_cache.radius_for_circle_on_inserter
  local length = vec.get_length(vector_to_square) - distance_from_pickup - distance_from_center
  if length <= 0 then return nil, nil, length end

  local from = vec.add(
    vec.copy(grid_center_position),
    vec.set_length(vector_to_square, distance_from_center)
  )
  local to = vec.add(
    grid_center_position, -- No need to copy here too.
    vec.set_length(vector_to_square, distance_from_center + length)
  )
  return from, to, length
end

---@param player PlayerDataQAI
local function draw_line_to_pickup_highlight(player)
  local from, to = get_from_and_to_for_line_from_center(player, utils.get_snapped_pickup_position(player), 0.5)
  if not from then return end ---@cast to -nil
  local do_animate, opacity, color_step = get_color_for_potential_animation(1)
  color_step.r = 0
  color_step.b = 0
  local id = rendering.draw_line{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color_step,
    width = 2,
    from = from,
    to = to,
  }
  player.line_to_pickup_highlight_id = id
  if do_animate then
    add_non_white_grid_fade_in_animation(id, opacity, color_step, {r = 0, g = 1, b = 0, a = 1})
  end
end

---@return Color
local function get_finish_animation_color()
  return {r = 0, g = 1, b = 0, a = 1}
end

---@return Color
local function get_finish_animation_color_step()
  return {r = 0, g = -1 / consts.finish_animation_frames, b = 0, a = -1 / consts.finish_animation_frames}
end

---@param player PlayerDataQAI
---@param visual_drop_position MapPosition
---@return boolean
local function try_reuse_existing_drop_highlight(player, visual_drop_position)
  local id = player.drop_highlight_id
  if not id or not rendering.is_valid(id) then return false end
  local left_top, right_bottom = utils.get_drop_box(visual_drop_position)
  if not utils.rectangle_positions_equal(id, left_top, right_bottom) then
    fade_out_or_destroy(id, consts.grid_fade_in_frames)
    return false
  end
  -- The color is the same, so nothing to do.
  return true
end

---@param player PlayerDataQAI
local function draw_white_drop_highlight(player)
  local position = utils.calculate_visualized_drop_position(player, player.target_inserter.drop_position)
  if try_reuse_existing_drop_highlight(player, position) then return end
  local left_top, right_bottom = utils.get_drop_box(position)
  player.drop_highlight_id
    = draw_pickup_or_drop_highlight(player, 1, left_top, right_bottom, 1, {r = 1, g = 1, b = 1})
end

---@param player PlayerDataQAI
---@param position MapPosition
local function play_drop_highlight_animation(player, position)
  if player.drop_highlight_id then
    rendering.destroy(player.drop_highlight_id)
    player.drop_highlight_id = nil
  end

  local color = get_finish_animation_color()
  local left_top, right_bottom = utils.get_drop_box(position)
  local id = rendering.draw_rectangle{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color,
    width = 2.999,
    left_top = left_top,
    right_bottom = right_bottom,
  }

  local step = consts.finish_animation_highlight_box_step
  add_animated_rectangle{
    id = id,
    remaining_updates = consts.finish_animation_frames - 1,
    destroy_on_finish = true,
    color = color,
    left_top = left_top,
    right_bottom = right_bottom,
    color_step = get_finish_animation_color_step(),
    left_top_step = {x = -step, y = -step},
    right_bottom_step = {x = step, y = step},
  }
end

---@param from MapPosition
---@param to MapPosition
---@param length number
---@return integer frames
---@return MapPosition step_vector
local function get_frames_and_step_vector_for_line_to_highlight(from, to, length)
  local final_length = length - consts.finish_animation_expansion
  local length_step = consts.finish_animation_expansion / consts.finish_animation_frames
  local frames = math.max(1, consts.finish_animation_frames - math.floor(math.max(0, -final_length) / length_step))
  local step_vector = vec.set_length(vec.sub(vec.copy(to), from), length_step / 2)
  return frames, step_vector
end

---@param player PlayerDataQAI
---@param position MapPosition
local function play_line_to_drop_highlight_animation(player, position)
  local from, to, length = get_from_and_to_for_line_from_center(
    player,
    vec.copy(position),
    44/256
  )
  if not from then return end ---@cast to -nil

  local color = get_finish_animation_color()
  local id = rendering.draw_line{
    surface = player.current_surface_index,
    forces = {player.force_index},
    color = color,
    width = 2,
    from = from,
    to = to,
  }

  local frames, step_vector = get_frames_and_step_vector_for_line_to_highlight(from, to, length)
  add_animated_line{
    type = animation_type.line,
    id = id,
    remaining_updates = frames - 1,
    destroy_on_finish = true,
    color = color,
    from = from,
    to = to,
    color_step = get_finish_animation_color_step(),
    from_step = step_vector,
    to_step = vec.mul_scalar(vec.copy(step_vector), -1),
  }
end

---@param player PlayerDataQAI
local function play_circle_on_inserter_animation(player)
  if not rendering.is_valid(player.inserter_circle_id) then return end
  local color = get_finish_animation_color()
  rendering.set_color(player.inserter_circle_id, color)
  add_animated_circle{
    id = player.inserter_circle_id,
    remaining_updates = consts.finish_animation_frames - 1,
    destroy_on_finish = true,
    color = color,
    radius = player.target_inserter_cache.radius_for_circle_on_inserter,
    color_step = get_finish_animation_color_step(),
    radius_step = (consts.finish_animation_expansion / 2) / consts.finish_animation_frames,
  }
  player.inserter_circle_id = nil -- Destroying is now handled by the animation.
end

---@param player PlayerDataQAI
local function play_pickup_highlight_animation(player)
  if not rendering.is_valid(player.pickup_highlight_id) then return end
  local step = (consts.finish_animation_expansion / 2) / consts.finish_animation_frames
  local left_top, right_bottom = utils.get_pickup_box(player)
  add_animated_rectangle{
    id = player.pickup_highlight_id,
    remaining_updates = consts.finish_animation_frames - 1,
    destroy_on_finish = true,
    color = get_finish_animation_color(),
    left_top = left_top,
    right_bottom = right_bottom,
    color_step = get_finish_animation_color_step(),
    left_top_step = {x = -step, y = -step},
    right_bottom_step = {x = step, y = step},
  }
  player.pickup_highlight_id = nil -- Destroying is now handled by the animation.
end

---@param player PlayerDataQAI
local function play_line_to_pickup_highlight_animation(player)
  local from, to, length = get_from_and_to_for_line_from_center(
    player,
    utils.get_snapped_pickup_position(player),
    0.5
  )
  -- The pickup position might have changed since the last time we checked.
  if not from then ---@cast to -nil
    -- Instantly destroy here, otherwise it would play a fade out animation.
    if player.line_to_pickup_highlight_id then rendering.destroy(player.line_to_pickup_highlight_id) end
    player.line_to_pickup_highlight_id = nil
    return
  end

  local id = player.line_to_pickup_highlight_id
  player.line_to_pickup_highlight_id = nil -- Destroying will be handled by the animation.
  if not id or not rendering.is_valid(id) then
    id = rendering.draw_line{
      surface = player.current_surface_index,
      forces = {player.force_index},
      color = get_finish_animation_color(),
      width = 2,
      from = from,
      to = to,
    }
  end

  local frames, step_vector = get_frames_and_step_vector_for_line_to_highlight(from, to, length)
  add_animated_line{
    id = id,
    remaining_updates = frames - 1,
    destroy_on_finish = true,
    color = get_finish_animation_color(),
    from = from,
    to = to,
    color_step = get_finish_animation_color_step(),
    from_step = step_vector,
    to_step = vec.mul_scalar(vec.copy(step_vector), -1),
  }
end

---@param player PlayerDataQAI
local function play_finish_animation(player)
  if not should_animate() then return end
  if player.state == "idle" then
    error("Attempt to play finish animation on idle player. The finish animation requires the current \
      target_inserter as well as its cache and it reuses some of the rendering objects."
    )
  end
  local drop_position = utils.calculate_visualized_drop_position(player, player.target_inserter.drop_position)
  play_drop_highlight_animation(player, drop_position)
  play_line_to_drop_highlight_animation(player, drop_position)
  play_circle_on_inserter_animation(player)
  play_pickup_highlight_animation(player)
  play_line_to_pickup_highlight_animation(player)
end

---@type table<AnimationTypeQAI, fun(animation: AnimationQAI)>
local update_animation_lut
do
  local set_color = rendering.set_color
  local set_radius = rendering.set_radius
  local set_left_top = rendering.set_left_top
  local set_right_bottom = rendering.set_right_bottom
  local set_from = rendering.set_from
  local set_to = rendering.set_to

  update_animation_lut = {
    ---@param animation AnimatedCircleQAI
    [animation_type.circle] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)

      local radius = animation.radius + animation.radius_step
      animation.radius = radius
      set_radius(id, radius)
    end,
    ---@param animation AnimatedRectangleQAI
    [animation_type.rectangle] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)

      local left_top = animation.left_top
      local left_top_step = animation.left_top_step
      left_top.x = left_top.x + left_top_step.x
      left_top.y = left_top.y + left_top_step.y
      set_left_top(id, left_top)

      local right_bottom = animation.right_bottom
      local right_bottom_step = animation.right_bottom_step
      right_bottom.x = right_bottom.x + right_bottom_step.x
      right_bottom.y = right_bottom.y + right_bottom_step.y
      set_right_bottom(id, right_bottom)
    end,
    ---@param animation AnimatedLineQAI
    [animation_type.line] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)

      local from = animation.from
      local from_step = animation.from_step
      from.x = from.x + from_step.x
      from.y = from.y + from_step.y
      set_from(id, from)

      local to = animation.to
      local to_step = animation.to_step
      to.x = to.x + to_step.x
      to.y = to.y + to_step.y
      set_to(id, to)
    end,
    ---@param animation AnimatedColorQAI
    [animation_type.color] = function(animation)
      local id = animation.id

      local color = animation.color
      local color_step = animation.color_step
      color.r = color.r + color_step.r
      color.b = color.b + color_step.b
      color.g = color.g + color_step.g
      color.a = color.a + color_step.a
      set_color(id, color)
    end,
  }
end

local rendering_is_valid = rendering.is_valid
local rendering_destroy = rendering.destroy

local function update_animations()
  local active_animations = global.active_animations
  local count = active_animations.count
  for i = count, 1, -1 do
    local animation = active_animations[i]
    local remaining_updates = animation.remaining_updates
    if remaining_updates > 0 and rendering_is_valid(animation.id) then
      animation.remaining_updates = remaining_updates - 1
      local update_animation = update_animation_lut[animation.type]
      update_animation(animation)
    else
      if animation.destroy_on_finish then
        rendering_destroy(animation.id) -- Destroy accepts already invalid ids.
      end
      active_animations[i] = active_animations[count]
      active_animations[count] = nil
      count = count - 1
      active_animations.count = count
    end
  end
end

---@class AnimationsFileQAI
local animations = {
  destroy_grid_lines_and_background = destroy_grid_lines_and_background,
  destroy_everything_but_grid_lines_and_background = destroy_everything_but_grid_lines_and_background,
  destroy_all_rendering_objects_if_kept_rendering = destroy_all_rendering_objects_if_kept_rendering,
  draw_grid_lines_and_background = draw_grid_lines_and_background,
  draw_grid_everything_but_lines_and_background = draw_grid_everything_but_lines_and_background,
  draw_green_pickup_highlight = draw_green_pickup_highlight,
  draw_white_pickup_highlight = draw_white_pickup_highlight,
  draw_line_to_pickup_highlight = draw_line_to_pickup_highlight,
  draw_white_drop_highlight = draw_white_drop_highlight,
  play_finish_animation = play_finish_animation,
  update_animations = update_animations,
}
return animations
