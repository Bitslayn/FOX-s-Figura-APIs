--[[@diagnostic disable: undefined-field, undefined-global
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Lift Protocol v1.0c

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

---@param key string
---@param vec Vector2|Vector3
---@param uuid string
function lift.proxy(key, vec, uuid)
	if not lift.enabled then return end
	return proxy[key](api, vec, uuid or avatar:getUUID())
end

-- Prompter, called by other avatars on the host system, will prompt sharing proxy to whitelisted avatars. Always visible

---Call this function to update whitelists
function lift.update()
	-- Call all acceptors of whitelisted players, giving them the proxy function

	local plr = world:getPlayers()
	for i, usr in ipairs(lift.whitelist) do
		local acceptor = plr[usr]
			and plr[usr]:getUUID() ~= avatar:getUUID()
			and plr[usr]:getVariable("lift_acceptor")

		pcall(acceptor, function(key, vec)
			if lift.whitelist[i] ~= usr then return false end
			return lift.proxy(key, vec, plr[usr]:getUUID())
		end)
	end
end

avatar:store("lift_prompter", lift.update)

-- Acceptor, called by host to receive host's proxy function. Visible only to the viewer

local prompter = client.getViewer():getVariable("lift_prompter")
if prompter then
	avatar:store("lift_acceptor", function(fun) lift.proxy = fun end)
	pcall(prompter)
end

---@class FOXLift
---@field enabled boolean Set whether other players can move you
---@field maxPos number Set the max pos distance from player
---@field maxVel number Set the max velocity length
---@field whitelist string[] List of names who are allowed to call your functions
---@field setPos fun(self: FOXLift, x: number, y: number, z: number)|fun(self: FOXLift, pos: Vector3) Sets the host's true position
---@field addPos fun(self: FOXLift, x: number, y: number, z: number)|fun(self: FOXLift, pos: Vector3) Sets the host's position offset from their current position
---@field setVel fun(self: FOXLift, x: number, y: number, z: number)|fun(self: FOXLift, vel: Vector3) Sets the host's true velocity
---@field addVel fun(self: FOXLift, x: number, y: number, z: number)|fun(self: FOXLift, vel: Vector3) Sets the host's velocity offset from their current velocity
---@field setRot fun(self: FOXLift, x: number, y: number)|fun(self: FOXLift, rot: Vector2) Sets the host's true rotation
---@field addRot fun(self: FOXLift, x: number, y: number)|fun(self: FOXLift, rot: Vector2) Sets the host's rotation offset from their current rotation
---@field package proxy fun(key: string, vec: Vector2|Vector3, uuid: string) Shared function which calls host functions
return setmetatable(lift, {
	---Allow indexing `lift` and calling viewer functions
	---@param _ FOXLift
	---@param key string
	__index = function(_, key)
		---@param tbl FOXLift
		---@param ... number|Vector2|Vector3
		return function(tbl, ...)
			if not host:isHost() then return false end

			---@type Vector2|Vector3
			---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
			local vec = type(...):find("Vector") and ... or vectors.vec3(...)
			vec:applyFunc(function(i) return i == i and i or 0 end)

			return pcall(tbl.proxy, key, vec, nil)
		end
	end,
})
