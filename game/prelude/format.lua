--
-- misc/format.lua
--
-- Utility functions for common string.format uses.
--

function printf( ... )
	print(string.format(...))
end

function assertf( cond, ... )
	if not cond then
		error(string.format(...), 2)
	end
end
