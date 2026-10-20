fx_version 'cerulean'
game 'gta5'

author 'Harun155'
description 'HUD Resource'
version '1.0.0'

ui_page 'web/index.html'

-- FlyBanditMods iOS LS Map (Lite): tiles are in stream/, the scaleform is registered below.
this_is_a_map 'yes'
data_file 'SCALEFORM_DLC_FILE' 'stream/int3232302352.gfx'

files {
    'stream/int3232302352.gfx',
    'assets/radar-mask.png',
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/images/*.png',
    'web/images/*.svg',
    'web/weapons/*.png'
}

client_scripts {
    'client/main.lua',
    'client/minimap.lua',
    'client/seatbelt.lua'
}

shared_scripts {
    'config.lua',
    'shared/bridge.lua'
}

exports {
    'GetFramework',
    'ShowHUD',
    'Notify'
}
-- SetMinimapVisible / RefreshMinimapLayout are exported from client/minimap.lua.

