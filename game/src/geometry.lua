local Vector = require 'src/Vector'

local geometry = {}



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

