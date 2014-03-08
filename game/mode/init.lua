--
-- mode/init.lua
--

local state = require 'src/state'
require 'mode/ShadowMode'
local schema, init = require 'src/mode' { 'ShadowMode' }

local function export()
	return state.machine(schema, init)
end

return export

