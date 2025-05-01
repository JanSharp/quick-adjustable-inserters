
---cSpell:ignore IDQAI

do return end -- To make it clear that this file is never run.

---Unique table for a ghost in the world. So multiple LuaEntity instances can evaluate to the same id.
---Specifically when they are actually a reference to the same ghost entity in the world.\
---Must store information purely to be able to remove the id from the `storage.ghosts_id` table again, because
---the entity may be destroyed before the id gets removed.
---@class EntityGhostIDQAI
---@field surface_index uint32
---@field x double
---@field y double

---`unit_number` or a unique table for ghosts which don't have a `ghost_unit_number`.
---@alias EntityIDQAI uint32|EntityGhostIDQAI

---@class StorageDataQAI
---@field data_structure_version 5 @ `nil` is version `1`. Use `(storage.data_structure_version or 1)`.
---@field players table<int, PlayerDataQAI>
---@field forces table<uint8, ForceDataQAI>
---@field inserters_in_use table<EntityIDQAI, PlayerDataQAI>
---@field active_players PlayerDataQAI[]|{count: integer, next_index: integer}
---@field active_animations AnimationQAI[]|{count: integer}
---Selectable entity unit number => player data.
---@field selectable_entities_to_player_lut table<uint32, PlayerDataQAI>
---Selectable entity unit number => entity with that unit number.
---@field selectable_entities_by_unit_number table<uint32, LuaEntity>
---Selectable square unit number => inserter.
---@field selectable_dummy_redirects table<uint32, LuaEntity>
---@field ghost_ids table<uint32, table<double, table<double, EntityGhostIDQAI>>>
---@field only_allow_mirrored boolean
---@field range_for_long_inserters LongInserterRangeTypeQAI
storage = {}

---@alias AnimationQAI
---| AnimatedCircleQAI
---| AnimatedRectangleQAI
---| AnimatedLineQAI
---| AnimatedColorQAI

---@class AnimationBaseQAI
---@field type AnimationTypeQAI
---@field obj LuaRenderObject
---@field remaining_updates integer @ Stays alive when going to 0, finishes the next update.
---@field destroy_on_finish boolean?

---@class AnimatedCircleQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field radius number @ Matches the current value.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.
---@field radius_step number @ Added each tick.

---@class AnimatedRectangleQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field left_top MapPosition @ Matches the current value.
---@field right_bottom MapPosition @ Matches the current value.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.
---@field left_top_step MapPosition @ Matches the current value.
---@field right_bottom_step MapPosition @ Matches the current value.

---@class AnimatedLineQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field from MapPosition @ Matches the current value.
---@field to MapPosition @ Matches the current value.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.
---@field from_step MapPosition @ Matches the current value.
---@field to_step MapPosition @ Matches the current value.

---@class AnimatedColorQAI : AnimationBaseQAI
---@field color Color @ Matches the current value. Must have fields r, g, b and a.
---@field color_step Color @ Added each tick. Must have fields r, g, b and a.

---@class ForceDataQAI
---@field force_index uint32
---@field force LuaForce
---@field inserter_cache_lut table<string, InserterCacheQAI>
---@field tech_level TechnologyLevelQAI

---@class LineDefinitionQAI
---@field from MapPosition
---@field to MapPosition

---@class DirectionArrowDefinitionQAI
---@field position MapPosition
---@field direction defines.direction

