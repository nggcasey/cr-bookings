fx_version 'cerulean'
game 'gta5'

name "cr-bookings"
description "A resource for booking appointments"
author "Casey Reed"
version "1.0.0"

shared_scripts {
	'shared/config.lua',
	'@ox_lib/init.lua'
}

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'client/cl_utils.lua',
	'client/cl_main.lua',

}

server_scripts {
	'server/sv_utils.lua',
	'server/sv_main.lua',
	'@oxmysql/lib/MySQL.lua'
}

lua54 'yes'