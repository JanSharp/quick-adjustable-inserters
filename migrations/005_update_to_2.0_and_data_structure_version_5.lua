
-- Migrations also run after `on_init`, do not touch `storage` in that case.
if (storage.data_structure_version or 1) >= 5 then return end

rendering.clear("quick-adjustable-inserters")

for _, animation in pairs(storage.active_animations) do
  animation.id = nil ---@diagnostic disable-line: inject-field
  animation.obj = {valid = false}
end

---@param vertices (ScriptRenderTarget|{target: MapPosition})[]
local function update_vertices(vertices)
  for i, vertex in pairs(vertices) do
    vertices[i] = vertex.target
  end
end

for _, force_data in pairs(storage.forces) do
  for _, cache in pairs(force_data.inserter_cache_lut) do
    update_vertices(cache.direction_arrow_vertices)
    update_vertices(cache.tiles_background_vertices)
    update_vertices(cache.tiles_background_vertices_flipped)
  end
end

for _, player_data in pairs(storage.players) do
  player_data.line_objs = {}
  player_data.direction_arrows_indicator_line_objs = {}
  player_data.background_polygon_id = nil ---@diagnostic disable-line: inject-field
  player_data.background_polygon_obj = {valid = false}
  player_data.inserter_circle_id = nil ---@diagnostic disable-line: inject-field
  player_data.inserter_circle_obj = {valid = false}
  player_data.direction_arrow_id = nil ---@diagnostic disable-line: inject-field
  player_data.direction_arrow_obj = {valid = false}
  player_data.pickup_highlight_id = nil ---@diagnostic disable-line: inject-field
  player_data.pickup_highlight_obj = {valid = false}
  player_data.drop_highlight_id = nil ---@diagnostic disable-line: inject-field
  player_data.drop_highlight_obj = {valid = false}
  player_data.line_to_pickup_highlight_id = nil ---@diagnostic disable-line: inject-field
  player_data.line_to_pickup_highlight_obj = {valid = false}
  player_data.inserter_speed_text_id = nil ---@diagnostic disable-line: inject-field
  player_data.inserter_speed_text_obj = {valid = false}
end

storage.data_structure_version = 5