---@class InserterCacheQAI
---@field disabled_because_of_tech_level boolean? @ When true everything else is `nil`.
---Always check valid before using, because prototypes can be removed and in the process of migrating before
---or in on_configuration_changed any other could could still end up running.
---@field prototype LuaEntityPrototype
---@field raw_tile_width integer @ Raw value from the prototype.
---@field raw_tile_height integer @ Raw value from the prototype.
---@field tech_level TechnologyLevelQAI
---@field range integer @ Without smart inserters this is always equal to tech_level.range.
---@field min_extra_reach_distance number @ The minimum extra reach distance when building this entity.
---@field diagonal_by_default boolean
---@field default_drop_offset_multiplier -1|0|1 @ -1 = near, 0 = center, 1 = far. Vanilla is all far, fyi.
---@field min_extra_build_distance number @ The minimum extra reach distance when building this entity.
---@field is_square boolean @ When false, `vertical_offset_from_inserter ~= horizontal_offset_from_inserter`.
---@field base_range integer
---@field range_gap_from_center integer
---Defines how to calculate the left top position of the grid when given an inserter entity. By adding
---this value to the inserter's position, the left top position - the grid origin - has been found. All
---other positions in this definition are then relative to this calculated position.\
---For inserters placable off grid, the tiles, lines and simply everything from this mod will also be off
---grid.
---@field offset_from_inserter MapPosition
---@field offset_from_inserter_flipped MapPosition @ Use when `player.should_flip` is true.
---@field grid_center MapPosition
---@field grid_center_flipped MapPosition
---@field radius_for_circle_on_inserter number
---@field placeable_off_grid boolean
---The width of the open inner grid, occupied by the collision box and selection box of the inserter.
---@field tile_width integer
---The height of the open inner grid, occupied by the collision box and selection box of the inserter.
---@field tile_height integer
---@field only_drop_offset boolean
---@field tiles MapPosition[] @ `nil` when only_drop_offset.
---@field tiles_flipped MapPosition[] @ `nil` when only_drop_offset.
---@field tiles_background_vertices ScriptRenderTarget[] @ `nil` when only_drop_offset.
---@field tiles_background_vertices_flipped ScriptRenderTarget[] @ `nil` when only_drop_offset.
---@field lines LineDefinitionQAI[] @ `nil` when only_drop_offset.
---@field lines_flipped LineDefinitionQAI[] @ `nil` when only_drop_offset.
---@field not_rotatable boolean
---@field direction_arrows_indicator_lines LineDefinitionQAI[] @ `nil` when not_rotatable.
---@field direction_arrows_indicator_lines_flipped LineDefinitionQAI[] @ `nil` when not_rotatable.
---`nil` when not_rotatable. 4 when square, otherwise 2 (north and south).
---@field direction_arrows DirectionArrowDefinitionQAI[]
---@field direction_arrow_position MapPosition @ `nil` when not_rotatable.
---@field direction_arrow_vertices ScriptRenderTarget[] @ `nil` when not_rotatable.
---@field chases_belt_items boolean

---@class TechnologyLevelQAI
---@field range integer
---@field drop_offset boolean
---@field cardinal boolean @ Meaning horizontal and vertical. Couldn't find a better term.
---@field diagonal boolean
---@field all_tiles boolean @ When true, `cardinal` and `diagonal` are implied to also be true.

---@class PlayerDataQAI : StateDataQAI, SelectablesDataQAI, RenderingDataQAI, HighlightsDataQAI, InserterSpeedDataQAI, PlayerSettingsDataQAI, PipetteDataQAI
---@field player LuaPlayer
---@field player_index uint
---If at any point a mod changes a player's force and some mod causes this mod here to use this force_index
---inside of their on_player_changed_force, before this mod here gets the event, then there will be errors
---I'm guessing. But that's worth the performance improvement of having this cached for all the performance
---critical code paths using it. (Same applies to force merging, probably.)
---@field force_index uint8
---Current internal direction of the cursor, represented as orientation for simplified computation. Performing
---math on direction values is bad practice because the values of defines is not part of the specification.
---@field current_cursor_orientation RealOrientation
---@field index_in_active_players integer @ Non `nil` when non idle or has_active_inserter_speed_text.

---@alias PlayerStateQAI
---| "idle"
---| "selecting-pickup"
---| "selecting-drop"

---@class StateDataQAI
---@field state PlayerStateQAI
---Always `nil` when not idle. Set to `true` when `keep_rendering` was set for `switch_to_idle`, because then
---the rendering objects are still alive even though the state is idle. This can then be used to ensure these
---objects get destroyed if another state switch happens before these objects were able to be reused. Which
---can only happen when mods do things in a raised event during our `switch_to_idle`.
---@field rendering_is_floating_while_idle boolean?
---`nil` when idle. Must be stored, because we can switch to idle _after_ an entity has been invalidated.
---@field target_inserter_id EntityIDQAI
---@field target_inserter LuaEntity @ `nil` when idle.
---@field target_inserter_cache InserterCacheQAI @ `nil` when idle.
---@field target_inserter_position MapPosition @ `nil` when idle.
---`nil` when idle. Used purely to detect changes. All other logic re-fetches the pickup position.
---@field target_inserter_pickup_position MapPosition
---`nil` when idle. Used purely to detect changes. All other logic re-fetches the drop position.
---@field target_inserter_drop_position MapPosition
---@field target_inserter_direction defines.direction @ `nil` when idle.
---@field target_inserter_force_index uint32 @ `nil` when idle.
---`nil` when idle.\
---`true` for non square inserters facing west or east.
---Those end up pretending to be north and south, but flipped diagonally.
---@field should_flip boolean
---@field is_rotatable boolean @ `nil` when idle.
---@field current_surface_index uint @ `nil` when idle.
---@field current_surface LuaSurface @ `nil` when idle.
---`nil` when idle. Ghosts don't need reach checks, and when going from ghost to real, it still shouldn't do
---reach checks, because that'd be annoying. Imagine bots kicking you out of adjustment.
---@field no_reach_checks boolean?
---@field pipette_when_done boolean?
---@field reactivate_inserter_when_done boolean?

