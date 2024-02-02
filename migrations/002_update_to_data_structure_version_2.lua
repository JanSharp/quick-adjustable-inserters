
-- Migrations also run after `on_init`, do not touch `global` in that case.
if (global.data_structure_version or 1) >= 2 then return end

-- This is just a dummy value to prevent an any errors which would expect this value to exist.
-- it is overwritten to the correct value in on_configuration_changed.
global.range_for_long_inserters = 1
global.data_structure_version = 2
