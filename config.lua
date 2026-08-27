Config = {}

-- Force a bridge instead of auto-detecting. 'auto' is almost always right.
Config.Bridges = {
    framework = 'auto',   -- auto | qbx_core | qb-core
    inventory = 'auto',   -- auto | ox_inventory | qb-inventory | qs-inventory | ps-inventory
}

-- ─────────────────────────────────────────────────────────────────────────────
-- What this script does, and deliberately does not do
--
-- A drop is a CONTEST. The script announces one, flies it in, and puts real
-- loot on the ground where everyone can see it. Who fights over it, and whether
-- fighting is allowed at all, is your server's business — this never touches
-- damage, never flags players, and never overrides your PvP rules. That is what
-- lets it run anywhere.
-- ─────────────────────────────────────────────────────────────────────────────

Config.Debug = false

-- ── When drops happen ────────────────────────────────────────────────────────
Config.Schedule = {
    Enabled = true,

    -- Minutes between drops. The gap is randomised between these so players
    -- cannot set a timer and be standing on the spot when it lands.
    MinInterval = 45,
    MaxInterval = 90,

    -- No drop unless this many players are connected. A crate that lands for
    -- one person to free-loot is worse than no crate.
    MinPlayers = 8,

    -- Optional hour window (24h), in SERVER LOCAL time, not in-game time.
    -- Empty means any time.
    -- e.g. { from = 18, to = 4 } for evenings and nights only.
    Hours = {},
}

-- Staff can call one on demand: /airdrop [location]
Config.AdminCommand = {
    Enabled = true,
    Command = 'airdrop',

    -- Falls back to the framework's own admin check when this is empty.
    -- Otherwise, any of these ace permissions will do.
    Aces = { 'command.airdrop', 'cipher.airdrops' },
}

-- ── The drop itself ──────────────────────────────────────────────────────────
Config.Drop = {
    -- Seconds between the announcement and the plane arriving. This window is
    -- the whole point: it is when people decide to go, gear up and travel.
    WarningTime = 90,

    -- How close the first blip is to the truth. The exact spot only appears
    -- when the crate lands, so the warning window is a race to the right area
    -- rather than a queue on the exact coordinate.
    ApproxBlipRadius = 250.0,

    -- Radius of the contested area drawn on the map once it lands.
    ZoneRadius = 120.0,

    -- Seconds of cracking before the crate opens. Long enough that someone can
    -- interrupt you, short enough that a lone player is not stuck kneeling for
    -- a minute in the open.
    CrackTime = 25,

    -- Once open, how long the crate stays lootable before it despawns.
    OpenDuration = 300,

    -- If nobody cracks it at all, it disappears after this.
    AbandonedAfter = 900,

    -- Metres a player may drift from the crate before cracking cancels. The
    -- server re-checks this on completion too, so a teleport does not help.
    CrackDistance = 3.0,
}

-- ── Delivery ─────────────────────────────────────────────────────────────────
Config.Delivery = {
    -- A plane flies over and the crate parachutes down. Turning this off makes
    -- the crate simply appear at the drop point, which is far less interesting
    -- but costs nothing to render on a heavily loaded server.
    Flyover = true,

    PlaneModel = 'titan',
    CrateModel = 'prop_box_ammo04a',

    Altitude = 320.0,
    PlaneSpeed = 90.0,

    -- Metres out the plane spawns and despawns.
    SpawnDistance = 900.0,
}

-- ── Where drops land ─────────────────────────────────────────────────────────
-- Add or remove freely. Pick open ground with more than one approach: a spot
-- with a single road in belongs to whoever parks on it.
--
-- `weight` biases selection. The same location will not be chosen twice in a
-- row regardless of weight.
Config.Locations = {
    { label = 'Sandy Shores Airfield', coords = vec3(1747.0, 3286.0, 41.0),   weight = 10 },
    { label = 'Grapeseed Fields',      coords = vec3(2263.0, 4780.0, 35.0),   weight = 10 },
    { label = 'Vinewood Racetrack',    coords = vec3(1020.0, -1290.0, 30.0),  weight = 8  },
    { label = 'Palmer-Taylor Power',   coords = vec3(2745.0, 1580.0, 24.0),   weight = 8  },
    { label = 'Cassidy Creek',         coords = vec3(-450.0, 4380.0, 60.0),   weight = 6  },
    { label = 'Chumash Beach',         coords = vec3(-3220.0, 1080.0, 11.0),  weight = 6  },
    { label = 'Elysian Docks',         coords = vec3(150.0, -3000.0, 6.0),    weight = 8  },
    { label = 'Zancudo Riverbed',      coords = vec3(-1180.0, 2680.0, 18.0),  weight = 6  },
    { label = 'Mount Gordo',           coords = vec3(2880.0, 5900.0, 370.0),  weight = 4  },
    { label = 'Route 68 Scrapyard',    coords = vec3(-430.0, 2790.0, 42.0),   weight = 6  },
}

