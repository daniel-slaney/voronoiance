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
local convex = require 'src/convex'

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
		hulls = {}
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

function roomgen.hexgrid( bbox, margin, terrain )
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

local function trim( result, graph, overlay )

	for vertex, peers in pairs(graph.vertices) do
		if vertex.terrain == 'wall' then
			local isolated = true
			for other, edge in pairs(peers) do
				if other.terrain ~= 'wall' then
					isolated = false
				end
			end

			if isolated then
				graph:removeVertex(vertex)
				if overlay ~= nil and overlay.vertices[vertex] then
					overlay:removeVertex(overlay)
				end
				
				for i, point in ipairs(result) do
					if point == vertex then
						table.remove(result, i)
						break
					end
				end
			end
		end
	end

	return result, graph, overlay
end

function roomgen.trigrid( bbox, margin, terrain )
	-- printf('roomgen.trigrid')
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	local theta = math.pi / 3
	local xmargin = margin * math.sin(theta)
	local ymargin = margin * math.cos(theta)

	local numx, gapx = math.modf(w / xmargin)
	local numy, gapy = math.modf(h / (margin + ymargin))
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xmin = bbox.xmin + (gapx * 0.5)
	local ymin = bbox.ymin + (gapy * 0.5)

	local rows = {}
	local graph = Graph.new()

	for y = 0, numy-1 do
		local yeven = (y % 2) == 0

		local row = {}

		for x = 0, numx-1 do
			local xeven = (x % 2) == 0

			local vx = xmin + (x * xmargin)
			local vy = ymin + (y * (ymargin + margin)) + (yeven == xeven and 0 or ymargin)

			local terrain = 'floor'
			if y == 0 or y == numy-1 or x == 0 or x == numx-1 then
				terrain = 'wall'
			end

			local v = vertex(vx, vy, terrain)
			result[#result+1] = v
			row[x+1] = v
			graph:addVertex(v)
		end

		rows[y+1] = row
	end

	local same = {
		-- { -1, 0 },
		{ 1, 0 },
		{ 0, -1 }
	}

	local diff = {
		-- { -1, 0 },
		{ 1, 0 },
		-- { 0, -1 }
	}

	local empty = {}

	for y, row in ipairs(rows) do
		local yeven = ((y-1) % 2) == 0
		for x, v in ipairs(row) do
			local xeven = ((x-1) % 2) == 0
			
			local lookup = (yeven == xeven) and same or diff

			for _, dir in ipairs(lookup) do
				local dx, dy = x+dir[1], y+dir[2]

				local dv = (rows[dy] or empty)[dx]
			
				if dv and not graph:isPeer(v, dv) then
					graph:addEdge({}, v, dv)
				end
			end
		end
	end

	-- return result, graph, nil
	return trim(result, graph, nil)
end
	
function roomgen.relaxed( aabb, margin, terrain )
	local start = love.timer.getTime()
	local width = math.ceil(aabb:width() / margin)
	local height = math.ceil(aabb:height() / margin)

	margin = aabb:width() / width

	local points = {}

	local border = 0.4
	for x = 1, width do
		for y = 1, height do
			local cx = aabb.xmin + (x-1) * margin
			local cy = aabb.ymin + (y-1) * margin

			local dx = (margin * border) + math.random() * margin * 2 * border
			local dy = (margin * border) + math.random() * margin * 2 * border
			
			local v = vertex(cx+dx, cy+dy, 'floor')
			points[#points+1] = v
		end
	end

	local bbox = {
		xl = aabb.xmin - margin,
		xr = aabb.xmax + margin,
		yt = aabb.ymin - margin,
		yb = aabb.ymax + margin,
	}

	local voronoi = Voronoi:new()
	local diagram
	local iterations = 0
	local maxIterations = 10

	repeat
		local iterstart = love.timer.getTime()
		diagram = voronoi:compute(points, bbox)

		local maxdisp = 0

		for _, cell in ipairs(diagram.cells) do
			if #cell.halfedges >= 3 then
				local hull = {}
				
				for _, halfedge in ipairs(cell.halfedges) do
					local start = halfedge:getStartpoint()
					hull[#hull+1] = start
				end

				assertf(#hull > 2, 'hull has %d points', #hull)

				hull = convex.hull(hull)

				local centroid = convex.centroid(hull)
				local site = cell.site
				local disp = Vector.toLength(site, centroid)
				maxdisp = math.max(disp, maxdisp)
				site.x, site.y = centroid.x, centroid.y
			else
				for i = 1, #points do
					if points[i] == cell.site then
						table.remove(points, i)
						break
					end
				end
			end
		end

		local minedge = math.huge
		local minspacing = math.huge
		for _, edge in ipairs(diagram.edges) do
            local lSite = edge.lSite
            local rSite = edge.rSite
            if lSite and rSite then
                local edgeLen = Vector.toLength(edge.va, edge.vb)
                minedge = math.min(edgeLen, minedge)
                local spacing = Vector.toLength(lSite, rSite)
                minspacing = math.min(spacing, minspacing)
            end
		end

		local dispPC = 100 * (maxdisp/margin)
		local minedgePC = 100 * (minedge/margin)
		-- printf('#%d max |s|:%.2f %.1f%% minedge:%.1f%% spacing:%.2f', iterations, maxdisp, dispPC, minedgePC, minspacing)

		iterations = iterations + 1
		local done = iterations == maxIterations
		-- We allow relaxed rooms to be slightly closer packed than normal
		local spaced = minspacing >= margin * 0.8
		local spread = minedgePC > 5
	until done or (spaced and spread)

	local graph = Graph.new()

	for _, point in ipairs(points) do
		graph:addVertex(point)
	end

	for _, cell in ipairs(diagram.cells) do
		local point = cell.site
		local border = false
		
		for _, halfedge in ipairs(cell.halfedges) do
			local lSite = halfedge.edge.lSite
			local rSite = halfedge.edge.rSite

			if lSite and rSite and not graph:isPeer(lSite, rSite) then
				graph:addEdge({}, lSite, rSite)
			end
		end
	end

	local finish = love.timer.getTime()

	printf('relexad %.3fs', finish-start)

	return points, graph, nil
end


local function brownian( genfunc )
	return
		function ( bbox, margin )
			local points, graph, overlay = genfunc(bbox, margin)

			local centre = bbox:centre()
			local floors = {}
			local mindisp = math.huge
			local seed = nil
			for _, point in ipairs(points) do
				if point.terrain == 'floor' and next(graph.vertices[point]) ~= nil then
					floors[point] = true
					local disp = Vector.toLength(centre, point)
					if disp < mindisp then
						mindisp = disp
						seed = point
					end
				end
			end

			assert(seed ~= nil)

			local numFloors = table.count(floors)
			assert(numFloors >= 4)
			local point = seed

			local found = { [point] = true }
			local count = 1
			
			local maxCount = math.round(numFloors * 0.75)
			local minCount = math.round(numFloors * 0.5)

			while count < maxCount do
				local peer = table.random(graph.vertices[point])

				if peer.terrain == 'floor' then
					if not found[peer] then
						found[peer] = true
						count = count + 1
					end
					point = peer
				else
					if math.random(1, 5) == 1 then
						break
					end
					-- hit a wall so let's restart
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
roomgen.browniantrigrid = brownian(roomgen.trigrid)
roomgen.brownianenclose = brownian(roomgen.enclose)
roomgen.brownianrelaxed = brownian(roomgen.relaxed)

local _genfuncs = {
	roomgen.browniangrid,
	roomgen.brownianhexgrid,
	roomgen.brownianrelaxed,
	roomgen.browniantrigrid
	-- roomgen.trigrid
}

function roomgen.random( bbox, margin )
	local genfunc = _genfuncs[math.random(1, #_genfuncs)]

	return genfunc(bbox, margin)
end

return roomgen
