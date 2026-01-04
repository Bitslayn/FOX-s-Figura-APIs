--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Lift Protocol v1.1

A unique interactions protocol focusing on security
Allows for moving and interacting with the viewer with a whitelist
Supports Extura, Goofy, Silly, or a custom addon

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/Lift.lua
]]

--==============================================================================================================================
--#REGION ˚♡ Config ♡˚
--==============================================================================================================================

local cfg = {
	---Set whether other players can move you
	enabled = true,
	---List of names who are allowed to call your functions
	whitelist = {
		Steve = true,
		Alex = true,
	},

	---Set the max pos distance from player
	maxPos = 10,
	---Set the max velocity length
	maxVel = 10,
}

-- Define map of functions, and api to use (Goofy, Extura, etc.)

---@type table
---@diagnostic disable-next-line: undefined-global
local api = silly or goofy or host
local map = {
	setPos = api.setPos,
	setRot = api.setRot,
	setVel = api.setVelocity,
}

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Proxy ♡˚
--==============================================================================================================================

---Proxy of all callable functions passed to avatars on the whitelist
---
---Do not touch this if you don't know what you're doing! NaN checking and clamping is your responsibility!
---@type table<string, FOXLift.Proxy>
local proxy = setmetatable({
	setPos = function(x, y, z, uuid)
		local vec = vectors.vec3(x, y, z):applyFunc(function(v)
			return v == v and v or 0
		end)

		vec = vec - player:getPos()
		vec:clampLength(0, cfg.maxPos)
		vec = vec + player:getPos()

		x, y, z = vec:unpack()
		return map.setPos(api, x, y, z, uuid)
	end,
	setRot = function(x, y, z, uuid)
		local vec = vectors.vec2(x, y):applyFunc(function(v)
			return v == v and v or 0
		end)

		x, y = vec:unpack()
		return map.setRot(api, x, y, uuid)
	end,
	setVel = function(x, y, z, uuid)
		local vec = vectors.vec3(x, y, z):applyFunc(function(v)
			return v == v and v or 0
		end)

		vec:clampLength(0, cfg.maxVel)

		x, y, z = vec:unpack()
		return map.setVel(api, x, y, z, uuid)
	end,
	addPos = function(x, y, z, uuid)
		local vec = vectors.vec3(x, y, z):applyFunc(function(v)
			return v == v and v or 0
		end)

		vec:clampLength(0, cfg.maxPos)
		vec = vec + player:getPos()

		x, y, z = vec:unpack()
		return map.setPos(api, x, y, z, uuid)
	end,
	addRot = function(x, y, z, uuid)
		local vec = vectors.vec2(x, y):applyFunc(function(v)
			return v == v and v or 0
		end)

		vec = vec + player:getRot()

		x, y = vec:unpack()
		return map.setRot(api, x, y, uuid)
	end,
	addVel = function(x, y, z, uuid)
		local vec = vectors.vec3(x, y, z):applyFunc(function(v)
			return v == v and v or 0
		end)

		vec = vec + vectors.vec3(table.unpack(player:getNbt().Motion))
		vec:clampLength(0, cfg.maxVel)

		x, y, z = vec:unpack()
		return map.setVel(api, x, y, z, uuid)
	end,
}, {
	__call = function(self, uuid, usr)
		return function(key, x, y, z)
			if not cfg.whitelist[usr] then return end
			if not cfg.enabled then return end

			return self[key](x, y, z, uuid)
		end
	end,
})

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Protocol ♡˚
--==============================================================================================================================

---@class FOXLift.Protocol
---@field config FOXLift.Config
local lib = { config = cfg, version = 1.1 }
avatar:store("FOXLift", lib)

---Function defined by the viewer when they prompt other avatars
---
---Used in validation
---@type function
local prompted
---Accepted function stored on other avatars when a function has been accepted and validated from the viewer
---@type function
local accepted

---Creates and shares proxy function to all avatars in this avatar's whitelist.
function lib.prompter()
	local plr = world:getPlayers()

	for usr in pairs(lib.config.whitelist) do
		local cur = plr[usr]
		if cur then
			local var = cur:getVariable("FOXLift")
			local acceptor = var and var.acceptor

			prompted = proxy(cur:getUUID(), usr)
			pcall(acceptor, prompted)
		end
	end