-- ── Loot ─────────────────────────────────────────────────────────────────────
-- Loot is rolled ON THE SERVER, at the moment the crate is cracked. Not when it
-- is announced, and never on a client — otherwise the contents are knowable
-- before the fight, and the fight is the product.
Config.Loot = {
    -- Slots and weight of the crate container.
    Slots = 12,
    MaxWeight = 80000,

    -- How many item stacks the crate contains.
    MinStacks = 4,
    MaxStacks = 7,

    -- Only used on inventories that cannot be handed a pre-filled container
    -- (everything except ox_inventory). There the crate yields this many stacks
    -- per search instead of opening as a shared box, so several people can pull
    -- something out of the same crate rather than the first arrival taking it
    -- all. See the note on the loot handler in server/main.lua.
    StacksPerSearch = 2,

    -- Every roll picks a tier first, then an item from it. Chances are relative
    -- weights, not percentages, so you can add a tier without rebalancing.
    Tiers = {
        {
            name = 'common',
            weight = 60,
            items = {
                { item = 'bandage',       min = 2, max = 5 },
                { item = 'water_bottle',  min = 2, max = 6 },
                { item = 'sandwich',      min = 2, max = 6 },
                { item = 'plastic',       min = 5, max = 15 },
                { item = 'metalscrap',    min = 5, max = 15 },
            },
        },
        {
            name = 'uncommon',
            weight = 28,
            items = {
                { item = 'lockpick',      min = 1, max = 3 },
                { item = 'advancedlockpick', min = 1, max = 2 },
                { item = 'radio',         min = 1, max = 1 },
                { item = 'firstaid',      min = 1, max = 2 },
                { item = 'steel',         min = 5, max = 12 },
            },
        },
        {
            name = 'rare',
            weight = 10,
            items = {
                { item = 'weapon_pistol', min = 1, max = 1 },
                { item = 'pistol_ammo',   min = 12, max = 30 },
                { item = 'thermite',      min = 1, max = 1 },
                { item = 'trojan_usb',    min = 1, max = 1 },
            },
        },
        {
            name = 'legendary',
            weight = 2,
            items = {
                { item = 'weapon_assaultrifle', min = 1, max = 1 },
                { item = 'rifle_ammo',    min = 30, max = 60 },
                { item = 'goldbar',       min = 1, max = 2 },
            },
        },
    },

    -- Guarantees at least one roll from this tier or better, so a crate is
    -- never entirely bandages after a five-minute fight. Set to nil to disable.
    GuaranteeAtLeast = 'uncommon',
}

-- ── Announcements ────────────────────────────────────────────────────────────
Config.Announce = {
    -- Whether to post the text announcements at all (inbound, landed, opened).
    -- Who receives them is decided by Config.Access.See, not here.
    --
    -- Turning this off leaves the blip and the on-screen countdown in place and
    -- removes the chat-style notifications, which suits a server that would
    -- rather players find out by looking at the map.
    ToEveryone = true,

    -- Name the rough area in the announcement. Turning this off makes drops
    -- much harder to find and heavily favours players who happen to be nearby.
    NameLocation = true,

    -- Post to Discord as well. Leave empty to disable.
    Webhook = '',
}

-- ── Police ───────────────────────────────────────────────────────────────────
-- An unregistered aircraft dropping cargo is a police matter. This fires a
-- dispatch call so law enforcement has a legitimate reason to attend, which
-- turns a gang fight into a three-way one.
Config.Police = {
    Alert = true,

    -- Seconds after landing before police are told. The delay gives whoever is
    -- racing for the crate a head start, which is the fair version of this.
    Delay = 45,

    Jobs = { 'police', 'sheriff', 'sasp' },

    -- Uses cipher-dispatch when present, then any common dispatch resource,
    -- then a plain notification. See client/dispatch.lua.
    Code = '10-66',
    Title = 'Unregistered Cargo Drop',
}

