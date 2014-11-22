--
-- src/actions.lua
--

local Vector = require 'src/Vector'
local Layers = require 'src/Layers'

local actions = {}

-- action = {
--     sync = <boolean>,
--     plan = function ( time ) -> fx
--     playerDeath = <boolean> | nil
-- }

-- parabola = -((2*(x-0.5))^2) + 1
--    x = [0..1]
--    y = [0..1]

function actions.null()
	local function plan( time )
		return false
	end

	return {
		sync = false,
		plan = plan
	}
end

function actions.kill( gameState, actor )
	local function plan( time )
		gameState:kill(actor)
		return false
	end

	local player = gameState.player
	local playerDeath = actor == player and player ~= nil

	return {
		sync = false,
		plan = plan,
		playerDeath = playerDeath
	}
end

function actions.move( gameState, actor, targetVertex )
	local loc = gameState:actorLocation(actor)
	assert(loc)
	assertf(not gameState:actorAt(loc.layer, targetVertex), 'actor:%d tried to move on occupied location\n%s', actor.id, debug.traceback())

	local slime = gameState:actorAt(Layers.SLIME, loc.vertex)
	if slime then
		slime.stickiness = slime.stickiness - actor.movecost

		return actions.struggle(gameState, actor)
	end

	local from = Vector.new(loc.vertex)
	local disp = Vector.to(from, targetVertex)

	gameState:move(actor, targetVertex)

	local duration = 0.25
	local apex = gameState.margin * 0.25
	local position = Vector.new { x=0, y=0 }
	local offset = Vector.new { x=0, y=0 }
	local vmadvnv = Vector.madvnv

	local function plan( time )
		if time > duration then
			return false
		end

		-- lerp the position
		local bias = time / duration
		vmadvnv(position, disp, bias, from)
		-- bouncey, bouncey
		local bt = 2 * (bias % 0.5)
		offset.y = -apex * parabola(bt)

		return true, {
			{
				fx = 'actor.position',
				actor = actor,
				position = position,
			},
			{
				fx = 'actor.offset',
				actor = actor,
				offset = offset,
			}
		}
	end

	return {
		sync = false,
		plan = plan
	}
end

function actions.slugmove( gameState, actor, targetVertex )
	local loc = gameState:actorLocation(actor)
	assert(loc)
	assertf(not gameState:actorAt(loc.layer, targetVertex))

	local from = Vector.new(loc.vertex)
	local disp = Vector.to(from, targetVertex)

	gameState:move(actor, targetVertex)

	local duration = 0.25
	local apex = gameState.margin * 0.25
	local position = Vector.new { x=0, y=0 }
	local offset = Vector.new { x=0, y=0 }
	local vmadvnv = Vector.madvnv

	local function plan( time )
		if time > duration then
			local slime = gameState:actorAt(Layers.SLIME, targetVertex)

			if slime then
				slime.stickiness = 5
			else
				gameState:spawn(targetVertex, 'slime')
			end

			return false
		end

		-- lerp the position
		local bias = time / duration
		vmadvnv(position, disp, bias, from)
		-- slugs do not bounce...

		return true, {
			{
				fx = 'actor.position',
				actor = actor,
				position = position,
			},
			{
				fx = 'actor.offset',
				actor = actor,
				offset = offset,
			}
		}
	end

	return {
		sync = false,
		plan = plan
	}
end

function actions.struggle( gameState, actor )
	local loc = gameState:actorLocation(actor)
	assert(loc)

	local duration = 0.25
	local wobbles = 2
	local offset = Vector.new { x=0, y=0 }
	local origin = Vector.new(loc.vertex)
	local radius = gameState.margin * 0.25

	local function plan( time )
		if time > duration then
			return false
		end

		local bias = time / duration

		offset.x = radius * math.sin(bias * 2 * wobbles * math.pi)

		return true, {
			fx = 'actor.offset',
			actor = actor,
			offset = offset,
		}
	end

	return {
		sync = false,
		plan = plan,
	}
end

function actions.search( gameState, actor )
	local loc = gameState:actorLocation(actor)
	assert(loc)

	local duration = 0.25
	local offset = Vector.new { x=0, y=0 }
	local origin = Vector.new(loc.vertex)
	local radius = gameState.margin * 0.25

	local function plan( time )
		if time > duration then
			return false
		end

		local bias = time / duration

		offset.x = radius * math.sin(bias * 2 * math.pi)
		offset.y = radius * math.cos(bias * 2 * math.pi)

		return true, {
			fx = 'actor.offset',
			actor = actor,
			offset = offset,
		}
	end

	return {
		sync = false,
		plan = plan,
	}
end

function actions.melee( gameState, actor, targetVertex )
	local actorLoc = gameState:actorLocation(actor)
	assert(actorLoc)
	local target = gameState:actorAt(actorLoc.layer, targetVertex)
	assert(target)

	local duration = 0.5
	local impact = duration * 0.25
	local recover = impact + (duration - impact) * 0.25

	assert(impact < recover)
	assert(recover < duration)

	local to = Vector.to(actorLoc.vertex, targetVertex)
	local toLength = to:length()
	local actorOffset = Vector.new { x=0, y=0 }
	local targetOffset = Vector.new { x=0, y=0 }
	local vzero = Vector.new { x=0, y=0 }
	local vmulvn = Vector.mulvn

	local function plan( time )
		if time >= duration then
			gameState:kill(target)

			return false
		end

		actorOffset:set(vzero)
		targetOffset:set(vzero)

		if time <= impact then
			local bias = time / impact
			bias = bias * bias
			vmulvn(actorOffset, to, bias * 0.75)
		else
			local bias = 1 - ((time - impact) / (duration - impact))
			bias = bias * bias
			vmulvn(actorOffset, to, bias * 0.75)
		end

		if impact <= time then
			if time <= recover then
				local bias = (time - impact) / (recover - impact)
				bias = math.sqrt(bias)
				vmulvn(targetOffset, to, bias * 0.2)
			else
				local bias = 1 - ((time - recover) / (duration - recover))
				bias = bias * bias
				vmulvn(targetOffset, to, bias * 0.2)
			end
		end

		return true, {
			{
				fx = 'actor.offset',
				actor = actor,
				offset = actorOffset,
			},
			{
				fx = 'actor.offset',
				actor = target,
				offset = targetOffset,
			},
		}
	end

	local player = gameState.player
	local playerDeath = target == player and player ~= nil

	return {
		sync = true,
		plan = plan,
		playerDeath = playerDeath
	}
