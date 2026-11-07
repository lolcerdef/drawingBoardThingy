local enet = require 'enet'

--[[
packets:
H|version|code|name: client -> host, hello
W|hostname: host -> client, welcome
X|reason: host -> client, deny
D: host -> client, snapshot
N|count: host -> client, people count
P|you|name|name...: host -> client, roster (you = your index, host is 1)
S|layer|width|r|g|b|a|x,y... : stroke 
E|layer|radius|x,y... : eraser
]]

local net = {}

local maxLayers = 1000
local connectTimeout = 8
local version = 1

net.mode = nil -- 'host' or 'client'
net.status = 'Offline'
net.host = nil
net.server = nil
net.peers = {}
net.ready = false
net.online = 1
net.people = {}
net.selfIndex = nil
net.name = 'Guest'
net.code = ''
net.address = ''
net.port = 0
net.connectStarted = 0

local function num(v)
	return string.format('%.8g', v)
end

local function decodeList(str)
	local out = {}
	if not str or str == '' then return out end
	for v in str:gmatch('[^,]+') do
		local n = tonumber(v)
		if not n then return nil end
		out[#out + 1] = n
	end
	return out
end

local function encodeList(t)
	local out = {}
	for i = 1, #t do out[i] = num(t[i]) end
	return table.concat(out, ',')
end

local function split(s)
	local out = {}
	for part in (s .. '|'):gmatch('(.-)|') do
		out[#out + 1] = part
	end
	return out
end

local function clean(s)
	s = (s or ''):gsub('[|%c]','')
	return s:sub(1,24)
end

local function shown(n)
	n = n or ''
	return n ~= '' and n or 'Guest'
end

local function ensureLayer(n)
	for i = #layers + 1, n do
		layers[i] = {}
	end
end

local function validLayer(n)
	return n and n == math.floor(n) and n >= 1 and n <= maxLayers
end

local function encodeStroke(lay, s)
	local c = s.color
	return table.concat({
		'S', string.format('%d', lay), num(s.width),
		num(c[1]), num(c[2]), num(c[3]), num(c[4]),
		encodeList(s.points),
	}, '|')
end

local function encodeErase(lay, rad, pts)
	return table.concat({
		'E', string.format('%d', lay), num(rad), encodeList(pts)
	}, '|')
end

local function applyStroke(data)
	local lay = tonumber(data[2])
	local width = tonumber(data[3])
	local r, g, b, a = tonumber(data[4]), tonumber(data[5]), tonumber(data[6]), tonumber(data[7])
	local pts = decodeList(data[8])
	if not (validLayer(lay) and width and r and g and b and a and pts) then return false end
	if #pts % 2 ==1 then pts[#pts] = nil end
	if #pts < 2 then return false end
	
	ensureLayer(lay)
	table.insert(layers[lay], {
		type = 'line', width = width,
		color = { r, g, b, a}, points = pts
	})
	return true
end

local function applyErase(data)
	local lay = tonumber(data[2])
	local radius = tonumber(data[3])
	local pts = decodeList(data[4])
	if not (validLayer(lay) and radius and pts) then return false end
	
	ensureLayer(lay)
	for i =1, #pts - 1, 2 do
		eraseAt(pts[i], pts[i+1], radius, lay)
	end
	return true
end

local function send(peer, data)
	pcall(function() peer:send(data, 0, 'reliable') end)
end

local function broadcast(data, skipIdx)
	for i, p in pairs(net.peers) do
		if p.ok and i ~= skipIdx then send(p.peer, data) end
	end
end

local function sendOut(data)
	if net.mode == 'host' then
		broadcast(data)
	elseif net.mode == 'client' and net.ready and net.server then
		send(net.server, data)
	end
end

function net.sendStroke(lay, stroke)
	if not net.mode or #stroke.points < 2 then return end
	
	sendOut(encodeStroke(lay, stroke))
end

function net.sendErase(lay, rad, pts)
	if not net.mode or #pts < 2 then return end
	sendOut(encodeErase(lay, rad, pts))
end

local function sendSnapshot(peer)
	local skip = rawget(_G, 'tempVisual')
	for li, l in ipairs(layers) do
		for _, s in ipairs(l) do
			if s.type == 'line' and s ~= skip and #s.points >= 2 then
				send(peer, encodeStroke(li, s))
			end
		end
	end
end

local function announceCount()
	if net.mode ~= 'host' then return end
	local names = { shown(net.name) }
	local idx = {}
	for i, p in pairs(net.peers) do
		if p.ok then
			names[#names + 1] = shown(p.name)
			idx[i] = #names
		end
	end
	net.online = #names
	net.people = names
	net.selfIndex = 1
	local list = table.concat(names, '|')
	for i, n in pairs(idx) do
		local peer = net.peers[i].peer
		send(peer, 'N|' .. #names)
		send(peer, 'P|' .. n .. '|' .. list)
	end
end

function net.isActive()
	return net.mode ~= nil
end

function net.stop(statusOverride)
	pcall(function()
		if net.mode == 'host' then
			for _, p in pairs(net.peers) do
				p.peer:disconnect()
			end
		elseif net.server then
			net.server:disconnect()
		end
		if net.host then net.host:flush() end
	end)
	net.host, net.server = nil, nil
	net.peers = {}
	net.mode = nil
	net.ready = false
	net.online = 1
	net.people = {}
	net.selfIndex = nil
	net.status = statusOverride or 'Offline'
	multiplayerDialog = true
end

function net.startHost(port, code, name)
	if net.mode then net.stop() end
	port = tonumber(port)
	if not port or port < 1 or port > 65535 then
		net.status = 'Invalid Port'
		return false
	end
	
	local ok, host = pcall(enet.host_create, '*:' .. port, 16)
	if not ok or not host then
		net.status = "Can't host (Port in use?)"
		return false
	end
	
	net.host, net.mode = host, 'host'
	net.peers = {}
	net.name, net.code, net.port = clean(name), code or '', port
	net.online = 1
	net.people = { shown(net.name) }
	net.selfIndex = 1
	net.status = 'Hosting on port ' .. net.port
	return true
end

function net.join(address, port, code, name)
	if net.mode then net.stop() end
	port = tonumber(port)
	address = (address or ''):gsub('%s', '')
	if address == '' then
		net.status = 'Enter an address'
		return false
	end
	if not port or port < 1 or port > 65535 then
		net.status = 'Invalid Port'
		return false
	end
	
	local ok, host = pcall(enet.host_create)
	if not ok or not host then
		net.status = "Can't host (Port in use?)"
		return false
	end
	local ok2, server = pcall(function() return host:connect(address .. ':' .. port) end)
	if not ok2 or not server then
		net.status = "Couldn't reach " .. address
		return false
	end
	
	net.host, net.server, net.mode = host, server, 'client'
	net.name, net.code, net.port = clean(name), code or '', port
	net.address = address
	net.ready = false
	net.online = 1
	net.connectStarted = os.time()
	net.status = 'Connecting'
	return true
end

local function hHandle(entry, i, msg)
	local parts = split(msg)
	local t = parts[1]
	
	if t == 'H' then
		if entry.ok then return end
		if tonumber(parts[2]) ~= version then
			send(entry.peer, 'X|Version mismatch')
			entry.peer:disconnect_later()
			return
		end
		if net.code ~= '' and parts[3] ~= net.code then
			send(entry.peer, 'X|Wrong Code')
			entry.peer:disconnect_later()
			return
		end
		entry.ok = true
		entry.name = clean(parts[4])
		send(entry.peer, 'W|' .. net.name)
		sendSnapshot(entry.peer)
		send(entry.peer, 'D')
		announceCount()
	elseif entry.ok and t == 'S' then
		if applyStroke(parts) then broadcast(msg, i) end
	elseif entry.ok and t == 'E' then
		if applyErase(parts) then broadcast(msg, i) end
	end
end

local function cHandle(msg)
	local parts = split(msg)
	local t = parts[1]
	
	if t == 'W' then
		net.ready = true
		net.status = 'Joined ' .. clean(parts[2])
	elseif t == 'X' then
		net.stop('Denied: ' .. clean(parts[2]))
	elseif not net.ready then
		return
	elseif t == 'S' then
		applyStroke(parts)
	elseif t == 'E' then
		applyErase(parts)
	elseif t == 'N' then
		net.online = tonumber(parts[2]) or net.online
	elseif t == 'P' then
		local names = {}
		for i = 3, math.min(#parts, 66) do
			names[#names + 1] = shown(clean(parts[i]))
		end
		net.people = names
		net.selfIndex = tonumber(parts[2])
		net.online = #names
	end
end

local function handleEvent(ev)
	if net.mode == 'host' then
		local i = ev.peer:index()
		if ev.type == 'connect' then
			net.peers[i] = {peer = ev.peer, name = '?', ok = false}
		elseif ev.type == 'disconnect' then
			net.peers[i] = nil
			announceCount()
		elseif ev.type == 'receive' then
			local entry = net.peers[i]
			if entry then pcall(hHandle, entry, i, ev.data) end
		end
	elseif net.mode == 'client' then
		if ev.type == 'connect' then
			send(ev.peer, table.concat({'H', version, net.code, net.name}, '|'))
		elseif ev.type == 'disconnect' then
			if net.ready then
				net.stop('Disconnected')
			else
				net.stop("Couldn't connect to ".. net.address.. ':' .. net.port)
			end
		elseif ev.type == 'receive' then
			pcall(cHandle, ev.data)
		end
	end
end

function net.update()
	if not net.host then return end
	
	if net.mode == 'client' and not net.ready
		and os.time() - net.connectStarted > connectTimeout then
		net.stop("Couldn't connect to ".. net.address.. ':' .. net.port)
		return
	end
	
	for _ = 1, 500 do
		if not net.host then break end
		local ok, ev = pcall(function() return net.host:service(0) end)
		if not ok or not ev then break end
		handleEvent(ev)
	end
end

function net.hud()
	if net.mode == 'host' then
		return 'Hosting :' .. net.port .. ' - ' .. net.online .. ' online'
	elseif net.mode == 'client' and net.ready then
		return 'Joined - ' .. net.online .. ' online'
	elseif net.mode == 'client' then
		return 'Connecting...'
	end
	return nil
end

return net