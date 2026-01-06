--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Lift Protocol v1.2

A unique interactions protocol focusing on security
Allows for interacting with the viewer with a whitelist
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
---@type FOXLift.Proxy.Table
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
	setRot = function(x, y, _, uuid)
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
	addRot = function(x, y, _, uuid)
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

-- This is the current protocol, made with the help of 4P5.
-- It's very simple, calling acceptors which store only the viewer's proxy function.

-- The proxy function, provided by the wrapper, gives avatars access to functions in the viewer scope.

-- All you'll need to make Lift's protocol compatible with your wrapper is to provide your own proxy and config.
-- You can make the prompter do anything as long as lib.prompted stores the proxy as a function. The prompter is host scope.
-- Modifying what the acceptor does requires a Lift protocol version bump. Avoid touching this as it is viewer scope.

---@class FOXLift.Protocol
---@field config FOXLift.Config
local lib = { config = cfg, version = 1.2 }
avatar:store("FOXLift", lib)

---Creates and shares proxy function to all avatars in this avatar's whitelist.
function lib.prompter()
	local plr = world:getPlayers()

	for usr in pairs(lib.config.whitelist) do
		local cur = plr[usr]
		if cur then
			local var = cur:getVariable("FOXLift")
			local acceptor = var and var.acceptor

			lib.prompted = proxy(cur:getUUID(), usr)
			pcall(acceptor)
			lib.prompted = nil
		end
	end
end

---Accepted function stored on other avatars when a function has been accepted from the viewer.
---@type function?
local accepted

---Receives and stores proxy function.
function lib.acceptor()
	local var = client.getViewer():getVariable("FOXLift")
	accepted = var.prompted or accepted
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
---| fun(uuid: string?, x: number, y: number, z: number): boolean, ...
---| fun(uuid: string?, pos: Vector3): boolean, ...
---@alias FOXLift.Velocity
---| fun(uuid: string?, x: number, y: number, z: number): boolean, ...
---| fun(uuid: string?, vel: Vector3): boolean, ...
---@alias FOXLift.Rotation
---| fun(uuid: string?, x: number, y: number): boolean, ...
---| fun(uuid: string?, rot: Vector2): boolean, ...
---@alias FOXLift.Proxy.Function
---| fun(x: number, y: number, z: number, uuid: string): ...
---@alias FOXLift.Proxy.Table
---| table<string, FOXLift.Proxy.Function>
---@class FOXLift
---@field config FOXLift.Config
---@field proxy FOXLift.Proxy.Table
---@field setPos FOXLift.Position Sets the host's true position. Returns a callback saying whether this function executed successfully
---@field addPos FOXLift.Position Sets the host's position offset from their current position. Returns a callback saying whether this function executed successfully
---@field setVel FOXLift.Velocity Sets the host's true velocity. Returns a callback saying whether this function executed successfully
---@field addVel FOXLift.Velocity Sets the host's velocity offset from their current velocity. Returns a callback saying whether this function executed successfully
---@field setRot FOXLift.Rotation Sets the host's true rotation. Returns a callback saying whether this function executed successfully
---@field addRot FOXLift.Rotation Sets the host's rotation offset from their current rotation. Returns a callback saying whether this function executed successfully
local lift = { config = cfg, proxy = proxy }

---Returns if the viewer has FOXLift
---@return boolean
function lift.hasLift()
	local _var = client.getViewer():getVariable("FOXLift")
	return _var and true or false
end

---Returns a config from the viewer by its key
---@param ... any
---@return any
function lift.getConfig(...)
	local v = { ... }
	local key = v[#v]

	local _var = client.getViewer():getVariable("FOXLift")
	local _cfg = _var and _var.config
	return _cfg and (key and _cfg[key] or _cfg) or nil
end

---Returns if this avatar is whitelisted by the viewer
---@return boolean?
function lift.isWhitelisted()
	local _cfg = lift.getConfig("whitelist")
	return _cfg and _cfg[avatar:getEntityName()]
end

---Returns if the viewer has FOXLift enabled
---@return boolean?
function lift.isEnabled()
	return lift.getConfig("enabled")
end

setmetatable(lift, {
	---Allow indexing `lift` and calling viewer functions
	---@param _ FOXLift
	---@param key string
	__index = function(_, key)
		---@param uuid FOXLift
		---@param x number|Vector2|Vector3
		---@param y string|number
		---@param z number
		return function(uuid, x, y, z)
			uuid = type(uuid) ~= "string" and uuid or client.getViewer():getUUID() == uuid -- 1.2
			y = type(y) ~= "string" and y or client.getViewer():getUUID() == y -- 1.1
			if uuid ~= true and y ~= true then return true, "viewer isn't target" end

			if type(x):find("Vector") then
				x, y, z = x --[[@as Vector.any]]:unpack()
			end

			if not accepted then return false, "accepted is nil" end
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
