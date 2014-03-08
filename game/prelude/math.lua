--
-- misc/math.lua
--
-- TODO: lerpf -> math.lerp
-- TODO: clampf -> math.clamp

function math.round( value )
	return math.floor(0.5 + value)
end

function math.sign( value )
	if value < 0 then
		return -1
	else
		return 1
	end
end

-- Not infinite or a NaN
function math.finite( value )
	return math.abs(value) ~= math.huge and value == value
end

local epsilon = 1 / 2^7

function lerpf( value, in0, in1, out0, out1 )
    -- This isn't just to avoid a divide by zero but also a catstrophic loss of precision.
	assertf(math.abs(in1 - in0) > epsilon, "lerp() - in bounds [%f..%f] are too close together", in0, in1)
	local normed = (value - in0) / (in1 - in0)
	local result = out0 + (normed * (out1 - out0))
	return result
end

function clampf( value, min, max )
	if value < min then
		return min
	elseif value > max then
		return max
	end

	return value
end

