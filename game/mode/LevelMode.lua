--
-- mode/LevelMode.lua
--

local schema, LevelMode = require 'src/mode' { 'LevelMode' }
local Vector = require 'src/Vector'
local AABB = require 'src/AABB'
local roomgen = require 'src/roomgen'
local Level = require 'src/Level'

function LevelMode:enter()
	printf('LevelMode:enter()')

	self.level = nil
end

function LevelMode:gen()
	local genfunc = roomgen.brownianhexgrid
	-- local genfunc = roomgen.hexgrid
	local extents = {
		width = {
			min = 100,
			max = 200,
		},
		height = {
			min = 100,
			max = 200,
		},
	}
	local margin = 20
	local numRooms = 10

	self.level = Level.new(numRooms, genfunc, extents, margin)
end

function LevelMode:update( dt )
end

local zoom = true
local drawVoronoi = false

function LevelMode:draw()
	local rooms = self.rooms

	if zoom then
		love.graphics.scale(1/3, 1/3)
		-- love.graphics.translate(-800, -600)
		love.graphics.translate(800, 600)
	end

	if self.level then
		local rooms = self.level.rooms

		if drawVoronoi then
			for _, point in ipairs(self.level.points) do
				if point.terrain == 'floor' then
					love.graphics.setColor(64, 64, 64, 255)
				else
					love.graphics.setColor(64, 0, 0, 255)
				end

				love.graphics.polygon('fill', point.poly)
			end

			love.graphics.setColor(0, 0, 0, 255)
			for _, point in ipairs(self.level.points) do
				love.graphics.polygon('line', point.poly)
			end

			love.graphics.setColor(0, 255, 0, 255)
			for edge, endverts in pairs(self.level.graph.edges) do
				local a, b = endverts[1], endverts[2]
				if a.terrain == 'floor' and b.terrain == 'floor' then
					love.graphics.line(a.x, a.y, b.x, b.y)
				end
			end

			return
		end

		for i = 1, #rooms do
			local room = rooms[i]
			local points = room.points

			for j = 1, #points do
				local point = points[j]
				local radius = 3

				if point.terrain == 'floor' then
					love.graphics.setColor(0, 255, 0, 255)
				else
					love.graphics.setColor(255, 0, 0, 255)
				end

				love.graphics.circle('fill', point.x, point.y, radius)
			end

			love.graphics.setColor(0, 0, 255, 255)
			love.graphics.polygon('line', room.poly)

			love.graphics.setColor(255, 255, 255, 255)
			local centroid = room.centroid
			local x, y = centroid.x, centroid.y
			local d = 10

			love.graphics.line(x+d, y+d, x-d, y-d)
			love.graphics.line(x-d, y+d, x+d, y-d)

			love.graphics.setColor(255, 255, 0, 255)
			local aabb = room.aabb
			love.graphics.line(aabb.xmin, aabb.ymin, aabb.xmax, aabb.ymin)
			love.graphics.line(aabb.xmax, aabb.ymin, aabb.xmax, aabb.ymax)
			love.graphics.line(aabb.xmax, aabb.ymax, aabb.xmin, aabb.ymax)
			love.graphics.line(aabb.xmin, aabb.ymax, aabb.xmin, aabb.ymin)

			local graph = room.graph

			if graph then
				love.graphics.setColor(128, 128, 128, 255)
				for edge, endverts in pairs(graph.edges) do
					local a, b = endverts[1], endverts[2]
					love.graphics.line(a.x, a.y, b.x, b.y)
				end
			end
		end

		love.graphics.setColor(128, 128, 128, 255)
		for edge, endverts in pairs(self.level.connections.edges) do
			local a, b = endverts[1], endverts[2]
			love.graphics.line(a.x, a.y, b.x, b.y)
		end

		love.graphics.setColor(255, 0, 255, 255)
		for _, point in ipairs(self.level.corridors) do
			local radius = 4
			love.graphics.circle('fill', point.x, point.y, radius)
		end

		love.graphics.setColor(128, 0, 0, 255)
		for _, point in ipairs(self.level.borders) do
			local radius = 4
			love.graphics.circle('fill', point.x, point.y, radius)
		end

		love.graphics.setColor(0, 128, 64, 255)
		for _, point in ipairs(self.level.fillers) do
			local radius = 4
			love.graphics.circle('fill', point.x, point.y, radius)
		end

	end
end

function LevelMode:keypressed( key, is_repeat )
	if key == ' ' then
		self.level = nil
	elseif key == 'g' then
		self:gen()		
	elseif key == 'q' then
		local seed = os.time()
		printf('seed:%s', seed)
		math.randomseed(seed)
	elseif key == 'v' then
		drawVoronoi = not drawVoronoi
	elseif key == 'z' then
		zoom = not zoom
	end
end

