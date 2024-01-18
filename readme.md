
# Quick Adjustable Inserters

Quickly adjust inserter pickup and drop positions in world using a single key bind, `SHIFT + F`.

- Hover an inserter, `SHIFT + F`
- Hover the desired pickup position, `SHIFT + F`
  - Or hover the inserter and `SHIFT + F` to keep the current position
- Hover the desired drop position, `SHIFT + F`

Stop adjusting an inserter by pressing `SHIFT + F` anywhere else, or instantly switch to adjusting a different inserter.

## Place and Adjust

While having an inserter in hand/cursor, place it and instantly adjust it by pressing `SHIFT + F` instead of the usual left click.

**Known Issue:** Sometimes the inserter will be placed facing the wrong way. The mod tries its best to get it right, but there are cases that simply cannot be handled. Pipette an existing inserter and it will face the right way the next time you place an inserter again.

## Pipette copies Vectors

This is an opt in feature (a mod settings) to make smart pipette (`Q`) remember the pickup and drop vectors of the inserter that got picked, and applies these vectors to newly placed inserters. This stays in effect so long as the inserter is in hand/cursor.

## Inserter Direction

While adjusting an inserter there are 4 big selection boxes on the outside of the adjustment grid. Hovering them and pressing `SHIFT + F` changes the base direction of the inserter while keeping the pickup and drop positions the same. This is useful to have consistent inserter directions for predictable copy paste and placement behavior.

## Disabled by Script

Inserters are disabled by script while being adjusted, which works nicely with place and adjust. They won't start moving until adjustment is complete.

## Inserter Throughput Estimation

This mod shows estimated inserter speed. By default only while choosing a drop position, but this can be changed in the mod settings.

It is using the [Inserter Throughput Library](https://mods.factorio.com/mod/inserter-throughput-lib), see there for technical details. If you are a mod creator yourself and one of your mods would benefit from inserter speed calculations and estimations, I'd recommend to take a look. The library also helps with ghost support.

## Ghosts Support

This mod supports ghosts. Quite a bit went into it, but for you it's just that simple. It supports adjusting ghost inserters and throughput estimation works with ghosts as well.

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

As well as some startup settings ...

- to choose which technologies should even be available (if [Bob's Adjustable Inserters](https://mods.factorio.com/mod/bobinserters) is present it will use its settings)
- to normalize default inserter vectors, to make modded inserters more consistent
