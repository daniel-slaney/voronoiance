--
-- mode/init.lua
--

local state = require 'src/state'
require 'mode/ShadowMode'
require 'mode/LevelMode'
local schema, init = require 'src/mode' { 'LevelMode' }

local function export()
	return state.machine(schema, init)
end

return export

