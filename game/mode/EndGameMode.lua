--
-- mode/EndGameMode.lua
--

local schema, EndGameMode, GameMode = require 'src/mode' { 'EndGameMode', 'GameMode' }

function EndGameMode:enter( reason )
	printf('EndGameMode:enter(%s)', reason)

	self.won = reason == 'won'
	self.time = 0
	self.cancelTime = 2.5
end

function EndGameMode:update( dt )
	self.time = self.time + dt
end

local function shadowf( x, y, ... )
	love.graphics.setColor(0, 0, 0, 255)

	local font = love.graphics.getFont()
	local text = string.format(...)

	local hh = font:getHeight() * 0.5
	local hw = font:getWidth(text) * 0.5

	local tx = x - hw
	local ty = y - hh

	love.graphics.print(text, tx-1, ty-1)
	love.graphics.print(text, tx-1, ty+1)
	love.graphics.print(text, tx+1, ty-1)
	love.graphics.print(text, tx+1, ty+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, tx, ty)
end

function EndGameMode:draw()
	local sw, sh = love.graphics.getDimensions()
	local hw, hh = sw * 0.5, sh * 0.5

	if self.won then
		shadowf(hw, hh, 'Congratulations you WON!')
	else
		shadowf(hw, hh, 'Congratulations you Died!')
	end

	if self.time >= self.cancelTime then
		shadowf(hw, hh+50, 'Press any key to restart')
	end
end

function EndGameMode:keypressed( key, is_repeat )
	if self.time >= self.cancelTime then
		self:become(GameMode, 'restart')
	end
end

