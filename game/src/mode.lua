--
-- lib/mode.lua
--
-- A mode is a high-level state of the game that has love callbacks as events.
-- 

--[[

usage:

local schema, mode1, mode2, .., modeN = require 'lib/mode' { 'mode1', 'mode2', ..., 'modeN' }

local state = require 'lib/state'
local schema, MainMode = require 'lib/mode' { 'MainMode' }

local machine = state.machine(schema, MainMode, ...)


--]]

local state = require 'src/state'

local schema = state.schema {
	draw = true,
	focus = true,
	keypressed = true,
	keyreleased = true,
	mousepressed = true,
	mousereleased = true,
	update = true,
	textinput = true,
	joystickpressed = true,
	joystickreleased = true,
	joystickaxis = true,
	joystickhat = true,
	gamepadpressed = true,
	gamepadreleased = true,
	gamepadaxis = true,
	joystickadded = true,
	joystickremoved = true,
	mousefocus = true,
	visible = true,
}

local modes = {}

local function export( names )
	local result = {}

	for i, name in ipairs(names) do
		local mode = modes[name]

		if not mode then
			mode = state.state(schema, name)
			modes[name] = mode
		end

		result[#result+1] = mode
	end

	return schema, unpack(result)
end

return export

