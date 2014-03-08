--
-- lib/state.lua
--
-- A stack based state machine library.
--

-- - Cannot call become(), push() or kill() in a state's exit handler.
-- - enter() and exit() should only be called by this library if possible.
-- - become() and kill() should be tail called but I can't really ensure it.

--[[

require state = 'lib/state'

local foo = state.new(<name>)

funcion foo:enter( args )
	-- c'tor like logic here.
end

function foo:exit()
	-- d'tor like logic here
end

function foo:draw()
	-- ...

	-- draw() not called on previous states.
	return 'break'
end

function foo:update( dt )
	-- ...
end

function foo:keypressed( key, isrepeat )
	if key == 'delete' then
		return self:push('Dialog', {
			'Delete' = function () ... end,
			"Don't Delete" = function () .. end,
		})
	elseif key == 'return' then
		return self:become('NextState', foo)
	end
end

local bar = state.machine(<init-state>, <args>)

--]]

--[[

 Implementation
================

 instance --mt-->  instancemt  --mt-->  state  ---mt---> statemt
----------        ------------         ---------        ---------
 <state>           machine              name             <nop-event>
                   level                <event>          __index=self
                   exiting              __index=self
 			       __index=state

 machine --mt-->  machinemt
---------        -----------
  stack           schema
                  __index=self


]]

local function _newinstance( machine, level, state )
	assert(machine.schema.states[state.name] == state, 'state not in schema')
	local stack = machine.stack
	assert(1 <= level and level <= #stack+1, 'out of bounds level for new instance')

	local instancemt = {
		machine = machine,
		level = level,
		exiting = false,
		__index = state
	}

	local instance = setmetatable({}, instancemt)
	stack[level] = instance

	return instance
end

local function _become( instance, state, ... )
	local info = debug.getinfo(1)
	for k, v in pairs(info) do print('info', k, v) end
	local instancemt = getmetatable(instance)
	if instancemt.exiting then
		error('become called while exiting state', 2)
	end

	instancemt.exiting = true
	instance:exit()
	instancemt.exiting = false

	local machine = instancemt.machine
	local level = instancemt.level
	local newinstance = _newinstance(machine, level, state)

	newinstance:enter(...)
end

local function _push( instance, state, ... )
	local instancemt = getmetatable(instance)
	if instancemt.exiting then
		error('push called while exiting state', 2)
	end

	local machine = instancemt.machine
	local stack = machine.stack
	local newinstance = _newinstance(machine, #stack+1, state)

	newinstance:enter(...)
end

local function _kill( instance )
	local instancemt = getmetatable(instance)
	if not instancemt.exiting then
		error('kill called while exiting state', 2)
	end

	instancemt.exiting = true
	instance:exit()
	instancemt.exiting = false

	local stack = instancemt.machine.stack
	local level = instancemt.level

	table.remove(stack, level)

	for i = level, #stack do
		local instancemt = getmetatable(stack[level])
		assert(instancemt.level == i+1, 'instance level corrupted')
		instancemt.level = i
	end
end


local _schemas = {}

-- A set of banned event names.
-- TODO: is this overly conservative?
local _banned = {
	__index = true,
	enter = true,
	exit = true,
	become = true,
	push = true,
	kill = true,
	machine = true,
	exiting = true,
	schema = true,
}

local function _handler( event )
	assert(not _banned[event], 'banned event')
	return
		function ( machine, ... )
			local stack = machine.stack
			for i = #stack, 1, -1 do
				local instance = stack[i]

				-- TODO: error if more than one state gets killed.
				
				if instance[event](instance, ...) == 'break' then
					break
				end
			end
		end
end

local _nop = function () end

local function _newschema( events )
	assert(type(events) == 'table', 'schema should be a table')

	local statemt = {
		enter = _nop,
		exit = _nop,
		become = _become,
		push = _push,
		kill = _kill,
		__index = nil
	}
	statemt.__index = statemt
	
	local machinemt = { __index = nil }
	machinemt.__index = machinemt

	for event, v in pairs(events) do
		assert(type(event) == 'string', 'schema key must be a string')
		local s, f = event:find('[_%a][_%w]+')
		assert(s == 1 and f == #event, 'schema key is not a valid lua identifier')
		assert(not _banned[event], 'schema key is banned')

		assert(v == true or type(v) == 'function', 'schema value should be true or a function')

		statemt[event] = (type(v) == 'function') and v or _nop
		machinemt[event] = _handler(event)
	end

	local result = {
		states = {},
		statemt = statemt,
		machinemt = machinemt
	}

	machinemt.schema = result

	_schemas[result] = true

	return result
end

function _newstate( schema, name )
	assert(_schemas[schema], 'undefined schema')
	assert(schema.states[name] == nil, 'state redefinition detected')

	local state = {
		name = name,
		__index = nil
	}
	state.__index = state
	setmetatable(state, schema.statemt)

	schema.states[name] = state

	return state
end

function _newmachine( schema, state, ... )
	assert(_schemas[schema], 'undefined schema')
	print(state.name)
	for k, v in pairs(schema.states) do print(k,v) end
	assert(schema.states[state.name] == state, 'state not in schema')

	local machine = {
		stack = {},
		schema = schema
	}
	setmetatable(machine, schema.machinemt)

	local instance = _newinstance(machine, 1, state)

	instance:enter(...)

	return machine
end

local state = {
	schema = _newschema,
	state = _newstate,
	machine = _newmachine
}

-- test

local schema = state.schema {
	draw = true,
	focus = true,
	keypressed = true,
	keyreleased = true,
	mousepressed = true,
	mousereleased = true,
	quit = true,
	update = true,
	textinput = true,
	joystickpressed = true,
	joystickreleased = true,
}

local test1 = state.state(schema, 'test1')
local test2 = state.state(schema, 'test2')
local test3 = state.state(schema, 'test3')

-- test1

function test1:enter(arg)
	print(arg, arg)
	return self:become(test2, 'bar')
end

function test1:exit()
	print('test1:exit()')
end

-- test2

function test2:enter(arg)
	print('test2', arg)
end

function test2:draw()
	print('test2:draw')
end

function test2:update(dt)
	print('test2:update', dt)
	return self:push(test3, 'baz')
end

-- test3

function test3:enter(arg)
	print('test3', arg)
end
function test3:exit(arg)
	print('test3:exit()')
end
function test3:update(dt)
	print('test3:update', dt)
	return self:kill()
end
local machine = state.machine(schema, test1, 'foo')

local function printf( ... ) print(string.format(...)) end

printf('#stack %d', #machine.stack)
machine:update(1/30)
printf('#stack %d', #machine.stack)
print(machine.update)
printf('#stack %d', #machine.stack)
machine:draw()

return state
