--
-- src/Actor.lua
--

local behaviours = require 'src/behaviours'
local Layers = require 'src/Layers'

local defs = {
	player = {
		tag = 'player',
		layer = Layers.CRITTER,
		fx = {
			fx = 'actor.text',
			actor = nil,
			text = '@'
		},
		behaviour = 'player',
		movecost = 2,
	},
	grunt = {
		tag = 'grunt',
		layer = Layers.CRITTER,
		fx = {
			fx = 'actor.text',
			actor = nil,
			text = 'g'
		},
		behaviour = 'simple',
		movecost = 2,
	},
	runner = {
		tag = 'runner',
		layer = Layers.CRITTER,
		fx = {
			fx = 'actor.text',
			actor = nil,
			text = 'r'
		},
		behaviour = 'simple',
		movecost = 1,
	},
	leaper = {
		tag = 'leaper',
		layer = Layers.CRITTER,
		fx = {
			fx = 'actor.text',
			actor = nil,
			text = 'l'
		},
		behaviour = 'leaper',
		movecost = 2,
	},
	slug = {
		tag = 'slug',
		layer = Layers.CRITTER,
		fx = {
			fx = 'actor.text',
			actor = nil,
			text = 's'
		},
		behaviour = 'slug',
		movecost = 2,
		on_die =
			function ( gameState, actor )
				local area = gameState:dijkstraMap(actor, 1)

				for vertex in pairs(area) do
					local slime = gameState:actorAt(Layers.SLIME, vertex)
					if slime then
						slime.stickiness = 5
					else
						gameState:spawn(vertex, 'slime')
					end
				end
			end,
	},
	slime = {
		tag = 'slime',
		layer = Layers.SLIME,
		fx = {
			fx = 'actor.vertex.colour',
			actor = nil,
			colour = { 0, 113, 0 , 255 }
		},
		behaviour = 'slime',
		movecost = nil,
		stickiness = 5,
	},
	bomber = {
		tag = 'bomber',
		layer = Layers.CRITTER,
		fx = {
			fx = 'actor.text',
			actor = nil,
			text = 'b'
		},
		behaviour = 'bomber',
		movecost = 2,
	},
	bomb = {
		tag = 'bomb',
		layer = Layers.CRITTER,
		fx = {
			fx = 'actor.text',
			actor = nil,
			text = '*'
		},
		behaviour = 'bomb',
		movecost = 2,
	},
}

local Actor = {
	defs = defs
}
Actor.__index = Actor

local _nextId = 1

function Actor.new( def, on_die, on_exit )
	local id = _nextId
	_nextId = _nextId + 1

	local fx = table.copy(def.fx)

	assert(type(def.tag) == 'string' and defs[def.tag] == def)
	assert(Layers[def.layer])
	assertf(behaviours[def.behaviour], '%s is not a behaviour', def.behaviour)
	assert(def.tag == 'player' or def.behaviour ~= 'player')

	local result = {
		id = id,
		tag = def.tag,
		layer = def.layer,
		fx = fx,
		behaviour = coroutine.wrap(behaviours[def.behaviour]),
		movecost = def.movecost,
		stickiness = def.stickiness,
		anims = {},
		on_die = on_die or def.on_die,
		on_exit = on_exit,
	}

	fx.actor = result

	setmetatable(result, Actor)

	return result
end

function Actor:animate( name, plan )
	if not plan then
		self.anims[name] = nil
	else
		self.anims[name] = {
			time = 0,
			plan = plan
		}
	end
end

return Actor
