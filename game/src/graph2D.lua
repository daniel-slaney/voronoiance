--
-- graph2D.lua
--
-- Utility functions of graphs with vertices that're 2D vectors.
-- 

require 'Graph'
require 'Vector'
require 'graphgen'
local AABB = require 'lib/AABB'

graph2D = {}

function graph2D.aabb( graph )
	assert(not graph:isEmpty())

	local xmin, xmax = math.huge, -math.huge
	local ymin, ymax = math.huge, -math.huge

	for vertex, _ in pairs(graph.vertices) do
		xmin = math.min(xmin, vertex.x)
		xmax = math.max(xmax, vertex.x)
		ymin = math.min(ymin, vertex.y)
		ymax = math.max(ymax, vertex.y)
	end

	return AABB.new {
		xmin = xmin,
		xmax = xmax,
		ymin = ymin,
		ymax = ymax,
	}
end

function graph2D.matchAABB( match )
	local xmin, xmax = math.huge, -math.huge
	local ymin, ymax = math.huge, -math.huge

	for _, vertex in pairs(match) do
		xmin = math.min(xmin, vertex.x)
		xmax = math.max(xmax, vertex.x)
		ymin = math.min(ymin, vertex.y)
		ymax = math.max(ymax, vertex.y)
	end

	return AABB.new {
		xmin = xmin,
		xmax = xmax,
		ymin = ymin,
		ymax = ymax,
	}
end

function graph2D.nearest( graph1, graph2 )
	local mindist = math.huge
	local near1, near2 = nil, nil

	for vertex1, _ in pairs(graph1.vertices) do
		for vertex2, _ in pairs(graph2.vertices) do
			local distance = Vector.toLength(vertex1, vertex2)

			if distance < mindist then
				mindist = distance
				near1, near2 = vertex1, vertex2
			end
		end
	end

	return mindist, near1, near2
end


