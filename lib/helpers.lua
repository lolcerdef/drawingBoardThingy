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

return helpers