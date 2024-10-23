
-- Migrations also run after `on_init`, do not touch `storage` in that case.
if (storage.data_structure_version or 1) >= 4 then return end

-- This is just a dummy value to prevent an any errors which would expect this value to exist.
-- it is overwritten to the correct value in on_configuration_changed.
storage.range_for_long_inserters = 1

for _, player in pairs(storage.players) do
  if not player.player.valid then
    player.always_use_default_drop_offset = false
    goto continue
  end
  local player_settings = settings.get_player_settings(player.player)
  player.always_use_default_drop_offset = player_settings["qai-always-use-default-drop-offset"].value--[[@as boolean]]
  -- on_configuration_changed ends up running switch_to_idle_and_back on all players.
  ::continue::
end

storage.data_structure_version = 4