function graph2D.connect( graph, rooms )
	local centres = {}

	for _, room in ipairs(rooms) do
		local centre = graph2D.aabb(room):centre()

		centre.room = room

		centres[#centres+1] = centre
	end

	local skele = graphgen.rng(centres)

	for edge, verts in pairs(skele.edges) do
		local room1, room2 = verts[1].room, verts[2].room
		local mindist, near1, near2 = graph2D.nearest(room1, room2)

		if near1 and near2 then
			graph:addEdge({ length = mindist }, near1, near2)
		end
	end
end

-- For each vertex with more than one incident edge sort the edges by their
-- angle and calculate the signed angle between neighboring edges.
function graph2D.spurs( graph )
	-- { [vertex] = { { edge1 , edge2, signedAngle} }+ }*
	local result = {}
	for vertex, peers in pairs(graph.vertices) do
		-- Create an array of edges, sorted by their angle.
		local winding = {}

		for other, edge in pairs(peers) do
			local to = Vector.to(vertex, other)
			local angle = math.atan2(to.y, to.x)
			winding[#winding+1] = { angle = angle, edge = edge, to = to }
		end

		if #winding >= 2 then
			table.sort(winding,
				function ( lhs, rhs )
					return lhs.angle < rhs.angle
				end)

			local edgePairs = {}

			-- Now create the lists of edge pairs with signed angles between them.
			for index = 1, #winding do
				local winding1 = winding[index]
				local nextIndex = (index < #winding) and index or 1
				local winding2 = winding[nextIndex]

				local edge1, to1 = winding1.edge, winding1.to
				local edge2, to2 = winding2.edge, winding2.to

				edgePairs[#edgePairs+1] = {
					edge1 = edge1,
					edge2 = edge2,
					signedAngle = to1:signedAngle(to2),
				}
			end

			result[vertex] = edgePairs
		end
	end

	return result
end

function graph2D.subdivide( graph, margin )
	local subs = {}

	for edge, endverts in pairs(graph.edges) do
		local numpoints = math.floor(Vector.toLength(endverts[1], endverts[2]) / margin) - 1

		if numpoints > 0 then
			local length = edge.length / (numpoints + 1)
			local start, finish = endverts[1], endverts[2]
			assert(start ~= finish)
			local normal = Vector.to(start, finish):normalise()

			local vertices = { start }

			for i = 1, numpoints do
				local vertex = Vector.new {
					x = start.x + (i * length * normal.x),
					y = start.y + (i * length * normal.y),
				}

				vertex.subdivide = true

				graph:addVertex(vertex)

				vertices[#vertices+1] = vertex
			end

			vertices[#vertices+1] = finish

			subs[#subs+1] = {
				vertices = vertices,
				length = length,
			}
			
			graph:removeEdge(edge)
		end
	end

	for _, sub in ipairs(subs) do
		for i = 1, #sub.vertices-1 do
			graph:addEdge({ length = sub.length }, sub.vertices[i], sub.vertices[i+1])
		end
	end
end

-- This sets the vertex position as a side effect.
function graph2D.forceDraw(
	graph,
	springStrength,
	edgeLength,
	repulsion,
	maxDelta,
	convergenceDistance,
	yield )

	local start = love.timer.getTime()

	local forces = {}
	local vertices = {}

	for vertex, _ in pairs(graph.vertices) do
		forces[vertex] = Vector.new { x = 0, y = 0 }
		-- vertex.force = forces[vertex]
		vertices[#vertices+1] = vertex
	end

	local converged = false
	-- The edge-edge forces are not employed straightaway.
	local edgeForces = false
	local count = 0

	while not converged do
		for i = 1, #vertices-1 do
			local vertex = vertices[i]
			local peers = graph.vertices[vertex]

			-- Vertex-vertex forces.
			for j = i+1, #vertices do
				local other = vertices[j]
				-- assert(vertex ~= other)
				local edge = peers[other]

				if edge then
					local to = Vector.to(vertex, other)
					local d = to:length()

					-- Really short edges cause trouble.
					d = math.max(d, 0.5)

					local desiredLength = (edge.length or edgeLength) * (edge.lengthFactor or 1)

					-- Use log with base sqrt(2) so that overly long edges pull
					-- together a bit more.
					local f = -springStrength * math.log(d/desiredLength, math.sqrt(2))

					-- If you specify a length we ensure it is never less that
					-- what is provided.
					if edge.length and d < edge.length then
						f = 100
					end

					local vforce = forces[vertex]
					local oforce = forces[other]

					vforce.x = vforce.x - (to.x * f)
					vforce.y = vforce.y - (to.y * f)

					oforce.x = oforce.x + (to.x * f)
					oforce.y = oforce.y + (to.y * f)
				else
					local to = Vector.to(vertex, other)
					local d = to:length()

					local c = (vertex.radius or 0) + (other.radius or 0)
					d = d - c

					-- Really short edges cause trouble.
					d = math.max(d, 0.5)


					-- This 'normalises' the repulsive force which means we
					-- don't need to scale it if we change edgeLength.
					d = d / edgeLength

					-- TODO: this is a magic number and needs to be made a
					--       parameter, does seem to impove matters though.
					if d < 3 then
						local f = repulsion * (1 / (d*d))

						-- If we're too close, push back very hard.
						if d == 0.5 then
							f = 100
						end

						local vforce = forces[vertex]
						local oforce = forces[other]

						vforce.x = vforce.x - (to.x * f)
						vforce.y = vforce.y - (to.y * f)

						oforce.x = oforce.x + (to.x * f)
						oforce.y = oforce.y + (to.y * f)
					end
				end
			end

			-- The edge-edge force really halp to balnce the graph out but if
			-- they're applied to early they can force strange configurations.
			if edgeForces then
				-- Now edge-edge forces.
				local edges = {}
				for other, edge in pairs(peers) do
					local to = Vector.to(vertex, other)
					local angle = math.atan2(to.y, to.x)

					edges[#edges+1] = { angle, edge, other, to }
				end

				if #edges >= 2 then
					-- This puts the edges into counter-clockwise order.
					table.sort(edges,
						function ( lhs, rhs )
							return lhs[1] < rhs[1]
						end)

					for index = 1, #edges do
						local angle1, edge1, other1, to1 = unpack(edges[index])
						local nextIndex = (index == #edges) and 1 or index+1
						local angle2, edge2, other2, to2 = unpack(edges[nextIndex])

						-- TODO: really should be an argument...
						local edgeRepulse = 1

						if to1:length() > 0.001 and to2:length() > 0.001 then
							to1:normalise()
							to2:normalise()
							local dot = to1:dot(to2)

							local f = edgeRepulse * dot

							local o1force = forces[other1]
							local o2force = forces[other2]

							local dir1 = to1:antiPerp()
							local dir2 = to2:perp()

							o1force.x = o1force.x + (dir1.x * f)
							o1force.y = o1force.y + (dir1.y * f)

							o2force.x = o2force.x + (dir2.x * f)
							o2force.y = o2force.y + (dir2.y * f)
						end
					end
				end
			end
		end

		converged = true
		local maxForce = 0

		for _, vertex in ipairs(vertices) do
			local force = forces[vertex]
			local l = force:length()

			maxForce = math.max(l, maxForce)

			-- Are we there yet?
			if l > convergenceDistance then
				-- No...
				converged = false
			end

			-- Don't allow too much movement.
			if l > maxDelta then
				force:scale(maxDelta/l)
			end

			vertex.x = vertex.x + force.x
			vertex.y = vertex.y + force.y
		end

		-- printf('maxForce:%.2f conv:%.2f', maxForce, convergenceDistance)

		-- We only start to apply edge forces once we're converged.
		if converged and not edgeForces then
			converged = false
			edgeForces = true
		end

		-- Only show every 10 iterations or it's just too slow to be useful.
		if yield and count % 10 == 0 then
			coroutine.yield(graph)
		end

		count = count + 1

		if count % 100 == 0 then
			-- TODO: maybe make this a parameter.
			convergenceDistance = convergenceDistance * 1.5
			-- This is a quite busy print statement but useful for debugging.
			-- printf('  #%d maxForce:%.2f conv:%.2f', count, maxForce, convergenceDistance)
		end
	end

	local finish = love.timer.getTime()
	local delta = finish-start
	printf('  forceDraw:%.2fs runs:%d runs/s:%.3f conv:%.2f', delta, count, count / delta, convergenceDistance)
end

-- TODO: circles aren't very flexible, maybe axis aligned elipses or just use
--       the convex hulls of the rooms.
function graph2D.assignRoomsAndRelax( graph, theme, yield )
	local margin = theme.margin
	local radiusFudge = theme.radiusFudge
	local tags = theme.tags

	local preRoomSelfIntersect = graph2D.isSelfIntersecting(graph)

	for vertex, _ in pairs(graph.vertices) do
		local params = theme
		
		if tags then
			params = tags[vertex.tag] or params
		end

		local extent = math.random(params.minExtent, params.maxExtent)

		local aabb = AABB.new {
			xmin = 0,
			xmax = extent * margin,
			ymin = 0,
			ymax = extent * margin,
		}

		local points
		local hull
		local centroid

		-- This is to avoid rooms without enough verts or invalid centroids.
		repeat
			points = params.roomgen(aabb, margin, params.terrain, params.fringe)
			local enoughPoints = #points > 2
			local finiteCentroid = false
			
			if enoughPoints then			
				hull = geometry.convexHull(points)
				-- NOTE: This returns NaNs and infinities every now and again.
				--       Probably because of colinear points.
				centroid = geometry.convexHullCentroid(hull)

				-- NaN check.
				finiteCentroid = math.finite(centroid.x) and math.finite(centroid.y)
			end
		until enoughPoints and finiteCentroid

		local furthest, distance =  geometry.furthestPointFrom(centroid, hull)
		local radius = distance + (radiusFudge * margin)
		
		-- This moves the hull as well becuase the points aren't copied by
		-- geometry.convexHull().
		for _, point in ipairs(points) do
			point.x = point.x - centroid.x
			point.y = point.y - centroid.y
		end

		-- Recalc the AABB from the actual points.
		aabb = AABB.newFromPoints(points)

		vertex.aabb = aabb
		vertex.points = points
		vertex.hull = hull
		vertex.centroid = Vector.new { x = 0, y = 0 }
		vertex.fringe = params.fringe

		-- forceDraw() knows about the radius and treats it properly-ish.
		vertex.radius = radius
	end

	local maxScale = 0

	-- Find out the desired edge length so the circles don't intersect.
	for edge, endverts in pairs(graph.edges) do
		-- local distance = radiusFudge + (endverts[1].radius + endverts[2].radius)
		local distance = (margin * radiusFudge) + (endverts[1].radius + endverts[2].radius)
		local length = Vector.toLength(endverts[1], endverts[2])

		local scale = distance / length
		maxScale = math.max(maxScale, scale)

		edge.length = distance
	end


	-- printf('maxScale:%.2f', maxScale)

	-- Add a little extra to the maxScale as breathing room.
	maxScale = maxScale * 1.1

	-- Scale the graph up so that no aabbs intersect.
	local aabb = graph2D.aabb(graph)
	local centre = aabb:centre()

	for vertex, _ in pairs(graph.vertices) do
		local disp = Vector.to(centre, vertex)
		disp:scale(maxScale)

		vertex.x, vertex.y = centre.x + disp.x, centre.y + disp.y
	end

	local preScaleSelfIntersect = graph2D.isSelfIntersecting(graph)

	-- Use force drawing to relax the size of the graph.
	graph2D.forceDraw(
		graph,
		theme.relaxSpringStrength,
		theme.relaxEdgeLength,
		theme.relaxRepulsion,
		theme.relaxMaxDelta,
		theme.relaxConvergenceDistance,
		yield)

	-- Now we set all the vertices and points to integer coordinates.
	for vertex, _ in pairs(graph.vertices) do
		vertex.x = math.round(vertex.x)
		vertex.y = math.round(vertex.y)

		for _, point in ipairs(vertex.points) do
			point.x = math.round(point.x)
			point.y = math.round(point.y)
		end
	end

	local postScaleSelfIntersect = graph2D.isSelfIntersecting(graph)

	printf('[relax] pre-room:%s pre-scale:%s post-scale:%s',
		tostring(preRoomSelfIntersect),
		tostring(preScaleSelfIntersect),
		tostring(postScaleSelfIntersect))

	local br = preRoomSelfIntersect and 't' or 'f'
	local bs = preScaleSelfIntersect and 't' or 'f'
	local as = postScaleSelfIntersect and 't' or 'f'

	return graph, string.format("%s-%s-%s", br, bs, as)
end

function graph2D.meanEdgeLength( graph )
	local totalLength = 0
	local count = 0

	for edge, endverts in pairs(graph.edges) do
		totalLength = totalLength + Vector.toLength(endverts[1], endverts[2])
		count = count + 1
	end

	if count == 0 then
		return 0
	else
		return totalLength / count
	end
end

function graph2D.isSelfIntersecting( graph )
	local vertices = {}
	for vertex, _ in pairs(graph.vertices) do
		vertices[#vertices+1] = vertex
	end

	local edges = {}
	for edge, _ in pairs(graph.edges) do
		-- We don't check cosmetic edges because they're allowed to overlap.
		if not edge.cosmetic then
			edges[#edges+1] = edge
		end
	end

	-- Any circles intersect?
	for i = 1, #vertices-1 do
		for j = i+1, #vertices do
			local vertex1 = vertices[i]
			local vertex2 = vertices[j]

			local d = Vector.toLength(vertex1, vertex2)
			local s = (vertex1.radius or 0) + (vertex2.radius or 0)

			if d < s then
				return true, 'circles'
			end
		end
	end

	-- Any circles intersect non-cosmetic lines they aren't attached to?
	for i, vertex in ipairs(vertices) do
		local peers = graph.vertices[vertex]
		local radius  = vertex.radius or 0
		
		for _, edge in ipairs(edges) do
			local endverts = graph.edges[edge]
			if not edge.cosmetic and vertex ~= endverts[1] and vertex ~= endverts[2] then
				local point = geometry.closestPointOnLine(endverts[1], endverts[2], vertex)
				local d = Vector.toLength(vertex, point)

				if d < radius then
					return true, 'circle line'
				end
			end
		end
	end

	-- Any non-cosmetic edges, that don't share a vertex, intersect?
	for i = 1, #edges-1 do
		local edge1 = edges[i]
		local endverts1 = graph.edges[edge1]
		local e11, e12 = endverts1[1], endverts1[2]

		for j = i+1, #edges do
			local edge2 = edges[j]
			local endverts2 = graph.edges[edge2]
			local e21, e22 = endverts2[1], endverts2[2]

			if e11 ~= e21 and e11 ~= e22 and e12 ~= e21 and e12 ~= e22 then
				if geometry.lineLineIntersection(e11, e12, e21, e22) then
					return true, 'line line'
				end
			end
		end
	end

	return false
end

local function _heuristic( from, to )
	return Vector.toLength(from, to)
end

local function _defaultVertexFilter( fromVertex, toVertex )
	return true
end

function graph2D.aStar( graph, fromVertex, toVertex, vertexFilter )
	vertexFilter = vertexFilter or _defaultVertexFilter

	assert(graph.vertices[fromVertex])
	assert(graph.vertices[toVertex])
	-- assert(vertexFilter(toVertex))

	local gScore = { [fromVertex] = 0 }
	local hScore = { [fromVertex] = _heuristic(fromVertex, toVertex) }
	local fScore = { [fromVertex] = hScore[fromVertex] }

	local cmp =
		function ( lhs, rhs )
			return fScore[lhs] <= fScore[rhs]
		end

	local vertices = graph.vertices
	local closed = {}
	local open = { [fromVertex] = true }
	local openHeap = Heap.new(cmp)
	openHeap:push(fromVertex)

	local cameFrom = {}
	local cameFromVia = {}

	while #openHeap > 0 do
		local candidate = openHeap:pop()
		open[candidate] = nil
		closed[candidate] = true

		if candidate == toVertex then
			local path = {}

			local current = candidate

			repeat
				path[#path+1] = current
				path[#path+1] = cameFromVia[current]
				current = cameFrom[current]
			until not current

			path = table.reverse(path)

			return true, path
		end

		for peer, edge in pairs(vertices[candidate]) do
			if not closed[peer] then
				if not vertexFilter(candidate, peer) then
					closed[peer] = true
				else
					local candidateGScore = gScore[candidate] + Vector.toLength(candidate, peer)

					local candidateIsBetter = false

					if not open[peer] then
						open[peer] = true
						candidateIsBetter = true
					elseif candidateGScore < gScore[peer] then
						candidateIsBetter = true
					end

					if candidateIsBetter then
						cameFrom[peer] = candidate
						cameFromVia[peer] = link
						gScore[peer] = candidateGScore
						hScore[peer] = _heuristic(peer, toVertex)

						if fScore[peer] then
							openHeap:remove(peer)
						end

						fScore[peer] = gScore[peer] + hScore[peer]
						openHeap:push(peer)
					end
				end
			end
		end
	end

	return false
end

