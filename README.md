# Cipher — Airdrops

Contested supply drops for FiveM. A crate is announced, flown in by cargo plane,
parachuted onto the map and cracked open by whoever gets there and holds the
ground long enough.

Standalone for **QBox** and **QBCore**. No database.

---

## What it is, and what it deliberately isn't

A drop is a **contest**. The script announces one, flies it in, and puts real
loot on the ground where everyone can see it.

**It never touches PvP.** It does not enable or disable damage, does not flag
players, and does not override your server's rules about who may shoot whom.
Whether a fight breaks out over the crate — and whether that fight is allowed —
is entirely your server's business.

That is a deliberate design choice, not a missing feature. It means the script
runs on a hardcore PvP server and a strict-RP server without either of them
having to fight it, and it means installing this never changes how combat works
anywhere else on your map.

---

## How a drop plays out

1. **Announced.** Everyone is told a drop is inbound, and roughly where. A
   flashing blip shows the *approximate* area — a 250m circle, not the exact
   spot. The warning window is the interesting part: it is when people decide
   whether to go, gear up, and travel.
2. **Inbound.** A cargo plane flies over on a random bearing and releases the
   crate under a chute.
3. **Landed.** The exact position appears, with smoke and a flare. The contested
   radius is drawn on the map.
4. **Cracking.** Standing at the crate for 25 seconds opens it. You cannot move,
   drive or fight while doing it — that exposure is what makes the crate worth
   contesting rather than just racing to.
5. **Open.** Loot is rolled *at this moment*, server-side, and the crate becomes
   lootable by anyone who reaches it. Not just whoever cracked it.
6. **Gone.** The crate despawns once it is emptied, or after five minutes.

Police are alerted **45 seconds after landing**, not immediately. Whoever raced
for the crate should get there first; law enforcement arriving into an existing
fight is a better scene than law enforcement waiting at the coordinates.

---

## Installation

1. Drop `cipher-airdrops` in your resources folder.
2. `ensure cipher-airdrops` in your `server.cfg`, after your framework and
   inventory.
3. Open `config.lua` and set your drop locations. The ten shipped ones are real
   coordinates and work as-is.

**There is no SQL.** A drop lives and dies inside one server session, so there
is nothing to import and nothing to migrate on upgrade.

### Requirements

- `ox_lib`
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
| `Config.Locations` | Where drops can land, with weights |
| `Config.Loot` | Tiers, item ranges, stack counts, guaranteed minimum tier |
| `Config.Police` | Whether police are alerted, and how long after landing |
| `Config.Announce` | Server messages, whether to name the area, Discord webhook |

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
exports['cipher-airdrops']:IsDropActive()      -- boolean
exports['cipher-airdrops']:GetDrop()           -- the public state, or nil
exports['cipher-airdrops']:StartDrop('sandy')  -- start one; returns ok, err
```

`GetDrop()` returns what clients are allowed to know, which means the exact
coordinates only once the crate is on the ground.

---

## Works with the rest of the line

If you run **cipher-dispatch**, the police alert becomes a proper dispatch call
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

## The rest of the Cipher line

Free, source-available FiveM scripts — [xyralscripts.dev](https://xyralscripts.dev)

---

## License

See `LICENSE`.
