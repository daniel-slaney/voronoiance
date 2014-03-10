--
-- src/Level.lua
--

local Vector = require 'src/Vector'
local AABB = require 'src/AABB'
local roomgen = require 'src/roomgen'
local Graph = require 'src/Graph'
local graphgen = require 'src/graphgen'
local convex = require 'src/convex'
local newgrid = require 'src/newgrid'
local Voronoi = require 'src/Voronoi'

local Level = {}
Level.__index = Level

function Level.new( numRooms, genfunc, extents, margin )
	local result = {
		rooms = {},
		connections = nil,
		corridors = {},
		points = {},
		borders = {},
		fillers = {}
	}

	setmetatable(result, Level)

	result:_genrooms(numRooms, genfunc, extents, margin)
	result:_connectRooms()
	result.corridors = result:_gencorridors(margin)
	result:_enclose(margin)
	result:_genvoronoi()

	return result
end

function Level:_roomgen( genfunc, extents, margin )
	local width = math.random(extents.width.min, extents.width.max)
	local height = math.random(extents.height.min, extents.height.max)

	local hw = width * 0.5
	local hh = height * 0.5

	local aabb = AABB.new {
		xmin = -hw,
		xmax = hw,
		ymin = -hh,
		ymax = hh,
	}

	local points, graph = genfunc(aabb, margin)

	--  Need three or more points to be able to create a convex hull.
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
			graph = graph,
		}
	end

	return nil
end

