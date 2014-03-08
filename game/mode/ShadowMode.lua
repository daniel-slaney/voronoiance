--
-- mode/ShadowMode.lua
--

local schema, ShadowMode = require 'src/mode' { 'ShadowMode' }
local Vector = require 'src/Vector'
local Voronoi = require 'src/Voronoi'
local geometry = require 'src/geometry'

local function gen( numPoints )
	local xmin, ymin = 0, 0
	local xmax, ymax = love.graphics.getDimensions()

	local sites = {}

	for i = 1, numPoints do
		sites[#sites+1] = Vector.new {
			x = math.random(xmin, xmax),
			y = math.random(ymin, ymax)
		}
	end

	local bbox = {
		xl = xmin,
		xr = xmax,
		yt = ymin,
		yb = ymax,
	}

	local diagram = Voronoi:new():compute(sites, bbox)
	local cells = {}
	local blockers = {}

	for index, cell in ipairs(diagram.cells) do
		-- { x1, y1, x2, y2, ..., xN, yN }
		local poly = {}
		local hull = {}

		for _, halfedge in ipairs(cell.halfedges) do
			local startpoint = halfedge:getStartpoint()

			poly[#poly+1] = startpoint.x
			poly[#poly+1] = startpoint.y
			hull[#hull+1] = Vector.new(startpoint)
		end

		local centroid = geometry.convexHullCentroid(hull)
		local blocker = love.math.noise(centroid.x, centroid.y) <= 0.5
		blockers[index] = blocker

		local cell = {
			poly = poly,
			hull = hull,
			centroid = centroid,
			blocker = blocker
		}

		cells[#cells+1] = cell
	end

	local casters = {}
	for _, edge in ipairs(diagram.edges) do
		local lSite = edge.lSite
		assert(lSite ~= nil)
		local rSite = edge.rSite

		-- So for an edge to be a caster on and only one of the sites must be a
		-- blocker. If both sites are blockers it's an internal edge.

		local lBlock = blockers[lSite.voronoiId]
		local rBlock = rSite ~= nil and blockers[rSite.voronoiId]

		if lBlock and not rBlock then
			casters[#casters+1] = Vector.new(edge.va)
			casters[#casters+1] = Vector.new(edge.vb)
		end

		if not lBlock and rBlock then
			casters[#casters+1] = Vector.new(edge.vb)
			casters[#casters+1] = Vector.new(edge.va)
		end

	end

	return cells, casters
end

function ShadowMode:enter()
	self.numPoints = 200
	self.cells, self.casters = gen(self.numPoints)
	self.index = nil
	self.shadows = false
	self.lights = {}
end

function ShadowMode:update( dt )
	local mouse = Vector.new {
		x = love.mouse.getX(),
		y = love.mouse.getY(),
	}

	for index, cell in ipairs(self.cells) do
		if geometry.isPointInHull(mouse, cell.hull) then
			self.index = index
		end
	end
end

function ShadowMode:draw()
	local colour1 = { 0, 121, 194, 255 }
	local colour2 = { 184, 118, 61, 255 }

	love.graphics.setColor(colour2[1], colour2[2], colour2[3], colour2[4])
	for index, cell in ipairs(self.cells) do
		if cell.blocker then
			love.graphics.polygon('fill', cell.poly)
		end	
	end

	love.graphics.setColor(colour1[1], colour1[2], colour1[3], colour1[4])
	for index, cell in ipairs(self.cells) do
		if not cell.blocker then
			love.graphics.polygon('fill', cell.poly)
		end	
	end

	love.graphics.setLineWidth(2)
	love.graphics.setColor(0, 0, 0, 255)

	for index, cell in ipairs(self.cells) do
		love.graphics.polygon('line', cell.poly)		
	end

	if self.index then
		love.graphics.setColor(255, 0, 255, 255)
		love.graphics.polygon('line', self.cells[self.index].poly)
	end

	if self.shadows then
		local light = Vector.new {
			x = love.mouse.getX(),
			y = love.mouse.getY()
		}

		love.graphics.setColor(0, 0, 0, 255)

		local casters = self.casters
		local to = Vector.new { x = 0, y = 0 }
		local dir = Vector.new { x = 0, y = 0 }
		local vsub = Vector.sub
		local vmulnv = Vector.mulnv
		local vcross = Vector.perpDot
		local proj1 = Vector.new { x = 0, y = 0 }
		local proj2 = Vector.new { x = 0, y = 0 }
		for i = 1, #casters, 2 do
			local p1, p2 = casters[i], casters[i+1]
			vsub(dir, p2, p1)
			vsub(to, p1, light)

			if vcross(to, dir) < 0 then
				love.graphics.line(p1.x, p1.y, p2.x, p2.y)

				vsub(proj1, p1, light)
				vsub(proj2, p2, light)
				local f = 100
				vmulnv(proj1, f, proj1)
				vmulnv(proj2, f, proj2)

				love.graphics.polygon('fill', p1.x, p1.y, p2.x, p2.y, p2.x+proj2.x, p2.y+proj2.y, p1.x+proj1.x, p1.y+proj1.y)
			end
		end
	end
end

function ShadowMode:keypressed( key, is_repeat )
	if key == ' ' then
		self.cells, self.casters = gen(self.numPoints)
	elseif key == 's' then
		self.shadows = not self.shadows
	end
end

