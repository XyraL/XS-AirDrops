<h1 align="center">XS-AirDrops</h1>

<p align="center">Contested supply drops for <strong>QBox</strong> and <strong>QBCore</strong> — announced, flown in by cargo plane, and cracked open by whoever holds the ground.</p>

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
puts loot on the ground and announces it; whether a fight happens over that, and
whether it is allowed, is your server's business.

That is why it installs on a hardcore PvP server and a strict-RP server without
either having to fight it.

---

## How a drop plays out

1. **Announced.** Everyone is told a drop is inbound, and roughly where. A
   flashing blip shows the *approximate* area — a 250m circle, not the exact
   spot — and an **on-screen countdown** runs until it lands, turning red in the
   last fifteen seconds. The warning window is the interesting part: it is when
   people decide whether to go, gear up, and travel, and a number they can
   glance at while driving is what makes that a decision rather than a guess.
2. **Inbound.** A cargo plane flies over on a random bearing and releases the
   crate under a chute.
3. **Landed.** The exact position appears, with smoke and a flare, and the
   contested radius is drawn on the map as a **red circle** — the yellow search
   area becomes a red zone, so the two states are never mistaken for each other
   at a glance.
4. **Cracking.** Standing at the crate for 25 seconds opens it. You cannot move,
   drive or fight while doing it — that exposure is what makes the crate worth
   contesting rather than just racing to.
5. **Open.** Loot is rolled *at this moment*, server-side, and the crate becomes
   lootable by anyone who reaches it. Not just whoever cracked it.
6. **Gone.** The crate despawns once it is emptied, or after its timer runs out.

### It will not vanish out from under you

The despawn timer only runs out on an **empty** zone. If anyone is there, or
mid-crack, the crate is held for another `PresenceGrace` — repeatedly, so it
outlives whoever is using it. `MaxLifetime` caps that from landing so nobody
can camp one all night.

An emptied crate lingers for `EmptyLinger` rather than vanishing on the last
item, so late arrivals can see they missed it.

Each of those steps has an audio cue, using native GTA sounds so there are no
files to stream. The last ten seconds of the warning window tick audibly — that
one is separately switchable, because it is the cue people tire of first.

Police are alerted **45 seconds after landing**, not immediately. Whoever raced
for the crate should get there first; law enforcement arriving into an existing
fight is a better scene than law enforcement waiting at the coordinates.

---

## Installation

1. Drop `XS-AirDrops` in your resources folder.
2. Run `sql/airdrops.sql` against your database. It creates four tables and is
   safe to re-run.
3. `ensure XS-AirDrops` in your `server.cfg`, after your framework and
   inventory.

The ten drop locations and four loot tiers in `config.lua` are copied into those
tables the first time the resource starts, so a fresh install behaves exactly as
the config file reads.

**After that the database owns them and the admin panel edits them.** Editing
`config.lua` later does nothing, which is deliberate — two places claiming to
own the same setting is how they quietly drift apart.

### Requirements

- `ox_lib`
- `oxmysql`
- A framework: **qbx_core** or **qb-core** (auto-detected)
- An inventory: **ox_inventory**, qb-inventory, qs-inventory, codem-inventory,
  core_inventory or ps-inventory (auto-detected)

`ox_target` is optional — the crate has a key prompt either way.

### A note on inventories

On **ox_inventory** the crate is a real shared stash: several people can rummage
in the same box at once and the inventory sorts out who grabbed what. This is
what the script is designed around.

The other five backends only create a stash when a player opens one, and none of
them can be handed a filled container. On those, the crate yields
`Config.Loot.StacksPerSearch` stacks per search instead, so the scramble still
works — being first still matters, being second still gets you something. It is
a different feel, and worth knowing before you pick.

---

## Configuration

Everything lives in `config.lua`.

| Setting | What it does |
| --- | --- |
| `Config.Schedule` | Interval between drops, minimum players, optional hour window |
| `Config.Drop` | Warning time, crack time, zone radius, how long a crate lasts |
| `Config.Delivery` | Plane model, crate model, altitude — or turn the flyover off |
| `Config.Locations` | Seed locations only — the panel owns these after first start |
| `Config.Loot` | Stack counts and the guaranteed minimum tier. Tiers and items live in the panel |
| `Config.Access` | Who sees drops, who can collect, and the police exception |
| `Config.Blip` | Pin and zone colours; the live zone is red, the search area yellow |
| `Config.Police` | Whether police are alerted, and how long after landing |
| `Config.Announce` | Server messages, whether to name the area, Discord webhook |
| `Config.Sounds` | Audio cues, and the countdown ticks separately |

### Loot tiers

Weights are **relative, not percentages**, so you can add a tier without
rebalancing every other number.

`GuaranteeAtLeast` forces one roll up to that tier or better. A crate that is
entirely bandages after a five-minute fight is the fastest way to teach players
to ignore the next one.

