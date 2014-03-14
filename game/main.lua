require 'jit'
print(jit.version)

-- All other lua files assume this is required before they are.
require 'prelude'

local genMachine = require 'mode'

print('_VERSION', _VERSION)

local machine
local splash
local SPLASH_DURATION = 4
local time = 0
local frames = 0

function love.load()
	gFont30 = love.graphics.newFont('resource/inconsolata.otf', 30)
	gFont15 = love.graphics.newFont('resource/inconsolata.otf', 15)
	splash = love.graphics.newImage('resource/splash.png')
	love.graphics.setFont(gFont30)
end

function love.update( dt )
	time = time + dt
	frames = frames + 1

	if machine then
		machine:update(dt)
	elseif time >= SPLASH_DURATION * 0.5 then
		machine = genMachine('start')
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



