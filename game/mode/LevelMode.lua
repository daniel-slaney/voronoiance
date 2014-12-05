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
	local genfunc = roomgen.random
	-- local genfunc = roomgen.brownianhexgrid
	-- local genfunc = roomgen.hexgrid
	-- local genfunc = roomgen.enclose
	-- local genfunc = roomgen.browniangrid
	-- local genfunc = roomgen.relaxed
	-- local genfunc = roomgen.brownianrelaxed
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
	local numRooms = 9

	self.level = Level.new(numRooms, genfunc, extents, margin, false)
end

function LevelMode:update( dt )
end

local zoom = true
local drawVoronoi = false
local offsetX = 0
local offsetY = 0

function LevelMode:draw()
	local rooms = self.rooms

	if zoom and self.level then
		local sw, sh = love.graphics.getDimensions()
		local screen = AABB.new {
			xmin = 0,
			xmax = sw,
			ymin = 0,
			ymax = sh,
		}
		local aabb = self.level.aabb
		local viewport = AABB.new(aabb)
		viewport:similarise(screen)
		local vw, vh = viewport:width(), viewport:height()
		local aspectW = sw / vw
		local aspectH = sh / vh

		love.graphics.scale(aspectW, aspectH)
		love.graphics.translate(-viewport.xmin, -viewport.ymin)
	else
		love.graphics.translate(-offsetX, -offsetY)
	end

	if self.level then
		local rooms = self.level.rooms

		if drawVoronoi then
			local drawFringe = true
			for _, point in ipairs(self.level.points) do
				if point.critical then
					local b = 64
					love.graphics.setColor(184+b, 118+b, 61+b, 255)
				elseif point.terrain == 'floor' then
					if drawFringe then
						local f = self.level.fringe[point]
						love.graphics.setColor(184*f, 118*f, 61*f, 255)
					else
						love.graphics.setColor(184, 118, 61, 255)
					end
				else
					love.graphics.setColor(64, 64, 64, 255)
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
				local radius = 5

				if point.terrain == 'floor' then
					love.graphics.setColor(0,4255, 0, 255)
					love.graphics.circle('fill', point.x, point.y, radius)
				elseif points.terrain == 'filler' then
					love.graphics.setColor(255, 0, 255, 255)
					love.graphics.circle('line', point.x, point.y, radius)
				else
					love.graphics.setColor(255, 255, 255, 255)
					love.graphics.circle('line', point.x, point.y, radius)
				end
			end

			love.graphics.setColor(0, 0, 255, 255)
			love.graphics.polygon('line', room.poly)

			love.graphics.setColor(255, 255, 255, 255)
			local centroid = room.centroid
			local x, y = centroid.x, centroid.y
			local d = 10

			love.graphics.line(x+d, y+d, x-d, y-d)
			love.graphics.line(x-d, y+d, x+d, y-d)

			-- love.graphics.setColor(255, 255, 0, 255)
			-- local aabb = room.aabb
			-- love.graphics.line(aabb.xmin, aabb.ymin, aabb.xmax, aabb.ymin)
			-- love.graphics.line(aabb.xmax, aabb.ymin, aabb.xmax, aabb.ymax)
			-- love.graphics.line(aabb.xmax, aabb.ymax, aabb.xmin, aabb.ymax)
			-- love.graphics.line(aabb.xmin, aabb.ymax, aabb.xmin, aabb.ymin)

			local graph = room.graph

			if graph then
				love.graphics.setColor(128, 128, 128, 255)
				for edge, endverts in pairs(graph.edges) do
					local a, b = endverts[1], endverts[2]
					love.graphics.line(a.x, a.y, b.x, b.y)
				end
			end
		end

		local hulls = {}
		for i, point in ipairs(self.level.points) do
			if point.hulls then
				for hull in pairs(point.hulls) do
					hulls[hull] = true
				end
			end
		end

		for i, room in ipairs(self.level.rooms) do
			hulls[room.safehull] = true
		end

		for hull in pairs(hulls) do
			local poly = {}

			for i, point in ipairs(hull) do
				poly[#poly+1] = point.x
				poly[#poly+1] = point.y
			end

			love.graphics.polygon('line', poly)
		end

		love.graphics.setColor(128, 128, 128, 255)
		for edge, endverts in pairs(self.level.connections.edges) do
			local a, b = endverts[1], endverts[2]
			love.graphics.line(a.x, a.y, b.x, b.y)
		end

		love.graphics.setColor(0, 255, 0, 255)
		for _, point in ipairs(self.level.corridors) do
			local radius = 4
			love.graphics.circle('fill', point.x, point.y, radius)
		end

		love.graphics.setColor(128, 0, 0, 255)
		for _, point in ipairs(self.level.borders) do
			local radius = 4
			love.graphics.circle('fill', point.x, point.y, radius)
		end

		love.graphics.setColor(255, 0, 255, 255)
		for _, point in ipairs(self.level.fillers) do
			local radius = 4
			love.graphics.circle('fill', point.x, point.y, radius)
		end

	end
end

local delta = 100

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
	elseif key == 'right' then
		offsetX = offsetX + delta
	elseif key == 'left' then
		offsetX = offsetX - delta
	elseif key == 'down' then
		offsetY = offsetY + delta
	elseif key == 'up' then
		offsetY = offsetY - delta
	end
end

