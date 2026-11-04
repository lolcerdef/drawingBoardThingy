local helpers = {}

function helpers.copyTable(tbl, shallow, dp, maxDp)
	local maxDp = maxDp or 10
	if dp == nil then
		dp = 0
	end
	local newtable = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" and dp < maxDp and not shallow then
			newtable[k] = helpers.copyTable(v, shallow, dp + 1, maxDp)
		else
			newtable[k] = v
		end
	end
	return newtable
end

function helpers.clamp(v, low, up)
	if low > up then low, up = up, low end
	return math.max(low, math.min(up, v))
end

function helpers.isInBox(x,y, bx, by, bw, bh)
	return (bx < x and (bx+bw) > x) and (by < y and (by+bh) > y)
end

function helpers.dottedCirc(cx, cy, r, numDots, dotRad)
	local step = (2 * math.pi) / numDots
	dotRad = dotRad or 3
	
	for i = 0, numDots - 1 do
		local angle = i * step
		local x = cx + r * math.cos(angle)
		local y = cy + r * math.sin(angle)
		love.graphics.circle("fill", x, y, dotRad)
	end
end

function helpers.distToSeg(px, py, x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local lenSq = dx^2 + dy^2
	local t = 0
	if lenSq > 0 then
		t = ((px-x1) * dx + (py - y1) * dy) / lenSq
		t = helpers.clamp(t, 0, 1)
	end
	local cx, cy = x1 + t*dx, y1 + t*dy
	return math.sqrt((px-cx)^2 + (py-cy)^2)
end

function helpers.eraseFromStroke(stroke, cx, cy, radius)
	local pts = stroke.points
	local n = #pts - (#pts % 2)
	local r = radius + stroke.width / 2
	
	if n == 0 then return {} end
	
	-- a dot
	if n == 2 then
		local d = math.sqrt((pts[1]-cx)^2 + (pts[2]-cy)^2)
		if d <= r then return {} else return {stroke} end
	end
	
	local result = {}
	local run = {}
	local hitAnything = false
	
	local function flush()
		if #run >= 4 then
			table.insert(result, {
				type = 'line',
				width = stroke.width,
				color = stroke.color,
				points = run
			})
		end
		run = {}
	end
	
	for i = 1, n - 3, 2 do
		local x1, y1, x2, y2 = pts[i], pts[i+1], pts[i+2], pts[i+3]
		local dx, dy = x2 - x1, y2 - y1
		local fx, fy = x1 - cx, y1 - cy
		local a = dx*dx + dy*dy
		local c = fx*fx + fy*fy - r*r
		
		-- find part that is in circle
		local ta, tb
		if a == 0 then
			if c <= 0 then ta, tb = 0, 1 end
		else
			local b = 2 * (fx*dx + fy*dy)
			local disc = b*b - 4*a*c
			if disc > 0 then
				local sq = math.sqrt(disc)
				local t1, t2 = (-b - sq) / (2*a), (-b + sq) / (2*a)
				if t1 < 1 and t2 > 0 then
					ta, tb = math.max(t1, 0), math.min(t2, 1)
				end
			end
		end
		
		if not ta then
			-- untouched
			if #run == 0 then
				table.insert(run, x1)
				table.insert(run, y1)
			end
			table.insert(run, x2)
			table.insert(run, y2)
		else
			hitAnything = true
			if ta > 0 then
				-- before cut
				if #run == 0 then
					table.insert(run, x1)
					table.insert(run, y1)
				end
				table.insert(run, x1 + ta * dx)
				table.insert(run, y1 + ta * dy)
			end
			flush()
			if tb < 1 then
				-- after cut
				table.insert(run, x1 + tb * dx)
				table.insert(run, y1 + tb * dy)
				table.insert(run, x2)
				table.insert(run, y2)
			end
		end
	end
	flush()
	
	if not hitAnything then return {stroke} end
	return result
end

function helpers.play(snd, vol)
	snd:setVolume(vol)
	snd:play()
end

return helpers