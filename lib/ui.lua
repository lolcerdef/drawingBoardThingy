local ui = {}
ui.activeSlider = nil
ui.activeTextBox = nil
ui.pendingText = ""
ui.pendingBackspaces = 0
ui.hasMouse = false
ui.canInput = true
ui.scrollValues = {}
local g = love.graphics

function ui.drawbox(x, y, w, h, col)
	local col = col or {1,1,1,1}
	local pw, ph = 72 * w, 72 * h
	
	if helpers.isInBox(mouse.x, mouse.y, x, y, pw, ph) then
		ui.hasMouse = true
	end
	
	g.setColor(col)
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
	if icon then
		g.draw(icon, x, y, 0, 2, 2)
	end
	
	if hovered and mouse.pressed and ui.canInput then
		helpers.play(sounds.click, math.random(10,20)/30)
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
	
	if mouse.lb and not ui.activeSlider and ui.canInput then
		local dx, dy = mouse.x - hx, mouse.y - y
		if dx * dx + dy * dy <= r * r then
			ui.activeSlider = id
			helpers.play(sounds.press, math.random(10,20)/30)
		end
	end
	
	if not mouse.lb and ui.activeSlider == id then
		ui.activeSlider = nil
		helpers.play(sounds.release, math.random(10,20)/30)
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

function ui.handleText(text)
	if ui.activeTextBox then
		ui.pendingText = ui.pendingText .. text
	end
end

function ui.handleKey(key)
	if not ui.activeTextBox then return end
	if key == "backspace" then
		ui.pendingBackspaces = ui.pendingBackspaces + 1
	elseif key == 'return' or key == 'kpenter' or key == 'escape' then
		ui.activeTextBox = nil
	end
end

function ui.textBox(val, x, y, w, h, allowedChars)
	local id = x .. "," .. y
	local hovered = helpers.isInBox(mouse.x, mouse.y, x, y, w, h)
	if hovered then ui.hasMouse = true end
	
	if mouse.pressed and ui.canInput then
		if hovered then
			ui.activeTextBox = id
			helpers.play(sounds.press, math.random(10,20)/30)
		elseif ui.activeTextBox == id then
			ui.activeTextBox = nil
			helpers.play(sounds.release, math.random(10,20)/30)
		end
	end
	
	local active = ui.activeTextBox == id
	if active then
		for _ = 1, ui.pendingBackspaces do
			local off = utf8.offset(val, -1)
			if off then val = val:sub(1, off - 1) end
		end
		for _, p in utf8.codes(ui.pendingText) do
			local c = utf8.char(p)
			if not allowedChars or c:match(allowedChars) then
				val =val .. c
			end
		end
	end
	
	local col = ui.canInput and {1,1,1,1} or {.7,.7,.7,1}
	g.setColor(col)
	g.rectangle('fill', x, y, w, h)
	g.setColor(0,0,0,1)
	g.setLineWidth(active and 4 or 2)
	g.rectangle('line', x, y, w, h)
	
	local font = g.getFont()
	local pad = 8
	local tw = font:getWidth(val)
	local offset = math.min(0, (w - pad * 2) - tw)
	g.setScissor(x + pad, y, w - pad * 2, h)
	g.print(val, x + pad + offset, y + (h - font:getHeight()) /2 + pad/2)
	if active and math.floor(love.timer.getTime() * 2) % 2== 0 then
		local cx = x + pad + offset + tw + 2
		g.line(cx, y +8, cx, y + h - 8)
	end
	g.setScissor()
	
	return val
end

function ui.scrollSpace(x, y, w, h, maxScroll, items)
	local hovered = helpers.isInBox(mouse.x, mouse.y, x, y, w, h)
	if hovered then ui.hasMouse = true end
	
	local id = x .. ',' .. y
	local s = ui.scrollValues[id]
	if not s then
		s = {scroll = 0, velo = 0}
		ui.scrollValues[id] = s
	end
	s.used = true
	
	if hovered and mouse.uiSc ~= 0 then
		s.velo = s.velo - mouse.uiSc * 8
	end
	s.scroll = helpers.clamp(s.scroll + s.velo, 0, maxScroll)
	if s.scroll == 0 or s.scroll == maxScroll then s.velo = 0 end
	s.velo = s.velo * 0.8
	if math.abs(s.velo) < 0.1 then s.velo = 0 end
	
	local mx, my = mouse.x, mouse.y
	if hovered or ui.activeSlider then
		mouse.x, mouse.y = mx - x, my - y + s.scroll
	else
		mouse.x, mouse.y = -1e6, -1e6
	end
	
	ui.drawbox(x,y,w/72,h/72)
	
	g.setScissor(x+4,y+4, w-8,h-8)
	g.push()
	g.translate(x,y-s.scroll)
	
	for _, i in ipairs(items or {}) do
		local p = i.params
		if i.type == 'button' then
			ui.button(unpack(p))
		elseif i.type == 'text' then
			g.setColor(i.color or {0,0,0,1})
			g.print(unpack(p))
		elseif i.type == 'slider' then
			local v = ui.slider(unpack(p))
			if i.onChange then i.onChange(v) end
		end
	end
	g.pop()
	g.setScissor()
	
	mouse.x,mouse.y = mx, my
end

function ui.cleanScrollValues()
	for id, v in pairs(ui.scrollValues) do
		if not v.used then
			ui.scrollValues[id] = nil
		end
		v.used = false
	end
end

return ui