--[[@diagnostic disable: undefined-field, undefined-global
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Lift Protocol v1.0d

A unique interactions protocol focusing on security
Allows for interacting with the host with a whitelist
Supports Extura, Goofy, or a custom addon

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/Lift.lua
]]

---@class FOXLift
local lift = {
	---Set whether other players can move you
	enabled = true,
	---Set the max pos distance from player
	maxPos = 10,
	---Set the max velocity length
	maxVel = 10,
	---List of names who are allowed to call your functions
	whitelist = { "Steve", "Alex" },
}

-- Define map of functions, and api to use (Goofy, Extura, etc.)

local api = goofy or host
local map = {
	setPos = api.setPos,
	setRot = api.setRot,
	setVel = api.setVelocity,
}

---Internal table containing all functions avatars can run
---@type table<string, fun(slf: any, vec: Vector2|Vector3, uuid: string)>
local proxy = {
	setPos = function(slf, vec, uuid)
		local pos = player:getPos()

		vec = vec - pos
		vec:clampLength(0, lift.maxPos)
		vec = vec + pos

		local x, y, z = vec:unpack()
		return map.setPos(slf, x, y, z, uuid)
	end,
	setRot = function(slf, vec, uuid)
		vec = vectors.vec2():add(vec:unpack())

		local x, y = vec:unpack()
		return map.setRot(slf, x, y, uuid)
	end,
	setVel = function(slf, vec, uuid)
		vec:clampLength(0, lift.maxVel)

		local x, y, z = vec:unpack()
		return map.setVel(slf, x, y, z, uuid)
	end,
	addPos = function(slf, vec, uuid)
		vec:clampLength(0, lift.maxPos)
		vec = vec + player:getPos()

		local x, y, z = vec:unpack()
		return map.setPos(slf, x, y, z, uuid)
	end,
	addRot = function(slf, vec, uuid)
		vec = vectors.vec2():add(vec:unpack())
		vec = vec + player:getRot()

		local x, y = vec:unpack()
		return map.setRot(slf, x, y, uuid)
	end,
	addVel = function(slf, vec, uuid)
		local Motion = player:getNbt().Motion

		vec = vec + vectors.vec3(table.unpack(Motion))
		vec:clampLength(0, lift.maxVel)

		local x, y, z = vec:unpack()
		return map.setVel(slf, x, y, z, uuid)
	end,
}

---@type FOXLift.Functions.Proxy
function lift.proxy(key, x, y, z, uuid)
	if not lift.enabled then error("Not accepting Lift requests") end
	local vec = vectors.vec3(x, y, z)
		:applyFunc(function(i) return i == i and i or 0 end)

	return proxy[key](api, vec, uuid or avatar:getUUID())
end

-- Validator, called by other avatars on the host system while accepting a function. Validates the function to make sure this came from the viewer. Always visible

---@type function
local prompted
avatar:store("lift_validator", function(fun)
	return fun == prompted
end)

-- Prompter, called by other avatars on the host system, will prompt sharing proxy to whitelisted avatars. Always visible

avatar:store("lift_prompter", function()
	-- Call all acceptors of whitelisted players, giving them the proxy function

	local plr = world:getPlayers()
	for _, usr in ipairs(lift.whitelist) do
		local acceptor = plr[usr]
			and plr[usr]:getUUID() ~= avatar:getUUID()
			and plr[usr]:getVariable("lift_acceptor")

		prompted = function(key, x, y, z)
			return lift.proxy(key, x, y, z, plr[usr]:getUUID())
		end
		pcall(acceptor, prompted)
	end
end)

-- Acceptor, called by avatars to receive host's proxy function. Visible only to the viewer

local viewer = client.getViewer()
local prompter = viewer:getVariable("lift_prompter")
local validator = viewer:getVariable("lift_validator")
if prompter and validator then
	avatar:store("lift_acceptor", function(fun)
		lift.proxy = validator(fun) and fun or lift.proxy
	end)
	pcall(prompter)
end

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
---@field maxPos number Set the max pos distance from player
---@field maxVel number Set the max velocity length
---@field whitelist string[] List of names who are allowed to call your functions
---@field setPos FOXLift.Functions.Position Sets the host's true position. Returns a callback saying whether this function executed successfully
---@field addPos FOXLift.Functions.Position Sets the host's position offset from their current position. Returns a callback saying whether this function executed successfully
---@field setVel FOXLift.Functions.Velocity Sets the host's true velocity. Returns a callback saying whether this function executed successfully
---@field addVel FOXLift.Functions.Velocity Sets the host's velocity offset from their current velocity. Returns a callback saying whether this function executed successfully
---@field setRot FOXLift.Functions.Rotation Sets the host's true rotation. Returns a callback saying whether this function executed successfully
---@field addRot FOXLift.Functions.Rotation Sets the host's rotation offset from their current rotation. Returns a callback saying whether this function executed successfully
---@field package proxy FOXLift.Functions.Proxy Shared function which calls host functions
return setmetatable(lift, {
	---Allow indexing `lift` and calling viewer functions
	---@param _ FOXLift
	---@param key string
	__index = function(_, key)
		---@param tbl FOXLift
		---@param x number|Vector2|Vector3
		---@param y number
		---@param z number
		return function(tbl, x, y, z)
			if type(x) == "Vector3" then
				x, y, z = x:unpack()
			elseif type(x) == "Vector2" then
				x, y = x:unpack()
				z = 0
			end

			return pcall(tbl.proxy, key, x, y, z, nil)
		end
	end,
})
