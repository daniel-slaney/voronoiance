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
local dirs = require 'src/dirs'

local Level = {}
Level.__index = Level

function Level.new( numRooms, genfunc, extents, margin, check )
	local start = love.timer.getTime()
	local attempts = 0

	local result
	repeat
		attempts = attempts + 1
		result = {
			rooms = {},
			connections = nil,
			corridors = {},
			points = {},
			borders = {},
			fillers = {},
			graph = nil,
			walkable = nil,
			dirmap = nil,
			paths = nil,
			longestPath = math.huge,
			entry = nil,
			exit = nil,
		}

		setmetatable(result, Level)

		result:_genrooms(numRooms, genfunc, extents, margin)
		result:_connectRooms()
		result.corridors = result:_gencorridors(margin)
		result:_enclose(margin)
		result:_genvoronoi()
		result:_gendirs()
		local connected = result.walkable:isConnected()
		local dirsOK = not result.dirsProblem
		printf('connected:%s dirs ok:%s', connected, dirsOK)
		if not check then
			break
		end
	until connected and dirsOK

	result:_genpaths()
	result:_genentry()

	local finish = love.timer.getTime()

	-- no longer need 'wall', 'filler' and 'border' just set them all to 'wall'
	for vertex in pairs(result.graph.vertices) do
		if vertex.terrain ~= 'floor' then
			vertex.terrain = 'wall'
		end
	end

	printf('level gen #attempts:%s %.2fs', attempts, finish - start)

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

	local points, graph, overlay = genfunc(aabb, margin)

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

		for _, point in ipairs(points) do
			point.hull = hull
		end

		return {
			points = points,
			hull = hull,
			aabb = aabb,
			graph = graph,
			overlay = overlay
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

				if convex.collides(room.hull, other.hull, centre, vzero, margin) then
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
	local count = 0
	
	while #self.rooms ~= numRooms do
		self:_insertRoom(genfunc, extents, margin)
		count = count + 1
	end

	local finish = love.timer.getTime()
	printf('genrooms #:%d %.2f%%(%d/%d) %ss', numRooms, 100*(numRooms/count), numRooms, count, finish-start)
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
			near1.corridor = true
			near2.corridor = true

			-- We already have the end points of the corridor so we only create
			-- the internal points.
			-- TODO: if numPoints < 1 then something has gone wrong, maybe
			--       assert on it. Need to ensure the layoutgen functions
			--       always leave at least 2*margin distance between rooms.
			
			local numPoints = math.round(distance / margin) - 1

			if distance > margin * 0.75 and numPoints == 0 then
				numPoints = 1
			end

			-- local numPoints = math.max(1, math.round(distance / margin) - 1)
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
					terrain = 'floor',
					corridor = true
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
			cell = { point, hulls = nil }
			grid.set(x, y, cell)
		end

		if point.hull then
			local hulls = cell.hulls

			if hulls then
				hulls[point.hull] = true
			else
				hulls = { [point.hull] = true }
			end
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
				local hulls = {}

				for _, dir in ipairs(dirs) do
					local dx, dy = x + dir[1], y + dir[2]
					
					if 1 <= dx and dx <= width and 1 <= dy and dy <= height then
						local cell = grid.get(dx, dy) or empty
						for _, vertex in ipairs(cell) do
							if Vector.toLength(vertex, candidate) < margin then
								accepted = false
								break
							end
						end
						if cell.hulls then
							for hull, _ in pairs(cell.hulls) do
								hulls[hull] = true
							end
						end
					end

					for hull, _ in pairs(hulls) do
						if convex.contains(hull, candidate) then
							accepted = false
							break
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
	local start = love.timer.getTime()

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
	local walkable = Graph.new()
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

		assertf(#poly >= 6, 'only %d points in hull', #hull)

		graph:addVertex(vertex)
		if vertex.terrain == 'floor' then
			walkable:addVertex(vertex)
		end

		-- This moves the centre of the cells to the centroid of their hull.
		-- It looks a lot better and feels more natural.
		-- NOTE: it means the hulls will look a bit wrong now.
		local centroid = convex.centroid(hull)
		vertex.x, vertex.y = centroid.x, centroid.y
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

			local walkable1 = vertex1.terrain == 'floor'
			local walkable2 = vertex2.terrain == 'floor'

			if walkable1 and walkable2 and not walkable:isPeer(vertex1, vertex2) then
				walkable:addEdge({ length = neighbour.edgeLength }, vertex1, vertex2)
			end
		end
	end

	-- Now add any missing overlay edges (should only be diagonals on grid
	-- based rooms).
	for _, room in ipairs(self.rooms) do
		local overlay = room.overlay
		if overlay then
			for edge, endverts in pairs(overlay.edges) do
				local a, b = endverts[1], endverts[2]
				local walkable1 = a.terrain == 'floor'
				local walkable2 = b.terrain == 'floor'
				assert(walkable1)
				assert(walkable2)

				if not graph:isPeer(a, b) then
					graph:addEdge({}, a, b)
				end				

				if not walkable:isPeer(a, b) then
					walkable:addEdge({}, a, b)
				end
			end
		end
	end

	self.graph = graph
	self.walkable = walkable

	local finish = love.timer.getTime()
	printf('_genvoronoi %.3fs', finish-start)
end

function Level:_gendirs()
	local start = love.timer.getTime()
	local walkable = self.walkable

	local dirmap = {}

	local vdot = Vector.dot
	local vsub = Vector.sub
	local vnorm = Vector.normalise
	local disp = Vector.new { x=0, y=0 }

	local limit = math.cos(math.rad(45))

	for vertex, peers in pairs(walkable.vertices) do
		-- create a list of all dir and peer combinations
		local dirdots = {}
		for dir, dirv in pairs(dirs) do
			local dirdot = dirdots[dir]
			for peer, edge in pairs(peers) do
				vsub(disp, peer, vertex)
				vnorm(disp)
				local dot = vdot(disp, dirv)
				if dot > limit then
					dirdots[#dirdots+1] = {
						dir = dir,
						peer = peer,
						dot = dot
					}
				end
			end
		end

		-- The larger the dot value, the closer to the ideal direction. So by
		-- sorting in this way we get the array in 'best to worst' order.
		table.sort(dirdots,
			function ( lhs, rhs )
				return lhs.dot > rhs.dot
			end)

		-- { [dir] = peer }
		local map = {}
		local taken = {}
		local valence = walkable.valences[vertex]
		local count = 0
		
		-- Go from best to worse choices making sure:
		-- - Each direction has one peer assigned.
		-- - Each peer is assigned to one direction.
		for _, dirdot in ipairs(dirdots) do
			local dir = dirdot.dir
			local peer = dirdot.peer
			if not map[dir] and not taken[peer] then
				map[dir] = peer
				taken[peer] = dir
				count = count + 1

				if count == valence then
					break
				end
			end
		end

		dirmap[vertex] = map

		if count ~= valence then
			vertex.problem = true
			self.dirsProblem = true
			printf('dir problem')
		end
	end

	self.dirmap = dirmap

	local finish = love.timer.getTime()
	printf('_gendirs %.3fs', finish - start)
end

function Level:_genpaths()
	local start = love.timer.getTime()

	self.paths, self.longestPath = self.walkable:allPairsShortestPathsSparse()

	local finish = love.timer.getTime()
	printf('_genpaths %.3fs', finish-start)
end

function Level:_genentry()
	local start = love.timer.getTime()

	local nextId = 1
	local vid = {}

	for vertex in pairs(self.walkable.vertices) do
		vid[vertex] = nextId
		nextId = nextId + 1
	end

	local histogram = {}
	for i = 1, self.longestPath do
		histogram[i] = {}
	end

	local paths = self.paths
	local total = 0
	for v1, v2s in pairs(paths) do
		for v2, distance in pairs(v2s) do
			-- This means we get no duplicates and no 0-length paths.
			if vid[v1] < vid[v2] and not v1.corridor and not v2.corridor then
				local block = histogram[distance]
				block[#block+1] = { v1, v2 }
				total = total + 1
			end
		end
	end

	-- printf('#vertices:%d', nextId-1)
	-- for distance, block in ipairs(histogram) do
	-- 	printf('|%d| #%d', distance, #block)
	-- end

	-- We want a long path between the entry and exit.
	local choiceIndex = math.round(total * 0.95)

	local count = 0
	local entry, exit = nil, nil
	for _, block in ipairs(histogram) do
		local limit = count + #block
		if limit < choiceIndex then
			count = limit
		else
			local relIndex = choiceIndex - count
			local pair = block[relIndex]
			assert(pair)
			entry = pair[1]
			exit = pair[2]
			break
		end
	end

	assert(entry)
	assert(exit)

	self.entry = entry
	entry.entry = true
	self.exit = exit
	exit.exit = true

	local distance = paths[entry][exit]

	local finish = love.timer.getTime()
	printf('_genentry d:%d/%d %.3fs', distance, self.longestPath, finish-start)
end

return Level
