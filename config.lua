Config = {}

-- Force a bridge instead of auto-detecting. 'auto' is almost always right.
Config.Bridges = {
    framework = 'auto',   -- auto | qbx_core | qb-core
    inventory = 'auto',   -- auto | ox_inventory | qb-inventory | qs-inventory | codem-inventory | core_inventory | ps-inventory
    dispatch = 'auto',    -- auto | none | XS-Dispatch | ps-dispatch | qs-dispatch | cd_dispatch | core_dispatch | rcore_dispatch | linden_outlawalert
}

Config.Debug = false

-- Supply drops get announced, flown in and left on the ground for whoever
-- turns up. It never touches damage or PvP rules, so it runs on any server.
--
-- Almost everything below can be changed in game from /airdrops, the builder.
-- Anything changed there is saved in the database and wins over this file.
-- Drop zones, crate types and loot tables live only in the builder once the
-- script has started for the first time.

-- Who can open the builder and call drops by hand. Any one of these passing
-- is enough. The usual way is one line in server.cfg:
--   add_ace group.admin xs.airdrops allow
Config.Admin = {
    acePermission = 'xs.airdrops',

    -- Framework permission groups (QBox / QBCore).
    groups = { 'admin', 'god' },

    -- Rockstar licence identifiers, e.g. 'license:110000112345678'.
    licenses = {},
}

Config.AdminCommand = {
    -- /airdrops opens the builder.
    Builder = 'airdrops',

    -- /airdrop [zone] calls a drop straight away.
    Enabled = true,
    Command = 'airdrop',

    -- Any of these aces also opens the builder and calls drops.
    Aces = { 'command.airdrop', 'xs.airdrops' },
}

-- When drops happen. Builder > Schedule.
Config.Schedule = {
    Enabled = true,

    -- Minutes between drops, random between these two.
    MinInterval = 45,
    MaxInterval = 90,

    -- No drop unless this many players are online.
    MinPlayers = 8,

    -- Server time, 0-23. -1 on both means any time.
    -- e.g. { from = 18, to = 4 } for evenings and nights only.
    Hours = { from = -1, to = -1 },

    -- How many drops can run at the same time.
    MaxActive = 1,

    -- Minutes before the same zone can be picked again.
    -- 0 means only "never the same zone twice in a row".
    ZoneCooldown = 0,
}

-- The drop itself. Builder > Settings.
Config.Drop = {
    -- Seconds from the announcement to the crate landing.
    WarningTime = 90,

    -- Wide circle shown while it is inbound. Zones can set their own.
    ApproxBlipRadius = 250.0,

    -- Contested circle once it lands. Zones can set their own.
    ZoneRadius = 120.0,

    -- Seconds of cracking. Only used for the first crate type, which the
    -- builder owns after that.
    CrackTime = 25,

    -- How long an opened crate stays lootable.
    OpenDuration = 300,

    -- An unopened crate gives up after this, but only while the zone is empty.
    AbandonedAfter = 900,

    -- An emptied crate stays this long so late arrivals see they missed it.
    EmptyLinger = 60,

    -- Extra time each time it would expire with someone still in the zone.
    PresenceGrace = 120,

    -- Gone this long after landing no matter what. 0 = no cap.
    MaxLifetime = 3600,

    -- How close you must be to open or search the crate.
    CrackDistance = 5.0,

    -- How players open the crate: 'key' (walk up and press E) or 'target'
    -- (ox_target or qb-target). Without a target script it falls back to E.
    OpenWith = 'key',

    -- The on-screen timer only shows this close. 0 = always.
    HudDistance = 400.0,
}

-- The plane. Model, crate prop and height are only used for the first crate
-- type; the builder owns them after that.
Config.Delivery = {
    Flyover = true,
    PlaneModel = 'titan',
    CrateModel = 'prop_mil_crate_01',

    -- Metres above the landing point.
    Altitude = 320.0,

    PlaneSpeed = 90.0,

    -- Metres out the plane appears and leaves.
    SpawnDistance = 900.0,
}

-- Only read on the very first start, to make the first drop zones. Build
-- zones in game from /airdrops instead, standing on the spot.
Config.Locations = {}

-- Only read on the very first start, to make the first loot table and crate
-- type. Builder > Loot tables owns them after that.
Config.Loot = {
    Slots = 12,
    MaxWeight = 80000,

    MinStacks = 4,
    MaxStacks = 7,

    -- Inventories that cannot be handed a filled crate (everything except
    -- ox_inventory) give out this many stacks per search instead.
    StacksPerSearch = 2,

    -- Weights are relative, not percentages.
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

    -- At least one roll from this tier or better. nil turns it off.
    GuaranteeAtLeast = 'uncommon',
}

Config.Announce = {
    ToEveryone = true,
    NameLocation = true,

    -- Discord webhook for drops. Leave empty to turn it off.
    Webhook = '',
}

Config.Police = {
    -- Only used for the first crate type; each crate type has its own.
    Alert = true,
    Delay = 45,

    Jobs = { 'police', 'sheriff', 'sasp' },
    Code = '10-66',
    Title = 'Unregistered Cargo Drop',
}

Config.Blip = {
    -- Pin icon and colour are only used for the first crate type.
    Sprite = 478,
    Colour = 5,
    Scale = 1.1,

    ShowRadius = true,
    RadiusColour = 1,
    RadiusAlpha = 90,
    ApproxColour = 5,
    ApproxAlpha = 60,
}

Config.NotifyStyle = {
    title = 'Airdrop',
    icon = 'parachute-box',
    position = 'top',
    duration = 7000,
}

-- See: who gets the blip, the circles, the messages and the crate itself.
--   Mode = 'everyone', 'only' (just the jobs and gangs listed) or 'except'
--   (everyone but them, police too). Drop zones can set their own.
-- Collect: the default rule for who can open a crate. Crate types can set their own.
Config.Access = {
    See = {
        Mode  = 'everyone',
        Jobs  = {},
        Gangs = {},
    },

    Collect = {
        Everyone = true,
        Jobs  = {},
        Gangs = {},
    },

    Police = {
        Jobs = { 'police', 'sheriff', 'sasp' },
        CanSee = true,
        CanCollect = true,
    },

    DeniedMessage = 'You have no idea how to open this.',
}

-- Native GTA frontend sounds. No audio files to ship.
Config.Sounds = {
    Enabled = true,

    Events = {
        announced = { name = 'Beast_Barrage',       set = 'GTAO_Beast_Barrage_Sounds' },
        tick      = { name = 'TIMER_STOP',          set = 'HUD_MINI_GAME_SOUNDSET' },
        landed    = { name = 'CHECKPOINT_PERFECT',  set = 'HUD_MINI_GAME_SOUNDSET' },
        opened    = { name = 'ROBBERY_MONEY_TOTAL', set = 'HUD_FRONTEND_CUSTOM_SOUNDSET' },
    },

    CountdownTicks = true,
}

-- The freecam used to place landing points.
Config.Builder = {
    showExisting = true,
    showSeconds = 10,
    cameraSpeed = { normal = 8.0, fast = 40.0, slow = 1.5 },
}