end

function actions.leap( gameState, actor, targetVertex )
	local actorLoc = gameState:actorLocation(actor)
	assert(actorLoc)
	local target = gameState:actorAt(actorLoc.layer, targetVertex)

	local duration = 0.5
	local impact = duration * 0.25

	assert(impact < duration)

	local apex = gameState.margin * 0.5
	local to = Vector.to(actorLoc.vertex, targetVertex)
	local toLength = to:length()
	local actorOffset = Vector.new { x=0, y=0 }
	local targetOffset = Vector.new { x=0, y=0 }
	local vzero = Vector.new { x=0, y=0 }
	local vmulvn = Vector.mulvn

	local function plan( time )
		if time >= duration then
			if target then
				gameState:kill(target)
			end
			gameState:move(actor, targetVertex)

			return false
		end

		actorOffset:set(vzero)
		targetOffset:set(vzero)

		if time <= impact then
			local bias = time / impact
			vmulvn(actorOffset, to, bias)
			actorOffset.y = actorOffset.y - (apex * parabola(bias))
		else
			actorOffset:set(to)
		end

		if impact <= time then
			local bias = (time - impact) / (duration - impact)
			vmulvn(targetOffset, to, parabola(bias) * 0.35)
		end

		if target then
			return true, {
				{
					fx = 'actor.offset',
					actor = actor,
					offset = actorOffset,
				},
				{
					fx = 'actor.offset',
					actor = target,
					offset = targetOffset,
				},
			}
		else
			return true, {
				fx = 'actor.offset',
				actor = actor,
				offset = actorOffset,
			}
		end
	end

	local player = gameState.player
	local playerDeath = target == player and player ~= nil

	return {
		sync = true,
		plan = plan,
		playerDeath = playerDeath
	}
end

function actions.explode( gameState, actor )
	local dijkstra = gameState:dijkstraMap(actor, 1)
	local victims = { actor }
	local player = gameState.player
	local playerDeath = false

	for vertex, distance in pairs(dijkstra) do
		local victim = gameState:actorAt(Layers.CRITTER, vertex)

		if victim and victim.tag ~= 'bomb' then
			if victim == player and player ~= nil then
				playerDeath = true
			end

			victims[#victims+1] = victim
		end
	end

	local duration = 0.25
	local colour = { 255, 0, 0, 255 }

	local function plan( time )
		if time > duration then
			for _, victim in ipairs(victims) do
				gameState:kill(victim)
			end

			return false
		end

		local bias = time / duration
		local alpha = math.round(255 * parabola(bias))
		colour[4] = alpha

		local result = {}

		for vertex in pairs(dijkstra) do
			result[#result+1] = {
				fx = 'vertex.colour',
				vertex = vertex,
				colour = colour
			}
		end

		return true, result
	end

	return {
		sync = true,
		plan = plan,
		playerDeath = playerDeath
	}
end

function actions.throw( gameState, actor, targetVertex, def, text )
	local actorLoc = gameState:actorLocation(actor)
	assert(actorLoc)
	local actorVertex = actorLoc.vertex
	local target = gameState:actorAt(actorLoc.layer, targetVertex)

	local duration = 0.5
	local impact = duration * 0.25

	assert(impact < duration)

	local apex = gameState.margin * 0.5
	local to = Vector.to(actorLoc.vertex, targetVertex)
	local toLength = to:length()
	local actorPosition = Vector.new { x=0, y=0 }
	local targetOffset = Vector.new { x=0, y=0 }
	local vzero = Vector.new { x=0, y=0 }
	local vmulvn = Vector.mulvn
	local vmadvnv = Vector.madvnv

	local function plan( time )
		if time >= duration then
			if target then
				gameState:kill(target)
			end
			gameState:spawn(targetVertex, def)

			return false
		end

		actorPosition:set(vzero)
		targetOffset:set(vzero)

		if time <= impact then
			local bias = time / impact
			vmadvnv(actorPosition, to, bias, actorVertex)
			actorPosition.y = actorPosition.y - (apex * parabola(bias))
		else
			actorPosition:set(targetVertex)
		end

		if impact <= time then
			local bias = (time - impact) / (duration - impact)
			vmulvn(targetOffset, to, parabola(bias) * 0.35)
		end

		if target then
			return true, {
				{
					fx = 'text',
					text = text,
					position = actorPosition,
				},
				{
					fx = 'actor.offset',
					actor = target,
					offset = targetOffset,
				},
			}
		else
			return true, {
				fx = 'text',
				text = text,
				position = actorPosition,
			}
		end
	end

	local player = gameState.player
	local playerDeath = target == player and player ~= nil

	return {
		sync = true,
		plan = plan,
		playerDeath = playerDeath
	}
end

return actions
