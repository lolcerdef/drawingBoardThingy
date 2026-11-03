local ui = {}
ui.activeSlider = nil
ui.hasMouse = false
local g = love.graphics

function ui.drawbox(x, y, w, h, col)
	local col = col or {1,1,1,1}
	local pw, ph = 72 * w, 72 * h
	
	if helpers.isInBox(mouse.x, mouse.y, x, y, pw, ph) then
		ui.hasMouse = true
	end
	
	g.draw(sprites.ui.boxMid, x + 72, y + 72, 0, 2*(w-2), 2*(h-2))
	g.draw(sprites.ui.boxEdge, x + 72, y, 0, 2*(w-2),  2)
	g.draw(sprites.ui.boxEdge, x + 72, y + ph, 0, 2*(w-2), -2)
	g.draw(sprites.ui.boxEdge, x, y + 72, math.pi / 2, 2*(h-2), -2)
	g.draw(sprites.ui.boxEdge, x + pw, y + 72, math.pi / 2, 2*(h-2),  2)
	g.draw(sprites.ui.boxCorner, x, y, 0,  2, 2)
	g.draw(sprites.ui.boxCorner, x + pw, y, 0, -2, 2)
	g.draw(sprites.ui.boxCorner, x, y + ph, 0, 2, -2)
	g.draw(sprites.ui.boxCorner, x + pw, y + ph,  0, -2, -2)
end

function ui.button(x, y, col, icon, icCol, func)
	local col = col or {1,1,1,1}
	local icCol = icCol or {1,1,1,1}
	local hovered = helpers.isInBox(mouse.x, mouse.y, x, y, 64, 64)
	if hovered then
		ui.hasMouse = true
		y = y - 4
	end
	
	g.setColor(col)
	g.draw(sprites.ui.buttonEmpty, x, y, 0, 2, 2)
	g.setColor(icCol)
	g.draw(icon, x, y, 0, 2, 2)
	
	if hovered and mouse.pressed then
		if func then
			func()
		end
		return true
	end
	return false
end

function ui.slider(val, min, max, x, y, r, w, l, handCol, col)
	local id = x .. "," .. y
	val = helpers.clamp(val, min, max)
	
	local t = (val-min) / (max - min)
	local hx = x + t * l
	
	local pad = math.max(r, w / 2)
	if ui.activeSlider == id
		or helpers.isInBox(mouse.x, mouse.y, x - r, y - pad, l + r * 2, pad * 2) then
		ui.hasMouse = true
	end
	
	if mouse.lb and not ui.activeSlider then
		local dx, dy = mouse.x - hx, mouse.y - y
		if dx * dx + dy * dy <= r * r then
			ui.activeSlider = id
		end
	end
	
	if not mouse.lb and ui.activeSlider == id then
		ui.activeSlider = nil
	end
	
	if ui.activeSlider == id then
		local nt = helpers.clamp((mouse.x - x) / l, 0, 1)
		val = min + nt * (max - min)
		hx = x + nt * l
	end
	
	local col = col or {0.8,0.8,0.8}
	local handCol = handCol or {1,1,1,1}
	g.setLineWidth(w)
	g.setColor(col)
	g.line(x, y, x + l, y)
	g.circle('fill', x, y, w/2)
	g.circle('fill', x + l, y, w/2)
	
	local s = (r * 2) / 16
	g.setColor(handCol)
	g.draw(sprites.ui.slider, hx, y, 0, s, s, 8, 8)
	
	return val
end

return ui