utf8 = require "utf8"
enet = require 'enet'

function love.load()
	math.randomseed(os.time())
	math.random()
	
	love.keyboard.setKeyRepeat(true)
	love.graphics.setLineJoin('bevel')
	love.graphics.setLineStyle('smooth')
	love.graphics.setDefaultFilter( 'nearest', 'nearest' )
		
	fonts = require 'preload.fonts'
	love.graphics.setFont(fonts.main)
	
	sprites = require 'preload.sprites'
	sounds = require 'preload.sounds'
	
	helpers = require 'lib.helpers'
	ui = require 'lib.ui'
	
	cursors = {
		brush = love.mouse.newCursor( love.image.newImageData("assets/sprites/icons/brush.png"), 4, 26 ),
		erase = love.mouse.newCursor( love.image.newImageData("assets/sprites/icons/eraser.png"), 4, 26 ),
		cursor = love.mouse.newCursor( love.image.newImageData("assets/sprites/icons/cursor.png"), 1, 1 ),
	}
	love.mouse.setCursor(cursors.brush)
	multiplayerDialog = false
	mpDialogTab = 0
	
	mouse = {
		lb = false,
		rb = false,
		mb = false,
		pressed = false,
		sc = 0,
		x = 0,
		y = 0,
		wx = 0,
		wy = 0,
	}
	pan = { x = 0, y = 0, sx = nil, sy = nil}
	color = {0,0,0,1}
	tool = 'brush'
	toolBuffer = {}
	tempVisual = {}
	startDrag = nil
	endDrag = nil
	lastErase = {}
	size = 4
	layer = 1
	layers = {
		{}
	}
	--[[
	{ type: '', data: { stuff } }
	{ type: 'line', width: size, points: {points} }
	
	]]
	
	port = 8888
	joinAddress = 'localhost'
	code = ''
	name = 'Guest'
	ranImg = nil
end

function resetTool()
	toolBuffer = {}
	startDrag = nil
	endDrag = nil
end

function eraseAt(wx, wy)
	local lines = layers[layer]
	local i = 1
	while i <= #lines do
		local s = lines[i]
		if s.type == 'line' and s ~= tempVisual then
			local pieces = helpers.eraseFromStroke(s, wx, wy, size / 2)
			if #pieces == 1 and pieces[1] == s then
				i = i + 1
			else
				table.remove(lines, i)
				for j, p in ipairs(pieces) do
					table.insert(lines, i + j - 1, p)
				end
				i = i + #pieces
			end
		else
			i = i + 1
		end
	end
end

