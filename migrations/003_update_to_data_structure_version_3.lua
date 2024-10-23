
-- Migrations also run after `on_init`, do not touch `storage` in that case.
if (storage.data_structure_version or 1) >= 3 then return end

local entity_prototypes = prototypes.entity
for _, force in pairs(storage.forces) do
  for name, cache in pairs(force.inserter_cache_lut) do
    cache.prototype = entity_prototypes[name]
      or {valid = false} -- To handle removed prototypes in this migration. Cache will get regenerated anyway.
    ---@diagnostic disable-next-line: inject-field
    cache.name = nil
  end
end

storage.data_structure_version = 3
