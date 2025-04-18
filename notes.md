
- [x] change force of selectable entities to match the player
- [x] change visibility of rendering objects to the same force as the player
- [x] change visibility of highlight entities to a single player
- [x] switch to idle and back when player changes force
- [x] add player reach restriction
- [x] impl disabled custom drop vectors
- [x] impl only cardinal
- [x] impl only cardinal and diagonal
- [x] detect and support inserters with already longer base range than 1
- [x] support the technologies from bobinserters
  - [x] make inserter caches per force
- [x] don't do anything if the inserter doesn't support runtime changeable vectors
- [x] maybe add some animations
  - [x] happy little popup at both the pickup and drop positions (squares getting bigger and transparent)
  - [x] with it lines connecting the 2, and a circle on the inserter base itself
  - [x] do it in a way where there isn't any overlapping lines, so transparency doesn't screw us
  - [x] maybe fade the grid lines and background and the direction arrow in and out, very rapidly
  - [x] fade in for pickup highlight and line to said pickup highlight
- [x] maybe add very transparent white rendering in each tile that you can actually interact with
  - [x] generate vertices for a polygon and save it in cache, so the entire background is just 1 polygon
- [x] ~~speaking of, what if the entire grid was just a polygon that's cached~~
  - [x] see polygon-for-lines branch, the "lines" end up changing thickness inconsistently and disappear, while lines drawn using draw_line are consistent and have a minimal thickness of 1 pixel, even fully zoomed out
