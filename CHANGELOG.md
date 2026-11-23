# Changelog

## [2.0.0] — 2026-11-23

The admin panel is now a full builder. `/airdrops` opens it.

- Drop zones with more than one landing point, placed with a freecam or at your feet
- Each zone sets its own circles, crate type, loot table, players or police needed, hours and plane direction
- Crate types: prop, crack time, who can open it, plane, parachute, flare, smoke, police alert and map pin
- More than one loot table, with the odds worked out and a search box for your server's items
- Roll a test crate to see what comes out
- Schedule page: gap, hours, players needed, drops at once and zone cooldown
- Live page shows every running drop with a countdown
- Every setting is searchable with Ctrl+K
- Police alerts are sent once from the server, so officers no longer get the same call twice
- The plane now comes in from the same side for everyone
- The countdown now runs to the landing
- Changing job mid-drop shows or hides the drop straight away
- Pick who sees each drop zone: everyone, only some jobs and gangs, or everyone except some, like police
- Settings › Who takes part sets that rule for every zone that does not pick its own
- Players a drop is hidden from are never told where it is, and police are only called when they can see it
- Crates open with E or with your target script (ox_target or qb-target), picked in Settings › Opening
- The map pin and circle now go for everyone the moment the crate is opened
- Logging out takes every drop off your map, and the next character only sees what it is allowed to

### Updating

Replace the folder. Your old locations, loot and panel settings move into the builder by themselves on the first start, and so does the old "Everyone sees drops" switch. No SQL to run.
