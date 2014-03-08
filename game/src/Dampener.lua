--
-- lib/Dampener.lua
--
-- Simple object for interpolating scalar or vector values.
-- Charles Machin is the inspiration for it.
--

require 'Vector'

local Dampener = {}
Dampener.__index = Dampener

function Dampener.newf( value, target, bias )
	local result = {
		value = value,
		target = target,
		bias = bias,
	}

	setmetatable(result, Dampener)

	return result
end

function Dampener.newv( value, target, bias )
	local result = {
		value = { x = value.x, y = value.y },
		target = { x = target.x, y = target.y },
		bias = bias,
	}

	setmetatable(result, Dampener)

	return result
end

function Dampener:updatef( target )
	target = target or self.target

	self.value = self.value + self.bias * (target - self.value)

	return self.value
end

function Dampener:updatev( target )
	target = target or self.target

	local vtot = Vector.to(self.value, target)
	Vector.scale(vtot, self.bias)

	self.value.x = self.value.x + vtot.x
	self.value.y = self.value.y + vtot.y

	return self.value
end

return Dampener
