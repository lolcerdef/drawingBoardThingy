enet = require 'enet'

function love.load()
	helpers = require 'lib.helpers'
	tween = require 'lib.tween'
	love.graphics.setLineStyle('smooth')
	
	mouse = {
		lb = false,
		rb = false,
		mb = false,
		sc = 0,
		x = 0,
		y = 0,
		wx = 0,
		wy = 0,
	}
	pan = { x = 0, y = 0, worldDragPoint = nil }
	tool = 'brush'
	toolBuffer = {}
	startDrag = nil
	endDrag = nil
	size = 4
	layer = 1
	layers = {
		{}
	}
	--[[
	{ type: '', data: { stuff } }
	{ type: 'line', width: size, points: {points} }
	
	]]
end

function resetTool()
	toolBuffer = {}
	startDrag = nil
	endDrag = nil
end

function love.update(dt)
	--print(mouse.lb, mouse.rb, mouse.mb)
	--print(mouse.x, mouse.y, mouse.sc)
	mouse.wx, mouse.wy = mouse.x + pan.x, mouse.y + pan.y
	
	if tool == 'brush' then
		if mouse.lb then
			if startDrag then
				table.insert(toolBuffer, mouse.wx)
				table.insert(toolBuffer, mouse.wy)
			else
				startDrag = startDrag or {}
			end
		end
		
		if startDrag and not mouse.lb then
			local points = helpers.copyTable(toolBuffer)
			table.insert(layers[layer], { type = 'line', width = size, points = points })
			toolBuffer = {}
		end
	end
	
	if mouse.mb then
		
	end
	
	mouse.sc = 0
end

function love.mousepressed(x,y,b)
	mouse.lb = b == 1 or mouse.lb
	mouse.rb = b == 2 or mouse.rb
	mouse.mb = b == 3 or mouse.mb
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

function love.draw()
	love.graphics.clear(1,1,1,1)
	love.graphics.setColor(0,0,0,1)
	for _, l in ipairs(layers) do
		for _, d in ipairs(l) do
			if d.type == 'line' then
				if not (#d.points % 2) then goto skip end
				if #d.points >= 4 then
					love.graphics.setLineWidth(d.width)
					love.graphics.line(d.points)
				end
			end
			::skip::
		end
	end
	
end