function Level:_insertRoom( genfunc, extents, margin )
	local room = self:_roomgen(genfunc, extents, margin)

	if not room then
		return
	end

	local vadd = Vector.add
	local centre = Vector.new { x=400, y=300 }
	local rooms = self.rooms

	if #rooms > 0 then
		local anchorIndex = math.random(1, #rooms)
		local anchor = rooms[anchorIndex]
		local ax = anchor.centroid.x
		local ay = anchor.centroid.y
		local rw = room.aabb:width()
		local rh = room.aabb:height()
		local vzero = Vector.new { x=0, y=0 }
		local count = 0
		local done = false

		while not done do
			centre.x = math.random(ax-rw, ax+rw)
			centre.y = math.random(ay-rh, ay+rh)
			count = count + 1

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

	local points = self.points
	for _, point in ipairs(room.points) do
		points[#points+1] = point
	end

	rooms[#rooms+1] = room
end

function Level:_genrooms( numRooms, genfunc, extents, margin )
	local start = love.timer.getTime()

	self.skele = nil
	
	while #self.rooms ~= numRooms do
		self:_insertRoom(genfunc, extents, margin)
	end

	local finish = love.timer.getTime()
	printf('genrooms #:%d %ss', numRooms, finish-start)
end

function Level:_connectRooms()
	local rooms = self.rooms
	local centroids = {}

	for i = 1, #rooms do
		local centroid = rooms[i].centroid
		centroids[#centroids+1] = {
			x = centroid.x,
			y = centroid.y,
			room = rooms[i],
		}
	end

	-- local skele = graphgen.rng(centroids)
	local connections = graphgen.gabriel(centroids)

	self.connections = connections
end

-- TODO: this can generate points that are too close together so corridors end
--       up merging. Might need to use path finding code instead...
function Level:_gencorridors( margin )
	-- Now create corridor the points along the edges.
	local points = {}

	for edge, verts in pairs(self.connections.edges) do
		local room1, room2 = verts[1].room, verts[2].room

		-- Choose the nearest two points of the two rooms to connect.
		local distance, near1, near2 = Vector.nearest(room1.points, room2.points)

		-- This should always succeed.
		if near1 and near2 then
			near1.terrain = 'floor'
			near2.terrain = 'floor'
			-- We already have the end points of the corridor so we only create
			-- the internal points.
			-- TODO: if numPoints < 1 then something has gone wrong, maybe
			--       assert on it. Need to ensure the layoutgen functions
			--       always leave at least 2*margin distance between rooms.
			local numPoints = math.round(distance / margin) - 1
			local segLength = distance / (numPoints + 1)
			local normal = Vector.to(near1, near2):normalise()

			for i = 1, numPoints do
				local bias = 0.5

				if numPoints > 1 then
					bias = lerpf(i, 1, numPoints, 0, 1)
				end

				local point = {
					x = near1.x + (i * segLength * normal.x),
					y = near1.y + (i * segLength * normal.y),
					terrain = 'floor'
				}

				points[#points+1] = point
			end			
		end
	end

	local all = self.points
	for _, point in ipairs(points) do
		all[#all+1] = point
	end

	return points
end

-- This is technically a slow algorithm but seems to be ok in practise.
-- 1. Put all the points into a margin sized grid of buckets.
-- 2. For each cell try 10 times to create a random point within the cell.
-- 3. Check the point isn't too close (within margin distance) of other points.
function Level:_enclose( margin )
	-- make an array of all room and corridor points.

	local points = self.points
	local aabb = AABB.newFromPoints(points)
	-- nice safe border for the level
	aabb = aabb:expand(4 * margin)
	self.aabb = aabb

	local width = math.ceil(aabb:width() / margin)
	local height = math.ceil(aabb:height() / margin)

	-- print('margin', margin)

	margin = aabb:width() / width

	-- print('margin', margin)

	local grid = newgrid(width, height, false)

	for _, point in pairs(points) do
		local x = math.round((point.x - aabb.xmin) / margin)
		local y = math.round((point.y - aabb.ymin) / margin)

		assert(x ~= 1 and x ~= width)
		assert(y ~= 1 and y ~= height)

		local cell = grid.get(x, y)

		if cell then
			cell[#cell+1] = point
		else
			grid.set(x, y, { point })
		end
	end

	local border = 'border'
	
	local result = {}

	-- Now fill a 1 cell thick perimiter with walls.
	for x = 1, width do
		local top = grid.get(x, 1)
		local bottom = grid.get(x, height)

		assert(top == false)
		assert(bottom == false)

		local mx = aabb.xmin + ((x-1) * margin) + (margin * 0.5)

		local topBorder = { x = mx, y = aabb.ymin + (margin * 0.5), terrain = border }
		local bottomBorder = { x = mx, y = aabb.ymax - (margin * 0.5), terrain = border }

		grid.set(x, 1, { topBorder })
		grid.set(x, height, { bottomBorder })

		result[#result+1] = topBorder
		result[#result+1] = bottomBorder
	end

	for y = 2, height-1 do
		local left = grid.get(1, y)
		local right = grid.get(width, y)

		assert(left == false)
		assertf(right == false, '[%d %d]', y, width)

		local my = aabb.ymin + ((y-1) * margin) + (margin * 0.5)

		local leftWall = { x = aabb.xmin + (margin * 0.5), y = my, terrain = border }
		local rightWall = { x = aabb.xmax - (margin * 0.5), y = my, terrain = border }

		grid.set(1, y, { leftWall })
		grid.set(width, y, { rightWall })

		result[#result+1] = leftWall
		result[#result+1] = rightWall
	end

	-- grid.print()

	-- Any point within a cell could be too close to other cell neighbouring.
	local dirs = {
		{ 0, 0 },
		{ -1, -1 },
		{  0, -1 },
		{  1, -1 },
		{ -1,  0 },
		{  1,  0 },
		{ -1,  1 },
		{  0,  1 },
		{  1,  1 },
	}

	for x = 2, width-1 do
		for y = 2, height-1 do
			for attempt = 1, 10 do
				local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
				local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

				local candidate = { x = rx, y = ry, terrain = 'filler' }
				local empty = {}
				local accepted = true

				for _, dir in ipairs(dirs) do
					local dx, dy = x + dir[1], y + dir[2]
					
					if 1 <= dx and dx <= width and 1 <= dy and dy <= height then
						for _, vertex in ipairs(grid.get(dx, dy) or empty) do
							if Vector.toLength(vertex, candidate) < margin then
								accepted = false
								break
							end
						end
					end

					if not accepted then
						break
					end
				end

				if accepted then
					local cell = grid.get(x, y)

					if cell then
						cell[#cell+1] = candidate
					else
						cell = { candidate }
						grid.set(x, y, cell)
					end

					result[#result+1] = candidate
				end
			end
		end
	end

	local all = self.points
	local borders = self.borders
	local fillers = self.fillers
	for _, point in ipairs(result) do
		if point.terrain == 'border' then
			borders[#borders+1] = point
		else
			fillers[#fillers+1] = point
		end
		all[#all+1] = point
	end
end

function Level:_genvoronoi()
	-- Build voronoi diagram.
	local points = self.points
	local sites = {}
	for index, point in ipairs(points) do
		local site = {
			x = point.x,
			y = point.y,
			vertex = point,
			index = index,
		}
		sites[#sites+1] = site
	end

	local aabb = self.aabb
	local bbox = {
		xl = aabb.xmin,
		xr = aabb.xmax,
		yt = aabb.ymin,
		yb = aabb.ymax,
	}

	local voronoiStart = love.timer.getTime()
	local diagram = Voronoi:new():compute(sites, bbox)
	local voronoiFinish = love.timer.getTime()

	printf('Voronoi:compute(%d) %.3fs', #sites, voronoiFinish - voronoiStart)

	-- From voronoi diagram create a cell connectivity graph.
	local graph = Graph.new()
	local cells = {}

	-- First add the vertices and contruct the polygon for the vertices.
	for _, cell in ipairs(diagram.cells) do
		local vertex = points[cell.site.index]
		local poly = {}
		local hull = {}

		for _, halfedge in ipairs(cell.halfedges) do
			local startpoint = halfedge:getStartpoint()

			poly[#poly+1] = startpoint.x
			poly[#poly+1] = startpoint.y
			hull[#hull+1] = Vector.new(startpoint)
		end

		vertex.poly = poly
		vertex.hull = hull

		if #poly >= 6 then
			graph:addVertex(vertex)
		end
	end

	-- Now the connections.
	for _, cell in ipairs(diagram.cells) do
		local neighbours = cell:getNeighborIdAndEdgeLengths()

		local vertex1 = points[cell.site.index]

		for _, neighbour in ipairs(neighbours) do
			local vertex2 = points[diagram.cells[neighbour.voronoiId].site.index]
			
			if not graph:isPeer(vertex1, vertex2) then
				graph:addEdge({ length = neighbour.edgeLength }, vertex1, vertex2)
			end
		end
	end

	self.graph = graph
end

return Level