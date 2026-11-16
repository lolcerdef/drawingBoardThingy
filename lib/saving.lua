local svg = {}
local dbd = {}
local png = {}

local function hex(r, g, b)
	local r255 = math.floor(r * 255 + 0.5)
	local g255 = math.floor(g * 255 + 0.5)
	local b255 = math.floor(b * 255 + 0.5)
	return string.format("#%02X%02X%02X", r255, g255, b255)
end

local function fwrite(name, data)
	local ok, err = love.filesystem.write(name, data)
	if not ok then return false, err end
	return true
end

local function bounds(t)
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	local found = false
	for _, l in ipairs(t) do
		for _, st in ipairs(l) do
			if st.type == 'line' and #st.points >= 2 then
				local r = (st.width or 0) / 2
				for i = 1, #st.points - 1, 2 do
					local x, y = st.points[i], st.points[i+1]
					if x - r < x0 then x0 = x - r end
					if y - r < y0 then y0 = y - r end
					if x + r > x1 then x1 = x + r end
					if y + r > y1 then y1 = y + r end
					found = true
				end
			end
		end
	end
	if not found then return nil end
	return { x0 = math.floor(x0), y0 = math.floor(y0), x1 = math.ceil(x1), y1 = math.ceil(y1), }
end

--svg

function svg.ecStroke(s)
	local points = {}
	for i = 1, #s.points - 1, 2 do
		points[#points + 1] = s.points[i] .. "," .. s.points[i + 1]
	end
	local col = hex(s.color[1], s.color[2], s.color[3])
	
	return string.format(
		'<polyline points="%s" fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="%s" stroke="%s" stroke-opacity="%s"/>',
		table.concat(points, " "),
		s.width,
		col,
		s.color[4]
	)
end

function svg.ecLayer(l, n)
	local res = { '<g id="layer', n, '">' }
	for _, s in ipairs(l) do
		if s.type == 'line' then
			res[#res + 1] = svg.ecStroke(s)
		end
	end
	res[#res + 1] = '</g>'
	return table.concat(res)
end

function svg.export(t, n)
	local b = bounds(t)
	if not b then return false, 'Nothing to export' end
	local res = { string.format(
		'<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%s" height="%s">',
		b.x0, b.y0, b.x1 - b.x0, b.y1 - b.y0, b.x1 - b.x0, b.y1 - b.y0
	) }
	for i, l in ipairs(t) do
		res[#res + 1] = svg.ecLayer(l, i)
	end
	res[#res + 1] = '</svg>'
	return fwrite(n or "export.svg", table.concat(res))
end


--dbd
-- 0 is stroke
-- file layout:
-- <layer number>
-- 0 width r g b a x y x y ...|0 width ...|
-- <blank line>

function dbd.ecStroke(s)
	return string.format("0 %s %s %s|", s.width, table.concat(s.color, " "), table.concat(s.points, " "))
end

function dbd.ecLayer(l, i)
	local res = {i, "\n"}
	for _, s in ipairs(l) do
		if s.type == 'line' and #s.points >= 2 then
			res[#res + 1] = dbd.ecStroke(s)
		end
	end
	res[#res + 1] = "\n"
	return table.concat(res)
end

function dbd.export(t, n)
	local res = {}
	for i, l in ipairs(t) do
		res[#res + 1] = dbd.ecLayer(l, i)
	end
	return fwrite(n or "export.dbd", table.concat(res))
end

function dbd.decode(str)
	local res, cur = {}, nil
	for line in ((str:gsub('\r', '')) .. '\n'):gmatch('([^\n]*)\n') do
		if line:match('^%s*%d+%s*$') then
			cur = {}
			res[#res + 1] = cur
		else
			for chunk in line:gmatch('[^|]+') do
				local nums = {}
				for tok in chunk:gmatch('%S+') do
					local v = tonumber(tok)
					if not v then error('bad number: ' .. tok) end
					nums[#nums + 1] = v
				end
				if nums[1] == 0 and #nums >= 6 then
					if not cur then
						cur = {}
						res[#res + 1] = cur
					end
					local pts = {}
					for i = 7, #nums do pts[#pts + 1] = nums[i] end
					if #pts % 2 == 1 then pts[#pts] = nil end
					cur[#cur + 1] = {
						type = 'line',
						width = nums[2],
						color = { nums[3], nums[4], nums[5], nums[6] },
						points = pts,
					}
				end
			end
		end
	end
	if #res == 0 then res[1] = {} end
	return res
end

function dbd.import(n)
	local data, err = love.filesystem.read(n)
	if not data then return nil, err or 'File not found' end
	local ok, res = pcall(dbd.decode, data)
	if not ok then return nil, res end
	return res
end

--png
-- need to add m,ore options for png exporting
local function drawStroke(st)
	local pts = st.points
	if #pts % 2 == 1 or #pts == 0 then return end
	love.graphics.setColor(st.color)
	if #pts >= 4 then
		love.graphics.setLineWidth(st.width)
		love.graphics.line(pts)
	end
	love.graphics.circle('fill', pts[1], pts[2], st.width / 2)
	love.graphics.circle('fill', pts[#pts - 1], pts[#pts], st.width / 2)
end

function png.export(t, n, scale)
	local b = bounds(t)
	if not b then return false, 'Nothing to export' end
	
	scale = scale or 1
	local w, h = b.x1 - b.x0, b.y1 - b.y0
	local limit = love.graphics.getSystemLimits().texturesize
	scale = math.min(scale, limit/w, limit/h)
	local pw, ph = math.max(1, math.floor(w * scale)), math.max(1, math.floor(h*scale))
	
	local ok, canvas = pcall(love.graphics.newCanvas, pw, ph, {msaa = 4})
	if not ok then 
		ok, canvas = pcall(love.graphics.newCanvas, pw, ph)
		if not ok then return false, 'Could not create canvas: ' .. tostring(canvas) end
	end
	
	love.graphics.push('all')
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0,0,0,0)
	love.graphics.setBlendMode('alpha', 'alphamultiply')
	love.graphics.setLineJoin('bevel')
	love.graphics.setLineStyle('smooth')
	love.graphics.scale(scale)
	love.graphics.translate(-b.x0, -b.y0)
	for _, l in ipairs(t) do
		for _, st in ipairs(l) do
			if st.type == 'line' then drawStroke(st) end
		end
	end
	love.graphics.setCanvas()
	love.graphics.pop()
	
	local data
	if canvas.newImageData then
		data = canvas:newImageData() -- LÖVE 11
	end
	
	local ok2, err = pcall(data.encode, data, 'png', n or 'export.png')
	if not ok2 then return false, err end
	return true
end



local s = {
	svg = svg,
	dbd = dbd,
	png = png,
}
return s