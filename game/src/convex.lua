--
-- src/convex.lua
--

local Vector = require 'src/Vector'

local function _isConcaveEdge( point1, point2, point3 )
	local v1to3 = Vector.to(point1, point3)
	local v1to2 = Vector.to(point1, point2)

	return Vector.dot(v1to3:perp(), v1to2) > 0
end

-- Graham's scan, produces clockwise sequence of points.
-- NOTE: sorts the points so make a copy if the order matters.
-- NOTE: does no degeneracy testing.
local function hull( points )
	-- Hulls don't make sense for points or lines.
	assert(#points > 2)

	table.sort(points,
		function ( lhs, rhs )
			if lhs.x == rhs.x then
				return lhs.y < rhs.y
			else
				return lhs.x < rhs.x
			end
		end)

	if #points == 3 then
		-- Ensure clockwise ordering.
		if points[2].y < points[3].y then
			points[2], points[3] = points[3], points[2]
		end

		return points
	end

	-- Create upper hull.
	local upper = { points[1], points[2] }
	for index= 3, #points do
		upper[#upper+1] = points[index]
		while #upper > 2 and not _isConcaveEdge(upper[#upper-2], upper[#upper-1], upper[#upper]) do
			table.remove(upper, #upper-1)
		end
	end

	-- Create lower hull.
	local lower = { points[#points], points[#points-1] }
	for i = #points-2,1,-1 do
		lower[#lower+1] = points[i]
		while #lower > 2 and not _isConcaveEdge(lower[#lower-2], lower[#lower-1], lower[#lower]) do
			table.remove(lower, #lower-1)
		end
	end

	-- The hulls into one.
	local result = upper

	for i = 2, #lower-1 do
		result[#result+1] = lower[i]
	end

	return result
end

-- NOTE: counts a point on the edge of the hull as being inside.
local function contains( point, hull )
	local x, y = point.x, point.y

	for index = 1, #hull do
		local point1 = hull[index]
		local point2 = hull[(index < #hull) and index + 1 or 1]

		local x1, y1 = point1.x, point1.y
		local x2, y2 = point2.x, point2.y

		local r = (y-y1)*(x2-x1)-(x-x1)*(y2-y1)
		
		if r == 0 then
			return true
		end

		if r > 0 then
			return false
		end
	end

	return true
end

local function signedArea( hull )
	local result = 0

	for i = 1, #hull do
		local p1 = hull[i]
		local p2 = hull[(i < #hull) and i+1 or 1]
		result = result + ((p1.x * p2.y) - (p2.x * p1.y))
	end

	return 0.5 * result
end

local function centroid( hull )
	local signedArea = 0
	local cx = 0
	local cy = 0

	for i = 1, #hull do
		local p1 = hull[i]
		local p2 = hull[(i < #hull) and i+1 or 1]

		local a = (p1.x * p2.y) - (p2.x * p1.y)
		signedArea = signedArea + a
		
		cx = cx + (p1.x + p2.x) * a
		cy = cy + (p1.y + p2.y) * a
	end
	
	signedArea = 0.5 * signedArea
	local factor = 1 / (6 * signedArea)

	return Vector.new { x = factor * cx, y = factor * cy }
end

-- SAT based convex hull collision test.
local function collides( hull1, hull2, offset1, offset2 )
	local vnorm = Vector.normalise
	local vadd = Vector.add
	local vsub = Vector.sub
	local vdot = Vector.dot
	local norm = Vector.new { x=0, y=0 }
	local disp = Vector.new { x=0, y=0 }
	local origin = Vector.new { x=0, y=0 }

	for i = 1, #hull1 do
		local p1 = hull1[i]
		local j = i+1
		local p2 = hull1[j <= #hull1 and j or 1]

		vsub(norm, p2, p1)
		vnorm(norm)

		vadd(origin, p1, offset1)

		local min1, max1 = math.huge, -math.huge

		for k = 1, #hull1 do
			vsub(disp, hull1[k], origin)
			local proj = vdot(norm, disp)

			min1 = math.min(min1, proj)
			max1 = math.max(max1, proj)
		end

		local min2, max2 = math.huge, -math.huge

		for k = 1, #hull2 do
			vsub(disp, hull2[k], origin)
			local proj = vdot(norm, disp)

			min2 = math.min(min2, proj)
			max2 = math.max(max2, proj)
		end

		if max1 < min2 or max2 < min1 then
			return false
		end
	end

	for i = 1, #hull2 do
		local p1 = hull2[i]
		local j = i+1
		local p2 = hull2[j <= #hull2 and j or 1]

		vsub(norm, p2, p1)
		vnorm(norm)

		vadd(origin, p1, offset1)

		local min1, max1 = math.huge, -math.huge

		for k = 1, #hull2 do
			vsub(disp, hull2[k], origin)
			local proj = vdot(norm, disp)

			min1 = math.min(min1, proj)
			max1 = math.max(max1, proj)
		end

		local min2, max2 = math.huge, -math.huge

		for k = 1, #hull1 do
			vsub(disp, hull1[k], origin)
			local proj = vdot(norm, disp)

			min2 = math.min(min2, proj)
			max2 = math.max(max2, proj)
		end

		if max1 < min2 or max2 < min1 then
			return false
		end
	end


	return true
end

return {
	hull = hull,
	contains = contains,
	signedArea = signedArea,
	centroid = centroid,
	collides = collides,
}
