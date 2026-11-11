local svg = {}
local dbd = {}
local png = {}

local function hex(r, g, b, a)
	local r255 = math.floor(r * 255 + 0.5)
	local g255 = math.floor(g * 255 + 0.5)
	local b255 = math.floor(b * 255 + 0.5)
	local a255 = math.floor(a * 255 + 0.5)
	return string.format("#%02X%02X%02X%02X", r255, g255, b255, a255)
end
--svg

function svg.ecStroke(s)
	local points = {}
	for i = 1, #s.points, 2 do
		points[#points + 1] = s.points[i] .. "," .. s.points[i + 1]
	end
	local col = hex(s.color[1], s.color[2], s.color[3], s.color[4])
	
	return string.format(
		'<polyline points="%s" fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="%s" stroke="%s"/>',
		table.concat(points, " "),
		s.width,
		col
	)
end

function svg.ecLayer(l, n)
	local res = { '<g id="', n, '">' }
	for _, s in ipairs(l) do
		res[#res + 1] = svg.ecStroke(s)
	end
	res[#res + 1] = '</g>'
	return table.concat(res)
end

function svg.export(t, n)
	local res = { '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg">' }
	for i, l in ipairs(t) do
		res[#res + 1] = svg.ecLayer(l, i)
	end
	res[#res + 1] = '</svg>'
	love.filesystem.write(n or "export.svg", table.concat(res))
end


--dbd
-- 0 is stroke

function dbd.ecStroke(s)
	return string.format("0 %s %s %s|", s.width, table.concat(s.color, " "), table.concat(s.points, " "))
end

function dbd.ecLayer(l, i)
	local res = {i, "\n"}
	for _, s in ipairs(l) do
		res[#res + 1] = dbd.ecStroke(s)
	end
	res[#res + 1] = "\n"
	return table.concat(res)
end

function dbd.export(t, n)
	local res = {}
	for i, l in ipairs(t) do
		res[#res + 1] = dbd.ecLayer(l, i)
	end
	love.filesystem.write(n or "export.dbd", table.concat(res))
end


--png

function png.export(t)
	
end



local s = {
	svg = svg,
	dbd = dbd,
	png = png,
}
return s