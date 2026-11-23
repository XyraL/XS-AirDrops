<h1 align="center">XS-AirDrops</h1>

<p align="center">Contested supply drops for <strong>QBox</strong> and <strong>QBCore</strong> — announced, flown in by cargo plane, and cracked open by whoever holds the ground. Built in game.</p>

<p align="center">
  <a href="https://github.com/XyraL/XS-AirDrops/releases"><img src="https://img.shields.io/github/v/release/XyraL/XS-AirDrops?style=flat-square&color=f5a524&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/framework-QBox%20%7C%20QBCore-55dcff?style=flat-square" alt="framework">
  <img src="https://img.shields.io/badge/price-free-30d158?style=flat-square" alt="price">
  <a href="https://xyralscripts.dev/docs-xs-airdrops"><img src="https://img.shields.io/badge/docs-xyralscripts.dev-a889ff?style=flat-square" alt="docs"></a>
  <a href="https://discord.gg/XRURAw4TM2"><img src="https://img.shields.io/badge/support-discord-5865F2?style=flat-square" alt="support"></a>
</p>

---

## It never touches PvP

No damage flags, no combat rules, no overriding who may shoot whom. The script
puts loot on the ground and announces it. Whether a fight happens over it, and
whether that is allowed, is your server's business.

That is why it installs on a hardcore PvP server and a strict RP server alike.

---

## How a drop plays out

1. **Announced.** Everyone is told a drop is inbound and roughly where. A wide
   yellow circle shows the search area and an on-screen countdown runs until it
   lands, turning red in the last fifteen seconds.
2. **Inbound.** A cargo plane flies over and drops the crate under a chute.
3. **Landed.** The circle shrinks to a red contest zone, with smoke and a flare
   on the crate.
4. **Cracking.** Standing at the crate for its crack time opens it. You cannot
   move, drive or fight while doing it. That is what makes it worth fighting
   over instead of just racing to.
5. **Open.** Loot is rolled right then, on the server, and anyone who reaches
   the crate can take from it. The pin and circle come off the map for everyone.
6. **Gone.** The crate goes once it is emptied, or when its time runs out.

The timer only runs out on an empty zone. If anyone is there, or someone is
mid-crack, the crate is held a bit longer, up to a hard cap from landing.

Police are told **after** landing, 45 seconds by default. Whoever raced for the
crate gets there first.

---

## Installation

1. Drop `XS-AirDrops` in your resources folder.
2. `ensure XS-AirDrops` in your `server.cfg`, after `ox_lib`, `oxmysql`, your
   framework and your inventory.
3. Give your staff the builder: `add_ace group.admin xs.airdrops allow`
4. Restart, go in game and type `/airdrops`.

No SQL to run. The tables are made on first start. `sql/airdrops.sql` is there
if you would rather make them yourself.

### Updating from 1.0.x

Replace the folder. On the first start your old locations become drop zones,
your loot tiers become a "Standard loot" table, and your old panel settings
become a "Standard crate". Nothing is lost. Your old `config.lua` still works,
the new one has the new options in it.

### Requirements

- `ox_lib`
- `oxmysql`
- A framework: **qbx_core** or **qb-core**
- An inventory: **ox_inventory**, qb-inventory, qs-inventory, codem-inventory,
  core_inventory or ps-inventory

`ox_target` or `qb-target` is optional. Settings › Opening picks whether crates
open with E or with the target eye. Without a target script it uses E.

### A note on inventories

On **ox_inventory** the crate is a real shared stash. Several people can dig
through the same box at once.

The other five cannot be handed a filled box, so the crate gives out a few
stacks per search instead. Being first still matters, being second still gets
you something. Crate types can also cap how many times one player can search.

---

## The builder

```
/airdrops
```

Everything about drops is built in game. Changes are live as soon as you save,
no restart. Ctrl+K searches every zone, crate, loot table, setting and page.

- **Overview** — how ready your setup is, what still needs fixing (each problem
  is a button straight to it), drops today, what is running, and what the
  script found on your server.
- **Drop zones** — where crates land. A zone has one or more landing points
  (one is picked each drop), placed from the sky with a freecam that shows the
  crate and the contest circle, or at your feet. Each zone sets its contest and
  search radius, crate type, loot table, its share of the rotation, players or
  police needed, a time of day, and which way the plane flies in. Teleport to it,
  show every point in the world, or run a silent test drop there.
- **Crate types** — the prop, how long it takes to open, slots or stacks per
  search, who can open it, police allowed or not, the plane and its height,
  parachute, flare and smoke, the police alert and its delay, the announcement
  text and the map pin.
- **Loot tables** — tiers and items with the real odds worked out for you.
  The item box searches your server's items and warns you about names that do
  not exist. Roll a test crate to see what comes out.
- **Schedule** — automatic drops on or off, the gap between them, active hours,
  players needed, how many can run at once, zone cooldown and warning time. It
  also shows which zones can take a drop right now and why not.
- **Live** — what is running, with countdowns. Start one at any zone with any
  crate and loot, cancel one, or teleport to it.
