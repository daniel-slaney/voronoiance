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
	local min = margin * 7
	local max = margin * 10
	local extents = {
		width = {
			min = min,
			max = max,
		},
		height = {
			min = min,
			max = max,
		},
	}
	local numRooms = 7

	local level = Level.new(numRooms, genfunc, extents, margin, true)
	
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
		queue = {},
		player = nil,
		playerAction = nil,
		seen = {},
		fovDepth = 7,
		turns = 0,
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

function GameState:spawnPlayer( layer, vertex, actor )
	assert(self.player == nil)
	self.player = actor
	self:spawn(layer, vertex, actor)
end

function GameState:actorLocation( actor )
	return self.locations[actor]
end

function GameState:actorAt( layer, vertex )
	return self.overlays[layer][vertex]
end

-- Returns a map { [vertex] = distance } of the walkable graph centred on the
-- supplied actor. Cells occupied by actors in the same layer as the supplied
-- actor.
--
-- If depth is not supplied it assume infinite depth.
function GameState:occludedDijkstraMap( actor, depth )
	depth = depth or math.huge
	local loc = self.locations[actor]
	local overlay = self.overlays[loc.layer]

	local function vertexFilter( vertex )
		return overlay[vertex] == nil
	end

	return self.level.walkable:vertexFilteredDistanceMap(loc.vertex, depth, vertexFilter)
end

-- As above but doesn't discount vertices occupied by actors in the same layer.
function GameState:dijkstraMap( actor, depth )
	depth = depth or math.huge
	local loc = self.locations[actor]
	local overlay = self.overlays[loc.layer]

	return self.level.walkable:dmap(loc.vertex, depth)
end

function GameState:fov()
	local player = self.player
	assert(player)
	local source = self.locations[player].vertex
	assert(source)

	-- We want to see the walls but not beyond them.
	local function edgeFilter( edge, from, to )
		local terrain = from.terrain
		return terrain == 'floor'
	end

	local result = self.level.graph:edgeFilteredDistanceMap(source, self.fovDepth, edgeFilter)

	local seen = self.seen
	for vertex in pairs(result) do
		seen[vertex] = true
	end

	return result
end

function GameState:nextAction()
	local queue = self.queue

	if #queue < 1 then
		return nil
	end

	-- TODO: Would be more efficient to use a priority queue.
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
		self.turns = self.turns + surplus
		for _, item in ipairs(queue) do
			item.cost = item.cost - surplus
		end
	end

	local top = queue[1]
	local cost, actor = top.cost, top.actor
	local newcost, action = actor.behaviour(self, actor)
	-- only costless calls can have nil actions
	assert(cost == 0 or action ~= nil)
	top.cost = newcost

	return action
end

-- The target vertex must be unoccupied and be a floor.
function GameState:move( actor, targetVertex )
	local location = self.locations[actor]
	assert(location)
	assert(self.level.walkable.vertices[targetVertex])
	assert(not self:actorAt(location.layer, targetVertex))
	assert(targetVertex.terrain == 'floor')
	
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

	if actor == self.player then
		self.player = nil
		self.playerAction = nil
	end

	assert(not self:actorAt(loc.layer, loc.vertex))
end

return GameState