-- ── Blips ────────────────────────────────────────────────────────────────────
Config.Blip = {
    Sprite = 478,
    Colour = 5,          -- the pin itself
    Scale  = 1.1,

    -- The contested area, drawn as a filled circle on the map rather than a
    -- lone pin. Red because that is what every player already reads as
    -- "something is happening here and it is not safe".
    ShowRadius = true,
    RadiusColour = 1,    -- 1 = red
    RadiusAlpha = 90,

    -- The search area during the inbound window, before the exact spot is
    -- known. Deliberately a different colour from the live zone so the two
    -- states are not mistaken for each other at a glance.
    ApproxColour = 5,    -- 5 = yellow
    ApproxAlpha = 60,
}

-- ── Admin ────────────────────────────────────────────────────────────────────
-- Used by the framework bridge to decide who may call a drop by hand.
-- Any one of these passing is enough.
Config.Admin = {
    acePermission = 'cipher.airdrops',

    -- Framework permission groups (QBox / QBCore).
    groups = { 'admin', 'god' },

    -- Rockstar licence identifiers, e.g. 'license:110000112345678'.
    -- Leave this empty unless you specifically need it — anything you put here
    -- is committed to your repo along with everything else.
    licenses = {},
}

-- ── Notification styling ─────────────────────────────────────────────────────
Config.NotifyStyle = {
    title = 'Airdrop',
    icon = 'parachute-box',
    position = 'top',
    duration = 7000,
}

-- ── Who gets to take part ────────────────────────────────────────────────────
--
-- Two separate questions, because they usually have different answers:
--   See     — who is told a drop is happening, and gets the blip
--   Collect — who can actually crack the crate and take from it
--
-- The common setup is "everyone sees it, everyone can take it". The second most
-- common is "police see every drop but cannot loot it", which makes them
-- responders rather than another gang — that is what Config.Access.Police is
-- for, and it overrides the two blocks below for those jobs.
Config.Access = {
    See = {
        Everyone = true,
        -- Only consulted when Everyone = false.
        Jobs  = {},          -- e.g. { 'police', 'ambulance' }
        Gangs = {},          -- e.g. { 'ballas', 'families' }
    },

    Collect = {
        Everyone = true,
        Jobs  = {},
        Gangs = {},
    },

    -- Police are called out separately because they are the usual exception.
    Police = {
        Jobs = { 'police', 'sheriff', 'sasp' },

        -- Officers always get told, even when See.Everyone is false. Set this
        -- to false and police find out the same way everyone else does.
        CanSee = true,

        -- Whether an officer can crack and loot a crate. Setting this false is
        -- what turns a drop into a three-way scene: criminals fight for it,
        -- police turn up to stop them, and nobody in uniform is there to loot.
        CanCollect = true,
    },

    -- Shown to someone who tries to crack a crate they are not allowed to.
    -- Saying nothing at all reads as the script being broken.
    DeniedMessage = 'You have no idea how to open this.',
}

-- ── Sound ────────────────────────────────────────────────────────────────────
-- Native GTA frontend sounds, so there are no audio files to ship and nothing
-- to stream.
--
-- A drop that only announces itself in text is easy to miss entirely when you
-- are driving — which is exactly when the announcement matters, because that is
-- the moment you decide whether to turn around.
Config.Sounds = {
    Enabled = true,

    Events = {
        -- A drop has been called. The one cue that has to cut through.
        announced = { name = 'Beast_Barrage',      set = 'GTAO_Beast_Barrage_Sounds' },

        -- Last ten seconds of the warning window, once per second.
        tick      = { name = 'TIMER_STOP',         set = 'HUD_MINI_GAME_SOUNDSET' },

        -- The crate is on the ground.
        landed    = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },

        -- Somebody got it open.
        opened    = { name = 'ROBBERY_MONEY_TOTAL', set = 'HUD_FRONTEND_CUSTOM_SOUNDSET' },
    },

    -- The countdown ticks are the one cue people will tire of first, so they are
    -- separately switchable.
    CountdownTicks = true,
}
