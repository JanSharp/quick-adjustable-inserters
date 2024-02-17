
-- Migrations also run after `on_init`, do not touch `global` in that case.
if (global.data_structure_version or 1) >= 2 then return end

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
