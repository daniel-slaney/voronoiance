local Vector = require 'src/Vector'
local Graph = require 'src/Graph'

local graphgen = {}

local function _contains( circle, point )
	return Vector.toLength(circle, point) < circle.radius
end

-- This is a simple but horrendously slow implementation O(n^3).
function graphgen.gabriel( points )
	local vertices = {}
	local edges = {}

	for _, point in ipairs(points) do
		vertices[point] = {}
	end

	local count = 0

	local circle = { x=0, y=0, radius = 0 }

	for i = 1, #points do
		local source = points[i]

		for j = i + 1, #points do
			local target = points[j]

			local dst = Vector.toLength(source, target)

			circle.x = source.x + (target.x - source.x) / 2
			circle.y = source.y + (target.y - source.y) / 2
			circle.radius = dst / 2

			local accepted = true

			for k = 1, #points do
				count = count + 1

				if k ~= i and k ~= j then
					local other = points[k]

					if _contains(circle, other) then
						accepted = false

						break
					end
				end
			end

			if accepted then
				local edge = { length = dst }
				
				vertices[source][target] = edge
				vertices[target][source] = edge
				
				edges[edge] = { source, target }
			end
		end
	end

	-- print('gabriel', count)

	local result = Graph.new(vertices, edges)

	return result, count
end

-- This is a simple but horrendously slow implementation O(n^3).
-- Relative Neighbourhood Graph.
function graphgen.rng( points )
	local vertices = {}
	local edges = {}

	for _, point in ipairs(points) do
		vertices[point] = {}
	end

	local count = 0

	for i = 1, #points do
		local source = points[i]
		for j = i + 1, #points do
			local target = points[j]

			local dst = source:toLength(target)

			local accepted = true

			for k = 1, #points do
				count = count + 1

				if k ~= i and k ~= j then
					local other = points[k]

					local dso = source:toLength(other)
					local dto = target:toLength(other)

					if dso < dst and dto < dst then
						accepted = false

						break
					end
				end
			end

			if accepted then
				local edge = { length = dst }
				
				vertices[source][target] = edge
				vertices[target][source] = edge
				
				edges[edge] = { source, target }
			end
		end
	end

	local result = Graph.new(vertices, edges)

	return result, count
end

return graphgen

