fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'cipher-airdrops'
author 'XyraL'
description 'Cipher — Airdrops. Contested supply drops: announced, flown in, cracked open and fought over. Standalone for QBox/QBCore.'
version '1.0.0'

-- Works on QBox (qbx_core) OR QBCore (qb-core). The bridge auto-detects.
-- Inventory: ox_inventory / qb-inventory / qs-inventory / codem-inventory /
-- core_inventory / ps-inventory — bridge auto-detects, force via Config.Bridges.
-- Dispatch: cipher-dispatch / ps-dispatch / qs-dispatch / cd_dispatch /
-- core_dispatch, with a plain-notification fallback.
--
-- No database. Nothing here is persisted: a drop lives and dies inside one
-- server session, so there is no schema to import and nothing to migrate.
dependencies {
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'client/main.lua',
    'client/delivery.lua',
    'client/crate.lua',
    'client/dispatch.lua',
}

server_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'server/loot.lua',
    'server/main.lua',
}
