--
-- src/dirs.lua
--

local Vector = require 'src/Vector'

local function V( x, y )
	return (Vector.new { x=x, y=y }):normal()
end

--
--       ^ -y           ^ N
--       |              |
-- -x <--+--> +x   W <--+--> E
--       |              |
--       v +y           v S
--
local n = V(0,-1)
local ne = V(1,-1)
local e = V(1,0)
local se = V(1,1)
local s = V(0,1)
local sw = V(-1,1)
local w = V(-1,0)
local nw = V(-1,-1)

return {
	N = n,
	NE = ne,
	E = e,
	SE = se,
	S = s,
	SW = sw,
	W = w,
	NW = nw
}
