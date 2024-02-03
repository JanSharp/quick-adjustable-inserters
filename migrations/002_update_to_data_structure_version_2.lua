
-- Migrations also run after `on_init`, do not touch `global` in that case.
if (global.data_structure_version or 1) >= 2 then return end

-- This is just a dummy value to prevent an any errors which would expect this value to exist.
-- it is overwritten to the correct value in on_configuration_changed.
global.range_for_long_inserters = 1

for _, player in pairs(global.players) do
  if not player.player.valid then
    player.always_use_default_drop_offset = false
    goto continue
  end
  local player_settings = settings.get_player_settings(player.player)
  player.always_use_default_drop_offset = player_settings["qai-always-use-default-drop-offset"].value--[[@as boolean]]
  -- on_configuration_changed ends up running switch_to_idle_and_back on all players.
  ::continue::
end

for _, force in pairs(global.forces) do
  for _, cache in pairs(force.inserter_cache_lut) do
    -- Cache will get regenerated in on_configuration_changed anyway, just needs some non `nil` values until then.
    if cache.prototype.valid then
      cache.raw_tile_width = cache.prototype.tile_width
      cache.raw_tile_height = cache.prototype.tile_height
    else
      cache.raw_tile_width = cache.tile_width
      cache.raw_tile_height = cache.tile_height
    end
  end
end

global.data_structure_version = 2
