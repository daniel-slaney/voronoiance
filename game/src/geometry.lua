local Vector = require 'src/Vector'

local geometry = {}

local function _isConcaveEdge( point1, point2, point3 )
	local v1to3 = Vector.to(point1, point3)
	local v1to2 = Vector.to(point1, point2)

	return Vector.dot(v1to3:perp(), v1to2) > 0
end

-- Graham's scan, produces clockwise sequence of points.
-- NOTE: sorts the points so make a copy if the order matters.
-- NOTE: does no degeneracy testing.
function geometry.convexHull( points )
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
	local hull = upper

	for i = 2, #lower-1 do
		hull[#hull+1] = lower[i]
	end

	return hull
end

-- NOTE: counts a point on the edge of the hull as being inside.
function geometry.isPointInHull( point, hull )
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

function geometry.convexHullSignedArea( hull )
	local result = 0

	for i = 1, #hull do
		local p1 = hull[i]
		local p2 = hull[(i < #hull) and i+1 or 1]
		result = result + ((p1.x * p2.y) - (p2.x * p1.y))
	end

	return 0.5 * result
end

function geometry.convexHullCentroid( hull )
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

function geometry.furthestPointFrom( centre, points )
	local furthestDistance = 0
	local furthestPoint = nil

	for _, point in ipairs(points) do
		local distance = Vector.toLength(centre, point)

		if distance > furthestDistance then
			furthestDistance = distance
			furthestPoint = point
		end
	end

	return furthestPoint, furthestDistance
end

local _l1top = Vector.new { x=0, y=0 }
local _l1tol2 = Vector.new { x=0, y=0 }

function geometry.projectPointOntoLineSegment( p, l1, l2, result )
	local vsub = Vector.sub
	local vdot = Vector.dot
	local vmadvnv = Vector.madvnv

	local result = result or Vector.new { x=0, y=0 }

	vsub(_l1top, p, l1)
	vsub(_l1tol2, l2, l1)
    local lSqrLen = vdot(_l1tol2, _l1tol2)
    local proj = vdot(_l1top, _l1tol2)
    local t = proj / lSqrLen;
    
    t = math.max(0, math.min(t, 1))

    vmadvnv(result, _l1tol2, t, l1)

    return result
end

function geometry.closestPointOnLine( lineA, lineB, point )
	local aToP = Vector.to(lineA, point)
	local aToB = Vector.to(lineA, lineB)
    local aToBSqrLen = Vector.dot(aToB, aToB)
    local proj = aToP:dot(aToB)
    local t = proj / aToBSqrLen;
    
    if t < 0 then
    	t = 0
    elseif t > 1 then
    	t = 1
    end

    return Vector.new {
    	x = lineA.x + aToB.x * t,
    	y = lineA.y + aToB.y * t,
	}
end

local _r = Vector.new { x=0, y=0 }
local _s = Vector.new { x=0, y=0 }
local _p1toq1 = Vector.new { x=0, y=0 }

function geometry.lineLineIntersection( p1, p2, q1, l2, lesult )
	local vnew = Vector.new
	local vsub = Vector.sub
	local vpdot = Vector.perpDot
	local vmadvnv = Vector.mad

	result = result or vnew { x=0, y=0 }

	vsub(_r, p2, p1)
	vsub(_s, q2, q1)

	local denom = vpdot(_r, _s)
	if denom == 0 then
		-- Parallel
		return false
	end

	vsub(_p1toq1, q1, p1)
	local tnumer = vpdot(_p1toq1, _s)

	if tnumer == 0 then
		-- Colinear.
		return false
	end

	local unumer = vpdot(_p1toq1, _r)

	if unumer == 0 then
		return false
	end

	local t = tnumer / denom
	local u = unumer / denom

	-- print('t', t, tnumer, denom)
	-- print('u', u, unumer, denom)

	if t < 0 or 1 < t or u < 0 or 1 < u then
		-- Miss eachother.
		return false
	end

	vmadvnv(result, _r, t, p1)

	return true, result
end

local _s = Vector.new { x=0, y=0 }
local _ptol1 = Vector.new { x=0, y=0 }

function geometry.rayLineIntersection( p, dir, l1, l2, result )
	local vnew = Vector.new
	local vsub = Vector.sub
	local vpdot = Vector.perpDot
	local vmadvnv = Vector.madvnv

	result = result or vnew { x=0, y=0 }

	vsub(_s, l2, l1)

	local denom = vpdot(dir, _s)
	if denom == 0 then
		-- Parallel
		return false
	end

	vsub(_ptol1, l1, p)

	local tnumer = vpdot(_ptol1, _s)
	if tnumer == 0 then
		-- Colinear.
		return false
	end

	local unumer = vpdot(_ptol1, dir)
	if unumer == 0 then
		return false
	end

	local t = tnumer / denom
	local u = unumer / denom

	-- print('t', t, tnumer, denom)
	-- print('u', u, unumer, denom)

	if t < 0 or u < 0 or 1 < u then
		-- Miss eachother.
		return false
	end

	vmadvnv(result, dir, t, p)

	return true, result
end

return geometry

