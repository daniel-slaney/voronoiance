--
-- src/render.lua
--

local function clock( x, y, radius, theta )
	local r = radius * 0.8
	local rx = x + (r * math.sin(theta))
	local ry = y + (r * math.cos(theta))

	love.graphics.push()
	
	love.graphics.setLineWidth(6)
	-- love.graphics.setColor(255, 255, 255, 255)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.circle('line', x, y, radius)
	love.graphics.line(x, y, rx, ry)

	love.graphics.setLineWidth(3)
	-- love.graphics.setColor(0, 0, 0, 255)
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.circle('line', x, y, radius)
	love.graphics.line(x, y, rx, ry)	

	love.graphics.pop()
end


return {
	clock = clock
}
