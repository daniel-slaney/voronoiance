--
-- src/actions.lua
--

local actions = {}

-- action = {
--     blocking = <boolean>,
--     anim = function ( time ) -> boolean, offset
--     effect = function ( gameState )
-- }

-- parabola = -((2*(x-0.5))^2) + 1
--    x = [0..1]
--    y = [0..1]

local function parabola( t )
	return -((2*(x-0.5))^2) + 1
end


function actions.move( gameState, actor, target )
	return {

	}

end

return actions
