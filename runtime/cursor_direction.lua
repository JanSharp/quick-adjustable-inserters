
local inserter_throughput = require("__inserter-throughput-lib__.inserter_throughput")
local utils = require("__quick-adjustable-inserters__.runtime.utils")

-- TODO: this entire file most likely needs to handle all 16 directions.

--[[

rotation rules while holding item in cursor

- [x] if place result 8 way, press R: apply 0.125 rotation
- [x] if place result 4 way (normal, even robots, tanks, chests, spider trons), press R: apply 0.25 rotation.
  Does not snap, the result can be 0.125 for example
- [x] if place as tile, press R: behave like above
- [x] if rolling stock, press R: apply 0.5 rotation, Does not snap, see 4 way
- [x] if rolling stock, hovering rails: does nothing
- [x] if rail and using rail planner to build: reset to north. I don't believe we can detect the usage of the rail planner.
- [x] if signal or train stop, hovering next to rail: sets cursor direction accordingly, impossible to detect.
  Closest would be on build
- [x] if offshore pump, hovering at a shore: same as signals. Closest would be using on build
- [x] finishing selection with a blueprint item: reset to north.
  Could use on_player_setup_blueprint, however that only gets raised if entities were actually selected, but
  the direction gets reset even on an empty selection. Not only that, copy or cut do not change the cursor
  direction, yet they also raise on_player_setup_blueprint _and_ the item name is "blueprint" in all cases.
  Unfortunate, but at least the best solution is to just not handle it at all, so it's less code.
- [x] finishing selection with a copy or cut tool: does nothing
- [x] rotating a blueprint: does nothing - they have a rotation state of their own it seems

depending on the internal cursor rotation state, the actual visualization then rounds down to the nearest
valid direction. And w hen building it of course also rounds down.

underground belts and pipes appear to have another internal flag saying "flip my current direction" which does
not affect the internal cursor direction. This flag gets toggled every time one is built. The 2 are actually
sharing this flag.

pipette:

- [x] on a rolling stock: uses orientation and _rounds_ to nearest 4 way direction (when in the middle, rounds up. Like 0.125 becomes 0.25)
- [x] on an underground belt: uses direction, if belt_to_ground_type == "output" apply 0.5 rotation (flip)
- [x] on an underground pipe: uses direction, nothing special
- [x] on a loader: uses direction, if loader_type == "input" apply 0.5 rotation (flip)
- [x] on an entity that does not support direction: does not affect rotation state
- [x] on an entity that does support direction: use its direction as is to set cursor direction

send help, please, how does the game determine if an assembling machine has directions or not
Ah! Saved! Thank you for the api and docs, the answer is simple! LuaEntity::supports_direction! Done!
supports_direction on an entity also handles entities like assembling machines which can conditionally support
direction.

]]

---@param orientation RealOrientation
local function validate_orientation(orientation)
  if ((orientation * 8) % 1) ~= 0 then
    error("The cursor rotation, while it is represented using an orientation, is only allowed to have \z
      steps in 1/8 (0.125) increments. Invalid rotation value: "..orientation.."."
    )
  end
end

---@param player PlayerDataQAI
---@param reverse boolean
---@param rotation RealOrientation
local function rotate_cursor(player, reverse, rotation)
  validate_orientation(rotation)
  local current = player.current_cursor_orientation
  player.current_cursor_orientation = (current + rotation * (reverse and -1 or 1)) % 1
end

---@param player PlayerDataQAI
---@param orientation RealOrientation
local function set_cursor_orientation(player, orientation)
  validate_orientation(orientation)
  player.current_cursor_orientation = orientation % 1
end

