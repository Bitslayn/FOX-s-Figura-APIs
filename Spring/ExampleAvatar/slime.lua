--#REGION ˚♡ Setup ♡˚

vanilla_model.ALL:visible(false)
vanilla_model.HELMET:visible(true)
vanilla_model.HELMET_ITEM:visible(true)

local slime = models:newPart("Slime")
slime:newPart("HelmetPivot", "HelmetPivot")
	:scale(4)
slime:newPart("HelmetItemPivot", "HelmetItemPivot")
	:scale(4)
local slimeEntity = slime:newEntity("Slime")
	:setNbt("minecraft:slime", "{Size:3}")
	:rot(0, 180)

renderer:shadowRadius(1)

--#ENDREGION
--#REGION ˚♡ Light level ♡˚

function events.tick()
	local eyePivot = player:getPos()
		:add(0, player:getEyeHeight())
		:add(player:getVariable("eyePos"))

	slimeEntity:light(
		world.getBlockLightLevel(eyePivot),
		world.getSkyLightLevel(eyePivot)
	)
end

--#ENDREGION
--#REGION ˚♡ Slime Physics ♡˚

local spring = require("spring")
local phys = spring:new(slime, {
	velStrength = vec(1, 1, 1),
	offsetMat = matrices.mat4()
		:rotate(0, 0, 0)
		:scale(1, 1, 1)
		:translate(0, 0, 0),

	springiness = 0.5,
	squishiness = 0.5,
	viscosity = 0.25,
})

function events.tick()
	phys.deformation.y = player:isCrouching() and -0.5 or 0
end

--#ENDREGION
--#REGION ˚♡ Slime Effects ♡˚

function events.entity_init()
	local wasOnGround = player:isOnGround()
	function events.tick()
		local isOnGround = player:isOnGround()
		if wasOnGround == isOnGround then return end
		wasOnGround = isOnGround

		if isOnGround then
			-- Land on ground

			sounds:playSound("minecraft:entity.slime.squish", player:getPos())
			for _ = 1, 16 do
				particles:newParticle("minecraft:item_slime", vectors.vec3()
					:applyFunc(function(_, v)
						if v == 2 then return 0 end
						return (math.random() - 0.5) * 2
					end)
					:add(player:getPos())
				)
			end
		else
			-- Jump

			sounds:playSound("minecraft:entity.slime.jump", player:getPos())
		end
	end

	local wasCrouching = player:isCrouching()
	function events.tick()
		local isCrouching = player:isCrouching()
		if wasCrouching == isCrouching then return end
		wasCrouching = isCrouching

		sounds:playSound("minecraft:entity.slime.squish", player:getPos())
	end
end

--#ENDREGION
