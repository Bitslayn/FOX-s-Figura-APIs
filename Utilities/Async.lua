--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Async Utility

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/Async.lua
]]

---@class FOXAsync
local async = {}

---@class FOXAsync.Task
---@field queue (fun(...): ...)[]
---@field params any[]
---@field running boolean
---@field event Event|function
local task = {}
task.__index = task

---Creates a new async task
---
---The given parameters will be passed into the next function
---@param ... any
function async.new(...)
	local self = {
		queue = {},
		params = { ... },
		running = false,
		event = events.tick,
	}
	return setmetatable(self, task)
end

---Initializes an async task
---@param self FOXAsync.Task
local function init(self)
	if self.running then return end

	local func = table.remove(self.queue)
	local params = self.params

	local function run()
		local returns = { func(table.unpack(params)) }
		if #returns == 0 then return end

		func = table.remove(self.queue)
		params = returns
		if func then return end

		self.running = false
		self.event:remove(run)
	end

	self.running = true
	self.event:register(run)
end

---Adds a new function to an existing async task
---
---Returning in this function will stop the currently running function, using the returned values as parameters for the next function
---@param func fun(...): ...
---@return FOXAsync.Task
function task:add(func)
	table.insert(self.queue, func)
	init(self)
	return self
end

return async
