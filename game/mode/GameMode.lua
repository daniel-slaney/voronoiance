--
-- src/GameMode.lua
--

local schema, GameMode, EndGameMode = require 'src/mode' { 'GameMode', 'EndGameMode' }
local Vector = require 'src/Vector'
local AABB = require 'src/AABB'
local roomgen = require 'src/roomgen'
local Level = require 'src/Level'
local Actor = require 'src/Actor'
local GameState = require 'src/GameState'
local behaviours = require 'src/behaviours'
local actions = require 'src/actions'

function shadowf( align, x, y, ... )
	love.graphics.setColor(0, 0, 0, 255)

	local font = love.graphics.getFont()

	local text = string.format(...)

	local hh = font:getHeight() * 0.5
	local hw = font:getWidth(text) * 0.5

	local tx, ty = 0, 0

	if align == 'cc' then
		tx = x - hw
		ty = y - hh
	end

	love.graphics.print(text, tx-1, ty-1)
	love.graphics.print(text, tx-1, ty+1)
	love.graphics.print(text, tx+1, ty-1)
	love.graphics.print(text, tx+1, ty+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, tx, ty)
end

function GameMode:enter( reason )
	printf('GameMode:enter(%s)', reason)

	self:gen()
end

function GameMode:gen()
	local gameState = GameState.new()
	local function on_player_die( gameState, actor )
		self:become(EndGameMode, 'died')
	end
	local player = Actor.new('@', 'player', on_player_die)
	local start = gameState.level.entry

	gameState:spawnPlayer(GameState.Layer.CRITTER, start, player)

	self.gameState = gameState
	self.player = player
	self.pending = nil
	self:resetFX()
	self.fastmode = false
end

function GameMode:addFX( fx )
	if fx == nil then
		return
	end

	if #fx > 0 then
		for _, v in ipairs(fx) do
			self:addFX(v)
		end
	end

	if fx.fx == 'actor.position' then
		local positions = self.fx.actor.positions
		positions[fx.actor] = fx.position
	end

	if fx.fx == 'actor.offset' then
		local offsets = self.fx.actor.offsets
		local offset = offsets[fx.actor]

		if not offset then
			offsets[fx.actor] = Vector.new(fx.offset)
		else
			Vector.add(offset, offset, fx.offset)
		end
	end
end

function GameMode:resetFX()
	self.fx = {
		actor = {
			positions = {},
			offsets = {}
		},
	}
end

function GameMode:update( dt )
	local start = love.timer.getTime()
	if not self.pending then
		local unsynced = {}

		local start = love.timer.getTime()

		while true do
			local action = self.gameState:nextAction()
		
			if not action then
				if #unsynced > 0 then
					self.pending = {
						unsynced = unsynced
					}
				end
				break
			end

			if not action.sync then
				unsynced[#unsynced+1] = {
					time = 0,
					plan = action.plan
				}
			else
				self.pending = {
					unsynced = unsynced,
					synced = {
						time = 0,
						plan = action.plan,
					}
				}
				break
			end
		end

		local finish = love.timer.getTime()

		if self.pending then
			printf('action polling %ss', finish - start)
		end
	end

	local actionDT = (self.fastmode) and math.huge or dt

	local pending = self.pending
	if pending then
		local done = true
		local unsynced = pending.unsynced
		for i = #unsynced, 1, -1 do
			local action = unsynced[i]
			local running, fx = action.plan(action.time)
			self:addFX(fx)

			if running then
				done = false
				action.time = action.time + actionDT
			else
				table.remove(unsynced, i)
			end
		end

		if done then
			pending.unsynced = {}

			local synced = pending.synced
			if not synced then
				self.pending = nil
			else
				local running, fx = synced.plan(synced.time)
				self:addFX(fx)

				if running then
					synced.time = synced.time + actionDT
				else
					self.pending = nil
				end
			end
		end
	end
	local finish = love.timer.getTime()
	-- printf('update %.2fs', finish-start)
end