---@class SelectablesDataQAI
---Used to redirect interaction to the inserter itself when selecting drop within a single tile. Allows for
---quick double tap to finish adjustment when using only_allow_mirrored for example.
---@field dummy_pickup_square LuaEntity?
---@field dummy_pickup_square_unit_number uint32?
---@field used_squares uint[]
---@field used_ninths uint[]
---@field used_rects uint[]

---@class RenderingDataQAI
---Contains a rectangle id instead, when highlighting a single tile as the drop position.
---@field line_objs LuaRenderObject[]
---@field direction_arrows_indicator_line_objs LuaRenderObject[]
---Contains a rectangle id instead, when highlighting a single tile as the drop position.
---@field background_polygon_obj LuaRenderObject?
---@field inserter_circle_obj LuaRenderObject?
---@field direction_arrow_obj LuaRenderObject? @ Only exists when `is_rotatable`.
---@field pickup_highlight_obj LuaRenderObject?
---@field drop_highlight_obj LuaRenderObject?
---@field line_to_pickup_highlight_obj LuaRenderObject? @ Can even be `nil` when `pickup_highlight_obj` is not `nil`.

---@class HighlightsDataQAI
---@field default_drop_highlight LuaEntity?
---@field mirrored_highlight LuaEntity? @ Only used with only_allow_mirrored.

---@class InserterSpeedDataQAI
---@field has_active_inserter_speed_text boolean? @ Value is entirely unrelated to `state`.
---@field inserter_speed_reference_inserter LuaEntity @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_stack_size integer @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_pickup_position MapPosition @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_drop_position MapPosition @ `nil` when not has_active_inserter_speed_text.
---@field inserter_speed_text_obj LuaRenderObject? @ Only `nil` initially, once it exists, it's never destroyed (by this mod).
---@field inserter_speed_text_surface_index uint32? @ Only `nil` initially, once it exists, it exists.

---@class PlayerSettingsDataQAI
---@field show_throughput_on_drop boolean
---@field show_throughput_on_pickup boolean
---@field show_throughput_on_inserter boolean
---@field highlight_default_drop_offset boolean
---@field always_use_default_drop_offset boolean
---@field pipette_after_place_and_adjust boolean
---@field pipette_copies_vectors boolean

---@class PipetteDataQAI
---@field pipetted_inserter_name string?
---@field pipetted_pickup_vector MapPosition @ `nil` when `pipetted_inserter_name` is `nil`.
---@field pipetted_drop_vector MapPosition @ `nil` when `pipetted_inserter_name` is `nil`.

---@diagnostic disable-next-line: duplicate-doc-alias
---@enum defines.events
defines.events = {
  on_qai_inserter_direction_changed = #{}--[[@as defines.events.on_qai_inserter_direction_changed]],
  on_qai_inserter_vectors_changed = #{}--[[@as defines.events.on_qai_inserter_vectors_changed]],
  on_qai_inserter_adjustment_finished = #{}--[[@as defines.events.on_qai_inserter_adjustment_finished]],
}

---Called when QAI changed the direction of an inserter through the selectables on the outside of the
---adjustment UI, with the large arrow. QAI makes the inserter keep the pickup and drop positions even though
---the direction did change.
---@class (exact) EventData.on_qai_inserter_direction_changed : EventData
---The inserter which direction has been changed.
---@field entity LuaEntity
---The previous direction. Technically possible to be unchanged if another mod changed the direction inside
---of its event handler for this same event.
---@field previous_direction defines.direction

---Called when QAI changed the pickup and or drop position of an inserter due to a player adjusting it through
---QAI's UI.
---@class (exact) EventData.on_qai_inserter_vectors_changed : EventData
---The index of the player which performed an adjustment.
---@field player_index uint
---The inserter which has been adjusted.
---@field inserter LuaEntity
---The previous `pickup_position`. May be unchanged.
---@field previous_pickup_position MapPosition
---The previous `drop_position`. May be unchanged.
---@field previous_drop_position MapPosition

---Called when QAI finished adjusting an inserter, aka the UI begins disappearing.\
---Called regardless of if anything changed.
---@class (exact) EventData.on_qai_inserter_adjustment_finished : EventData
---The index of the player which was adjusting an inserter. A player for this index may no longer exist if
---adjustment was finished due to player having been removed, see
---[remove_offline_players](https://lua-api.factorio.com/latest/classes/LuaGameScript.html#remove_offline_players).
---@field player_index uint
---The inserter which was being adjusted. May be nil, in which case QAI is finishing adjustment due to the
---inserter having been destroyed.
---@field inserter LuaEntity?
