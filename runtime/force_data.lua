local consts = require("__quick-adjustable-inserters__.runtime.consts")
local generate_cache_for_inserter = require("__quick-adjustable-inserters__.runtime.cache")
local player_data = require("__quick-adjustable-inserters__.runtime.player_data")
local utils = require("__quick-adjustable-inserters__.runtime.utils")
local long_inserter_range_type = consts.long_inserter_range_type

---@type StatesFileQAI
local states

---@param refs {states: StatesFileQAI}
local function set_circular_references(refs)
  states = refs.states
end

local init_force

---@param force_index uint32 @ Does not necessarily even need to exist.
local function remove_force_index(force_index)
  storage.forces[force_index] = nil
end

---@param force ForceDataQAI
local function remove_force(force)
  remove_force_index(force.force_index)
end

---@param force ForceDataQAI?
---@return ForceDataQAI?
local function validate_force(force)
  if not force then return end
  if force.force.valid then return force end
  remove_force(force)
end

---@param force_index uint32
---@return ForceDataQAI?
local function get_force(force_index)
  return validate_force(storage.forces[force_index])
end

---Can be called even if the given `force_index` actually does not exist at this point in time.
---@param force_index uint32
---@return ForceDataQAI?
local function get_or_init_force(force_index)
  local force = get_force(force_index)
  if force then return force end
  local actual_force = game.forces[force_index]
  return actual_force and init_force(actual_force) or nil
end

---@param force ForceDataQAI
local function update_inserter_cache(force)
  force.inserter_cache_lut = {}
  for _, inserter in pairs(prototypes.get_entity_filtered { { filter = "type", type = "inserter" } }) do
    -- No matter what other flags the inserter has set (in other words no matter what crazy things other mods
    -- might be doing), generate cache for it if it has `allow_custom_vectors` set, allowing this mod to
    -- adjust it. Even if it isn't selectable or if it is rotatable 8 way, both of which make little sense for
    -- this mod, the remote interface exists, and the 8 directions won't break this mod.
    if inserter.allow_custom_vectors
      and not inserter.name:match("^hps__ml%-") -- See 'exclude' annotations in 'data_core.lua'.
    then
      force.inserter_cache_lut[inserter.name] = generate_cache_for_inserter(inserter, force.tech_level)
    end
  end
  for _, actual_player in ipairs(force.force.players) do
    local player = storage.players[actual_player.index]
    if player then
      states.switch_to_idle_and_back(player)
    end
  end
end

local update_tech_level_for_force
do
  ---@generic T
  ---@param name string
  ---@param default_value T
  ---@return T
  local function get_startup_setting_value(name, default_value)
    local setting = settings.startup[name]
    -- A setting from another mod, we cannot trust it actually existing.
    -- There's an argument to be made that this should throw an error if the setting does not exist, and yea
    -- I'm considering it. But also :shrug:.
    if setting then
      return setting.value
    else
      return default_value
    end
  end

  ---@param tech_level TechnologyLevelQAI
  ---@param techs LuaCustomTable<string, LuaTechnology>
  local function evaluate_near(tech_level, techs)
    if consts.use_smart_inserters and not get_startup_setting_value("si-offset-technologies", false) then
      tech_level.drop_offset = true
      return
    end
    local near_inserters = techs[consts.near_inserters_name]
    tech_level.drop_offset = near_inserters and near_inserters.researched or false
  end

  ---@param tech_level TechnologyLevelQAI
  ---@param techs LuaCustomTable<string, LuaTechnology>
  local function evaluate_tiles(tech_level, techs)
    if consts.use_smart_inserters and not get_startup_setting_value("si-diagonal-technologies", false) then
      tech_level.all_tiles = true
      tech_level.cardinal = true
      tech_level.diagonal = true
      return
    end
    local cardinal_inserters = consts.cardinal_inserters_name and techs[consts.cardinal_inserters_name]
    local more_inserters_1 = techs[consts.more_inserters_1_name]
    local more_inserters_2 = techs[consts.more_inserters_2_name]
    tech_level.all_tiles = more_inserters_2 and more_inserters_2.researched or false
    tech_level.cardinal = tech_level.all_tiles or (cardinal_inserters == nil and true or cardinal_inserters.researched)
    tech_level.diagonal = tech_level.all_tiles or more_inserters_1 and more_inserters_1.researched or false
  end

  ---@param techs LuaCustomTable<string, LuaTechnology>
  ---@return integer
  local function get_range_from_technologies(techs)
    local range = 1
    for level = 1, 1 / 0 do      -- No artificial limit, the practical limit will be hit pretty quickly anyway.
      local tech = techs[string.format(consts.range_technology_format, level)]
      if not tech then break end -- Gaps in technologies are not accepted.
      if tech.researched then
        range = level + 1        -- "bob-long-inserters-1" equates to having 2 range.
      end
      -- Continue even if a technology isn't researched to find the highest technology which has been researched.
      -- The highest technology is unknown, so it's just a loop from the bottom up.
    end
    return range
  end

  ---@param tech_level TechnologyLevelQAI
  ---@param techs LuaCustomTable<string, LuaTechnology>
  local function evaluate_range(tech_level, techs)
    if consts.use_smart_inserters and not get_startup_setting_value("si-range-technologies", false) then
      -- Using math.max because this is the setting from another mod therefore we cannot trust it.
      tech_level.range = math.max(1, get_startup_setting_value("si-max-inserters-range", 3))
      return
    end
    tech_level.range = get_range_from_technologies(techs)
  end

  ---@param force ForceDataQAI
  function update_tech_level_for_force(force)
    local tech_level = force.tech_level
    local techs = force.force.technologies
    evaluate_near(tech_level, techs)
    evaluate_tiles(tech_level, techs)
    evaluate_range(tech_level, techs)
    update_inserter_cache(force)
  end
