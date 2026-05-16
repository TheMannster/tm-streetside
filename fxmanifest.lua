fx_version 'cerulean'
game 'gta5'

name 'tm-streetside'
description 'Modular display + ambient city vehicles'
author 'themannster'
version '1.3.8'

dependencies {
    'ox_lib',
    'ox_inventory',
    'qbx_core',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/logger.lua',
}

client_scripts {
    'client/modules/display.lua',
    'client/modules/citycars.lua',
    'client/modules/policegate.lua',
}

server_scripts {
    'server/modules/citycars.lua',
    'server/modules/policegate.lua',
    'server/modules/versioncheck.lua',
    'server/main.lua',
}
