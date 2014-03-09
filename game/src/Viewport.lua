require 'Vector'
local AABB = require 'lib/AABB'

local Dampener = require 'lib/Dampener'

Viewport = {}
Viewport.__index = Viewport

function Viewport.new( bounds, portal )
	local portal = portal or AABB.new {
		xmin = 0,
		xmax = love.graphics.getWidth(),
		ymin = 0,
		ymax = love.graphics.getHeight(),
	}

	local result = {
		portal = AABB.new(portal),
		bounds = AABB.new(bounds),
		zoom = 1,
		centreDamp = Dampener.newv(portal:centre(), portal:centre(), 0.1),
		zoomDamp = Dampener.newf(1, 1, 0.1),
	}

	setmetatable(result, Viewport)

	-- Ensure the portal is within the bounds.
	result:_constrain()

	return result
end


function Viewport:_constrain()
	local portal = self.portal
	local bounds = self.bounds

	local portalWidth, portalHeight = portal:width(), portal:height()
	local borderWidth, borderHeight = bounds:width(), bounds:height()

	local wide = portalWidth > borderWidth
	local tall = portalHeight > borderHeight

	local centre = bounds:centre()

	if wide then
		portal.xmin = math.round(centre.x - portalWidth * 0.5)
		portal.xmax = math.round(centre.x + portalWidth * 0.5)
	else
		-- The portal is smaller than the screen so just move it.
		
		-- Portal is left of the bounds.
		if portal.xmin < bounds.xmin then
			portal.xmin = bounds.xmin
			portal.xmax = bounds.xmin + portalWidth
		-- Portal is right of the bounds.
		elseif portal.xmax > bounds.xmax then
			portal.xmax = bounds.xmax
			portal.xmin = bounds.xmax - portalWidth
		end
	end

	if tall then
		portal.ymin = math.round(centre.y - portalHeight * 0.5)
		portal.ymax = math.round(centre.y + portalHeight * 0.5)
	else
		-- Portal is below the bounds.
		if portal.ymin < bounds.ymin then
			portal.ymin = bounds.ymin
			portal.ymax = bounds.ymin + portalHeight
		-- Portal is above the bounds.
		elseif portal.ymax > bounds.ymax then
			portal.ymax = bounds.ymax
			portal.ymin = bounds.ymax - portalHeight
		end
	end
end

function Viewport:update()
	local centre = self.centreDamp:updatev()
	local zoom = self.zoomDamp:updatef()

	self:_setCentre(centre)
	self:_setZoom(zoom)
end

function Viewport:setup()
	local windowWidth = love.graphics.getWidth()
	local windowHeight = love.graphics.getHeight()
	local portal = self.portal

	
	local xScale = windowWidth / portal:width()
	local yScale = windowHeight / portal:height()

	love.graphics.scale(xScale, yScale)
	love.graphics.translate(-portal.xmin, -portal.ymin)
end

function Viewport:screenToWorld( point )
	local portal = self.portal

	local windowWidth = love.graphics.getWidth()
	local windowHeight = love.graphics.getHeight()

	local x = lerpf(point.x, 0, windowWidth, portal.xmin, portal.xmax)
	local y = lerpf(point.y, 0, windowHeight, portal.ymin, portal.ymax)

	return Vector.new { x = math.round(x), y = math.round(y) }
end

function Viewport:worldToScreen( point )
	local portal = self.portal

	local windowWidth = love.graphics.getWidth()
	local windowHeight = love.graphics.getHeight()

	local x = lerpf(point.x, portal.xmin, portal.xmax, 0, windowWidth)
	local y = lerpf(point.y, portal.ymin, portal.ymax, 0, windowHeight)

	return Vector.new { math.round(x), math.round(y) }
end

function Viewport:_setCentre( centre )
	local portal = self.portal
	local halfWidth = portal:width() * 0.5
	local halfHeight = portal:height() * 0.5

	portal.xmin = math.round(centre.x - halfWidth)
	portal.xmax = math.round(centre.x + halfWidth)
	portal.ymin = math.round(centre.y - halfHeight)
	portal.ymax = math.round(centre.y + halfHeight)

	self:_constrain()
end

function Viewport:setCentre( centre )
	self.centreDamp.target = Vector.new(centre)
end

function Viewport:_setZoom( zoom )
	assert(zoom > 0)

	local halfWindowWidth = love.graphics.getWidth() * 0.5
	local halfWindowHeight = love.graphics.getHeight() * 0.5

	local portal = self.portal
	local centre = portal:centre()

	portal.xmin = math.round(centre.x - (halfWindowWidth / zoom))
	portal.xmax = math.round(centre.x + (halfWindowWidth / zoom))
	portal.ymin = math.round(centre.y - (halfWindowHeight / zoom))
	portal.ymax = math.round(centre.y + (halfWindowHeight / zoom))

	self.zoom = zoom

	self:_constrain()
end

function Viewport:setZoom( zoom )
	self.zoomDamp.target = zoom
end

function Viewport:setZoomImmediate( zoom )
	self.zoomDamp.target = zoom
	self.zoomDamp.value = zoom
end

function Viewport:getZoom()
	return self.zoom
end