function GameMode:draw()
	love.graphics.push()

	love.graphics.setLineStyle('rough')

	local sw, sh = love.graphics.getDimensions()
	if self.overview then
		local screen = AABB.new {
			xmin = 0,
			xmax = sw,
			ymin = 0,
			ymax = sh,
		}
		local aabb = self.gameState.level.aabb
		local viewport = AABB.new(aabb)
		viewport:similarise(screen)
		local vw, vh = viewport:width(), viewport:height()
		local aspectW = sw / vw
		local aspectH = sh / vh

		love.graphics.scale(aspectW, aspectH)
		love.graphics.translate(-viewport.xmin, -viewport.ymin)
	else
		local positions = self.fx.actor.positions
		local vertex = positions[self.player] or self.gameState:actorLocation(self.player).vertex
		love.graphics.translate(-vertex.x + sw * 0.5, -vertex.y + sh * 0.5)
	end

	local fov = self.gameState:fov()

	for _, point in ipairs(self.gameState.level.points) do
		if fov[point] then
			if point.terrain == 'floor' then
				if point.entry or point.exit then
					love.graphics.setColor(255, 0, 255, 255)
				else
					love.graphics.setColor(184, 118, 61, 255)
				end
			else
				love.graphics.setColor(64, 64, 64, 255)
			end

			love.graphics.polygon('fill', point.poly)

			if point.problem then
				love.graphics.setColor(255, 0, 255, 255)
				local radius = 10
				love.graphics.circle('fill', point.x, point.y, radius)
			end
		end
	end

	love.graphics.setColor(0, 0, 0, 255)
	for _, point in ipairs(self.gameState.level.points) do
		if fov[point] then
			love.graphics.polygon('line', point.poly)
		end
	end

	love.graphics.setColor(0, 255, 0, 255)
	for edge, endverts in pairs(self.gameState.level.walkable.edges) do
		local a, b = endverts[1], endverts[2]
		if fov[a] or fov[b] then
			love.graphics.line(a.x, a.y, b.x, b.y)
		end
	end

	local positions = self.fx.actor.positions
	local offsets = self.fx.actor.offsets
	local vzero = Vector.new { x=0, y=0 }

	for actor, location in pairs(self.gameState.locations) do
		local vertex = positions[actor] or location.vertex
		local offset = offsets[actor] or vzero
		shadowf('cc', vertex.x + offset.x, vertex.y + offset.y, actor.symbol)
	end

	love.graphics.pop()

	local fasttext = self.fastmode and '- fast' or ''
	shadowf('lt', 60, 40, '%shz t:%d %s', love.timer.getFPS(), self.gameState.turns, fasttext)

	self:resetFX()
end

--
-- Support for vi-keys, WASD and numpad
--
-- y k u  q w e  7 8 9
-- h   l  a   d  4   6
-- b j n  z s c  1 2 3
--

local keytodir = {
	h = 'W',
	j = 'S',
	k = 'N',
	l = 'E',
	y = 'NW',
	u = 'NE',
	b = 'SW',
	n = 'SE',

	a = 'W',
	s = 'S',
	w = 'N',
	d = 'E',
	q = 'NW',
	e = 'NE',
	z = 'SW',
	c = 'SE',

	kp4 = 'W',
	kp2 = 'S',
	kp8 = 'N',
	kp6 = 'E',
	kp7 = 'NW',
	kp9 = 'NE',
	kp1 = 'SW',
	kp3 = 'SE',
}

local nearby = {
	N = { 'NE', 'NW' },
	NE = { 'N', 'E' },
	E = { 'NE', 'SE' },
	SE = { 'E', 'S' },
	S = { 'SE', 'SW' },
	SW = { 'S', 'W' },
	W = { 'SW', 'NW' },
	NW = { 'W', 'N' },
}

local delta = 100
function GameMode:keypressed( key, is_repeat )
	if key == ' ' then
		self:gen()
	elseif key == 'q' then
		local seed = os.time()
		printf('seed:%s', seed)
		math.randomseed(seed)
	elseif key == 'm' then
		local dof = self.gameState:occludedDijkstraMap(self.player, 1)
		if next(dof) then
			local targetVertex = table.random(dof)
			self.gameState:move(self.player, targetVertex)
		end
	elseif key == 'z' then
		self.overview = not self.overview
	elseif key == '1' then
		local layer = GameState.Layer.CRITTER
		local target = self.gameState:randomWalkableVertex()
		local actor = Actor.new('S', 'simple')
		self.gameState:spawn(layer, target, actor)
	elseif key == 'left' then
		self.gameState.fovDepth = self.gameState.fovDepth - 1
	elseif key == 'right' then
		self.gameState.fovDepth = self.gameState.fovDepth + 1
	elseif key == '0' then
		draw = not draw
	elseif key == 'f' then
		self.fastmode = not self.fastmode
	elseif not self.pending then
		local dir = keytodir[key]
		local gameState = self.gameState

		if dir then
			local loc = gameState:actorLocation(self.player)
			local dirmap = gameState.level.dirmap[loc.vertex]
			local target = dirmap[dir]

			-- TODO: if there's no target try a nearby direction.
			--       - If only one of them is valid move that way

			if not target then
				local dirA = nearby[dir][1]
				local dirB = nearby[dir][2]
				local targetA = dirmap[dirA]
				local targetB = dirmap[dirB]

				if targetA and not targetB then
					target = targetA
				elseif not targetA and targetB then
					target = targetB
				end
			end

			if target then
				local targetActor = gameState:actorAt(GameState.Layer.CRITTER, target)

				if not targetActor then
					-- self.gameState:move(self.player, target)
					gameState.playerAction = {
						cost = 2,
						action = actions.move(gameState, self.player, target)
					}
				else
					gameState.playerAction = {
						cost = 2,
						action = actions.melee(gameState, self.player, target)
					}
				end
			end
		end

		if key == '9' then
			gameState.playerAction = {
				cost = 2,
				action = actions.search(gameState, self.player)
			}
		end
	end
end