end

local function update_tech_level_for_all_forces()
  for _, force in utils.safer_pairs(storage.forces) do
    if validate_force(force) then
      update_tech_level_for_force(force)
    end
  end
end

---@param actual_force LuaForce
---@return ForceDataQAI
function init_force(actual_force)
  local force_index = actual_force.index
  ---@type ForceDataQAI
  local force = {
    force = actual_force,
    force_index = force_index,
    tech_level = {},
    inserter_cache_lut = (nil) --[[@as any]], -- Set in `update_inserter_cache`.
  }
  storage.forces[force_index] = force
  update_tech_level_for_force(force)
  return force
end

local function update_only_allow_mirrored_setting()
  storage.only_allow_mirrored = settings.global["qai-mirrored-inserters-only"].value --[[@as boolean]]
  for _, player in utils.safer_pairs(storage.players) do
    if player_data.validate_player(player) then
      states.switch_to_idle_and_back(player)
    end
  end
end

local update_range_for_long_inserters_setting
do
  ---@return "inserter"|"incremental"|"equal"|"rebase"|"incremental-with-rebase"|"inserter-with-rebase"|string
  local function get_range_adder_setting_value()
    local setting = settings.startup["si-range-adder"]
    -- A setting from another mod, we cannot trust it actually existing.
    -- There's an argument to be made that this should throw an error if the setting does not exist, and yea
    -- I'm considering it. But also :shrug:.
    return setting and setting.value --[[@as string]] or "equal"
  end

  local smart_inserters_mapping = {
    ["inserter"] = long_inserter_range_type.retract_only_inverse,
    ["incremental"] = long_inserter_range_type.extend_only_starting_at_inner,
    ["equal"] = long_inserter_range_type.extend_only_starting_at_inner,
    ["rebase"] = long_inserter_range_type.extend_only_starting_at_inner_intersect_with_gap,
    ["incremental-with-rebase"] = long_inserter_range_type.extend_only,
    ["inserter-with-rebase"] = long_inserter_range_type.unlock_when_range_tech_reaches_inserter_range,
  }

  local function update_using_smart_inserters_setting()
    local range_adder_type = get_range_adder_setting_value()
    storage.range_for_long_inserters = smart_inserters_mapping[range_adder_type]
      or long_inserter_range_type.retract_then_extend -- Setting from another mod, could have unknown values.
  end

  local function update_using_qai_setting()
    local value = settings.global["qai-range-for-long-inserters"].value --[[@as string]]
    if value == "retract-then-extend" then
      storage.range_for_long_inserters = long_inserter_range_type.retract_then_extend
    elseif value == "extend-only" then
      storage.range_for_long_inserters = long_inserter_range_type.extend_only
    elseif value == "extend-only-without-gap" then
      storage.range_for_long_inserters = long_inserter_range_type.extend_only_without_gap
    end
  end

  ---@param do_not_update_forces boolean?
  function update_range_for_long_inserters_setting(do_not_update_forces)
    if consts.use_smart_inserters then
      update_using_smart_inserters_setting()
    else
      update_using_qai_setting()
    end
    if do_not_update_forces then return end
    update_tech_level_for_all_forces()
  end
end

---@class ForceDataUtilQAI
local force_data = {
  set_circular_references = set_circular_references,
  remove_force_index = remove_force_index,
  get_force = get_force,
  get_or_init_force = get_or_init_force,
  update_tech_level_for_force = update_tech_level_for_force,
  update_tech_level_for_all_forces = update_tech_level_for_all_forces,
  init_force = init_force,
  update_only_allow_mirrored_setting = update_only_allow_mirrored_setting,
  update_range_for_long_inserters_setting = update_range_for_long_inserters_setting,
}
return force_data