end

---Receives and stores proxy function.
function lib.acceptor(fun)
	local var = client.getViewer():getVariable("FOXLift")
	local validator = var.validator

	local suc, val = pcall(validator, fun)
	accepted = (suc and val) and fun or accepted
end

---Validates incoming proxy function to make sure they were made by the viewer.
function lib.validator(fun)
	return fun == prompted
end

local var = client.getViewer():getVariable("FOXLift")
local prompter = var and var.prompter
pcall(prompter)

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Wrapper ♡˚
--==============================================================================================================================

---@class FOXLift.Config
---@field enabled boolean Set whether other players can move you
---@field whitelist table<string, boolean> List of names who are allowed to call your functions
---@field maxPos number Set the max pos distance from player
---@field maxVel number Set the max velocity length
---@alias FOXLift.Position
---| fun(self: FOXLift, x: number, y: number, z: number): boolean, ...
---| fun(self: FOXLift, pos: Vector3, uuid: string?): boolean, ...
---@alias FOXLift.Velocity
---| fun(self: FOXLift, x: number, y: number, z: number): boolean, ...
---| fun(self: FOXLift, vel: Vector3, uuid: string?): boolean, ...
---@alias FOXLift.Rotation
---| fun(self: FOXLift, x: number, y: number): boolean, ...
---| fun(self: FOXLift, rot: Vector2, uuid: string?): boolean, ...
---@alias FOXLift.Proxy
---| fun(key: string, x: number, y: number, z: number, uuid: string): ...
---@class FOXLift
---@field config FOXLift.Config
---@field setPos FOXLift.Position Sets the host's true position. Returns a callback saying whether this function executed successfully
---@field addPos FOXLift.Position Sets the host's position offset from their current position. Returns a callback saying whether this function executed successfully
---@field setVel FOXLift.Velocity Sets the host's true velocity. Returns a callback saying whether this function executed successfully
---@field addVel FOXLift.Velocity Sets the host's velocity offset from their current velocity. Returns a callback saying whether this function executed successfully
---@field setRot FOXLift.Rotation Sets the host's true rotation. Returns a callback saying whether this function executed successfully
---@field addRot FOXLift.Rotation Sets the host's rotation offset from their current rotation. Returns a callback saying whether this function executed successfully
local lift = { config = cfg }

---Returns if the viewer has FOXLift
---@return boolean
function lift:hasLift()
	local _var = client.getViewer():getVariable("FOXLift")
	return _var and true or false
end

---Returns a config from the viewer by its key
---@param key any
---@return any
function lift:getConfig(key)
	local _var = client.getViewer():getVariable("FOXLift")
	return _var and (key and _var.config[key] or _var.config) or nil
end

---Returns if this avatar is whitelisted by the viewer
---@return boolean?
function lift:isWhitelisted()
	local _cfg = self:getConfig("whitelist")
	return _cfg and _cfg[avatar:getName()]
end

---Returns if the viewer has FOXLift enabled
---@return boolean?
function lift:isEnabled()
	return self:getConfig("enabled")
end

setmetatable(lift, {
	---Allow indexing `lift` and calling viewer functions
	---@param _ FOXLift
	---@param key string
	__index = function(_, key)
		---@param _ FOXLift
		---@param x number|Vector2|Vector3
		---@param y string|number
		---@param z number
		return function(_, x, y, z)
			if type(y) == "string" and client.getViewer():getUUID() ~= y then return end

			if type(x):find("Vector") then
				x, y, z = x --[[@as Vector.any]]:unpack()
			end

			return pcall(accepted, key, x, y, z)
		end
	end,
})

setmetatable(cfg.whitelist, {
	---Allow for adding names to whitelist
	---@param tbl table
	---@param key string
	---@param val boolean
	__newindex = function(tbl, key, val)
		rawset(tbl, key, val)
		lib.prompter()
	end,
})

return lift

--#ENDREGION
