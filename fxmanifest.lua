fx_version 'cerulean'
games { 'gta5' }

name 'Pulsar Escort'
description 'Drag and carry a player, plus vehicle trunk stuffing'
author 'Artmines - maintained for Pulsar Framework'
url 'https://pulsarframe.work'
version 'v1.0.0'

version_check 'yes'
github 'https://github.com/PulsarFW/pulsar_escort'

client_script '@pulsar_core/components/cl_error.lua'
shared_script '@pulsar_core/core/sh_pulsar.lua'
client_script '@pulsar_pwnzor/client/check.lua'

client_scripts({
	'client/**/*.lua',
})

server_scripts({
	'server/**/*.lua',
})

lua54 'yes'