--
-- src/actions.lua
--

local Vector = require 'src/Vector'
-- causes a require loop
-- local GameState = require 'src/GameState'

local actions = {}

-- action = {
--     blocking = <boolean>,
--     anim = function ( time ) -> boolean, offset
--     effect = function ( gameState )
-- }

-- parabola = -((2*(x-0.5))^2) + 1
--    x = [0..1]
--    y = [0..1]

local function parabola( t )
	return -((2*(t-0.5))^2) + 1
end

function actions.move( gameState, actor, targetVertex )
	local loc = gameState:actorLocation(actor)
	assert(loc)
	assert(not gameState:actorAt(loc.layer, targetVertex))

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

	return {
		sync = true,
		plan = plan
	}
end

function actions.leap( gameState, actor, targetVertex )
	local actorLoc = gameState:actorLocation(actor)
	assert(actorLoc)
	local target = gameState:actorAt(actorLoc.layer, targetVertex)

	local duration = 0.5
	local impact = duration * 0.25
	local recover = impact + (duration - impact) * 0.25

	assert(impact < recover)
	assert(recover < duration)

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

			return false
		end

		actorOffset:set(vzero)
		targetOffset:set(vzero)

		if time <= impact then
			local bias = time / impact
			local y = apex * parabola(bias)
			vmulvn(actorOffset, to, bias * 0.75)
			actorOffset.y = actorOffset.y - y
		else
			actorOffset:set(to)
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

	return {
		sync = true,
		plan = plan
	}
end

return actions
