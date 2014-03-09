--
-- mode/LevelMode.lua
--

local schema, LevelMode = require 'src/mode' { 'LevelMode' }
local Vector = require 'src/Vector'
local AABB = require 'src/AABB'
local convex = require 'src/convex'
local roomgen = require 'src/roomgen'
local graphgen = require 'src/graphgen'

local function _genCentredRoom( extents, genfunc, margin )
	local width = math.random(extents.width.min, extents.width.max)
	local height = math.random(extents.height.min, extents.height.max)

	printf('w:%s h:%s', width, height)

	local hw = width * 0.5
	local hh = height * 0.5

	local aabb = AABB.new {
		xmin = -hw,
		xmax = hw,
		ymin = -hh,
		ymax = hh,
	}

	local points = genfunc(aabb, margin)

	printf('#points:%d', #points)

	if #points >= 3 then
		local hull = convex.hull(points)
		local centroid = convex.centroid(hull)
		local vsub = Vector.sub

		for i = 1, #points do
			local point = points[i]
			vsub(point, point, centroid)
		end

		local aabb = AABB.newFromPoints(points)

		return {
			points = points,
			hull = hull,
			aabb = aabb,
		}
	end

	return nil
end

local function _attemptNewRoom( rooms, extents, genfunc, margin )
	local room = _genCentredRoom(extents, genfunc, margin)
	local vadd = Vector.add

	if #rooms == 0 then
		local centroid = convex.centroid(room.hull)

		local centre = Vector.new { x=400-centroid.x, y=300-centroid.y }

		for i = 1, #room.points do
			local point = room.points[i]
			vadd(point, point, centre)
		end

		local poly = {}
		for i = 1, #room.hull do
			local point = room.hull[i]
			poly[#poly+1] = point.x
			poly[#poly+1] = point.y
		end

		room.poly = poly
		room.centroid = convex.centroid(room.hull)
		room.aabb = AABB.newFromPoints(room.points)

		rooms[#rooms+1] = room
	else
		local anchorIndex = math.random(1, #rooms)
		printf('anchorIndex:%s', anchorIndex)
		local anchor = rooms[anchorIndex]
		local ax = anchor.centroid.x
		local ay = anchor.centroid.y
		local rw = room.aabb:width()
		local rh = room.aabb:height()
		local vzero = Vector.new { x=0, y=0 }
		local centre = Vector.new { x=0, y=0 }
		local count = 0
		local done = false

		while not done do
			centre.x = math.random(ax-rw, ax+rw)
			centre.y = math.random(ay-rh, ay+rh)
			count = count + 1
			printf('#:%s [%s, %s]', count, centre.x, centre.y)

			local collision = false
			for i = 1, #rooms do
				local other = rooms[i]

				if convex.collides(room.hull, other.hull, centre, vzero) then
					collision = true
					break
				end
			end

			if not collision then
				done = true
			elseif count >= 10 then
				return
			end
		end 

		for i = 1, #room.points do
			local point = room.points[i]
			vadd(point, point, centre)
		end

		local poly = {}
		for i = 1, #room.hull do
			local point = room.hull[i]
			poly[#poly+1] = point.x
			poly[#poly+1] = point.y
		end

		room.poly = poly
		room.centroid = convex.centroid(room.hull)
		room.aabb = AABB.newFromPoints(room.points)

		rooms[#rooms+1] = room	
	end
end


function LevelMode:enter()
	printf('LevelMode:enter()')

	self.rooms = {}
end

function LevelMode:update( dt )
end

local zoom = true

function LevelMode:draw()
	local rooms = self.rooms

	if zoom then
		love.graphics.scale(1/3, 1/3)
		-- love.graphics.translate(-800, -600)
		love.graphics.translate(800, 600)
	end

	for i = 1, #rooms do
		local room = rooms[i]
		local points = room.points

		love.graphics.setColor(0, 255, 0, 255)
		for j = 1, #points do
			local point = points[j]
			local radius = 3

			love.graphics.circle('fill', point.x, point.y, radius)
		end

		if not room.collided then
			love.graphics.setColor(0, 0, 255, 255)
		else
			love.graphics.setColor(255, 0, 255, 255)
		end

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

	end
	
	if self.skele then
		love.graphics.setColor(128, 128, 128, 255)
		for edge, endverts in pairs(self.skele.edges) do
			local a, b = endverts[1], endverts[2]
			love.graphics.line(a.x, a.y, b.x, b.y)
		end
	end
end

function LevelMode:keypressed( key, is_repeat )
	if key == ' ' then
		self.rooms = {}
		self.skele = nil
	elseif key == 'r' then
		printf('room')

		local xmin = math.random(0, 800)
		local ymin = math.random(0, 600)
		local width = math.random(100, 400)
		local height = math.random(100, 400)
		printf('[%s %s] w:%s h:%s', xmin, ymin, width, height)

		local aabb = AABB.new {
			xmin = xmin,
			xmax = xmin + width,
			ymin = ymin,
			ymax = ymin + height,
		}

		local margin = 20
		local points = roomgen.brownianhexgrid(aabb, margin)
		local aabb = AABB.newFromPoints(points)

		printf('#points:%d', #points)

		if #points >= 3 then
			local hull = convex.hull(points)
			local poly = {}

			for i = 1, #hull do
				local point = hull[i]
				poly[#poly+1] = point.x
				poly[#poly+1] = point.y
			end

			local rooms = self.rooms
			local vzero = Vector.new { x=0, y=0 }
			local collided = false

			for i = 1, #rooms do
				local other = rooms[i]
				if convex.collides(hull, other.hull, vzero, vzero) then
					other.collided = true
					collided = true
				end
			end

			local centroid = convex.centroid(hull)

			printf('collided:%s', collided)

			rooms[#rooms+1] = {
				points = points,
				hull = hull,
				poly = poly,
				collided = collided,
				centroid = centroid,
				aabb = aabb
			}
		end
	elseif key == 'q' then
		local seed = os.time()
		printf('seed:%s', seed)
		math.randomseed(seed)
	elseif key == 'n' then
		local extents = {
			width = {
				min = 100,
				max = 400,
			},
			height = {
				min = 100,
				max = 400,
			},
		}
		-- local genfunc = roomgen.brownianhexgrid
		local genfunc = roomgen.browniangrid
		local margin = 20
		_attemptNewRoom(self.rooms, extents, genfunc, margin )
	elseif key == 't' then
		local start = love.timer.getTime()

		self.rooms = {}
		self.skele = nil

		local extents = {
			width = {
				min = 100,
				max = 400,
			},
			height = {
				min = 100,
				max = 400,
			},
		}
		-- local genfunc = roomgen.brownianhexgrid
		local genfunc = roomgen.browniangrid
		local margin = 20
		
		while #self.rooms ~= 10 do
			_attemptNewRoom(self.rooms, extents, genfunc, margin )
		end

		local finish = love.timer.getTime()
		printf('time:%ss', finish-start)
	elseif key == 'l' then
		local rooms = self.rooms
		local centroids = {}

		for i = 1, #rooms do
			local room = rooms[i]
			centroids[#centroids+1] = room.centroid
		end

		-- local skele = graphgen.rng(centroids)
		local skele = graphgen.gabriel(centroids)

		self.skele = skele
	elseif key == 'z' then
		zoom = not zoom
	end
end

