
for _, player in pairs(global.players) do
  local id = player.inserter_speed_text_id
  if id then
    rendering.destroy(id)
  end
end