local rolling_stock_type_lut = {
  ["artillery-wagon"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["locomotive"] = true,
}

---@param player PlayerDataQAI
---@param reverse boolean
---@param entity LuaEntityPrototype
local function handle_rotation_for_entity_place_result(player, reverse, entity)
  if rolling_stock_type_lut[entity.type] then
    rotate_cursor(player, reverse, 0.5)
    return
  end
  local is_eight_way = entity.has_flag("building-direction-8-way")
  rotate_cursor(player, reverse, is_eight_way and 0.125 or 0.25)
end

---@param player PlayerDataQAI
---@param reverse boolean
local function handle_rotation_for_tile_place_result(player, reverse)
  rotate_cursor(player, reverse, 0.25)
end

---@param player PlayerDataQAI
---@param reverse boolean
local function handle_rotation(player, reverse)
  local item_prototype = utils.get_cursor_item_prototype(player)
  if not item_prototype then return end
  local place_result = item_prototype.place_result
  if place_result then
    handle_rotation_for_entity_place_result(player, reverse, place_result)
    return
  end
  local tile_place_result = item_prototype.place_as_tile_result
  if tile_place_result then
    handle_rotation_for_tile_place_result(player, reverse)
    return
  end
end

local direction_to_orientation_lut = {
  [defines.direction.north] = 0,
  [defines.direction.northeast] = 0.125,
  [defines.direction.east] = 0.25,
  [defines.direction.southeast] = 0.375,
  [defines.direction.south] = 0.5,
  [defines.direction.southwest] = 0.625,
  [defines.direction.west] = 0.75,
  [defines.direction.northwest] = 0.875,
}

---@param player PlayerDataQAI
---@param pipetted_entity LuaEntity
local function handle_pipette_direction(player, pipetted_entity)
  local entity_type = inserter_throughput.get_real_or_ghost_entity_type(pipetted_entity)

  if rolling_stock_type_lut[entity_type] then
    local orientation = pipetted_entity.orientation
    orientation = math.floor(orientation * 4 + 0.5) / 4
    set_cursor_orientation(player, orientation)
    return
  end

  -- Rolling stocks don't support direction, however they do affect the cursor direction when pipetted.
  -- That's why this check is below that logic
  if not pipetted_entity.supports_direction then return end

  if entity_type == "underground-belt" then
    local orientation = direction_to_orientation_lut[pipetted_entity.direction]
    if pipetted_entity.belt_to_ground_type == "output" then
      orientation = orientation + 0.5
    end
    set_cursor_orientation(player, orientation)
    return
  end

  if entity_type == "loader" or entity_type == "loader-1x1" then
    local orientation = direction_to_orientation_lut[pipetted_entity.direction]
    if pipetted_entity.loader_type == "input" then
      orientation = orientation + 0.5
    end
    set_cursor_orientation(player, orientation)
    return
  end

  set_cursor_orientation(player, direction_to_orientation_lut[pipetted_entity.direction])
end

local snapping_entity_type_lut = {
  ["offshore-pump"] = true,
  ["rail-signal"] = true,
  ["rail-chain-signal"] = true,
  ["train-stop"] = true,
}

---This doesn't exist because placing an entity affects the cursor direction. It just exists because these
---entities have snapping behavior while hovering them, so by using the build event for them we have a higher
---chance at catching those direction changes through hovers than we would have without this at all.
---@param player PlayerDataQAI
---@param created_entity LuaEntity @ Can be any entity.
---@param entity_type string?
local function handle_built_rail_connectable_or_offshore_pump(player, created_entity, entity_type)
  entity_type = entity_type or inserter_throughput.get_real_or_ghost_entity_type(created_entity)

  if snapping_entity_type_lut[entity_type] then
    set_cursor_orientation(player, direction_to_orientation_lut[created_entity.direction])
    return
  end

  -- It would be bad to use the direction of other created entities, because things like fluid tanks only have
  -- 2 directions, however holding them in the cursor or placing them does not change the direction of the
  -- cursor, even if the cursor direction is south or or west. Also for any 4 way entities, placing them
  -- doesn't have an effect on the cursor direction either, so you can switch to an 8 way entity and it would
  -- still be diagonal (if it was diagonal previously).
end

local eight_way_orientation_to_four_directions_lut = {
  [0] = defines.direction.north,
  [0.125] = defines.direction.north,
  [0.25] = defines.direction.east,
  [0.375] = defines.direction.east,
  [0.5] = defines.direction.south,
  [0.625] = defines.direction.south,
  [0.75] = defines.direction.west,
  [0.875] = defines.direction.west,
}

---@param player PlayerDataQAI
---@return defines.direction
local function get_cursor_direction_four_way(player)
  return eight_way_orientation_to_four_directions_lut[player.current_cursor_orientation]
end

local eight_way_orientation_to_eight_directions_lut = {
  [0] = defines.direction.north,
  [0.125] = defines.direction.northeast,
  [0.25] = defines.direction.east,
  [0.375] = defines.direction.southeast,
  [0.5] = defines.direction.south,
  [0.625] = defines.direction.southwest,
  [0.75] = defines.direction.west,
  [0.875] = defines.direction.northwest,
}

---@param player PlayerDataQAI
---@return defines.direction
local function get_cursor_direction_eight_way(player)
  return eight_way_orientation_to_eight_directions_lut[player.current_cursor_orientation]
end

---Because it isn't part of the game state, it'll reset to north on game load. Cannot detect that in single
---player, but in multiplayer we can so might as well.
---@param player PlayerDataQAI
local function on_player_joined(player)
  set_cursor_orientation(player, 0)
end

---@param player PlayerDataQAI
local function init_player(player)
  set_cursor_orientation(player, 0)
end

---@class CursorDirectionFileQAI
local cursor_direction = {
  handle_rotation = handle_rotation,
  handle_pipette_direction = handle_pipette_direction,
  handle_built_rail_connectable_or_offshore_pump = handle_built_rail_connectable_or_offshore_pump,
  get_cursor_direction_four_way = get_cursor_direction_four_way,
  get_cursor_direction_eight_way = get_cursor_direction_eight_way,
  on_player_joined = on_player_joined,
  init_player = init_player,
}
return cursor_direction
