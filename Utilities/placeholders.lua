--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Custom Placeholders v1.1.3
--]]

--#REGION ˚♡ Metatable store ♡˚

-- Stores important metatable information

local nameMeta, nameIndex = {
	figuraMetatables.NameplateCustomization,
	figuraMetatables.NameplateCustomizationGroup,
	figuraMetatables.EntityNameplateCustomization,
}, {}
local nameClasses = {
	[nameplate.ALL] = { name = "ALL", index = 2 },
	[nameplate.CHAT] = { name = "CHAT", index = 1 },
	[nameplate.ENTITY] = { name = "ENTITY", index = 3 },
	[nameplate.LIST] = { name = "LIST", index = 1 },
}

local taskMeta = figuraMetatables.TextTask
local taskIndex = taskMeta.__index

--#ENDREGION
--#REGION ˚♡ Placeholder applicator ♡˚

---@type {[string]: string}
local names = {}
---@type {[TextTask]: string}
local tasks = {}

---Table of custom placeholders
---
---Placeholders are replaced automatically if they are found in your nameplate
---
---`${key}` is replaced by value
---@class FOXPlaceholders
---@field [string] string|number
local placeholders = {}
---@package DO NOT TOUCH
placeholders[1] = {}

-- Functions to apply placeholders to nameplates and texttasks

---@param name string
local function applySingleName(name)
	local self = nameplate[name]
	local class = nameClasses[self]

	local old = nameIndex[class.index].getText(self)
	local new = names[class.name]:gsub("%${([%w_]+)}", placeholders[1])
	if old == new then return end

	nameIndex[class.index].setText(self, new)
end

local function applyAllNames()
	for key in pairs(names) do
		applySingleName(key)
	end
end

---@param self TextTask
local function applySingleTask(self)
	local old = taskIndex.getText(self)
	local new = tasks[self]:gsub("%${([%w_]+)}", placeholders[1])
	if old == new then return end

	taskIndex.setText(self, new)
end

local function applyAllTasks()
	for key in pairs(tasks) do
		applySingleTask(key)
	end
end

-- Sets a metatable for placeholders table so that it updates all nameplates and text tasks when a placeholder is updated

setmetatable(placeholders, {
	__newindex = function(self, key, value)
		self[1][key] = value
		if value and not pcall(function() _ = value .. "" end) then
			error("Placeholder must be useable in strings!", 2)
		end
		applyAllNames()
		applyAllTasks()
	end,
})

--#ENDREGION
--#REGION ˚♡ Nameplate listener ♡˚

-- Listens for setting the nameplate

local nameProxy = {}
function nameProxy:setText(text)
	local class = nameClasses[self]
	local ok, err = pcall(nameIndex[class.index].setText, self, text)

	if class.name == "ALL" then
		for _, name in ipairs { "CHAT", "ENTITY", "LIST" } do
			names[name] = text
		end
		applyAllNames()
	else
		names[class.name] = text
		applySingleName(class.name)
	end

	return ok and self or error(err, 2)
end

-- Gets the unmodified nameplate text

function nameProxy:getText()
	local class = nameClasses[self]

	return names[class.name]
end

-- Proxies into each Nameplate index

for i = 1, 3 do
	nameIndex[i] = nameMeta[i].__index
	---@diagnostic disable-next-line: assign-type-mismatch
	nameMeta[i].__index = function(_, key) return nameProxy[key] or nameIndex[i][key] end
end

--#ENDREGION
--#REGION ˚♡ TextTask Listener ♡˚

-- Listens for setting a text task

local taskProxy = {}
function taskProxy:setText(text)
	local ok, err = pcall(taskIndex.setText, self, text)

	if ok then
		tasks[self] = string.find(text or "", "%$%b{}") and text or nil
		if tasks[self] then applySingleTask(self) end
	end

	return ok and self or error(err, 2)
end

taskProxy.text = taskProxy.setText

-- Gets the unmodified or original texttask text

function taskProxy:getText()
	return tasks[self] or taskIndex.getText(self)
end

-- Proxies into texttask index

taskMeta.__index = function(_, key) return taskProxy[key] or taskIndex[key] end

--#ENDREGION

return placeholders
