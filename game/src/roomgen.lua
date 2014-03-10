--
-- roomgen.lua
--
-- The roomgen table contained function with the following signature:
--
--   roomgen.<func>( aabb, margin )
--
-- An array of points is the result.
--

local newgrid = require 'src/newgrid'
local Graph = require 'src/Graph'

local roomgen = {
	grid = nil,
}

local function vertex( x, y, terrain )
	-- assert(terrain)
	-- assert(fringe ~= nil or terrain == terrains.filler)

	return {
		x = x,
		y = y,
		terrain = terrain or 'floor',
	}
end

function roomgen.grid( bbox, margin, terrain, fringe )
	local points = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * margin)

			points[#points+1] = vertex(x, y, terrain, fringe)
		end
	end

	return points
end

function roomgen.walledgrid( bbox, margin, terrain, fringe )
	local points = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * margin)

			if x == 0 or x == numx-1 or y == 0 or y == numy-1 then
				points[#points+1] = vertex(x, y, terrains.filler, nil)
			else
				points[#points+1] = vertex(x, y, terrain, fringe)
			end
		end
	end

	return points
end

function roomgen.browniangrid( bbox, margin, terrain, fringe )
	local points = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local mask = newgrid(numx, numy, false)

	local centrex, centrey = math.floor(0.5 + (numx * 0.5)), math.floor(0.5 + (numy * 0.5))
	local x, y = centrex, centrey
	local walked = 0
	local maxattempts = 2 * numx * numy

	local dirs = {
		{  0, -1 },
		{  0,  1 },
		{ -1,  0 },
		{  1,  0 },
	}

	local xmin, xmax = numx, 1
	local ymin, ymax = numy, 1

	repeat
		mask.set(x, y, true)
		local dir = dirs[math.random(1, #dirs)]
		x = x + dir[1]
		y = y + dir[2]
		if (x < 1 or numx < x) or (y < 1 or numy < y) then
			if walked > maxattempts * 0.25 and math.random(1, 3) == 1 then
				break
			else
				-- break
				x = centrex
				y = centrey
			end
		end
		xmin = math.min(xmin, x)
		xmax = math.max(xmax, x)
		ymin = math.min(ymin, y)
		ymax = math.max(ymax, y)
		walked = walked + 1
	until walked > maxattempts 

	-- mask.print()
	-- print(x, y, numx, numy)


	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			if mask.get(x+1, y+1) then
				local x = xoffset + (x * margin)
				local y = yoffset + (y * margin)

				points[#points+1] = vertex(x, y, terrain, fringe)
			end
		end
	end

	return points
end

function roomgen._brownianhexgrid( bbox, margin, terrain, fringe )
	local points = {}

	local w = bbox:width()
	local h = bbox:height()

	local ymargin = math.sqrt(0.75) * margin

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / ymargin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local mask = newgrid(numx, numy, false)

	local centrex, centrey = math.floor(0.5 + (numx * 0.5)), math.floor(0.5 + (numy * 0.5))
	local x, y = centrex, centrey
	local walked = 0
	local maxattempts = 2 * numx * numy

	local dirs = {
		{  0, -1 },
		{  0,  1 },
		{ -1,  0 },
		{  1,  0 },
	}

	local xmin, xmax = numx, 1
	local ymin, ymax = numy, 1

	repeat
		mask.set(x, y, true)
		local dir = dirs[math.random(1, #dirs)]
		x = x + dir[1]
		y = y + dir[2]
		if (x < 1 or numx < x) or (y < 1 or numy < y) then
			if walked > maxattempts * 0.25 and math.random(1, 3) == 1 then
				break
			else
				-- break
				x = centrex
				y = centrey
			end
		end
		xmin = math.min(xmin, x)
		xmax = math.max(xmax, x)
		ymin = math.min(ymin, y)
		ymax = math.max(ymax, y)
		walked = walked + 1
	until walked > maxattempts 

	-- mask.print()
	-- print(x, y, numx, numy)

	local xmin = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for y = 1, numy do
		local even = ((y-1) % 2) == 0
		local xoffset = xmin + (even and 0.5 or 0) * margin

		for x = 1, numx-(even and 1 or 0) do
			if mask.get(x, y) then
				local x = xoffset + ((x-1) * margin)
				local y = yoffset + ((y-1) * ymargin)

				points[#points+1] = vertex(x, y, terrain, fringe)
			-- elseif mask.anyFourwayNeighboursSet(x, y) then
			-- 	points[#points+1] = vertex(x, y, terrains.filler, fringes.empty)
			end
		end
	end

	return points
end

function roomgen.brownianhexgrid( bbox, margin )
	local points, graph = roomgen.hexgrid(bbox, margin)

	local floors = {}
	for _, point in ipairs(points) do
		if point.terrain == 'floor' then
			floors[point] = true
		end
	end

	local numFloors = table.count(floors)
	local point = table.random(floors)
	local found = { [point] = true }
	local count = 1
	local max = numFloors * 0.75
	local attempts = 0
	local maxAttempts = 2 * numFloors

	while count < max and attempts < maxAttempts do
		local peer = table.random(graph.vertices[point])
		attempts = attempts + 1

		if peer.terrain == 'floor' then
			if not found[peer] then
				found[peer] = true
				count = count + 1
			end
			point = peer
		elseif math.random(1, 3) == 1 then
			break
		end
	end

	local newPoints = {}
	local newGraph = Graph.new()

	local walls = graph:multiSourceDistanceMap(found, 1)
	for point, depth in pairs(walls) do
		if depth == 1 then
			point.terrain = 'wall'
		end
		newPoints[#newPoints+1] = point
		newGraph:addVertex(point)
	end

	local newVertices = newGraph.vertices
	for edge, endverts in pairs(graph.edges) do
		local a, b = endverts[1], endverts[2]
		if newVertices[a] and newVertices[b] then
			newGraph:addEdge({}, a, b)
		end
	end

	return newPoints, newGraph
end

function roomgen.cellulargrid( bbox, margin, terrain, fringe )

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local old, new = newgrid(numx, numy, false), newgrid(numx, numy, false)

	local centrex, centrey = math.floor(0.5 + (numx * 0.5)), math.floor(0.5 + (numy * 0.5))

	local dirs = {
		{  0, -1 },
		{  0,  1 },
		{ -1,  0 },
		{  1,  0 },
		{  -1, -1 },
		{  -1,  1 },
		{  1,  -1 },
		{  1,  1 },
	}
	
	local area = numx * numy
	local leastAlive = math.round(area * 0.4)
	local mostAlive = math.round(area * 0.6)
	local numAlive = math.random(leastAlive, mostAlive)

	local alive = {}

	for i = 1, area do
		alive[i] = i <= numAlive
	end

	table.shuffle(alive)

	for y = 1, numx do
		for x = 1, numy do
			old.set(x, y, alive[(y-1) * numx + x])
		end
	end

	-- print('init')
	-- old.print()

	local passes = 4
	local birth = 3
	local survive = 2
	-- This controls whether cells outside the grid are counted as alive.
	local offMaskIsAlive = false

	for i = 1, passes do
		for y = 1, numx do
			for x = 1, numy do
				local count = 0

				for _, dir in ipairs(dirs) do
					local nx, ny = x + dir[1], y + dir[2]

					if 1 <= nx and nx <= numx and 1 <= ny and ny <= numy then
						count = count + (old.get(nx, ny) and 1 or 0)
					elseif offMaskIsAlive then
						-- The edges of the mask count as alive.
						count = count + 1
					end
				end

				local cell = old.get(x, y)

				if cell then
					new.set(x, y, count > survive)
				else
					new.set(x, y, count >= birth)
				end
			end
		end

		-- new.print()
		-- print()

		new, old = old, new
	end

	local mask = old

	new.print()
	print()
	
	local result = {}

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			if mask.get(x+1, y+1) then
				local x = xoffset + (x * margin)
				local y = yoffset + (y * margin)

				result[#result+1] = vertex(x, y, terrain, fringe)
			end
		end
	end

	-- print('#points', #result)

	return result
end

function roomgen.randgrid( bbox, margin, terrain, fringe )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	-- print(w, margin, numx, gapx)

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * margin)

			if math.random() > 0.33 then
				result[#result+1] = vertex(x, y, terrain, fringe)
			end
		end
	end

	return result
end

function roomgen.hexgrid( bbox, margin, terrain, fringe )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	local ymargin = math.sqrt(0.75) * margin

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / ymargin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xmin = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	local rows = {}
	local graph = Graph.new()

	for y = 0, numy-1 do
		local even = (y % 2) == 0
		local xoffset = xmin + (even and 0.5 or 0) * margin
		local lastx = numx-(even and 2 or 1)

		local row = {}

		for x = 0, lastx do
			local vx = xoffset + (x * margin)
			local vy = yoffset + (y * ymargin)

			local terrain = 'floor'
			if y == 0 or y == numy-1 or x == 0 or x == lastx then
				terrain = 'wall'
			end

			local v = vertex(vx, vy, terrain)
			result[#result+1] = v
			row[x+1] = v
			graph:addVertex(v)
		end

		rows[y+1] = row
	end

	local yodd = {
		{ 0, -1 },
		{ 1, -1 },
		{ -1, 0 },
		{ 1, 0 },
		{ 0, 1 },
		{ 1, 1 },
	}

	local yeven = {
		{ -1, -1 },
		{ 0, -1 },
		{ -1, 0 },
		{ 1, 0 },
		{ -1, 1 },
		{ 0, 1 },
	}

	local empty = {}

	for y, row in ipairs(rows) do
		for x, v in ipairs(row) do
			local lookup = (y % 2 == 0) and yeven or yodd

			for _, dir in ipairs(lookup) do
				local dx, dy = x+dir[1], y+dir[2]

				local dv = (rows[dy] or empty)[dx]
			
				if dv and not graph:isPeer(v, dv) then
					graph:addEdge({}, v, dv)
				end
			end
		end
	end

	return result, graph
end

function roomgen.randhexgrid( bbox, margin, terrain, fringe )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	local ymargin = math.sqrt(0.75) * margin

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / ymargin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xmin = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for y = 0, numy-1 do
		local even = (y % 2) == 0
		local xoffset = xmin + (even and 0.5 or 0) * margin

		for x = 0, numx-(even and 2 or 1) do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * ymargin)

			if math.random() > 0.33 then
				result[#result+1] = vertex(x, y, terrain, fringe)
			end
		end
	end

	return result
end

-- ensure all points are at least margin apart.
-- TODO: make this less terribly inefficient and stupid
local function _sanitise( bbox, margin, points )
	local result = {}

	for i, v in ipairs(points) do
		result[i] = vertex(v[1], v[2], v.terrain)
	end

	local count = 0
	local starti, startj = 1, 2

	repeat
		local modified = false

		for i = 1, #result do
			for j = i+1, #result do
				count = count + 1

				local point1 = result[i]
				local point2 = result[j]

				if point1:toLength(point2) < margin then
					-- local killindex = (math.random() >=  0.5) and i or j
					local killindex = math.min(i, j)

					-- print('kill', killindex)

					result[killindex] = result[#result]
					result[#result] = nil

					modified = true
					break
				end
			end

			if modified then
				break
			end
		end
	until not modified

	print('count', count, count / #result)

	return result
end

function roomgen.random( bbox, margin, terrain, fringe )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	-- TODO: Don't always try and fill the area.
	local numpoints = 1.5 * ((w * h) / (margin * margin))

	for i = 1, numpoints do
		result[#result+1] = vertex(
			math.random(bbox.xmin, bbox.xmax),
			math.random(bbox.ymin, bbox.ymax),
			terrain)
	end

	result = _sanitise(bbox, margin, result)

	return result
end

-- Based on the _enclose() function in Level.lua.
function roomgen.enclose( aabb, margin, terrain, fringe )
	local width = math.ceil(aabb:width() / margin)
	local height = math.ceil(aabb:height() / margin)

	margin = aabb:width() / width

	local grid = newgrid(width, height, false)

	-- grid.print()

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

	local result = {}

	for x= 1, width do
		for y = 1, height do
			-- if not grid.get(x, y) then
				for attempt = 1, 10 do
					-- local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
					-- local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

					local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
					local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

					local candidate = vertex(rx, ry, terrain, fringe)
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
						-- break
					end
				end
			-- end
		end
	end

	return result
end

return roomgen
