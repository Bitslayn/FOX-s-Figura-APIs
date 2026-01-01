--[[@diagnostic disable: undefined-field, undefined-global
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Lift Protocol v1.0e

A unique interactions protocol focusing on security
Allows for interacting with the host with a whitelist
Supports Extura, Goofy, or a custom addon

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/Lift.lua
]]

--==============================================================================================================================
--#REGION ˚♡ API ♡˚
--==============================================================================================================================

---@class FOXLift
local lift = {
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

local api = goofy or host
local map = {
	setPos = api.setPos,
	setRot = api.setRot,
	setVel = api.setVelocity,
}

---Internal table containing all functions avatars can run
---@type table<string, fun(x: number, y: number, z: number, uuid: string)>
local proxy_funcs = {
	setPos = function(x, y, z, uuid)
		local vec = vectors.vec3(x, y, z):applyFunc(function(v)
			return v == v and v or 0
		end)

		vec = vec - player:getPos()
		vec:clampLength(0, lift.maxPos)
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

		vec:clampLength(0, lift.maxVel)

		x, y, z = vec:unpack()
		return map.setVel(api, x, y, z, uuid)
	end,
	addPos = function(x, y, z, uuid)
		local vec = vectors.vec3(x, y, z):applyFunc(function(v)
			return v == v and v or 0
		end)

		vec:clampLength(0, lift.maxPos)
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
		vec:clampLength(0, lift.maxVel)

		x, y, z = vec:unpack()
		return map.setVel(api, x, y, z, uuid)
	end,
}

---Returns if the viewer has FOXLift
---@return boolean
function lift:hasLift()
	local var = client.getViewer():getVariable("FOXLift")
	return var and true or false
end

---Returns a config from the viewer by its key
---@param key any
---@return any
function lift:getConfig(key)
	local var = client.getViewer():getVariable("FOXLift")
	return var and (key and var.config[key] or var.config)
end

---Returns if this avatar is whitelisted by the viewer
---@return boolean?
function lift:isWhitelisted()
	local cfg = self:getConfig("whitelist")
	return cfg and cfg[avatar:getName()]
end

---Returns if the viewer has FOXLift enabled
---@return boolean?
function lift:isEnabled()
	return self:getConfig("enabled")
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Protocol ♡˚
--==============================================================================================================================

---@class FOXLift.Protocol
local lib = { config = lift }
avatar:store("FOXLift", lib)

---@type function
local prompted

---Creates and shares proxy function to all avatars in this avatar's whitelist.
function lib.prompter()
	local plr = world:getPlayers()

	for usr in pairs(lift.whitelist) do
		local var = plr[usr] and plr[usr]:getVariable("FOXLift")
		local acceptor = var and var.acceptor

		prompted = function(key, x, y, z)
			if not lift.whitelist[usr] then return false, "whitelist" end
			if not lift.enabled then return false, "disabled" end
			return true, proxy_funcs[key](x, y, z, plr[usr]:getUUID())
		end

		pcall(acceptor, prompted)
	end
end

---@type function
local proxy

---Receives and stores proxy function.
function lib.acceptor(fun)
	local var = client.getViewer():getVariable("FOXLift")
	local validator = var.validator

	local suc, val = pcall(validator, fun)
	proxy = (suc and val) and fun or proxy
end

---Validates incoming proxy function to make sure they were made by the viewer.
function lib.validator(fun)
	return fun == prompted
end

-- Call viewer prompter on this avatar's init

local var = client.getViewer():getVariable("FOXLift")
local prompter = var and var.prompter
pcall(prompter)

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Wrapper ♡˚
--==============================================================================================================================

---@alias FOXLift.Functions.Position
---| fun(self: FOXLift, x: number, y: number, z: number): boolean, ...
---| fun(self: FOXLift, pos: Vector3): boolean, ...
---@alias FOXLift.Functions.Velocity
---| fun(self: FOXLift, x: number, y: number, z: number): boolean, ...
---| fun(self: FOXLift, vel: Vector3): boolean, ...
---@alias FOXLift.Functions.Rotation
---| fun(self: FOXLift, x: number, y: number): boolean, ...
---| fun(self: FOXLift, rot: Vector2): boolean, ...
---@alias FOXLift.Functions.Proxy
---| fun(key: string, x: number, y: number, z: number, uuid: string)
---@class FOXLift
---@field enabled boolean Set whether other players can move you
---@field whitelist table<string, boolean> List of names who are allowed to call your functions
---@field maxPos number Set the max pos distance from player
---@field maxVel number Set the max velocity length
---@field setPos FOXLift.Functions.Position Sets the host's true position. Returns a callback saying whether this function executed successfully
---@field addPos FOXLift.Functions.Position Sets the host's position offset from their current position. Returns a callback saying whether this function executed successfully
---@field setVel FOXLift.Functions.Velocity Sets the host's true velocity. Returns a callback saying whether this function executed successfully
---@field addVel FOXLift.Functions.Velocity Sets the host's velocity offset from their current velocity. Returns a callback saying whether this function executed successfully
---@field setRot FOXLift.Functions.Rotation Sets the host's true rotation. Returns a callback saying whether this function executed successfully
---@field addRot FOXLift.Functions.Rotation Sets the host's rotation offset from their current rotation. Returns a callback saying whether this function executed successfully

setmetatable(lift, {
	---Allow indexing `lift` and calling viewer functions
	---@param _ FOXLift
	---@param key string
	__index = function(_, key)
		---@param _ FOXLift
		---@param x number|Vector2|Vector3
		---@param y number
		---@param z number
		return function(_, x, y, z)
			if type(x) == "Vector3" then
				x, y, z = x:unpack()
			elseif type(x) == "Vector2" then
				x, y = x:unpack()
			end

			local suc, c1, c2 = pcall(proxy, key, x, y, z, nil)
			return suc and c1, suc and c2 or c1
		end
	end,
})

setmetatable(lift.whitelist, {
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
