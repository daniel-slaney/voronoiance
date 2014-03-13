--
-- src/Actor.lua
--

local behaviours = require 'src/behaviours'

local Actor = {}
Actor.__index = Actor

local _nextId = 1

function Actor.new( symbol, behaviour, on_die )
	local id = _nextId
	_nextId = _nextId + 1

	local result = {
		id = id,
		symbol = symbol,
		behaviour = coroutine.wrap(behaviours[behaviour]),
		on_die = on_die
	}

	setmetatable(result, Actor)

	return result
end

return Actor