- [x] estimate inserter
- [x] update inserter speed text when pasting settings to an inserter
- [x] maybe position the inserter speed text next to the square the ninth is in instead of directly next to the ninth. Should make comparing numbers easier
- [x] use a consistent offset from the inserter position to prevent inserter speed text jumping around when rotating an inserter with an off center selection box
- [ ] maybe add white highlight box on the entity that would be targeted if the selected position were to be chosen (it's also the entity used for inserter throughput estimation)
- [x] maybe add a tilde in front of the estimated speed, but only when the pickup target is a belt. Every other situation can have perfect accuracy
- [x] per player setting to disable inserter speed estimation entirely
- [x] per player setting to show estimated inserter throughput when hovering any inserter
- [x] ~~per player setting to always use auto drop offset, even when near inserters have been researched~~ see below
- [x] ~~shortcut to toggle near inserters, remove above setting~~ see below
- [x] per player setting to highlight default/auto drop offset, which uses a little blue selection box
- [x] per player setting to make Q pick cause newly placed inserters (ghost or alive) to have the same pickup and drop offsets
- [x] ~~highlight drop positions which would be the fastest for the entity under the currently selected drop target selection~~ Decided against this because with an inserter already placed, plus the pickup position already selected, the fastest drop position is incredibly obvious. And in cases where it isn't 100% obvious, moving the cursor between a few drop positions and looking at the estimated throughput speeds makes it clear as well. So ultimately this is not needed, and would be a lot of logic, plus a significant performance impact on_selected_entity_changed.
- [x] ~~add feature where you can place the inserter using this mods key bind and it will automatically uses the same pickup and drop vectors as the last modified inserter, if they have the same dimensions.~~ You wouldn't be able to click and drag with this, so no that's bad. Use bobinserters GUI for this, or just use blueprints and or copy paste.
- [x] add feature where using the key bind while holding an inserter in hand places it and instantly enters configuration mode
  - [x] upon entering, clear the cursor
  - [x] upon leaving, restore the cursor, if possible and if it didn't change through other means in the mean time
  - [x] setting to not restore cursor when leaving. Even though I believe there's little reason to disable this, by having that setting there mentioning that you can use the key bind to place an inserter it ultimately makes that feature more discoverable. That's a good enough reason to keep the setting.
  - [x] maybe place ghosts when the player cannot reach? That is if ghost support gets added.
  - [x] place ghosts if the cursor is a ghost, not an actual item
- [x] support ghosts, if possible (I think it is)
  - [x] support a ghost becoming real (reviving)
  - [x] support an entity becoming a ghost (dieing)
  - [x] if a ghost became real, do not stop adjusting because of being "out of range". Just pretend there was no range limitation until the player is done adjusting
- [x] support inserters of any size, and off grid
- [x] handle multiplayer
  - [x] switch to idle when leaving
  - [x] ignore interactions with entities that are placed for a different player
  - [x] prevent 2 players from interacting with the same inserter at the same time
  - [x] add force restriction
    - [x] update player state if an inserter changes force while being adjusted
  - [x] maybe add flying text when trying to adjust an inserter someone else is adjusting
- [x] update player state when the inserter gets rotated or teleported while being adjusted
- [x] update existing grids/arrows/invisible entities whenever tech level or inserter prototype changes
- [x] listen to destroy events to switch to idle as soon as possible
- [x] maybe continuously check if the target inserter is still valid, so if the entity disappears without an event, we still clean up reasonably soon.
- [x] maybe add a rendering circle on the inserter itself
- [x] maybe detect inserters that are by default diagonal and allow them to be diagonal first, then cardinal after research
- [ ] maybe add support for "knight" inserters (straight pickup, diagonal drop, or the other way around), but this would require a notable change in the cache
- [x] maybe check if an inserter's default drop offset is far, center or near and use that information for auto determined drop positions. More exotic industries support, basically.
- [x] add locale for invisible entities
- [x] change all rendering to target a position, not the entity. That way being tick paused in the editor and having mods do weird stuff without raising an event doesn't make this mod look weird
- [x] add locale for the key bind/control
- [x] change default key sequence because it conflicts with bobinserters
  - [x] SHIFT + F conflicts with several search mods, however looking through all the key sequences I'd like to use, they all have conflicts so this is most likely one of the lesser evils
  - [x] play test with it a bit
- [x] maybe make direction arrow a little transparent
- [x] change visualization when pickup has been selected
  - [x] draw square around it instead of a highlight box
  - [x] draw a line from the inserter to the pickup tile
- [x] slight indication for the 4 big rectangles around the grid which change direction
- [x] test if creating and deleting entities is faster than teleporting and changing force
  - [x] yes it is. With pooling hitting the key bind 3 times on an inserter takes 2.57 ms, without pooling it takes 1.7 ms
- [x] thumbnail
- [x] readme/description
- [ ] maybe add tips and tricks simulations. It kind feels unnecessary, basically everything is either self explanatory or explained in tooltips.
- [x] don't restore when rotating and similar
- [x] ~~try using render_player_index for selectable entities. See if the selection box shows up for other players as well~~ Tried it, they are still selectable for other players, so this is not an option
- [x] ~~look into renai transportation and see if it needs special support just for fun~~ scope creep, and I sense that performance would be horrific with a large grid
  - [ ] alright, at least give it a look. Maybe it is possible
  - [x] maybe add technology or map setting to unlock the same behavior as si-range-adder "incremental"
    - [ ] maybe remove this setting again, at least the "Extend only, without gaps" because it causes > 70 ms spikes when switching to drop with near inserters researched
  - [ ] maybe add logic for differing base ranges for pickup and drop vectors
  - [ ] probably add support for the range adjust-ability research from renai
  - [ ] maybe somehow prevent throwers from flickering between being active and disabled by script. thing is that renai is using an on_nth_tick 3 handler for it, making this a bit of a challenge
- [ ] maybe add support for kux slim inserters
- [ ] wait, but why do we not get a selection changed event with selected being nil when we move the cursor off of a selectable entity from this mod and pressing the adjust key bind in the same tick, causing it to delete the previously selected entity?
- [x] maybe look into smart inserters and see how hard compatibility with that mod would be. For things like tech unlocks maybe
  - [ ] I don't believe mod load order actually matters for anything for support with smart inserters... but I didn't write down the initial reason for adding it so I need to figure that out
  - [x] update readme to include the smart inserters support oddities
    - [x] maybe, probably add a "does nothing" startup setting to inform players that settings have been hidden because smart inserters is enabled
  - [x] when smart inserters is enabled, hide all technology settings from qai, and do not create technologies in qai (fully rely on smart inserters)
    - [x] don't set forced_value, just hide the setting and pretend like their value is false in data stage
  - [x] ignore offset selector setting entirely. The visualization of the default drop offset handles this in qai (per player)
  - [x] support having cardinal, diagonal and all tiles being false, yet drop_offset being true. In this case there should be a way to just adjust the drop offset and nothing more
  - [x] handle offsets tech setting
    - [x] if the setting is disabled it is as though near-inserters was researched from the beginning of the game
    - [x] if the setting is disabled
      - [x] handle si-unlock-offsets (same as near-inserters)
  - [x] handle diagonal techs setting
    - [x] if the setting is disabled it is as though more-inserters-2 was researched from the beginning of the game
    - [x] if the setting is enabled
      - [x] add si-unlock-cross. Without it unlocked no inserters can be adjusted at all
      - [x] handle si-unlock-x-diagonals (same as more-inserters-1)
      - [x] handle si-unlock-all-diagonals (same as more-inserters-2)
  - [x] handle range techs setting
    - [x] if the setting is disabled it is as though the max range was researched from the beginning of the game. Using si-max-inserters-range
    - [x] with the setting enabled
      - [x] start at range 1, as per usual. The setting description says that without the first level the inserters won't be adjustable, but they are...
      - [x] handle si-unlock-range-x (same as long-inserters-x)
  - [x] handle si-range-adder
    - [x] when "equal" just do the exact same thing qai is already doing. every inserter has the same range. However qai will handle long handed inserters (or other longer range inserters) differently (and better) by starting at a further range, then moving inwards until it can reach the tiles next to the inserter, and then start moving outwards. smart inserters is giving every single inserter the same range (starting on the tiles directly next to the inserter even for long handed inserters) which I do not like at all, so i'm doing it my way
    - [x] when "inserter" then do the exact same thing qai is already doing, except that it is not allowed to reach further than the default reach of an inserter. In the case of vanilla that means that any range 2 (so 1 tech unlock) doesn't do anything anymore, but the fact that the technologies exist anyway is not an issue for qai to fix, that's smart inserters's problem
    - [x] when "incremental" then use the default range of an inserter as the starting range, it can reach any tiles starting directly next to the inserter up to its default range, and any range technologies extend that by 1. so inserters could go to range 5, long handed inserters could go to 6 for example
    - [x] note that "incremental" is bugged in smart inserters if the range techs are entirely disabled. Aside from that it also seems to think there's an inserter that can reach 1 tile further than any inserter actually can in vanilla. I'm going to pretend that it isn't bugged and implement it according to what makes sense and what the description of the setting describes
- [x] change hard dependency on bobinserters to hidden optional (for mod load order)
- [x] add own technologies with the same names and own custom icons
  - [x] revisit icons, probably using the inserter tech icon and adding something to it in gimp
  - [x] locale name and descriptions
- [x] add startup settings just like bobinserters, even with the same name, but only if they don't exist already
- [x] add startup setting to disable more-inserters-1
- [x] add startup setting to disable near-inserters
- [x] add logic in data updates and final fixes to enable runtime adjustable vectors
  - [x] remember which ones were touched in data updates and don't touch them again in final fixes
  - [x] ignore hidden inserters
- [x] maybe add startup setting to normalize pickup vectors, snapping them to tile centers
- [x] use "cardinal" instead of "perpendicular"
- [x] maybe add remote interface and api
  - [x] ~~api file which checks for the existence remote interfaces containing a certain name, and calls all of them (that is to support for example smart inserters implementing the same interface, and being enabled at the same time)~~ if tech unlocks and range cannot be modified through the remote interface then all the interface is really doing is things specific to this mod. So there's no reason to pretend like it's some standard other mods could follow. Because it isn't.
    - [x] ~~put the MIT license directly in the api file so others can copy it into their code. This allows for mods to implement the interface and replace quick adjustable inserters entirely without other mods using the api to have to change anything. It would "just work"~~
  - [x] ~~api file which is just a wrapper around the remote.call calls, because I like that~~ No, stop being weird. Let people use remote.call like everybody else would, because that's normal.
  - [x] ~~change which technologies unlock what~~ Thought about it, it'd be stupidly complicated to actually handle properly. No thank you.
  - [x] ~~add more or less range~~ Possible through auto detected technologies now. You can't skip levels but meh, it's better than nothing. Doing it through the remote has similar issues as the above
  - [x] trigger build & adjust
  - [x] trigger adjust key bind on a given entity
  - [x] trigger switch_to_idle (even though adjusting on a nil entity already does that)
  - [x] trigger switch_to_idle_and_back
- [x] make all qai prefixes lowercase, outside of type names of course
- [x] maybe always script disable while adjusting
- [x] do not use rotate locale, just make your own for not being able to adjust enemy structures
- [x] ~~maybe add nothing technology effects/modifies with descriptions~~ the tech descriptions are enough
- [x] or just add technology descriptions
- [x] use both the selection box and collision box to determine the size of the inserter
- [x] auto detect more range technologies, simply by going sequentially (long-inserters-1, long-inserters-2, long-inserters-3, ...)
  - [x] mention that in the readme along side the remote interface
- [x] map setting to "only allow mirrored". Select the pickup position, and the drop off position has to be in the tile on the opposite side, such that those 2 tiles are mirrored at the inserter's center
- [x] improve rotation state tracking. I don't know why yet but when play testing there's several times where using place and adjust places the inserter in the wrong direction and I didn't do anything that I'd expect to actually cause that to happen, because I know it will happen sometimes no matter what. But yea, investigate this.
- [x] make sure every event checks valid. Like the selected changed event doesn't.
- [x] LuaForce valid checking
- [x] on cursor stack changed is raised at the end of the tick, so everything using that data needs to have validation itself
- [x] maybe check pickup and drop positions in update_active_player to catch other mods modifying them while an inserter is being adjusted
- [x] why is it that selected is being set to nil when switching to idle again? wasn't that because of teleporting or something? (in other words outdated?) - yes it was used to get a selected entity changed event when teleportation was used, since an entity would get teleported away and back in the same tick, so selection didn't change.
- [x] in whenever a state switch happens with keep_rendering true, the following code is not actually cleaning up rendering objects properly, because any other state switch could have happened in between, leaving the old rendering objects floating forever
- [x] add key sequence to the tooltips of the selectable entities
- [x] add demonstration videos to readme
- [x] maybe explicitly ignore 8 way inserters
- [x] handle inserter that got rotated to "usually invalid" directions through script
- [x] with near inserters researched and only mirrored inserters and show inserter throughput on pickup, it should use the mirrored default drop offset for calculation, not the current drop offset
- [x] while inserter speed text is active save corresponding inserter_target_pickup_count, pickup_position and drop_position in player data and compare them in active player update to potentially update inserter throughput text
- [x] check non rotatable inserters
- [x] check not operable inserters
- [ ] maybe add editor support to bypass checks like force friendliness, rotatable and operable
- [x] maybe loosen the restriction on which inserters can be adjusted in the runtime checks to allow for other mods to do crazy things
- [ ] maybe make inserter speed text smaller? Or make it a setting?
- [ ] probably add some opt in key binds to adjust inserters without opening the grid. Look at bob inserters and or smart inserters key binds
  - [ ] add several key binds which affect the drop offset. something like near/far toggle, left/middle/right cycle... maybe that's it.
  - [ ] handle key binds which change drop offset while not idle and selecting a selectable differently
  - [ ] record a new video showcasing just all of the key bind interactions at once
- [x] probably add a setting to disable drop offset selection per player, especially with the addition of a "toggle near/far" offset key bind
  - [ ] add key bind to adjust the drop offset (and nothing else)
  - [ ] rerecord videos in which the settings window is visible, since settings have changed now
  - [ ] add an option to this setting for a smart mode which shows the drop offset only when targeting ground or belts
- [x] snap pickup highlight to grid
- [ ] handle pickup or drop vectors of length 0. Do not divide by length of vectors without checking if it is 0 first
- [x] fix that switching to idle and back after regenerating cache in on configuration changed errors trying to use invalidated cache.prototype
- [ ] look into ultra cube to see why the techs are not showing up at all
- [ ] when pasting to an inserter, restrict the pickup and drop positions to be within valid positions for the given target inserter. Basically when copying from a normal inserter to a long inserter without any range upgrades researched, do not apply the vectors. In fact, probably just do not change the current vectors of the target inserter at all
  - [ ] if smart inserters is enabled, probably just do nothing and let it do its thing
- [ ] key binds to only select pickup or only select drop
- [ ] some setting to automatically pick the fastest estimated drop offset when drop offset selection gets skipped through any means
- [ ] setting to change when direction adjustment selectables show up.
  - [ ] always
  - [ ] never
  - [ ] using a different key bind
- [ ] try and see if copy pasting with a ghost being the source and or destination is possible to add
- [ ] read through this one more time to make sure nothing got missed: https://mods.factorio.com/mod/quick-adjustable-inserters/discussion/6605c28e23f6dcb547a75e56
- [ ] try hiding other player's UIs and changing the player's selected entity whenever they hover an invisible selectable entity that's part of another player's adjustment UI
- [ ] tech icons do not look right
- [x] add migration from 1.1 to 2.0
- [ ] handle quality inserters
- [ ] setting to force inserters to be restricted to what qai considers to be valid pickup or drop positions, regardless of what other mods are doing
- [ ] key bind or setting to automatically pick the fastest estimated combination of pickup and drop positions
