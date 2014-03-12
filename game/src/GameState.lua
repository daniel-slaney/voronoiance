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


return GameState
