fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-AirDrops'
author 'XyraL'
description 'Contested supply drops: announced, flown in, cracked open and fought over. Standalone for QBox/QBCore.'
version '1.0.0'

-- Works on QBox (qbx_core) OR QBCore (qb-core). The bridge auto-detects.
-- Inventory: ox_inventory / qb-inventory / qs-inventory / codem-inventory /
-- core_inventory / ps-inventory — bridge auto-detects, force via Config.Bridges.
-- Dispatch: XS-Dispatch / ps-dispatch / qs-dispatch / cd_dispatch /
-- core_dispatch, with a plain-notification fallback.
dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'client/settings.lua',
    'client/main.lua',
    'client/delivery.lua',
    'client/crate.lua',
    'client/hud.lua',
    'client/sounds.lua',
    'client/dispatch.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'server/data.lua',
    'server/settings.lua',
    'server/loot.lua',
    'server/main.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/core.js',
    'html/js/app.js',
    'html/js/panels/live.js',
    'html/js/panels/locations.js',
    'html/js/panels/loot.js',
    'html/js/panels/history.js',
    'html/js/panels/settings.js',
}
