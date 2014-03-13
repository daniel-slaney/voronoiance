--
-- GameState.lua
--

local Level = require 'src/Level'
local Actor = require 'src/Actor'
local roomgen = require 'src/roomgen'

local Layer = {
	SURFACE = 'SURFACE',
	CRITTER = 'CRITTER',
}

local GameState = {
	Layer = Layer,
}
GameState.__index = GameState
local Layer = GameState.Layer

function GameState.new()
	local genfunc = roomgen.random
	local margin = 40
	local extents = {
		width = {
			min = margin * 5,
			max = margin * 10,
		},
		height = {
			min = margin * 5,
			max = margin * 10,
		},
	}
	local numRooms = 10

	local level = Level.new(numRooms, genfunc, extents, margin)
	
	-- { [actor] = { layer=Layer, vertex=vertex } }*
	local locations = {}
	-- { [layer] = {[vertex] = actor}* }*
	local overlays = {}
	for layer in pairs(Layer) do
		overlays[layer] = {}
	end

	local result = {
		margin = margin,
		level = level,
		locations = locations,
		overlays = overlays,
		queue = {}
	}

	setmetatable(result, GameState)

	return result
end

function GameState:randomWalkableVertex()
	return table.random(self.level.walkable.vertices)
end

function GameState:spawn( layer, vertex, actor )
	assert(Layer[layer])
	assert(self.level.walkable.vertices[vertex])
	local locations = self.locations
	local overlay = self.overlays[layer]
	assert(not overlay[target])

	locations[actor] = {
		layer = layer,
		vertex = vertex,
	}
	overlay[vertex] = actor
	local queue = self.queue
	queue[#queue+1] = {
		actor = actor,
		cost = 0
	}
end

function GameState:actorLocation( actor )
	return self.locations[actor]
end

function GameState:actorAt( layer, vertex )
	return self.overlays[layer][vertex]
end

function GameState:peersOf( actor )
	local location = self.locations[actor]
	assert(location)
	local overlay = self.overlays[location.layer]

	local peers = self.level.walkable.vertices[location.vertex]

	local result = {}

	for vertex, edge in pairs(peers) do
		if not overlay[vertex] then
			result[vertex] = true
		end
	end

	return result
end

function GameState:neighbourhoodOf( actor, depth )
	local loc = self.locations[actor]
	return self.level.graph:distanceMap(loc.vertex, depth)
end

function GameState:nextAction()
	local queue = self.queue

	if #queue < 1 then
		return nil
	end

	table.sort(queue,
		function ( lhs, rhs )
			if lhs.cost ~= rhs.cost then
				return lhs.cost < rhs.cost
			else
				return lhs.actor.id < rhs.actor.id
			end
		end)

	local result = {}
	local surplus = queue[1].cost

	-- Skip forward in time if we have to...
	if surplus > 0 then
		for _, item in ipairs(queue) do
			item.cost = item.cost - surplus
		end
	end

	local cost, actor = queue[1].cost, queue[1].actor
	local newcost, action = actor.behaviour(self, actor)
	-- only costless calls can have nil actions
	assert(cost == 0 or action ~= nil)
	queue[1].cost = newcost

	return action
end

-- The target vertex must be unoccupied.
function GameState:move( actor, targetVertex )
	local location = self.locations[actor]
	assert(location)
	assert(self.level.walkable.vertices[targetVertex])
	assert(not self:actorAt(location.layer, targetVertex))
	
	local overlay = self.overlays[location.layer]
	overlay[location.vertex] = nil
	overlay[targetVertex] = actor
	location.vertex = targetVertex
end

function GameState:kill( actor )
	assert(self.locations[actor])
	local on_die = actor.on_die
	if on_die then
		on_die(self, actor)
	end

	local locations = self.locations
	local loc = locations[actor]
	local overlay = self.overlays[loc.layer]
	overlay[loc.vertex] = nil
	locations[actor] = nil

	local queue = self.queue
	for i = 1, #queue do
		if queue[i].actor == actor then
			table.remove(queue, i)
			break
		end
	end

	assert(not self:actorAt(loc.layer, loc.vertex))
end

return GameState
