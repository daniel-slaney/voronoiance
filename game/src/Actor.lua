--
-- src/Actor.lua
--

local Actor = {}
Actor.__index = Actor

local _nextId = 1

function Actor.new( symbol, ai )
	local id = _nextId
	_nextId = _nextId + 1

	local result = {
		id = id,
		symbol = symbol,
		ai = ai,
	}

	setmetatable(result, Actor)

	return result
end

return Actor
