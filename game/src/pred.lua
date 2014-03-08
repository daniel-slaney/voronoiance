--
-- lib/pred.lua
--
-- Graph drawing.
--

require 'Vector'
require 'Graph'
require 'geometry'

--
-- Based on the PrEd algorithm in 'A force-directed algorithm that preserves
-- edge crossing properties.' The paper is behind a paywall so the main
-- inspiration is the paper 'ImPrEd: An Improved Force-Directed Algorithm that
-- Prevents Nodes from Crossing Edges' but none of the improvements have been
-- implemented yet.
--
-- There are three forces at play:
-- - Vertex-vertex repulsion: all vertices push each other away.
-- - Edge spring forces: edges try and maintain the specified edge length.
-- - Vertex-edge repulsion: vertices push away from non-incident edges.
--
-- To control the process there are quite a few parameters.
--
-- graph: the graph to draw
-- edgeLength: the desired length of each edges.
-- repulsion: the strength of the vertex-vertex repulsive force.
-- repulsionCutoff: the distance (in edgeLength units) that repulsion ceases to take effect.
-- springStrength: the power of the push and pull forces trying to keep edges at edgeLength
-- vertexEdgeForce: the power of the vertex to edge repulsive force
-- vertexEdgeSafetyFactor: a vertex cannot get closer to a non-incident edge than this
-- maxDelta: maximum vertex movement allowed per iteration

-- fvv    - force vertex-vertex
-- fvvcut - vertex-vertex cutoff
-- fe     - force edge
-- fve    - force vertex-edge
-- fvecut - vertex-edge cutoff
-- maxs   - maximum displacement
-- convf  - convergence factor

-- local function pred( graph, edgeLength, repulsion, repulsionCutoff, springStrength, crossDistance, crossForce, crossLimit, convergenceFactor )

-- delta, rf, rc, spring, 

-- local function pred( graph, delta, gamma, repulsion, repulsionCutoff, gammaCutoff, , gamma, epsilon, logging )

