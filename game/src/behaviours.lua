--
-- src/behaviours.lua
--

local Vector = require 'src/Vector'
local actions = require 'src/actions'

local behaviours = {}

local normal = 2

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
	local dof = gameState:occludedDijkstraMap(actor, 1)

	if next(dof) then
		local target = table.random(dof)
		coroutine.yield(actor.movecost, actions.move(gameState, actor, target))
	else
		coroutine.yield(normal, actions.search(gameState, actor))
	end
end

function behaviours.wander( gameState, actor )
	while true do
		_wander(gameState, actor)
	end
end

function behaviours.slug( gameState, actor )
	while true do
		local dof = gameState:occludedDijkstraMap(actor, 1)

		if next(dof) then
			local target = table.random(dof)
			coroutine.yield(actor.movecost, actions.slugmove(gameState, actor, target))
		else
			coroutine.yield(normal, actions.search(gameState, actor))
		end
	end
end

local function _approach( gameState, dijkstra, actor )
	local dof = gameState:occludedDijkstraMap(actor, 1)
	local loc = gameState:actorLocation(actor)

	if next(dof) == nil then
		return nil
	else
		local mindepth = math.huge
		for vertex in pairs(dof) do
			mindepth = math.min(mindepth, dijkstra[vertex])
		end
		
		local candidates = {}
		for vertex in pairs(dof) do
			if dijkstra[vertex] == mindepth then
				candidates[#candidates+1] = vertex
			end
		end

		assert(#candidates > 0)

		local target = candidates[math.random(1, #candidates)]
		return target
	end
end

function behaviours.simple( gameState, actor )
	local seen = false
	while not seen do
		local fov = gameState:fov(7)
		local loc = gameState:actorLocation(actor)

		if not fov[loc.vertex] then
			coroutine.yield(normal, actions.search(gameState, actor))
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
			local dijkstra = gameState:dijkstraMap(player)
			local source = gameState:actorLocation(actor).vertex

			if dijkstra[source] == 1 then
				coroutine.yield(normal, actions.melee(gameState, actor, playerVertex))
			else
				local dof = gameState:occludedDijkstraMap(actor, 1)
				local loc = gameState:actorLocation(actor)
				for target in pairs(dof) do
					assert(not gameState:actorAt(loc.layer, target))
				end
				if next(dof) == nil then
					coroutine.yield(normal, actions.search(gameState, actor))
				else
					local mindepth = math.huge
					for vertex, distance in pairs(dof) do
						mindepth = math.min(mindepth, dijkstra[vertex])
					end
					
					local candidates = {}
					for vertex in pairs(dof) do
						if dijkstra[vertex] == mindepth then
							candidates[#candidates+1] = vertex
						end
					end

					assert(#candidates > 0)

					local target = candidates[math.random(1, #candidates)]
					coroutine.yield(actor.movecost, actions.move(gameState, actor, target))
				end
			end
		end
	end
end

function behaviours.slime( gameState, actor )
	while actor.stickiness > 0 do
		local alpha = math.round(lerpf(actor.stickiness, 0, 5, 0, 255))
		local colour = actor.fx.colour
		local newcolour = { colour[1], colour[2], colour[3], alpha }
		actor.fx.colour = newcolour

		coroutine.yield(normal, actions.null())
		actor.stickiness = actor.stickiness - 1
	end
	coroutine.yield(normal, actions.kill(gameState, actor))
end

function behaviours.leaper( gameState, actor )
	while true do
		local player = gameState.player

		if not player then
			print('no player, is lonely')
			_wander(gameState, actor)
		else
			local dijkstra = gameState:dijkstraMap(player)
			local vertex = gameState:actorLocation(actor).vertex
			local targetVertex = gameState:actorLocation(player).vertex

			printf('player is %d steps away #%d', dijkstra[vertex] or math.huge, table.count(dijkstra))

			if (dijkstra[vertex] or math.huge) == 2 then
				local offset = Vector.new { x=0, y=0 }
				local apex = gameState.margin * 0.5
				local period = 0.25
				local function bounce( time )
					local bias = (time % period) / period
					offset.y = -apex * parabola(bias)

					return {
						fx = 'actor.offset',
						actor = actor,
						offset = offset
					}
				end
				actor:animate('bounce', bounce)
				coroutine.yield(normal, actions.null())
				actor:animate('bounce')
				coroutine.yield(normal, actions.leap(gameState, actor, targetVertex))
			else
				_wander(gameState, actor)
			end
		end
	end
end

function behaviours.bomb( gameState, actor )
	coroutine.yield(normal, actions.null())

	return normal, actions.explode(gameState, actor)
end

function behaviours.bomber( gameState, actor )
	local cooldown = 1
	while true do
		cooldown = cooldown - 1

		local player = gameState.player

		if not player then
			_wander(gameState, actor)
		else
			local dijkstra = gameState:dijkstraMap(player)
			local vertex = gameState:actorLocation(actor).vertex
			local targetVertex = gameState:actorLocation(player).vertex

			local range = 2
			if dijkstra[vertex] <= range and cooldown <= 0 then
				local dof = gameState:occludedDijkstraMap(player, 1)

				if next(dof) == nil then
					_wander(gameState, actor)
				else
					local peers = gameState:occludedDijkstraMap(actor, 1)
					local candidates = {}

					for vertex in pairs(dof) do
						if not peers[vertex] then
							candidates[#candidates+1] = vertex
						end
					end

					if #candidates > 0 then
						local target = table.random(dof)

						coroutine.yield(normal, actions.throw(gameState, actor, target, 'bomb', '*'))
						cooldown = 4
					else
						_wander(gameState, actor)	
					end
				end
			else
				local target = _approach(gameState, dijkstra, actor)

				if not target then
					coroutine.yield(normal, actions.search(gameState, actor))
				else
					coroutine.yield(actor.movecost, actions.move(gameState, actor, target))
				end
			end
		end
	end
end

for behaviour in pairs(behaviours) do
	printf('behaviour: %s', behaviour)
end

return behaviours
