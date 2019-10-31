resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

ui_page('html/index.html') 

dependency 'vrp'

files({
  'html/index.html',
  'html/script.js',
  'html/style.css',
	'html/img/burger.png',
	'html/img/bottle.png',
  'html/font/vibes.ttf',
  'html/img/box.png',
	'html/img/carticon.png',
})

client_scripts {
  'gui.lua',
  'lib/Proxy.lua',
  'lib/Tunnel.lua',
  'config.lua',
  'client/main.lua',
}

server_scripts {
  '@vrp/lib/utils.lua',
  'config.lua',
  'server/main.lua',
  '@mysql-async/lib/MySQL.lua'
}
