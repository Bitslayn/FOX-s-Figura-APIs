--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Better ModelPart Errors v0.1.2
]]

---Custom error message for calling a method on NullModelParts
local err = [=[ModelPart path is incorrect. Underlined does not exist in non-underlined

%s
script:
%s§o<--[Here]§c

(Below contains additional information)]=]

---@class ModelPart
local ModelPart = figuraMetatables.ModelPart
local MP_i = ModelPart.__index

---@class NullModelPart: ModelPart
local NullModelPart_i = {
	__type = "NullModelPart",
	__index = function(self, key)
		local priv = self[1]
		if type(MP_i(models, key)) ~= "function" and priv.depth < 16 then
			priv.depth = priv.depth + 1
			return self
		end

		error(err:format(priv.stack, priv.script), 2)
	end,
	__metatable = nil,
}

function ModelPart:__index(key)
	local valid = MP_i(self, key)
	if valid then return valid end

	-- Get traceback and line number of invalid indexed part

	---@type string, string
	local trace, stack = select(2, pcall(function() error("", 4) end)):match("([^\n]-)\n(.*)")
	---@type string, string
	local scriptPath, scriptLine = trace:match("(.*):([%d]*)")

	scriptPath = scriptPath:gsub("/", ".")
	scriptLine = tonumber(scriptLine)

	-- Get script where invalid part was indexed

	local buffer = data:createBuffer()
	for _, v in pairs(avatar:getNBT().scripts[scriptPath]) do
		buffer:write(v)
	end
	buffer:setPosition(0)
	local decoded = buffer:readByteArray()
	buffer:close()

	-- Get exact line from script where invalid part was indexed

	local rawScript
	local i = 0
	for v in decoded:gmatch("[^\n]*") do
		i = i + 1
		if i == scriptLine then rawScript = "  " .. v:gsub("%s*$", "") end
	end

	-- Underline invalid index

	local part = self
	local script = rawScript:gsub("([.%[])", function(sep)
		if not part then return end
		part = part:getParent()
		return part and sep or "§n" .. sep
	end) .. "§c"

	-- Create and return NullModelPart only if organically indexed

	return script:find("[=(,]%s*models") and
	setmetatable({ [1] = { stack = stack, script = script, depth = 1 } }, NullModelPart_i)
end

local a = models.Models
local b = a.b
print(type(b))