Loot is rolled **when the crate is cracked** — never when it is announced, and
never on a client. If the contents can be known before the fight, people decide
whether the fight is worth having, and the fight is the product.

### Locations

Pick open ground with **more than one approach**. A spot with a single road in
belongs to whoever parks on it, and that is not a contest.

The same location is never chosen twice in a row, whatever the weights say.

---

## Who can see and collect

Two separate questions, because they usually have different answers.
`Config.Access` answers both, and both are enforced **server-side** — a blip
filtered out on the client would stop nobody.

| | What it controls |
| --- | --- |
| `Access.See` | Who is told a drop is happening and gets the blip |
| `Access.Collect` | Who can crack the crate and take from it |
| `Access.Police` | Overrides both, for police jobs specifically |

The default is everyone sees it and everyone can take it. Both blocks accept
job and gang lists when `Everyone = false`.

**Police are called out separately because they are the usual exception.**
Setting `Police.CanSee = true` and `Police.CanCollect = false` is what turns a
drop into a three-way scene: criminals fight over it, police turn up to stop
them, and nobody in uniform is there to loot. Someone refused gets told why
rather than watching the prompt do nothing.

A player who changes job mid-event loses the blip rather than keeping a stale
one, because every state change is re-filtered.

---

## The admin panel

```
/airdrops
```

Four tabs, gated by the same permission as the command — and re-checked on every
single callback, since anyone can send one whether or not a panel exists on
their screen.

- **Live Drop** — what is running right now, with a countdown. Start one on a
  chosen location or by weight, or cancel the one in progress.
- **Locations** — add, edit, enable and delete. **Use my current position**
  captures where you are standing, which is the point of doing this in game
  rather than in a config file. *Go to* teleports you to a location to check it.
- **Loot Tables** — tiers and items, with the **resolved percentages worked out
  for you**. "Weight 28" means nothing on its own; "28% of rolls" is the actual
  question you were asking.
- **History** — every drop, what was in it, and who cracked it. The number that
  matters is the abandon rate: if more than half are going untouched, they are
  landing where nobody goes or the loot is not worth the trip.
- **Settings** — the numbers worth nudging while a drop is playing out: warning
  window, crack time, zone radius, schedule interval, loot stack counts. Saved to
  the database and applied immediately, **no restart**. Each field saves on its
  own, and anything you have not touched still follows config.lua — *Reset* puts
  a setting back to the file value rather than to a copy taken months ago.

Deleting the last remaining location is refused — an empty table makes drops
silently stop happening, which reads as a bug rather than a choice.

### Silent test drops

The start dialog has a **Silent test** option. It runs a real drop — real crate,
real loot, real cracking — but only admins can see it: no announcement, no blip
for players, no police call, and it is kept out of the history so testing a new
location does not skew the numbers you tune against.

It is the other half of the *use my current position* workflow: capture a spot,
test it without telling the server, keep it or bin it.

---

## Calling a drop by hand

```
/airdrop
/airdrop sandy
```

With no argument it picks a location by weight. With one, it matches the first
location whose label contains that text.

Permission comes from `Config.Admin` (ace, framework group, or licence) or any
ace in `Config.AdminCommand.Aces`. The server console can always call one.

---

## Exports

```lua
exports['XS-AirDrops']:IsDropActive()      -- boolean
exports['XS-AirDrops']:GetDrop()           -- the public state, or nil
exports['XS-AirDrops']:StartDrop('sandy')  -- start one; returns ok, err
```

`GetDrop()` returns what clients are allowed to know, which means the exact
coordinates only once the crate is on the ground.

---

## Works with the rest of the line

If you run **XS-Dispatch**, the police alert becomes a proper dispatch call
with a code, a description and a blip, rather than a notification. It falls back
through ps-dispatch, qs-dispatch, cd_dispatch and core_dispatch, and then to a
plain notification with a blip — so it always tells somebody.

---

## Notes on how it's built

**The crate is not a networked entity.** Under OneSync, ownership of a networked
entity follows whichever client has it in scope — not whoever created it. A
crate spawned server-side ends up owned by the first player who wanders near it,
and one spawned client-side is owned by someone who can then delete it. Since
the crate never needs to move, sync, or take damage, it is a local prop on every
client and the truth lives on the server as a coordinate. Nothing to steal,
nothing to clean up after a restart.

**The server does not trust the client.** It records when you started cracking,
checks you were near the crate then, checks you are still near it when you claim
to have finished, and checks that the time actually elapsed. Sending
`finishCrack` straight after `beginCrack` gets you nothing.

**Crates take their contents with them.** When a drop ends, its stash is
cleared. Otherwise a server accumulates one orphaned stash per drop forever,
each still holding whatever nobody collected.

---

## My other scripts

Free, source-available FiveM scripts — [xyralscripts.dev](https://xyralscripts.dev)

---

## License

See `LICENSE`.
