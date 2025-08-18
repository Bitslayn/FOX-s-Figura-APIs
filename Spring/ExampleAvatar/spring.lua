--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Spring Lib v1.0.0
--]]
--#REGION ˚♡ FOXSpring ♡˚

---@class FOXSpring
local FOXSpring = {}
local springMeta = { __index = FOXSpring, __type = "FOXSpring" }

local axis = vec(0, 1, 0)

---@package
function FOXSpring:tick()
	---@type FOXSpring.Internal
	local sprVec = self[1]

	-- Gets the directional velocity rotated to player-space

	local playerVelocity = player:getVelocity():mul(1, -1, 1) * self.velStrength
	local relativeVelocity = vectors.rotateAroundAxis(player:getBodyYaw(), playerVelocity, axis):add(self.deformation)

	-- Do the physics (Hooke's Law)

	local displacement = sprVec.pos - relativeVelocity
	local dampingForce = self.viscosity * sprVec.vel
	local force = -self.springiness * displacement - dampingForce

	sprVec.vel = sprVec.vel + force
	sprVec.pos = sprVec.pos + sprVec.vel

	sprVec.old = sprVec.new
	sprVec.new = sprVec.pos

	assert(sprVec.vel:length() < 100, "Velocity exceeded 100 blocks per second!") -- Do not remove this check, it's for your own protection
end

---@package
function FOXSpring:render(delta)
	---@type FOXSpring.Internal
	local sprVec = self[1]

	-- Shears the matrix according to directinal velocity

	local mat = matrices.mat4()
	mat.c2 = math.lerp(sprVec.old, sprVec.new, delta) --[[@as Vector3]]
		:add(0, 1)
		:augmented(0)
	mat.v22 = math.max(0.1, mat.v22)

	-- Stretches the matrix inverse to the vertical shear

	local squish = mat.v22 ^ -self.squishiness
	mat:scale(squish, 1, squish)

	if self.offsetMat then mat:multiply(self.offsetMat) end

	-- Apply the matrix

	self.model:matrix(mat)
end

---Removes this spring
function FOXSpring:remove()
	events.tick:remove(self[1].tick)
	events.render:remove(self[1].render)
end

--#ENDREGION
--#REGION ˚♡ FOXSpringLib ♡˚

---@class FOXSpringLib
local FOXSpringLib = setmetatable({}, { __type = "FOXSpringLib" })

---Creates a new spring
---@param model ModelPart|RenderTask.any|EntityTask
---@param cfg FOXSpring.Config?
---@return FOXSpring
function FOXSpringLib:new(model, cfg)
	-- Setup configs

	---@class FOXSpring.Config
	---@field model ModelPart|RenderTask.any|EntityTask? Model to apply springiness to
	---@field velStrength number|Vector3? `1, 1, 1` - How much the player's velocity affects the spring
	---@field offsetMat Matrix4? `nil` - Applies an offset matrix which you can scale, transform, and rotate
	---@field springiness number|Vector3? `1, 1, 1` - How much the force will try to spring back. Recommended values between 0 and 2
	---@field squishiness number? `0.5` - How much to widen the spring when it compresses
	---@field viscosity number? `0.5` - How easy it is for the spring to stay springy. Recommended values between 0 and 1
	---@field deformation Vector3? `0, 0, 0` - Deforms the spring in a direction relative to the spring's position in the world

	---@class FOXSpring
	---@field model ModelPart|RenderTask.any|EntityTask Model to apply springiness to
	---@field velStrength number|Vector3? `1, 1, 1` - How much the player's velocity affects the spring
	---@field offsetMat Matrix4 `nil` - Applies an offset matrix which you can scale, transform, and rotate
	---@field springiness number|Vector3 `1, 1, 1` - How much the force will try to spring back. Recommended values between 0 and 2
	---@field squishiness number `0.5` - How much to widen the spring when it compresses
	---@field viscosity number `0.5` - How easy it is for the spring to stay springy. Recommended values between 0 and 1
	---@field deformation Vector3 `0, 0, 0` - Deforms the spring in a direction relative to the spring's position in the world
	local spring = setmetatable({
		model = model,
		velStrength = vec(1, 1, 1),
		offsetMat = nil,

		springiness = vec(1, 1, 1),
		squishiness = 0.5,
		viscosity = 0.5,
		deformation = vec(0, 0, 0),
	}, springMeta)

	for key, value in pairs(cfg or {}) do spring[key] = value end

	local t = type(spring.model)
	if not (t:find("Part") or t:find("Task")) then
		error("Invalid model given to this spring! Any model expected, got " .. t, 2)
	end

	-- Setup internals

	---@class FOXSpring.Internal
	---@field vel Vector3 The spring's velocity
	---@field pos Vector3 The spring's displacement
	---@field old Vector3 Used for lerping in render, the old spring displacement
	---@field new Vector3 Used for lerping in render, the new spring displacement
	---@field tick function This spring's tick function so it can be removed
	---@field render function This spring's render function so it can be removed
	---@package
	spring[1] = {
		vel = vectors.vec3(),
		pos = vectors.vec3(),
		old = vectors.vec3(),
		new = vectors.vec3(),

		tick = function() spring:tick() end,
		render = function(delta) spring:render(delta) end,
	}

	events.tick = spring[1].tick
	events.render = spring[1].render

	return spring
end

--#ENDREGION

return FOXSpringLib
