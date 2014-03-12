--
-- src/GameMode.lua
--

local schema, GameMode = require 'src/mode' { 'GameMode' }
local Vector = require 'src/Vector'
local AABB = require 'src/AABB'
local roomgen = require 'src/roomgen'
local Level = require 'src/Level'
local Actor = require 'src/Actor'
local GameState = require 'src/GameState'

function shadowf( x, y, ... )
	love.graphics.setColor(0, 0, 0, 255)

	local font = love.graphics.getFont()

	local text = string.format(...)

	local hh = font:getHeight() * 0.5
	local hw = font:getWidth(text) * 0.5

	local tx = x - hw
	local ty = y - hh

	love.graphics.print(text, tx-1, ty-1)
	love.graphics.print(text, tx-1, ty+1)
	love.graphics.print(text, tx+1, ty-1)
	love.graphics.print(text, tx+1, ty+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, tx, ty)
end

function GameMode:enter()
	printf('GameMode:enter()')

	self:gen()
end

function GameMode:gen()
	local gameState = GameState.new()
	local player = Actor.new('@', nil)
	local start = gameState:randomWalkableVertex()

	gameState:spawn(GameState.Layer.CRITTER, start, player)

	self.gameState = gameState
	self.player = player
end

function GameMode:update( dt )
end

function GameMode:draw()
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
		local vertex = self.gameState:actorLocation(self.player).vertex
		love.graphics.translate(-vertex.x + sw * 0.5, -vertex.y + sh * 0.5)
	end

	for _, point in ipairs(self.gameState.level.points) do
		if point.terrain == 'floor' then
			love.graphics.setColor(184, 118, 61, 255)
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

	love.graphics.setColor(0, 0, 0, 255)
	for _, point in ipairs(self.gameState.level.points) do
		love.graphics.polygon('line', point.poly)
	end

	love.graphics.setColor(0, 255, 0, 255)
	for edge, endverts in pairs(self.gameState.level.walkable.edges) do
		local a, b = endverts[1], endverts[2]
		love.graphics.line(a.x, a.y, b.x, b.y)
	end

	for actor, location in pairs(self.gameState.locations) do
		local vertex = location.vertex
		shadowf(vertex.x, vertex.y, actor.symbol)
	end
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

local delta = 100
function GameMode:keypressed( key, is_repeat )
	if key == ' ' then
		self:gen()
	elseif key == 'q' then
		local seed = os.time()
		printf('seed:%s', seed)
		math.randomseed(seed)
	elseif key == 'm' then
		local peers = self.gameState:peersOf(self.player)
		local targetVertex = table.random(peers)
		self.gameState:move(self.player, targetVertex)
	elseif key == 'z' then
		self.overview = not self.overview
	else
		local dir = keytodir[key]

		if dir then
			local loc = self.gameState:actorLocation(self.player)
			local target = self.gameState.level.dirmap[loc.vertex][dir]

			if target and not self.gameState:actorAt(GameState.Layer.CRITTER, target) then
				self.gameState:move(self.player, target)
			end
		end
	end
end
