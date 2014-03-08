require 'jit'
print(jit.version)

-- All other lua files assume this is required before they are.
require 'prelude'

local genMachine = require 'mode'

print('_VERSION', _VERSION)

local machine

function love.load()
	gFont30 = love.graphics.newFont('resource/inconsolata.otf', 30)
	gFont15 = love.graphics.newFont('resource/inconsolata.otf', 15)
	love.graphics.setFont(gFont30)

	machine = genMachine()
end

function love.update( dt )
	machine:update(dt)
end

function love.draw()
	machine:draw()
end

function love.mousepressed( x, y, button )
	print('love.mousepressed', x, y, button)

	machine:mousepressed(x, y, button)
end

function love.mousereleased( x, y, button )
	print('love.mousereleased', x, y, button)

	machine:mousereleased(x, y, button)
end

function love.keypressed( key, isrepeat )
	printf('love.keypressed %s %s', key, tostring(isrepeat))

	if key == 'escape' then
		love.event.push('quit')
	else
		machine:keypressed(key, isrepeat)
	end
end

function love.keyreleased( key )
	print('love.keyreleased', key)

	machine:keyreleased(key)
end

function love.textinput( text )
	print('love.textinput', text)

	machine:textinput(text)
end

function love.focus( f )
	print('love.focus', f)

	machine:focus(f)
end

function love.mousefocus( f )
	print('love.mousefocus', f)

	machine:mousefocus(f)
end

function love.visible( v )
	print('love.visible', v)

	machine:visible(v)
end

-- TODO: add joystick and gamepad callbacks



