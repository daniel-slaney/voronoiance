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

local function _wander( gameState, actor )
	local peers = gameState:peersOf(actor)

	if next(peers) then
		local target = table.random(peers)
		coroutine.yield(3, actions.move(gameState, actor, target))
	else
		coroutine.yield(3, actions.search(gameState, actor))
	end
end

function behaviours.wander( gameState, actor )
	while true do
		_wander(gameState, actor)
	end
end

function behaviours.simple( gameState, actor )
	local seen = false
	while not seen do
		local fov = gameState:fov(7)
		local loc = gameState:actorLocation(actor)

		if not fov[loc.vertex] then
			coroutine.yield(3, actions.search(gameState, actor))
		else
			seen = true
		end
	end

	while true do
		local player = gameState.player

		if not player then
			_wander(gameState, actor)
		else
			local playerVertex = gameState:actorLocation(player).vertex
			local djkstra = gameState:neighbourhoodOf(player)
			local source = gameState:actorLocation(actor).vertex

			if djkstra[source] == 1 then
				coroutine.yield(3, actions.melee(gameState, actor, playerVertex))
			else
				local peers = gameState:peersOf(actor)

				if next(peers) == nil then
					coroutine.yield(3, actions.search(gameState, actor))
				else
					local mindepth = math.huge
					for vertex in pairs(peers) do
						mindepth = math.min(mindepth, djkstra[vertex])
					end
					
					local candidates = {}
					for vertex in pairs(peers) do
						if djkstra[vertex] == mindepth then
							candidates[#candidates+1] = vertex
						end
					end

					assert(#candidates > 0)

					local target = candidates[math.random(1, #candidates)]
					coroutine.yield(3, actions.move(gameState, actor, target))
				end
			end
		end
	end
end

return behaviours
