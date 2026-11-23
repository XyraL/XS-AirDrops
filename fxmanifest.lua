fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-AirDrops'
author 'XyraL'
description 'Contested supply drops: announced, flown in, cracked open and fought over. Built in game. Standalone for QBox/QBCore.'
version '2.0.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/util.lua',
    'shared/settings.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'client/ui.lua',
    'client/settings.lua',
    'client/main.lua',
    'client/delivery.lua',
    'client/crate.lua',
    'client/hud.lua',
    'client/sounds.lua',
    'client/dispatch.lua',
    'client/placement.lua',
    'client/builder.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/dispatch.lua',
    'server/db.lua',
    'server/settings.lua',
    'server/data.lua',
    'server/loot.lua',
    'server/main.lua',
    'server/builder.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
}
