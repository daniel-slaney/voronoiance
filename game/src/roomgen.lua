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
local Voronoi = require 'src/Voronoi'
local Vector = require 'src/Vector'

local roomgen = {
	grid = nil,
}

local function vertex( x, y, terrain )
	return {
		x = x,
		y = y,
		terrain = terrain or 'floor',
		-- These are added in Level.lua
		poly = nil,
		hull = nil,
	}
end

function roomgen.grid( bbox, margin )
	-- printf('roomgen.grid')
	local points = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	assert(numx >= 3)
	assert(numy >= 3)

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	local columns = {}
	local graph = Graph.new()
	-- The corners causes issues for corridor generation so don't create them.
	local forbidden = {
		[0] = { [0] = true, [numy-1] = true },
		[numx-1] = { [0] = true, [numy-1] = true },
	}	

	local empty = {}
	for x = 0, numx-1 do
		local column = {}
		for y = 0, numy-1 do
			if not (forbidden[x] or empty)[y] then
				local vx = xoffset + (x * margin)
				local vy = yoffset + (y * margin)

				local terrain = 'floor'

				if x == 0 or x == numx-1 or y == 0 or y == numy-1 then
					terrain = 'wall'
				end

				local v = vertex(vx, vy, terrain)
				points[#points+1] = v
				column[y+1] = v
				graph:addVertex(v)
			end
		end
		columns[x+1] = column
	end

	local dirs = {
		-- {  0, -1 },
		-- { -1, 0 },
		{  1, 0 },
		{  0, 1 },
	}

	local empty = {}
	for x, column in ipairs(columns) do
		for y, v in ipairs(column) do
			for _, dir in ipairs(dirs) do
				local dx, dy = x+dir[1], y+dir[2]
				local dv = (columns[dx] or empty)[dy]

				if dv and not graph:isPeer(v, dv) then
					graph:addEdge({}, v, dv)
				end
			end
		end
	end

	local ur = {
		{ 0, 0 },
		{ 0, 1 },
		{ 1, 0 },
		{ 1, 1 }
	}

	local ul = {
		{ 0, 0 },
		{ 0, 1 },
		{ -1, 0 },
		{ -1, 1 }
	}

	local dirs = {
		{  1, 1, contingent = ur },
		{ -1, 1, contingent = ul },
	}

	local overlay = Graph.new()
	for x, column in ipairs(columns) do
		for y, v in ipairs(column) do
			if v.terrain == 'floor' then
				overlay:addVertex(v)
			end
		end
	end

	local vertices = overlay.vertices
	for x, column in ipairs(columns) do
		for y, v in ipairs(column) do
			if vertices[v] then
				for _, dir in ipairs(dirs) do
					local dx, dy = x+dir[1], y+dir[2]
					local dv = (columns[dx] or empty)[dy]

					if dv then
						local dependencies = {}
						local valid = true
						for _, cdir in ipairs(dir.contingent) do
							local cx, cy = x+cdir[1], y+cdir[2]
							local cv = (columns[cx] or empty)[cy]

							if cv and cv.terrain == 'floor' then
								dependencies[cv] = true
							else
								valid = false
								break
							end
						end

						if valid then
							if not overlay:isPeer(v, dv) then
								assert(v.terrain == 'floor')
								assert(dv.terrain == 'floor')
								overlay:addEdge({ dependencies = dependencies }, v, dv)
							end
						end
					end
				end
			end
		end
	end

	return points, graph, overlay
end

function roomgen.hexgrid( bbox, margin, terrain, fringe )
	-- printf('roomgen.hexgrid')
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

	return result, graph, nil
end

-- Based on the _enclose() function in Level.lua.
function roomgen.enclose( aabb, margin, terrain, fringe )
	-- printf('roomgen.enclose')
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

	local points = {}

	for x= 1, width do
		for y = 1, height do
			-- if not grid.get(x, y) then
				for attempt = 1, 10 do
					-- local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
					-- local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

					local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
					local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

					local candidate = vertex(rx, ry, 'floor')
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

						points[#points+1] = candidate
						-- break
					end
				end
			-- end
		end
	end

	local bbox = {
		xl = aabb.xmin,
		xr = aabb.xmax,
		yt = aabb.ymin,
		yb = aabb.ymax,
	}

	local diagram = Voronoi:new():compute(points, bbox)
	local graph = Graph.new()

	for _, point in ipairs(points) do
		graph:addVertex(point)
	end

	-- First add the vertices and contruct the polygon for the vertices.
	for _, cell in ipairs(diagram.cells) do
		local point = cell.site
		local border = false
		
		for _, halfedge in ipairs(cell.halfedges) do
			local lSite = halfedge.edge.lSite
			local rSite = halfedge.edge.rSite
			
			-- not site means it's an border cell which we'll turn into a wall.
			if lSite == nil or rSite == nil then
				point.terrain = 'wall'
			elseif not graph:isPeer(lSite, rSite) then
				graph:addEdge({}, lSite, rSite)
			end
		end
	end

	-- we only want one thick walls so kill any wall points with only wall peers.
	for vertex, peers in pairs(graph.vertices) do
		if vertex.terrain == 'wall' then
			local cull = true
			for peer, _ in pairs(peers) do
				if peer.terrain == 'floor' then
					cull = false
					break
				end
			end

			if cull then
				graph:removeVertex(vertex)
				for i = 1, #points do
					if vertex == points[i] then
						table.remove(points, i)
						break
					end
				end
			end
		end
	end

	return points, graph, nil
end


local function brownian( genfunc )
	return
		function ( bbox, margin )
			local points, graph, overlay = genfunc(bbox, margin)

			local floors = {}
			for _, point in ipairs(points) do
				if point.terrain == 'floor' and next(graph.vertices[point]) ~= nil then
					floors[point] = true
				end
			end

			local numFloors = table.count(floors)
			local point = table.random(floors)
			local seed = point
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
				else
					point = seed
				end
			end

			local newPoints = {}
			local newGraph = Graph.new()
			local newOverlay = Graph.new()

			local walls = graph:multiSourceDistanceMap(found, 1)
			for point, depth in pairs(walls) do
				if depth == 1 then
					point.terrain = 'wall'
				end
				newPoints[#newPoints+1] = point
				newGraph:addVertex(point)
				if depth == 0 then
					newOverlay:addVertex(point)
				end
			end

			local newVertices = newGraph.vertices
			for edge, endverts in pairs(graph.edges) do
				local a, b = endverts[1], endverts[2]
				if newVertices[a] and newVertices[b] then
					newGraph:addEdge({}, a, b)
				end
			end

			if overlay then
				local selected = newOverlay.vertices
				for edge, endverts in pairs(overlay.edges) do
					local a, b = endverts[1], endverts[2]

					if selected[a] and selected[b] then
						local dependencies = edge.dependencies

						local valid = true
						for point in pairs(dependencies) do
							if not selected[point] then
								valid = false
								break
							end
						end

						if valid then
							newOverlay:addEdge({}, a, b)
						end
					end
				end
			end

			return newPoints, newGraph, newOverlay
		end
end

roomgen.browniangrid = brownian(roomgen.grid)
roomgen.brownianhexgrid = brownian(roomgen.hexgrid)
roomgen.brownianenclose = brownian(roomgen.enclose)

local _genfuncs = {
	roomgen.browniangrid,
	-- roomgen.grid,
	roomgen.brownianhexgrid,
	roomgen.brownianenclose,
}

function roomgen.random( bbox, margin )
	local genfunc = _genfuncs[math.random(1, #_genfuncs)]

	return genfunc(bbox, margin)
end

return roomgen
