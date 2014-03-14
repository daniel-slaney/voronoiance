--
-- mode/init.lua
--

local state = require 'src/state'
require 'mode/ShadowMode'
require 'mode/LevelMode'
require 'mode/GameMode'
require 'mode/EndGameMode'
local schema, init = require 'src/mode' { 'GameMode' }

local function export( ... )
	return state.machine(schema, init, ...)
end

return export

