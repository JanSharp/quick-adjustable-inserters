
local util = require("__core__.lualib.util")

qai_data = qai_data or {
  touched_inserters = {}--[[@as table<string, {did_allow_custom_vectors: boolean?, prev_drop: data.Vector, prev_pickup: data.Vector}>]],
}

---@param name string @ Name of a bool setting.
---@param default_if_non_existent boolean @ What value should it return if the setting doesn't exist?
---@return boolean
local function check_setting(name, default_if_non_existent)
  local setting = settings.startup[name]
  if not setting then
    return default_if_non_existent
  end
  return setting.value--[[@as boolean]]
end

---@param inserter data.InserterPrototype
---@return boolean
local function is_hidden(inserter)
  for _, flag in pairs(inserter.flags) do
    if flag == "hidden" then
      return true
    end
  end
  return false
end

---@param inserter data.InserterPrototype
local function modify_inserter(inserter)
  if qai_data.touched_inserters[inserter.name] then return end
  qai_data.touched_inserters[inserter.name] = {
    did_allow_custom_vectors = inserter.allow_custom_vectors,
    prev_pickup = util.copy(inserter.pickup_position),
    prev_drop = util.copy(inserter.insert_position),
  }
  inserter.allow_custom_vectors = true
  if not check_setting("qai-normalize-default-vectors", false) then return end

  local collision_box = inserter.collision_box
  -- 0.4 is just a semi-random number I chose to make it not error on bad data from other mods. Unless it's
  -- legitimately valid not to have a collision box, or not to define one of its members, in which case 0.4
  -- seems like a reasonable default when it comes to determining the tile_width and tile_height.
  local left_top = collision_box and collision_box[1] or {x = -0.4, y = -0.4}
  local right_bottom = collision_box and collision_box[2] or {x = 0.4, y = 0.4}
  local tile_width = inserter.tile_width
    or math.ceil((right_bottom.x or right_bottom[1]) - (left_top.x or left_top[1]))
  local tile_height = inserter.tile_height
    or math.ceil((right_bottom.y or right_bottom[2]) - (left_top.y or left_top[2]))
  local even_width = (tile_width % 2) == 0
  local even_height = (tile_height % 2) == 0

  local x, y
  ---@param vector data.MapPosition
  local function figure_out_the_format(vector)
    x = vector.x and "x" or 1
    y = vector.y and "y" or 2
  end

  ---@param vector data.MapPosition
  local function snap(vector)
    vector[x] = math.floor(vector[x] + (even_width and 0 or 0.5)) + (even_width and 0.5 or 0)
    vector[y] = math.floor(vector[y] + (even_height and 0 or 0.5)) + (even_height and 0.5 or 0)
  end

  local pickup = inserter.pickup_position
  figure_out_the_format(pickup)
  snap(pickup)

  local drop = inserter.insert_position
  figure_out_the_format(pickup)
  local old_x = drop[x]
  local old_y = drop[y]
  snap(drop)
  local x_from_tile_center = old_x - drop[x]
  local y_from_tile_center = old_y - drop[y]
  local x_offset = x_from_tile_center < -1/6 and -51/256
    or x_from_tile_center <= 1/6 and 0
    or 51/256
  local y_offset = y_from_tile_center < 1/6 and -51/256
    or y_from_tile_center <= 1/6 and 0
    or 51/256
  drop[x] = drop[x] + x_offset
  drop[y] = drop[y] + y_offset
end

---@param tab table?
local function clear_table(tab)
  if not tab then return end
  local next = next
  local k = next(tab)
  while k do
    local next_k = next(tab, k)
    tab[k] = nil
    k = next_k
  end
end

---@generic T : table
---@param destination T
---@param source T
local function overwrite_table(destination, source)
  clear_table(destination)
  for k, v in pairs(source) do
    destination[k] = v
  end
end

---Handles inserters becoming hidden after they've been modified.
---@param inserter data.InserterPrototype
local function undo_modification(inserter)
  local backup = qai_data.touched_inserters[inserter.name]
  if not backup then return end
  qai_data.touched_inserters[inserter.name] = nil
  inserter.allow_custom_vectors = backup.did_allow_custom_vectors
  if not check_setting("qai-normalize-default-vectors", false) then return end
  overwrite_table(inserter.pickup_position, backup.prev_pickup)
  overwrite_table(inserter.insert_position, backup.prev_drop)
end

local function modify_existing_inserters()
  for _, inserter in pairs(data.raw["inserter"]) do
    if is_hidden(inserter) then
      undo_modification(inserter)
    else
      modify_inserter(inserter)
    end
  end
end

return {
  check_setting = check_setting,
  modify_existing_inserters = modify_existing_inserters,
}
