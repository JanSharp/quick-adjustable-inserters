
local util = require("__core__.lualib.util")

qai_data = qai_data or {
  touched_inserters = {}--[[@as table<string, {did_allow_custom_vectors: boolean?, prev_drop: data.Vector, prev_pickup: data.Vector}>]],
  patterns = {}--[=[@as {is_include: boolean, pattern: string, match_against_all_lower: boolean}[]]=],
  final_fixes_did_run = false,
}

local modify_existing_inserter
local modify_existing_inserters

---**Important:** Any inserter which has `allow_custom_vectors` set to `true`, regardless of it being excluded
---using the `exclude` function, is going to be able to be adjusted by QAI.
---
---Tell QAI to mark all inserters where their prototype name matches the given Lua Pattern as allowed for
---adjustments. Inserters with names not matching the pattern keep their previous included or excluded state.
---
---Included inserters get `allow_custom_vectors` set to `true`, as well as having their pickup and drop
---vectors normalized, if the `"qai-normalize-default-vectors"` mod setting is enabled.
---By default all inserters which are not `hidden` nor have the flags `"building-direction-8-way"`,
---`"building-direction-16-way"` or `"not-selectable-in-game"` are included.
---
---The `include` and `exclude` patterns get applied in sequence.
---For example to exclude all inserters, except those containing the word "long":
---```
---qai.exclude("") -- Excludes every inserter, as the pattern matches any and all strings
---qai.include("long", true) -- Effectively case insensitive
---```
---@param name_pattern string @
---Use the `to_plain_pattern` api function in order convert literal/plain prototype names into a Lua pattern
---which matches against exactly that name, nothing else.
---@param match_against_all_lower boolean? @
---When `true` QAI matches the given pattern against a version of the prototype name which has been converted
---to all lowercase.
local function include(name_pattern, match_against_all_lower)
  qai_data.patterns[#qai_data.patterns+1] = {
    is_include = true,
    pattern = name_pattern,
    match_against_all_lower = not not match_against_all_lower,
  }
  if qai_data.final_fixes_did_run then
    modify_existing_inserters()
  end
end

---**Important:** Any inserter which has `allow_custom_vectors` set to `true`, regardless of it being excluded
---using the `exclude` function, is going to be able to be adjusted by QAI.
---
---Tell QAI to mark all inserters where their prototype name matches the given Lua Pattern as disallowed for
---adjustments. Inserters with names not matching the pattern keep their previous included or excluded state.
---
---Included inserters get `allow_custom_vectors` set to `true`, as well as having their pickup and drop
---vectors normalized, if the `"qai-normalize-default-vectors"` mod setting is enabled.
---By default all inserters which are not `hidden` nor have the flags `"building-direction-8-way"`,
---`"building-direction-16-way"` or `"not-selectable-in-game"` are included.
---
---The `include` and `exclude` patterns get applied in sequence.
---For example to exclude all inserters, except those containing the word "long":
---```
---qai.exclude("") -- Excludes every inserter, as the pattern matches any and all strings
---qai.include("long", true) -- Effectively case insensitive
---```
---
---The pattern `"^hps__ml%-"` is excluded by default in order to ignore all inserters from
---https://mods.factorio.com/mod/miniloader-redux . Those inherently have `allow_custom_vectors` set to
---`true`, so the exclusion happens in hardcoded control stage logic.
---@param name_pattern string @
---Use the `to_plain_pattern` api function in order convert literal/plain prototype names into a Lua pattern
---which matches against exactly that name, nothing else.
---@param match_against_all_lower boolean? @
---When `true` QAI matches the given pattern against a version of the prototype name which has been converted
---to all lowercase.
local function exclude(name_pattern, match_against_all_lower)
  qai_data.patterns[#qai_data.patterns+1] = {
    is_include = false,
    pattern = name_pattern,
    match_against_all_lower = not not match_against_all_lower,
  }
  if qai_data.final_fixes_did_run then
    modify_existing_inserters()
  end
end

exclude("^hps__ml%-") -- They are excluded in control stage no matter what but this keeps data stage cleaner.

---Convert literal/plain prototype names, or just strings in general, into a Lua pattern which matches against
---exactly that name, nothing else.
---
---In other words converting the given string into a fully escaped Lua pattern, as well as adding `^` and `$`
---anchors at the beginning and end respectively.
---
---For example `"long-handed-inserter"` would get converted into `"^long%-handed%-inserter$"`.
---@param plain_name string
---@return string escaped_pattern
local function to_plain_pattern(plain_name)
  return "^"..plain_name:gsub("[%^$()%%.%[%]*+%-?]", "%%%0").."$"
end

---Checks if the given prototype is ignored/excluded by QAI's adjustments. Aka cannot be adjusted.
---
---**Important:** Any inserter which has `allow_custom_vectors` set to `true`, regardless of it being excluded
---using `exclude` function, is going to be able to be adjusted by QAI. Therefore this function returns `true`
---in this case, regardless of previous `include`/`exclude` calls.
---@param inserter_prototype data.InserterPrototype
---@return boolean
local function is_ignored(inserter_prototype)
  modify_existing_inserter(inserter_prototype)
  return not inserter_prototype.allow_custom_vectors
end

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

---@param name string @ Name of a bool setting.
---@param default_if_non_existent boolean @ What value should it return if the setting doesn't exist?
---@return boolean
local function check_tech_setting(name, default_if_non_existent)
  if mods["Smart_Inserters"] then return false end
  local setting = settings.startup[name]
  if not setting then
    return default_if_non_existent
  end
  return setting.value--[[@as boolean]]
end

local function should_be_ignored(inserter_prototype)
  if inserter_prototype.hidden then return true end
  local flags = inserter_prototype.flags
  if not flags then return false end
  for _, flag in pairs(flags) do
    if flag == "building-direction-8-way"
      or flag == "building-direction-16-way"
      or flag == "not-selectable-in-game"
    then
      return true
    end
  end

  local is_included = true
  local name = inserter_prototype.name
  local lower_name = string.lower(name)
  for _, pattern in ipairs(qai_data.patterns) do
    if string.match(pattern.match_against_all_lower and lower_name or name, pattern.pattern) then
      is_included = pattern.is_include
    end
  end

  return not is_included
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
  ---@param vector data.Vector
  local function figure_out_the_format(vector)
    x = vector.x and "x" or 1
    y = vector.y and "y" or 2
  end

  ---@param vector data.Vector
  local function snap(vector)
    vector[x] = math.floor(vector[x] + (even_width and 0 or 0.5)) + (even_width and 0.5 or 0)
    vector[y] = math.floor(vector[y] + (even_height and 0 or 0.5)) + (even_height and 0.5 or 0)
  end

  local pickup = inserter.pickup_position
  figure_out_the_format(pickup)
  snap(pickup)

  local drop = inserter.insert_position
  figure_out_the_format(drop)
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

---@param inserter data.InserterPrototype
function modify_existing_inserter(inserter)
  if should_be_ignored(inserter) then
    undo_modification(inserter)
  else
    modify_inserter(inserter)
  end
end

---@param is_final_fixes boolean?
function modify_existing_inserters(is_final_fixes)
  for _, inserter in pairs(data.raw["inserter"]) do
    modify_existing_inserter(inserter)
  end
  qai_data.final_fixes_did_run = not not is_final_fixes
end

return {
  include = include,
  exclude = exclude,
  is_ignored = is_ignored,
  to_plain_pattern = to_plain_pattern,
  check_setting = check_setting,
  check_tech_setting = check_tech_setting,
  modify_existing_inserters = modify_existing_inserters,
}
