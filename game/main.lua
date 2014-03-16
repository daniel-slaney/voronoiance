require 'jit'
print(jit.version)

math.randomseed(os.time())

-- All other lua files assume this is required before they are.
require 'prelude'

local genMachine = require 'mode'

print('_VERSION', _VERSION)

local machine
local splash
local SPLASH_DURATION = 4
local time = 0
local frames = 0
local keypressed = false
local help = false

local info  = {
	'Controls:',
	'  ?              : toggle this help',
	'  escape         : quit',
	'  m              : toggle map view',
	'  f              : toggle fast mode',
	'  w, k, numpad 8 : move north',
	'  e, u, numpad 9 : move north east',
	'  d, l, numpad 6 : move east',
	'  c, n, numpad 3 : move south east',
	'  s, j, numpad 2 : move south',
	'  z, b, numpad 1 : move south west',
	'  a, h, numpad 4 : move west',
	'  q, y, numpad 7 : move north west',
}

local function shadowf( x, y, ... )
	love.graphics.setColor(0, 0, 0, 255)

	local font = love.graphics.getFont()

	local text = string.format(...)

	local hh = font:getHeight() * 0.5
	local hw = font:getWidth(text) * 0.5

	local tx, ty = x, y

	love.graphics.print(text, tx-1, ty-1)
	love.graphics.print(text, tx-1, ty+1)
	love.graphics.print(text, tx+1, ty-1)
	love.graphics.print(text, tx+1, ty+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, tx, ty)
end

function love.load()
	gFont30 = love.graphics.newFont('resource/inconsolata.otf', 30)
	gFont15 = love.graphics.newFont('resource/inconsolata.otf', 15)
	splash = love.graphics.newImage('resource/splash.png')
	love.graphics.setFont(gFont30)
end

function love.update( dt )
	time = time + dt
	frames = frames + 1

	if not machine and (time >= SPLASH_DURATION * 0.5 or keypressed) then
		machine = genMachine('start')
	end

	if machine then
		machine:update(dt)
	end
end

function love.draw()
	if machine then
		machine:draw()
	end

	if time <= SPLASH_DURATION then
		local bias = time / SPLASH_DURATION

		local alpha = math.round(255 * math.sin(bias * math.pi))
		love.graphics.setColor(255, 255, 255, alpha)
		love.graphics.draw(splash)
	end

	if help then
		local x, y = 100, 100
		local gap = 30
		for i, line in ipairs(info) do
			shadowf(x, y+(gap*(i-1)), line)
		end
	end
end

function love.mousepressed( x, y, button )
	print('love.mousepressed', x, y, button)

	if machine then
		machine:mousepressed(x, y, button)
	end
end

function love.mousereleased( x, y, button )
	print('love.mousereleased', x, y, button)

	if machine then
		machine:mousereleased(x, y, button)
	end
end

function love.keypressed( key, isrepeat )
	printf('love.keypressed %s %s', key, tostring(isrepeat))

	keypressed = true

	if key == 'escape' then
		love.event.push('quit')
	elseif machine then
		machine:keypressed(key, isrepeat)
	end
end

function love.keyreleased( key )
	print('love.keyreleased', key)

	if machine then
		machine:keyreleased(key)
	end
end

function love.textinput( text )
	print('love.textinput', text)

	if text == '?' then
		help = not help
	end

	if machine then
		machine:textinput(text)
	end
end

function love.focus( f )
	print('love.focus', f)

	if machine then
		machine:focus(f)
	end
end

function love.mousefocus( f )
	print('love.mousefocus', f)

	if machine then
		machine:mousefocus(f)
	end
end

function love.visible( v )
	print('love.visible', v)

	if machine then
		machine:visible(v)
	end
end

-- TODO: add joystick and gamepad callbacks



