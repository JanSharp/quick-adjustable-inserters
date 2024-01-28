
# Quick Adjustable Inserters

Quickly adjust inserter pickup and drop positions in world using a single key bind, `SHIFT + F`.

- Hover an inserter, `SHIFT + F`
- Hover the desired pickup position, `SHIFT + F`
  - Or hover the inserter and `SHIFT + F` to keep the current position
- Hover the desired drop position, `SHIFT + F`

Stop adjusting an inserter by pressing `SHIFT + F` anywhere else, or instantly switch to adjusting a different inserter.

![quick-adjustable-inserters.mp4](videos/quick-adjustable-inserters.mp4)

## Place and Adjust

While having an inserter in hand/cursor, place it and instantly adjust it by pressing `SHIFT + F` instead of the usual left click.

**Known Issue:** Sometimes the inserter will be placed facing the wrong way. The mod tries its best to get it right, but there are cases that simply cannot be handled. Pipette an existing inserter (or entity with direction) and it will face the right way the next time you place an inserter again.

![place-and-adjust.mp4](videos/place-and-adjust.mp4)

## Mirrored Inserters only

There is a map setting (off by default) to restrict how inserters can be adjusted. WHen enabled the pickup and drop positions (tiles) must be exactly mirrored/opposite of each other in relation to the center of the inserter. Basically if you like a bit of adjustment, but being able to make inserters pickup and drop on 2 adjacent tiles is too over powered, this setting might just be for you.

![mirrored-inserters-only.mp4](videos/mirrored-inserters-only.mp4)

## Pipette copies Vectors

This is an opt in feature (a mod settings) to make smart pipette (`Q`) remember the pickup and drop vectors of the inserter that got picked, and applies these vectors to newly placed inserters. This stays in effect so long as the inserter is in hand/cursor.

![pipette-copies-vectors.mp4](videos/pipette-copies-vectors.mp4)

## Inserter Direction

While adjusting an inserter there are 4 big selection boxes on the outside of the adjustment grid. Hovering them and pressing `SHIFT + F` changes the base direction of the inserter while keeping the pickup and drop positions the same. This is useful to have consistent inserter directions for predictable copy paste and placement behavior.

![inserter-direction.mp4](videos/inserter-direction.mp4)

## Disabled by Script

Inserters are disabled by script while being adjusted, which works nicely with place and adjust. They won't start moving until adjustment is complete.

![disabled-by-script.mp4](videos/disabled-by-script.mp4)

## Inserter Throughput Estimation

This mod shows estimated inserter speed. By default only while choosing a drop position, but this can be changed in the mod settings.

It is using the [Inserter Throughput Library](https://mods.factorio.com/mod/inserter-throughput-lib), see there for technical details. If you are a mod creator yourself and one of your mods would benefit from inserter speed calculations and estimations, I'd recommend to take a look. The library also helps with ghost support.

![inserter-throughput-estimation.mp4](videos/inserter-throughput-estimation.mp4)

## Ghosts Support

This mod supports ghosts. Quite a bit went into it, but for you it's just that simple. It supports adjusting ghost inserters and throughput estimation works with ghosts as well.

## Balancing

As a modded player there's some degree of balancing that you put upon yourself, to make the game and features fit for you. Many people consider adjusting inserters to be very over powered or they simplify the challenge of arranging setups properly too much. These are very valid concerns.

But what if you just wanted to be able to do some of the following?

- only change the drop position ever so slightly within a tile (aka changing the drop offset, aka near/far inserters)
- only change the range of inserters between 1 and 2, or maybe 3, keeping the drop offset unchanged and having inserters always swing 180 degrees
- change inserters between cardinal directions and diagonal

Well with the settings this mod provides all of those restrictions are possible to be enforced. Simply by disabling some of the technologies through startup settings, as well as through the map setting to only allow mirrored inserters (180 degree swings).

The default settings are the least restrictive and therefore most powerful.

## Compatibility

This mod handles all kinds of weird inserters. Not to say all of them, but a lot. Like diagonal inserters, off center, off grid or non square inserters. It can also co-exist with other inserter adjustment mods.

The technologies this mod uses are the same as [Bob's Adjustable Inserters](https://mods.factorio.com/mod/bobinserters), but if it isn't present this mod provides its own technologies with the same names. This is not a dependency.

## Settings

All settings have tooltips/descriptions so there should be little confusion. Here's just a summary of what this mod contains.

There are settings ...

- for when to show inserter throughput estimation
- to show the default drop offset within tiles
- for place and adjust to also pipette the inserter once done, to continue placing more inserters
- for pipette to copy vectors, see section a little bit higher up

A map setting ...

- to only allow mirrored inserters. The pickup and drop positions/tiles must be at the opposite sides of the inserter, see section higher up

As well as some startup settings ...

- to choose which technologies should even be available (if [Bob's Adjustable Inserters](https://mods.factorio.com/mod/bobinserters) is present it will use its settings, but this mod adds 2 more settings so they'll unfortunately be split between the 2 mods in the settings list)
- to normalize default inserter vectors, to make modded inserters more consistent

## API

### More range

The mod automatically detects more range technologies, they simply have to follow the naming pattern `"long-inserters-"..number` where `number` does not have any leading zeros. Technology hidden and enabled state and dependencies along side handling the settings for `long-inserters-1` and `long-inserters-2` would be 100% up to other mods.

Note that higher technologies should either not be created or be hidden and or disabled if one of the lower levels has been disabled through the settings `bobmods-inserters-long1` and or `bobmods-inserters-long2`.

### Remote

The mod provides a stupidly tiny remote interface called `"qai"`. It's documentation is done through annotations so take a look at the end of the `control.lua` file, or unpack the mod and use intellisense if you're using LuaLS and FMTK.