- **History** — every drop, what was in it and who opened it. If more than half
  are abandoned, they land where nobody goes or the loot is not worth the trip.
- **Settings** — every other number, saved in the database. Reset puts one back
  to `config.lua`.
- **Access** — who can get in, and the line to add.

### Silent test drops

A real crate with real loot that only staff can see. No announcement, no police,
kept out of the history. Build a zone, test it without telling the server, keep
it or bin it.

### Who can open the builder

Any one of these:

- the ace in `Config.Admin.acePermission` (`xs.airdrops`)
- any ace in `Config.AdminCommand.Aces`
- a framework group in `Config.Admin.groups`
- a licence in `Config.Admin.licenses`

```
add_ace group.admin xs.airdrops allow
```

Without one of them, `/airdrops` says you do not have permission. Every builder
action checks again on the server.

---

## Calling a drop by hand

```
/airdrop
/airdrop sandy
/airdrop 3
```

With no argument it picks a zone by weight. With a name it drops at the first
zone whose name contains it, or a zone number. Same permission as the builder.
The server console can always call one.

---

## Who can see and collect

| | What it controls |
| --- | --- |
| Drop zone › Who sees it | Everyone, only some jobs and gangs, everyone except some, or the default |
| Settings › Who takes part › Who sees drops | The default for every zone that does not pick its own |
| Settings › Who takes part › Collect | The default rule for who can open a crate |
| Crate type › Who can open | Everyone, only some jobs and gangs, or the default |
| Police | Always see drops, and can or cannot loot. Crate types can override it |

Seeing a drop means the pin, the circles, the messages and the crate itself.
Players a drop is hidden from are never sent where it is, so they cannot open it
either. "Everyone except police" keeps a drop off police maps even when police
always see drops, and police are only called when they can see it.

Turning police looting off is what makes a drop a three-way scene: crews fight
over it, police turn up to stop them, and nobody in uniform is there to loot.
Someone who is refused is told why.

A player who changes job, gang or character mid-drop loses or gains it straight
away.

---

## Configuration

`config.lua` holds the defaults. Anything changed in the builder wins over it.

| Setting | What it does |
| --- | --- |
| `Config.Admin` / `Config.AdminCommand` | Who gets the builder, and the two commands |
| `Config.Schedule` | Gap between drops, players needed, hours, drops at once, zone cooldown |
| `Config.Drop` | Warning time, circle sizes, how long a crate lasts, reach, E or target |
| `Config.Delivery` | Plane flyovers on or off, speed, how far out it appears |
| `Config.Loot` / `Config.Locations` | Only used to make the first loot table, crate type and zones |
| `Config.Access` | Who sees drops, who can open them, the police rule |
| `Config.Police` | Jobs alerted, dispatch code and title |
| `Config.Blip` | Pin size and circle colours |
| `Config.Announce` | Text on or off, name the zone, Discord webhook |
| `Config.Sounds` | Audio cues and the countdown ticks |
| `Config.Builder` | Freecam speed and how long "show all points" lasts |

### Items

The stock loot uses items QBCore already ships, plus two that are not standard.
Both have images in `inventory_images/`:

| Item | Add it as |
|---|---|
| `thermite` | `{ label = 'Thermite', weight = 900, stack = true }` |
| `trojan_usb` | `{ label = 'Trojan USB', weight = 100, stack = true }` |

Drop the PNGs into your inventory's image folder:

| Inventory | Where |
|---|---|
| ox_inventory | `ox_inventory/web/images/` |
| qb-inventory | `qb-inventory/html/images/` |
| ps-inventory | `ps-inventory/html/images/` |
| qs-inventory | `qs-inventory/html/images/` |
| codem-inventory | `codem-inventory/html/itemimages/` |
| core_inventory | `core_inventory/html/img/` |

Or take them out of the loot table in the builder.

---

## Exports

```lua
exports['XS-AirDrops']:IsDropActive()            -- boolean
exports['XS-AirDrops']:GetDrop()                 -- one running drop, or nil
exports['XS-AirDrops']:GetDrops()                -- every running drop
exports['XS-AirDrops']:StartDrop('sandy')        -- returns ok, drop id or error
exports['XS-AirDrops']:StartDrop(nil, { silent = true })
```

`GetDrop()` and `GetDrops()` return what players are allowed to know.

---

## Works with the rest of the line

The police alert goes through **XS-Dispatch** when it runs, then ps-dispatch,
qs-dispatch, cd_dispatch, core_dispatch, rcore_dispatch or linden_outlawalert,
and falls back to a plain notification with a blip. It is sent once from the
server, so officers never get the same call twice.

---

## How it is built

**The crate is not a networked entity.** It is a local prop on every client and
the truth lives on the server as a spot on the map. Nothing to steal, nothing to
clean up after a restart.

**The server does not trust the client.** It checks you were at the crate when
you started cracking, that you are still there when you finish, and that the
time really passed.

**Crates take their contents with them.** When a drop ends, its stash is cleared.

---

## My other scripts

Free FiveM scripts — [xyralscripts.dev](https://xyralscripts.dev)

---

## License

See `LICENSE`.