function love.update(dt)
	mouse.wx, mouse.wy = mouse.x - pan.x, mouse.y - pan.y
	
	if not ui.hasMouse then
		
		if tool == 'brush' then
			if mouse.lb then
				if startDrag then
					if (mouse.wx ~= toolBuffer[#toolBuffer-1]) or (mouse.wy ~= toolBuffer[#toolBuffer]) then
						table.insert(toolBuffer, mouse.wx)
						table.insert(toolBuffer, mouse.wy)
					end
				else
					startDrag = startDrag or {}
					tempVisual = { type = 'line', width = size, points = toolBuffer, color = color }
					table.insert(layers[layer], tempVisual)
				end
			end
			
			if startDrag and not mouse.lb then
				table.insert(layers[layer], { 
					type = 'line', width = size,
					points = helpers.copyTable(toolBuffer),
					color = helpers.copyTable(color)
				})
				resetTool()
				for i, v in ipairs(layers[layer]) do
					if v == tempVisual then
						table.remove(layers[layer], i)
					end
				end
			end
		elseif tool == 'erase' then
			if mouse.lb then
				local lx, ly = lastErase.x or mouse.wx, lastErase.y or mouse.wy
				local dist = math.sqrt((mouse.wx - lx)^2 + (mouse.wy - ly)^2)
				local steps = math.max(1, math.ceil(dist / math.max (1, size / 4)))
				for k = 1, steps do
					local t = k / steps
					eraseAt(lx + (mouse.wx - lx) * t, ly + (mouse.wy - ly) * t)
				end
				lastErase.x, lastErase.y = mouse.wx, mouse.wy
			else
				lastErase.x, lastErase.y = nil, nil
			end
		end
		
		if mouse.mb then
			if pan.sx and pan.sy then
				pan.x = mouse.x - pan.sx 
				pan.y = mouse.y - pan.sy
			else
				pan.sx = mouse.wx
				pan.sy = mouse.wy
			end
		elseif pan.sx and pan.sy then
			pan.sx, pan.sy = nil, nil
		end
	end
	
	mouse.sc = 0
end

function love.mousepressed(x,y,b)
	mouse.lb = b == 1 or mouse.lb
	mouse.rb = b == 2 or mouse.rb
	mouse.mb = b == 3 or mouse.mb
	mouse.pressed = true
end

function love.mousereleased(x,y,b)
	if b == 1 then
		mouse.lb = false
	elseif b == 2 then
		mouse.rb = false
	elseif b == 3 then
		mouse.mb = false
	end
end

function love.mousemoved(x,y)
	mouse.x, mouse.y = x, y
end

function love.wheelmoved(x, y)
	mouse.sc = y
end

function love.textinput(text)
	ui.handleText(text)
end

function love.keypressed(key)
	local ctrlKey = 'ctrl'
	if love.system.getOS() == 'OS X' then
		ctrlKey = 'gui' -- apparently this is what mac uses
	end
	if love.keyboard.isDown('l'..ctrlKey) or love.keyboard.isDown('r'..ctrlKey) then
		if key == 'v' then
			ui.handleText(love.system.getClipboardText())
		end
	end
	
	ui.handleKey(key)
end

function love.draw()
	love.graphics.clear(1,1,1,1)
	love.graphics.translate(pan.x, pan.y)
	for _, l in ipairs(layers) do
		for _, d in ipairs(l) do
			if d.type == 'line' then
				if not (#d.points % 2) then goto skip end
				love.graphics.setColor(d.color)
				if #d.points >= 4 then
					love.graphics.setLineWidth(d.width)
					love.graphics.line(d.points)
				end
				if d.points[1] and d.points[2] then
					love.graphics.circle('fill', d.points[1], d.points[2], d.width/2)
					love.graphics.circle('fill', d.points[#d.points-1], d.points[#d.points], d.width/2)
				end
			end
			::skip::
		end
	end
	love.graphics.translate(-pan.x,-pan.y)
	
	love.graphics.setColor(color)
	if tool == 'brush' then
		love.graphics.circle('fill', mouse.x, mouse.y, size/2)
	elseif tool == 'erase' then
		helpers.dottedCirc(mouse.x, mouse.y, size/2, math.floor(size), 1)
	end
	
	love.graphics.setColor(1,1,1,1)
	ui.hasMouse = false
	
	ui.canInput = not multiplayerDialog
	ui.drawbox(60, 628, 15, 2)
	local toolButtonPressed = false
	toolButtonPressed = ui.button(82, 646, nil, sprites.tools.brush, tool == 'brush' and color, function() tool = 'brush' end) or toolButtonPressed
	toolButtonPressed = ui.button(156, 646, nil, sprites.tools.eraser, tool == 'erase' and color, function() tool = 'erase' end) or toolButtonPressed
	color[1] = ui.slider(color[1], 0, 1, 500, 660, 16, 12, 100, {color[1], 0, 0}, {1 - color[1], 0, 0})
	color[2] = ui.slider(color[2], 0, 1, 575, 696, 16, 12, 100, {0, color[2], 0}, {0, 1 - color[2], 0})
	color[3] = ui.slider(color[3], 0, 1, 650, 660, 16, 12, 100, {0, 0, color[3]}, {0, 0, 1 - color[3]})
	size = ui.slider(size, 1, 100, 252, 678, 16 + ( size/100 * 16), 16, 200, {1,1,1})
	
	if toolButtonPressed then
		love.mouse.setCursor(cursors[tool])
	end
	love.graphics.setColor(0,0,0,1)
	love.graphics.printf('Layer: ' .. layer, 902, 646, 248, 'center')
	ui.button(962, 666, {0,0,0,0}, sprites.icons.left, nil, function() 
		if (layer - 1) < 1 then return end
		layer = layer - 1
	end)
	ui.button(1022, 666, {0,0,0,0}, sprites.icons.right, nil, function() 
		if not layers[layer + 1] then
			layers[layer + 1] = {}
		end
		layer = layer + 1
	end)
	ui.canInput = true
	
	if multiplayerDialog then
		ui.drawbox(-72,-72, 18, 12, {0,0,0,0.3})
		ui.drawbox(96,72, 14, 8)
		ui.button(8, 88, nil, sprites.icons.host, nil, function() mpDialogTab = 0 end)
		ui.button(8, 168, nil, sprites.icons.join, nil, function() mpDialogTab = 1 end)
		
		love.graphics.setFont(fonts.title)
		love.graphics.setColor(0,0,0)
		if mpDialogTab == 0 then
			love.graphics.print('Host', 116, 86, 0, 1.5, 1.5)
			love.graphics.setFont(fonts.main)
			love.graphics.print('Port', 116, 162, 0, 1, 1)
			port = tonumber(ui.textBox(tostring(port), 206, 157, 300, 34, '%d'))
			
			love.graphics.print('Code', 116, 212, 0, 1, 1)
			code = ui.textBox(code, 206, 206, 300, 34)
		elseif mpDialogTab == 1 then
			love.graphics.print('Join', 116, 86, 0, 1.5, 1.5)
			love.graphics.setFont(fonts.main)
			love.graphics.print('Address', 116, 162, 0, 1, 1)
			joinAddress = ui.textBox(joinAddress, 265, 157, 241, 34)
			
			love.graphics.print('Port', 116, 212, 0, 1, 1)
			port = tonumber(ui.textBox(tostring(port), 265, 206, 241, 34, '%d'))
			
			love.graphics.print('Code', 116, 262, 0, 1, 1)
			code = ui.textBox(code, 265, 255, 241, 34)
		end
		
		love.graphics.print('Name', 116 + 80, 584, 0, 1, 1)
		name = ui.textBox(name, 206 + 80, 578, 220, 34)
		ui.button(116, 564, nil, sprites.icons.right, nil, function()
			
		end)
		ui.button(564, 112, {0,0,0,0}, ranImg)
	end
	
	ui.button(8, 8, nil, sprites.icons.multiplayer, nil, function() 
		multiplayerDialog = not multiplayerDialog
		if multiplayerDialog then
			love.mouse.setCursor(cursors.cursor)
			ranImg = sprites.random[math.random(1,5)]
		else
			love.mouse.setCursor(cursors[tool])
		end
	end)
	ui.pendingText = ''
	ui.pendingBackspaces = 0
	mouse.pressed = false
end