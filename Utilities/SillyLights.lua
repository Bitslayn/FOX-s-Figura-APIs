--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Silly Lights v1.1b
--]]

local lib = {}

---@alias FOXLight.Light {pos: Vector3, level: integer}
---@alias FOXLight.Source {pos: Vector3, level: integer, filled: FOXLight.Light[]}
---@alias FOXLight.AsyncTask {paused: boolean, finish: fun(...), killed: boolean}

---Runs a floodfill that places light blocks to set light level
---@param pos Vector3
---@param level integer
---@param task FOXLight.AsyncTask
local function floodlight(pos, level, task)
	-- Skip floodfill if seeded block can have light set

	local state = world.getBlockState(pos)
	local is_empty = state:isAir() or state.id == "minecraft:water"
	local is_darker = world.getBlockLightLevel(pos) <= level

	if not is_darker then
		task.paused = false
		task.finish({})
		return
	elseif is_empty or state.id == "minecraft:light" and is_darker then
		task.paused = false
		task.finish({ { pos = pos, level = level } })
		return
	end

	-- Localize vars

	---@type Vector3[]
	local dirs = {
		vec(1, 0, 0),
		vec(-1, 0, 0),
		vec(0, 1, 0),
		vec(0, -1, 0),
		vec(0, 0, 1),
		vec(0, 0, -1),
	}

	---@type table<string, integer>
	local visited = {}
	---@type {pos: Vector3, level: integer}[]
	local queue = { { pos = pos, level = level } }
	---@type {pos: Vector3, level: integer}[]
	local filled = {}

	--[[
	Rules:
		Neighbors can only be filled if light can be set in that block but that block isn't air, water, or light
		Ignore filling if the light level at that block is stronger
		Immediately pop once a light block can be set
	]]

	---@return boolean
	local function fill()
		local old_queue = queue
		queue = {}

		for i = 1, #old_queue do
			local this_pos = old_queue[i].pos
			local this_level = old_queue[i].level

			for j = 1, 6 do
				local next_pos = this_pos + dirs[j]
				local next_level = this_level - 1
				local next_id = tostring(next_pos)
				local next_block = world.getBlockState(next_pos)

				if not next_block:isOpaque() and (visited[tostring(next_pos)] or world.getBlockLightLevel(next_pos)) <= next_level then
					visited[next_id] = next_level

					if next_block:isAir() or next_block.id == "minecraft:water" or next_block.id == "minecraft:light" then
						table.insert(filled, { pos = next_pos, level = next_level })
					else
						table.insert(queue, { pos = next_pos, level = next_level })
					end
				end
			end
		end

		return #queue == 0
	end

	local depth = 0
	local function async()
		depth = depth + 1
		if task.killed then
			events.render:remove(async)
		elseif depth > 10 or fill() then
			events.render:remove(async)
			task.paused = false
			task.finish(filled)
		end
	end
	events.render:register(async)
end

---@type table<string, integer>
local keys = {}
---@type FOXLight.Source[]
local sources = {}
---@type table<string, BlockState>
local placed = {}
---@type FOXLight.AsyncTask
local last_task = {}

--Forces light recalculation
function lib.update()
	if not silly then return end

	---@type table<string, BlockState>
	local queue = {}

	local function replace()
		-- Remove all placed light blocks

		for _, state in pairs(placed) do
			silly:setBlock(state:getPos(), nil)
		end

		-- Place queued light blocks

		for _, state in pairs(queue) do
			silly:setBlock(state)
		end

		placed = queue
	end

	-- Flush nil light placements

	for i = 1, #sources do
		if type(sources[i].level) ~= "number" then
			table.remove(sources, keys[i])
			keys[i] = nil
		end
	end

	-- Loop through all sources and propagate light

	local task = { paused = false }
	last_task.killed = true
	last_task = task

	local len = #sources
	local cur = 0

	local function async()
		if task.killed then
			events.render:remove(async)
		end
		if task.paused then return end

		cur = cur + 1

		local source = sources[cur]
		if not source then
			events.render:remove(async)
			replace()
			return
		end

		task.paused = true
		task.finish = function(filled)
			for i = 1, #filled do
				local light = filled[i]

				local water = tostring(not not world.getBlockState(light.pos):getFluidTags()[1])
				local state = string.format("minecraft:light[level=%s,waterlogged=%s]", light.level, water)

				local key = tostring(light.pos)
				if not queue[key] or tonumber(queue[key].properties.level) < light.level then
					queue[key] = world.newBlock(state, light.pos)
				end
			end

			source.filled = filled
		end
		floodlight(source.pos, source.level, task)
	end
	events.render:register(async)
end

---Sets the light level at the given block
---@param pos Vector3
---@param level integer?
function lib.setLight(pos, level)
	if not pos then return end

	pos = pos:floor()
	local key = tostring(pos)

	-- Try to update an existing light source before adding a new one

	if sources[keys[key]] then
		local source = sources[keys[key]]

		if source.level == level then return end
		source.level = level
	elseif type(level) == "number" then
		local index = #sources + 1

		sources[index] = { pos = pos, level = level, filled = {} }
		keys[key] = #sources
	end

	-- Double update makes sure light level propagates properly at the cost of flicker

	lib.update()
end

---Clears all set block lights
function lib.clearLights()
	for i = 1, #sources do
		table.remove(sources, keys[i])
		keys[i] = nil
	end

	lib.update()
end

return lib
