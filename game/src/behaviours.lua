--
-- src/behaviours.lua
--

local Vector = require 'src/Vector'
local actions = require 'src/actions'

local behaviours = {}

function behaviours.player( gameState, actor )
	while true do
		local playerAction = gameState.playerAction
		if not playerAction then
			coroutine.yield(0, nil)
		else
			local cost = playerAction.cost
			local action = playerAction.action
			gameState.playerAction = nil
			coroutine.yield(cost, action)
		end
	end
end

function behaviours.wander( gameState, actor )
	while true do
		printf('wander')
		local peers = gameState:peersOf(actor)

		if next(peers) then
			local target = table.random(peers)
			coroutine.yield(3, actions.move(gameState, actor, target))
		else
			coroutine.yield(3, actions.search(gameState, actor))
		end
	end
end

return behaviours