local function pred( graph, delta, gamma, epsilon, logging )
	local vnew = Vector.new
	local vsub = Vector.sub
	local vlen = Vector.length
	local vmadvnv = Vector.madvnv
	local vdot = Vector.dot
	local vset = Vector.set
	local vnorm = Vector.normalise
	local vscale = Vector.scale
	local vadd = Vector.add
    local vtolen = Vector.toLength
    local project = geometry.projectPointOntoLineSegment
    local vmulvn = Vector.mulvn

	local vertices = graph.vertices
	local varray, earray = graph:toarrays()
	local farray = {}
	for i = 1, #varray do
		farray[i] = vnew { x = 0, y = 0 }
	end

    local diag = math.sqrt(0.5)
    local dirs = {
        vnew { x=1,     y=0     },
        vnew { x=diag,  y=diag  },
        vnew { x=0,     y=1     },
        vnew { x=-diag, y=diag  },
        vnew { x=-1,    y=0     },
        vnew { x=-diag, y=-diag },
        vnew { x=0,     y=-1    },
        vnew { x=diag,  y=-diag },
    }
    
    local vsectors = {}
    for i = 1, #varray do
        vsectors[i] = {
            math.huge, math.huge,
            math.huge, math.huge,
            math.huge, math.huge,
            math.huge, math.huge
        }
    end

    local limit = math.cos(math.pi/2 + math.pi/8)

    local function constrain( vidx, s )
    	local sector = vsectors[vidx]
    	local l = vlen(s)

    	-- TODO: does this help?
    	--       It seems to stop lines crossing.
    	if l <= 2 then
    		l = 0
    	end

        for i = 1, #dirs do
            local dot = vdot(dirs[i], s)
            local angle = math.min(dot/l, math.pi*0.5)
            
            if angle > limit then
            	sector[i] = math.min(l * (1/math.cos(angle)), sector[i])
            end
        end
    end

	local converged = false
	local iterations = 0

	local to = vnew { x=0, y=0 }
	local proj = vnew { x=0, y=0 }
	local line = vnew { x=0, y=0 }

	local mid = vnew { x=0, y=0 }
	local s = vnew { x=0, y=0 }
	local normal = vnew { x=0, y=0 }

	local log = {}

	while not converged do
		-- vertex-vertex repulsive forces.
		for i = 1, #varray do
			local v = varray[i]
			local vforce = farray[i]
			for j = i+1, #varray do
				local o = varray[j]
				local oforce = farray[j]

				-- to = v -> o
				vsub(to, o, v)
				local tolen = vlen(to)
				
				local f = (delta / tolen)^2

				if tolen > delta * 3 then
					f = 0
				end

				vmadvnv(vforce, to, -f, vforce)
				vmadvnv(oforce, to, f, oforce)

				if logging then
					local f1 = vnew { x=0, y=0 }
					local f2 = vnew { x=0, y=0 }

					vmadvnv(f1, to, -f, f1)
					vmadvnv(f2, to, f, f2)

					log[#log+1] = { 'repulse', v.x, v.y, v.x + f1.x, v.y + f1.y }
					log[#log+1] = { 'repulse', o.x, o.y, o.x + f2.x, o.y + f2.y }

					printf('repulse %d-%d d:%.1f #:%.2f f:%.2f |f|:%.2f', i, j, delta, tolen, f, vlen(f1))
				end
			end
		end

		-- edge attractive forces.
		for i = 1, #earray do
			local edge = earray[i]
			local v1idx, v2idx = edge[1], edge[2]
			local v1 = varray[v1idx]
			local v2 = varray[v2idx]

			vsub(to, v2, v1)
			local tolen = vlen(to)

			-- local f = tolen / delta
			-- local f = (tolen / delta)^2
			local f = -math.log(delta / tolen)
			-- local f = math.max(0, (tolen-delta)*0.75)
			-- vscale(to, 1/tolen)

			local v1force = farray[v1idx]
			local v2force = farray[v2idx]
			vmadvnv(v1force, to, f, v1force)
			vmadvnv(v2force, to, -f, v2force)

			if logging then
				local f1 = vnew { x=0, y=0 }
				local f2 = vnew { x=0, y=0 }

				vmadvnv(f1, to, f, f1)
				vmadvnv(f2, to, -f, f2)

				if f > 0 then
					log[#log+1] = { 'attract', v1.x, v1.y, v1.x + f1.x, v1.y + f1.y }
					log[#log+1] = { 'attract', v2.x, v2.y, v2.x + f2.x, v2.y + f2.y }
				end

				printf('attract %d-%d d:%.1f #:%.2f f:%.2f |f|:%.2f', v1idx, v2idx, delta, tolen, f, vlen(f1))
			end
		end

		-- vertex-edge force.
		for i = 1, #varray do
			local v = varray[i]
			local vforce = farray[i]

			for j = 1, #earray do
				local edge = earray[j]
				local e1idx = edge[1]
				local e2idx = edge[2]

				if i ~= e1idx and i ~= e2idx then
					local e1 = varray[e1idx]
					local e2 = varray[e2idx]

					-- project v onto the line segment e1 -> e2.
					vsub(to, v, e1)
					vsub(line, e2, e1)
					local d = vdot(line, line)
					local lambda = vdot(to, line)
    				local t = lambda / d
    				t = math.min(1, math.max(0, t))
    
    				vmadvnv(proj, line, t, e1)

    				-- now the force.

    				-- to = proj -> v
    				vsub(to, v, proj)
    				local tolen = vlen(to)

    				-- local f = (gamma - tolen)^2 / tolen
    				-- local f = (tolen < gamma) and (gamma - tolen)^2 / tolen or 0
    				-- local f = (gamma - tolen) / tolen
    				local f = -10*math.log(math.min(tolen/gamma, 1))

    				vmadvnv(vforce, to, f, vforce)
    				local e1force = farray[e1idx]
    				vmadvnv(e1force, to, -f, e1force)
    				local e2force = farray[e2idx]
    				vmadvnv(e2force, to, -f, e2force)

    				if logging then
						local f1 = vnew { x=0, y=0 }
						vmadvnv(f1, to, f, f1)
						if math.abs(f) > 0 then
							log[#log+1] = { 'edge', v.x, v.y, v.x + f1.x, v.y + f1.y }
						end
						local f2 = vnew { x=0, y=0 }
						vmadvnv(f2, to, -f, f2)
						if math.abs(f) > 0 then
							log[#log+1] = { 'edge', e1.x, e1.y, e1.x + f2.x, e1.y + f2.y }
						end
						local f3 = vnew { x=0, y=0 }
						vmadvnv(f3, to, -f, f3)
						if math.abs(f) > 0 then
							log[#log+1] = { 'edge', e2.x, e2.y, e2.x + f3.x, e2.y + f3.y }
						end

						log[#log+1] = { 'proj', v.x, v.y, proj.x, proj.y }
						printf('edge %d %d-%d g:%.1f |t|:%.2f %.2f |f|:%.2f', i, e1idx, e2idx, gamma, tolen, f, vlen(f1))
					end
    			end
 			end
		end

		if logging then
			for i = 1, #varray do
				local v = varray[i]
				local f = farray[i]
				log[#log+1] = { 'accum', v.x, v.y, v.x+f.x, v.y+f.y }
				printf('accum %d %s', i, f)
			end
		end

		-- reset the sectors
		for i = 1, #vsectors do
			local sector = vsectors[i]
			for j = 1, 8 do
				-- TODO: if we have a 'max delta' this should be used here.
				sector[j] = math.huge
			end 
		end

		for i = 1, #varray do
			local v = varray[i]

			for j = 1, #earray do
				local edge = earray[j]
				local e1idx = edge[1]
				local e2idx = edge[2]

				if i ~= e1idx and i ~= e2idx then
					local e1 = varray[e1idx]
					local e2 = varray[e2idx]

					project(v, e1, e2, proj)
					vsub(s, proj, v)
					vscale(s, 0.5)
					
					constrain(i, s)

					vadd(mid, v, s)
					vset(normal, s)
					vscale(normal, -1)
					vnorm(normal)

					vsub(to, mid, e1)
					local d = vdot(to, normal)
					vmulvn(s, normal, d)

					constrain(e1idx, s)

					vsub(to, mid, e2)
					local d = vdot(to, normal)
					vmulvn(s, normal, d)

					constrain(e2idx, s)
				else
					-- v is a vertex of the edge
					local widx = (i == e1idx) and e2idx or e1idx
					local w = varray[widx]

					vsub(s, w, v)
					vscale(s, 0.5)
					
					constrain(i, s)
					vscale(s, -1)
					constrain(widx, s)
				end
			end
		end

		if logging then
			for i = 1, #vsectors do
				local sector = vsectors[i]
				local v = varray[i]
				for j = 1, 8 do
					local dir = dirs[j]
					log[#log+1] = { 'arc', v.x, v.y, dir, sector[j] }
				end 
			end
		end

		local limit = math.cos(math.pi/8)
		local maxf = -math.huge
		for i = 1, #varray do
			local v = varray[i]
			local force = farray[i]
			local f = vlen(force)
			maxf = math.max(maxf, f)
			local sector = vsectors[i]

			for j = 1, #dirs do
				local dot  = vdot(force, dirs[j])
				local angle = dot/f

				if angle >= limit then
					-- local bound = math.min(delta, sector[j])
					-- local bound = math.min(delta*0.1, sector[j])
					local bound = math.min(2, sector[j])
					if bound < f then
						force:scale(bound/f)
					end

					printf('bound:%s %f |f|:%s diff:%s', bound, f, vlen(force), vlen(force)-bound)

					if logging then
						log[#log+1] = { 'clip', v.x, v.y, v.x+force.x, v.y+force.y }
					end
					vadd(v, v, force)
					break
				end
			end
		end

		printf('max f:%.2f  %.2f%%', maxf, 100 * (maxf/delta))

		-- now clip the forces and apply them.
		-- for i = 1, #varray do
		-- 	local v = varray[i]
		-- 	local vforce = farray[i]
		-- 	local f = vlen(vforce)
		-- 	local maxf = delta * 0.5
		-- 	local maxs = math.huge

		-- 	-- TODO: magic number
		-- 	if f > 0.0001 then
		-- 		-- we need to find the nearest point on the edge in the
		-- 		-- direction of the force.

		-- 		for j = 1, #earray do
		-- 			local edge = earray[j]
		-- 			local v1idx = edge[1]
		-- 			local v2idx = edge[2]

		-- 			if i ~= v1idx and i ~= v2idx then
		-- 				local e1 = varray[v1idx]
		-- 				local e2 = varray[v2idx]

		-- 				if geometry.rayLineIntersection(v, vforce, e1, e2, hit) then
		-- 					vsub(to, hit, v)
		-- 					local tolen = vlen(to)

		-- 					maxf = math.min(maxf, tolen * epsilon)
		-- 				end

		-- 				geometry.projectPointOntoLineSegment(v, e1, e2, to)
		-- 				maxs = math.min(maxs, vlen(to))
	 --    			end
	 --    		end
		-- 	end

		-- 	if f > maxf then
		-- 		vscale(vforce, maxf/f)
		-- 	end

		-- 	-- TODO: epsilon check.

		-- 	if logging then
		-- 		log[#log+1] = { 'clip', v.x, v.y, v.x+vforce.x, v.y+vforce.y }
		-- 		printf('clip %d |f|:%.2f |c|:%.2f s:%.2f !:%s', i, f, maxf, maxs, maxf>maxs)
		-- 	end

		-- 	vadd(v, v, vforce)

		-- 	vforce.x, vforce.y = 0, 0
		-- end

		iterations = iterations + 1
		converged = iterations >= 1
	end

	return log
end

return pred
