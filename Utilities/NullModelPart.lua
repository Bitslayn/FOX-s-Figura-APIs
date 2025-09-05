--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Better ModelPart Errors v0.2.0
]]

---@param priv NullModelPart.*INTERNAL*
local function buildError(priv)
	local formatting = "§7" .. priv.index[1]
	for i = 2, #priv.index do
		local v = priv.index[i]
		formatting = formatting .. (v:find("%s") and '["%s"]' or ".%s"):format(v)

		if i == priv.validDepth then
			formatting = formatting .. "§c§n"
		end
	end
	formatting = formatting .. "§c"

	local err =
	'ModelPart path is incorrect. "%s" is not a child of "%s". Please check spelling and capitalization \n\n%s§o<--[Here]§c\n\n%s\nscript:\n  %s\n\n(Below contains additional information)'

	error(err:format(priv.index[priv.validDepth + 1], priv.index[priv.validDepth], formatting, priv.stack, priv.script), 3)
end

---@class ModelPart
local ModelPart = figuraMetatables.ModelPart
local MP_i = ModelPart.__index

---@class NullModelPart: ModelPart
local NullModelPart_i = {
	__type = "NullModelPart",
	__index = function(self, key)
		---@class NullModelPart.*INTERNAL*
		local priv = self[1]

		-- Add key to index if the indexed is not a function

		if type(MP_i(models, key)) ~= "function" and priv.invalidDepth < 16 then
			priv.invalidDepth = priv.invalidDepth + 1
			table.insert(priv.index, key)
			return self
		end

		buildError(priv)
	end,
	__metatable = nil,
}

function ModelPart:__index(key)
	local valid = MP_i(self, key)
	if valid then return valid end

	---@class NullModelPart.*INTERNAL*
	local priv = {}

	-- Get traceback and line number of invalid indexed part

	---@type string, string
	priv.trace, priv.stack = select(2, pcall(function() error("", 4) end)):match("([^\n]-)\n(.*)")
	---@type string, string
	local scriptPath, scriptLine = priv.trace:match("(.*):([%d]*)")

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

	local i = 0
	for v in decoded:gmatch("[^\n]*") do
		i = i + 1
		if i == scriptLine then priv.script = v:gsub("%s*$", "") end
	end

	-- Build index tree

	---@type number
	priv.validDepth = 0
	---@type string[]
	priv.index = {}
	local part = self
	while part do
		table.insert(priv.index, 1, part:getName())
		part = part:getParent()
		priv.validDepth = priv.validDepth + 1
	end

	---@type number
	priv.invalidDepth = 1
	table.insert(priv.index, key)

	-- Create and return NullModelPart only if organically indexed

	if not priv.script:find("[=(,]%s*models") then return end
	return setmetatable({ [1] = priv }, NullModelPart_i)
end

local a, b = models.Models.Player.root["A B"], models.Models.Player.Root
print(a:rot(), b:rot())
