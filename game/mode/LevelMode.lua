--
-- mode/LevelMode.lua
--

local schema, LevelMode = require 'src/mode' { 'LevelMode' }
local Vector = require 'src/Vector'
local AABB = require 'src/AABB'
local convex = require 'src/convex'
local roomgen = require 'src/roomgen'

function LevelMode:enter()
	printf('LevelMode:enter()')

	self.rooms = {}
end

function LevelMode:update( dt )
end

function LevelMode:draw()
	local rooms = self.rooms

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
	end
end

function LevelMode:keypressed( key, is_repeat )
	if key == ' ' then
		self.rooms = {}
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

			printf('collided:%s', collided)

			rooms[#rooms+1] = {
				points = points,
				hull = hull,
				poly = poly,
				collided = collided
			}
		end
	end
end

