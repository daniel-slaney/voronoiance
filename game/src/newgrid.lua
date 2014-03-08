--
-- newgrid.lua
--

local function newgrid( width, height, value )
	local data = {}

	for x = 1, width do
		local column = {}
		for y = 1, height do
			column[y] = value
		end
		data[x] = column
	end

	return {
		width = width,
		height = height,
		set = 
			function ( x, y, value )
				data[x][y] = value
			end,
		get =
			function ( x, y )
				return data[x][y]
			end,
		anyFourwayNeighboursSet =
			function ( x, y )
				local t, b, l, r = false, false, false, false

				if y < height then
					t = data[x][y+1]
				end

				if y > 1 then
					b = data[x][y-1]
				end

				if x < width then
					r = data[x+1][y]
				end

				if x > 1 then
					l = data[x-1][y]
				end

				return t or b or l or r
			end,
		print =
			function ()
				for y = 1, height do
					local line = {}
					for x = 1, width do
						line[x] = (data[x][y]) and 'x' or '.'
					end
					print(table.concat(line))
				end
			end,
	}
end

return newgrid
