
for _, player in pairs(storage.players) do
  if player.inserter_speed_text_obj then player.inserter_speed_text_obj.destroy() end
end
