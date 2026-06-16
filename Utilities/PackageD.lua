--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Data Packages Lib v1.0

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/PackageD.lua
]]

--==============================================================================================================================
--#REGION ˚♡ Class ♡˚
--==============================================================================================================================

---@class FOXPackageD
local lib = {}

---Stores the scripts that have loaded and their returns
---@type table<string, any[]>
lib.loaded = {}

---Custom _ENV for required scripts
local _FOX = setmetatable({}, { __index = _G })

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ require ♡˚
--==============================================================================================================================

---Gets the script's modname varargs at the given traceback level
---@param level integer
---@return string, string
local function get_script(level)
	return select(2, pcall(function() error("", level + 3) end)):match("(.-)/?([^/]+):")
end

---Normalizes `./` and `../` in the provided path to the literal path recognizable by the filesystem
---@param modname string
local function normalize(modname)
	---@type string[]
	local nav = {}

	modname = modname
		:gsub("%.", "/") -- Convert . -> /
		:gsub("^//", "./") -- Convert .. -> ./
		:gsub("///", "/..") -- Convert ... -> ../
		:gsub("//", "/.") -- Fix illegal path

	for dir in modname:gmatch("[^/]+") do
		if dir == ".." then
			nav[#nav] = nil
		elseif dir == "." then
			for _dir in get_script(3):gmatch("[^/]+") do
				nav[#nav + 1] = _dir
			end
		else
			nav[#nav + 1] = dir
		end
	end

	return table.concat(nav, "/")
end

---Stores what scripts are being required in the current stack
---
---Allows for detection of circular dependencies
---@type table<string, boolean>
local loading = {}

---Requires a script in the data folder
---@param modname string
---@return ...
function lib.require(modname)
	local path = normalize(modname)

	if lib.loaded[path] then return table.unpack(lib.loaded[path]) end

	if loading[path] then
		error("Detected circular dependency in script " .. select(2, get_script(2)), 2)
	end

	loading[path] = true
	local result = { load(file:readString(path .. ".lua"), path, _FOX)(path:match("(.-)/?([^/]+)$")) }
	loading[path] = nil

	lib.loaded[path] = result
	return table.unpack(result)
end

_FOX.require = lib.require

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ listFiles ♡˚
--==============================================================================================================================

---Recursive helper for listFiles
---@param list any
---@param dir string
---@param recursive boolean?
local function list_recursive(list, dir, recursive)
	local files = file:list(dir)
	for i = 1, #files do
		local curr = dir .. "/" .. files[i]
		local name, ext = files[i]:match("^([^.]+)%.?(.*)")

		if recursive and file:isDirectory(curr) then
			list_recursive(list, curr, recursive)
		elseif ext == "lua" then
			if dir == "" then
				list[#list + 1] = name
			else
				list[#list + 1] = dir .. "/" .. name
			end
		end
	end
end

---Gets a list of all data scripts in the directory
---@param dir string?
---@param recursive boolean?
---@return string[]
function lib.listFiles(dir, recursive)
	local list = {}
	list_recursive(list, dir and dir:gsub("%.", "/") or "", recursive)
	return list
end

_FOX.listFiles = lib.listFiles

return lib

--#ENDREGION
