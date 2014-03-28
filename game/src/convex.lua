--
-- src/convex.lua
--

local Vector = require 'src/Vector'

-- TODO: this could be more optimal garbage wise.
local function _isConcaveEdge( point1, point2, point3 )
	local v1to3 = Vector.to(point1, point3)
	local v1to2 = Vector.to(point1, point2)

	-- Use an epsilon instead of 0 to stop colinear edges being
	-- created for hulls.
	local epsilon = 1e-9
	return Vector.dot(v1to3:perp(), v1to2) > epsilon
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

local function fromLine( p1, p2, border )
	assert(border > 0)

	local normal = Vector.to(p1, p2):normalise()

	local perp = normal:perp()
	local corners = {
		Vector.new {
			x = p1.x + (border * perp.x) + (border * -normal.x),
			y = p1.y + (border * perp.y) + (border * -normal.y),
		},
		Vector.new {
			x = p1.x + (border * -perp.x) + (border * -normal.x),
			y = p1.y + (border * -perp.y) + (border * -normal.y),
		},
		Vector.new {
			x = p2.x + (border * perp.x) + (border * normal.x),
			y = p2.y + (border * perp.y) + (border * normal.y),
		},
		Vector.new {
			x = p2.x + (border * -perp.x) + (border * normal.x),
			y = p2.y + (border * -perp.y) + (border * normal.y),
		}
	}
	
	return hull(corners)
end

-- NOTE: counts a point on the edge of the hull as being inside.
local function contains( hull, point )
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
			vadd(disp, hull1[k], offset1)
			vsub(disp, disp, origin)
			local proj = vdot(norm, disp)

			min1 = math.min(min1, proj)
			max1 = math.max(max1, proj)
		end

		local min2, max2 = math.huge, -math.huge

		for k = 1, #hull2 do
			vadd(disp, hull2[k], offset2)
			vsub(disp, disp, origin)
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
		local p2 = hull2[i+1] or hull2[1]

		vsub(norm, p2, p1)
		vnorm(norm)

		vadd(origin, p1, offset2)

		local min1, max1 = math.huge, -math.huge

		for k = 1, #hull2 do
			vadd(disp, hull2[k], offset2)
			vsub(disp, disp, origin)
			local proj = vdot(norm, disp)

			min1 = math.min(min1, proj)
			max1 = math.max(max1, proj)
		end

		local min2, max2 = math.huge, -math.huge

		for k = 1, #hull1 do
			vadd(disp, hull1[k], offset1)
			vsub(disp, disp, origin)
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

-- mitre offset of a hull
local function offset( hull, amount )
	assert(amount > 0)


	local result = {}

	local dir = Vector.new { x=0, y=0 }
	local prevdir = Vector.new { x=0, y=0 }
	local vsub = Vector.sub
	local vnorm = Vector.normalise
    local vdot = Vector.dot

	for i = 1, #hull do
		local p1 = hull[i]
		local p2 = hull[i+1] or hull[1]

		vsub(dir, p2, p1)
		vnorm(dir)

		result[#result+1] = Vector.new {
			x = p1.x + amount * -dir.y,
			y = p1.y + amount * dir.x
		}
		result[#result+1] = Vector.new {
			x = p2.x + amount * -dir.y,
			y = p2.y + amount * dir.x
		}
	end

	for i = 1, #result do
		local p1 = result[i]
		local p2 = result[i+1] or result[1]

		assert(Vector.toLength(p1, p2) > 0)
	end

	return result
end

return {
	hull = hull,
	fromLine = fromLine,
	contains = contains,
	signedArea = signedArea,
	centroid = centroid,
	collides = collides,
	offset = offset
}
