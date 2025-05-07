--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Camera API v1.4.4

Recommended Figura 0.1.6 or Goofy Plugin
Supports 0.1.5 without pre_render with the built-in compatibility mode

It is HIGHLY recommended that you install Sumneko's Lua Language Server and GS Figura Docs
LLS: https://marketplace.visualstudio.com/items/?itemName=sumneko.lua
GS Docs: https://github.com/GrandpaScout/FiguraRewriteVSDocs

FOXCamera Download: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/FOXCamera/FOXCamera.lua
FOXCamera Wiki: https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXCamera

--]]

--#REGION ˚♡ Library configs ♡˚

-- Anything in here can be changed or adjusted. Just remember to keep things neat and tidy :3

local logOnCompat = true -- Set this to false to disable compatibility warnings

---@alias Camera.presets
---| "CASUAL" A preset optimized for casual play. Has a near-vanilla feel with crouching and crawling. Recommended to use this with a modelpart placed inside the body at eye level
---| "CASUAL_FAIR" Same as CASUAL, but disables offseting the eye pivot
---| "PRO" A preset optimized for a gimbal locked camera. Recommended to use this with a modelpart placed inside the head
---| "PRO_FAIR" Same as PRO, but disables offseting the eye pivot
---| "WORLD" A preset optimized for animations or drones. Recommended to use with world modelparts

---@type table<Camera.presets, Camera>
local cameraPresets = {
  CASUAL = { doEyeOffset = true },
  CASUAL_FAIR = {},
  PRO = { doEyeOffset = true, doEyeRotation = true, unlockPos = true, unlockRot = true },
  PRO_FAIR = { unlockPos = true, unlockRot = true },
  WORLD = { parentType = "WORLD", unlockRot = true },
}

--#ENDREGION
--#REGION ˚♡ Important ♡˚

local isHost = host:isHost()

-- Will apply to versions 1.20.6 and above, used to disable applying the camera matrix for scaling and rolling camera on versions that don't support it
local cameraMatVer = client.compareVersions(client:getVersion(), "1.20.6") ~= -1

-- Protect your metatables
figuraMetatables.Vector3.__metatable = false

---`FOXAPI` Raises an error if the value of its argument v is false (i.e., `nil` or `false`); otherwise, returns all its arguments. In case of error, `message` is the error object; when absent, it defaults to `"assertion failed!"`
---@generic T
---@param v? T
---@param message? any
---@param level? integer
---@return T v
function assert(v, message, level)
  return v or error(message or "Assertion failed!", (level or 1) + 1)
end

---@class Camera
local curr
---@class Camera
local last

-- Render context categories for preventing render events from running when they should not

-- Used for filtering out pulling the modelpart matrix for contexts that the player isn't rendering in-world
local playerContext = { RENDER = true, FIRST_PERSON = true }
-- Used for setting the hiddenPart visibility. ANY OTHER render context will always show the modelpart. (Other is here for FPM support. It cannot distinguish between FPM and shaders)
local firstPersonContext = { OTHER = true, RENDER = true, FIRST_PERSON = true }

--#ENDREGION
--#REGION ˚♡ API ♡˚

---@class CameraAPI
---@field attributes {scale: number, cameraDistance: number}
local CameraAPI = { attributes = {} }

---@class Camera
---@field private renderPart ModelPart? A modelpart created when the camera is set. Used for checking if partToWorldMatrix actually returns a matrix
---@field cameraPart ModelPart? The modelpart which the camera will follow. You would usually want this to be a pivot inside your body positioned at eye level
---@field hiddenPart ModelPart? The modelpart which will become hidden in first person. You would usually want this to be your head group
---@field parentType Camera.parentType? `"PLAYER"` What the camera is following, whether it be a player part or a world part. This should reflect the modelpart parent type
---@field distance number? `nil` The distance to move the camera out in third person
---@field scale number? `1` The camera's scale, used for camera collisions, and position offsets
---@field unlockPos boolean? `false` Unlocks the camera's horizontal movement to follow the modelpart's position
---@field unlockRot boolean? `false` Unlocks the camera's rotation to follow the modelpart's rotation
---@field doCollisions boolean? `true` Prevents the camera from passing through solid blocks
---@field doEyeOffset boolean? `false` Moves the player's eye offset with the camera
---@field doEyeRotation boolean? `false` Rotates the player's eye offset with the camera rotation. Only applied when doEyeOffset is also set to true
---@field doLerpH boolean? `true` If the camera's horizontal position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@field doLerpV boolean? `true` If the camera's vertical position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@field offsetPos Vector3? `vec(0, 0, 0)` Offsets the camera position. Uses the space defined in `offsetSpace`. Applied even if unlockPos is set to false
---@field offsetRot Vector3? `vec(0, 0, 0)` Offsets the camera rotation. Applied even if unlockRot is set to false
---@field offsetSpace Camera.offsetSpace? `"CAMERA"` The space which offsets are applied relative to
---@alias Camera.parentType
---| "PLAYER" Applies optimizations meant for cameras attached to the player
---| "WORLD" Applies optimizations meant for cameras attached to a world modelpart
---@alias Camera.offsetSpace
---| "LOCAL" Offsets the camera relative to the modelpart. Uses blockbench coordinates
---| "WORLD" Offsets the camera relative to the world. Uses world coordinates
---| "CAMERA" Offsets the camera relative to the camera. Uses world coordinates

---Generates a new camera with the given configurations
---@param cameraPart ModelPart The modelpart which the camera will follow. You would usually want this to be a pivot inside your body positioned at eye level
---@param hiddenPart ModelPart? The modelpart which will become hidden in first person. You would usually want this to be your head group
---@param parentType Camera.parentType? `"PLAYER"` What the camera is following, whether it be a player part or a world part. This should reflect the modelpart parent type
---@param distance number? `nil` The distance to move the camera out in third person
---@param scale number? `1` The camera's scale, used for camera collisions, and position offsets
---@param unlockPos boolean? `false` Unlocks the camera's horizontal movement to follow the modelpart's position
---@param unlockRot boolean? `false` Unlocks the camera's rotation to follow the modelpart's rotation
---@param doCollisions boolean? `true` Prevents the camera from passing through solid blocks
---@param doEyeOffset boolean? `false` Moves the player's eye offset with the camera
---@param doEyeRotation boolean? `false` Rotates the player's eye offset with the camera rotation. Only applied when doEyeOffset is also set to true
---@param doLerpH boolean? `true` If the camera's horizontal position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@param doLerpV boolean? `true` If the camera's vertical position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@param offsetPos Vector3? `vec(0, 0, 0)` Offsets the camera position. Uses the space defined in `offsetSpace`. Applied even if unlockPos is set to false
---@param offsetRot Vector3? `vec(0, 0, 0)` Offsets the camera rotation. Applied even if unlockRot is set to false
---@param offsetSpace Camera.offsetSpace? `"CAMERA"` The space which offsets are applied relative to
---@return Camera
function CameraAPI.newCamera(cameraPart, hiddenPart, parentType, distance, scale, unlockPos,
                             unlockRot, doCollisions, doEyeOffset, doEyeRotation, doLerpH, doLerpV,
                             offsetPos, offsetRot, offsetSpace)
  -- Create, and return a camera table with the given arguments

  return {
    cameraPart    = cameraPart,
    hiddenPart    = hiddenPart,
    parentType    = parentType,
    distance      = distance,
    scale         = scale,
    unlockPos     = unlockPos,
    unlockRot     = unlockRot,
    doCollisions  = doCollisions,
    doEyeOffset   = doEyeOffset,
    doEyeRotation = doEyeRotation,
    doLerpH       = doLerpH,
    doLerpV       = doLerpV,
    offsetPos     = offsetPos,
    offsetRot     = offsetRot,
    offsetSpace   = offsetSpace,
  }
end

---Generates a new camera from a preset
---@param preset Camera.presets The preset to apply to this camera
---@param cameraPart ModelPart The modelpart which the camera will follow. You would usually want this to be a pivot inside your body positioned at eye level
---@param hiddenPart ModelPart? The modelpart which will become hidden in first person. You would usually want this to be your head group
---@return Camera
function CameraAPI.newPresetCamera(preset, cameraPart, hiddenPart)
  -- Localize the preset, and make sure it exists

  local pTbl = cameraPresets[preset]
  assert(pTbl, "Unknown preset to apply to this camera!", 2)

  -- Create a camera table with the given arguments

  local newTbl = { cameraPart = cameraPart, hiddenPart = hiddenPart }

  -- Add the preset's configs to the newly created camera table, and return

  for k, v in pairs(pTbl) do
    newTbl --[[@as Camera]][k] = v
  end
  return newTbl
end

local cameraRot = vec(0, 0, 0) -- This is here just so I can reset it when the camera changes

---Sets the active camera
---
---When no camera is given, or the argument is nil, this disables FOXCamera, using the vanilla camera instead
---@param camera Camera?
function CameraAPI.setCamera(camera)
  -- When switching cameras, set the visibility of the last hidden part to visible so it's not stuck being invisible

  if curr and curr.hiddenPart then
    curr.hiddenPart:setVisible(true)
  end

  -- Apply the new camera

  curr = camera
  if camera then
    -- Edge case type check

    assert(
      type(camera.cameraPart) == "ModelPart",
      "Unexpected type for cameraPart, expected ModelPart",
      2
    )

    -- Create render part which is meant to check if partToWorldMatrix actually returns a matrix

    curr.renderPart = curr.cameraPart.renderValidator or curr.cameraPart:newPart("renderValidator")

    -- Apply defaults

    curr.parentType = curr.parentType or "PLAYER"
    curr.doCollisions = curr.doCollisions == nil and true or curr.doCollisions
    curr.scale = curr.scale or 1
    curr.doLerpH = curr.doLerpH == nil and true or curr.doLerpH
    curr.doLerpV = curr.doLerpV == nil and true or curr.doLerpV
    curr.offsetPos = curr.offsetPos or vec(0, 0, 0)
    curr.offsetRot = curr.offsetRot or vec(0, 0, 0)
    curr.offsetSpace = curr.offsetSpace or "CAMERA"

    -- Type checks

    assert(
      curr.parentType == "PLAYER" or curr.parentType == "WORLD",
      'The parentType must be "PLAYER" or "WORLD"',
      2
    )
    assert(
      type(curr.scale) == "number",
      "Unexpected type for scale, expected number",
      2
    )
    assert(
      curr.offsetSpace == "LOCAL" or curr.offsetSpace == "WORLD" or curr.offsetSpace == "CAMERA",
      'The offsetSpace must be "LOCAL", "WORLD", or "CAMERA"',
      2
    )

    -- Reset the camera rotation (Fixes bug with camera rotation from last frame being applied when changing cameras)

    cameraRot = vec(0, 0, 0)
  else
    -- Disabling the camera

    renderer:cameraPivot():offsetCameraRot():eyeOffset():cameraPos()
  end
end

---Gets the camera currently active. Useful for changing the configuration of a currently active camera
---
---Returns nil if none is active
---@return Camera? camera
function CameraAPI.getCamera()
  return curr
end

--#ENDREGION
--#REGION ˚♡ Library ♡˚

--#REGION ˚♡ Helpers ♡˚

--#REGION ˚♡ Raycast functions ♡˚

---Casts a boxcast out from the position, in the given direction for dist blocks. Takes a scale which scales the boxcast
---@param pos Vector3
---@param direction Vector3
---@param dist number
---@param scale number
---@return number
local function boxcast(pos, direction, dist, scale)
  for x = -1, 1, 2 do
    for y = -1, 1, 2 do
      for z = -1, 1, 2 do
        local corner = vec(x * scale, y * scale, z * scale)
        local startPos = pos + corner
        local endPos = startPos - (direction * dist)
        local _, hitPos = raycast:block(startPos, endPos, "VISUAL")
        dist = hitPos ~= endPos and (pos - hitPos):length() or dist
      end
    end
  end
  return dist
end

-- Used for raycasting an entity that isn't the player
local function predicate(entity)
  return entity ~= player
end

---Raycasts from the position in the direction as far as the player's reach.
---@param pos Vector3
---@param direction Vector3
---@return Vector3? hitpos
local function targetcast(pos, direction)
  local endPos = pos + (direction * host:getReachDistance())
  local _, blockPos = raycast:block(pos, endPos, "OUTLINE")
  local _, entityPos = raycast:entity(pos, endPos, predicate)

  blockPos = blockPos ~= endPos and blockPos or nil
  local blockDist = blockPos and (blockPos - pos):length() or nil
  local entityDist = entityPos and (entityPos - pos):length() or nil

  return (blockDist and entityDist) and (blockDist < entityDist and blockPos or entityPos) or
      blockPos or entityPos
end

--#ENDREGION
--#REGION ˚♡ Attributes ♡˚

-- Scale attribute

CameraAPI.attributes.scale = 1

local scPartA = models:newPart("FOXCamera_scaleA"):setPos(0, 16 / math.playerScale, 0)
local scPartB = models:newPart("FOXCamera_scaleB")
function events.tick()
  local scMatA = scPartA:partToWorldMatrix()
  if scMatA.v11 ~= scMatA.v11 then return end -- NaN check
  local scMatB = scPartB:partToWorldMatrix()
  CameraAPI.attributes.scale = scMatA:sub(scMatB):apply():length()
end

-- Distance attribute

CameraAPI.attributes.cameraDistance = 4 -- TODO Make this take the distance attribute added in 1.21.6

--#ENDREGION

--#ENDREGION
--#REGION ˚♡ Camera ♡˚

local doLerp = true -- Set to if the camera is a PLAYER camera or not
local cameraPos = vec(0, 1.62, 0)
local oldPos, newPos = cameraPos, cameraPos

-- Used for checking if the camera is inside the hiddenPart, and if it should be visible when using freecam or setting the camera distance to or near 0
local lastCameraPos = vec(0, 0, 0)
-- The camera's offset from the player when the camera parent type is PLAYER, used to make the camera appear smoother when partToWorldMatrix is delayed by a frame
local cameraOffset = vec(0, 0, 0)
-- The matrix of a modelpart created in the camera, and set to have a random x position. Used to verify if partToWorldMatrix of the camera part has actually updated this frame
local lastMat

if isHost then
  -- Lerps the camera's position for PLAYER cameras

  function events.tick()
    if not (curr and doLerp and (curr.doLerpH or curr.doLerpV)) then return end
    oldPos = newPos
    newPos = math.lerp(newPos, cameraPos, 0.5)
  end

  -- Set the visibility of arms

  function events.tick()
    if not curr then return end
    local hideArms = nil
    if curr.parentType == "WORLD" then
      hideArms = false
    end
    renderer:renderLeftArm(hideArms):renderRightArm(hideArms)
  end

  -- Sets the visibility of the hidden part, taking into account the position of the camera and the render context

  function events.render(_, context)
    if not (curr and curr.hiddenPart) then return end
    local hiddenRadius = 0.5 * curr.scale * CameraAPI.attributes.scale
    local cameraOffDistance = (lastCameraPos - client:getCameraPos()):length()
    curr.hiddenPart:setVisible(not firstPersonContext[context] or cameraOffDistance > hiddenRadius)
  end
end

-- Gets the partToWorldMatrix of the camera part for the PLAYER camera parent type. Separate from pre_render so there are no lerping

function events.post_render(delta, context)
  if not (curr and playerContext[context]) then return end
  doLerp = curr.parentType == "PLAYER"
  if curr.parentType == "WORLD" then return end

  -- Get the part matrix of the camera part

  local partMatrix = curr.cameraPart:partToWorldMatrix()
  if partMatrix.v11 ~= partMatrix.v11 then return end -- NaN check
  cameraPos = partMatrix:apply()

  -- Get the position from the matrix

  local localOffset = curr.offsetSpace == "LOCAL" and curr.offsetPos or nil
  local offsetPos = partMatrix:apply(localOffset):sub(cameraPos)

  local thisMat = curr.renderPart:setPos(math.random()):partToWorldMatrix()
  if thisMat ~= lastMat then
    lastMat = thisMat
    local xz = curr.unlockPos and 1 or 0
    cameraOffset = (cameraPos - player:getPos(delta))
        :mul(xz, 1, xz)
        :add(offsetPos)
  end

  -- Get the rotation from the matrix

  local offsetDir = partMatrix:applyDir(0, 0, -1)

  if curr.unlockRot then
    -- The roll is only applied on 1.20.6 and above
    cameraRot = vec(
      math.atan2(offsetDir.y, offsetDir.xz:length()),
      math.atan2(offsetDir.x, offsetDir.z),
      cameraMatVer and math.atan2(-partMatrix.v21, partMatrix.v22) or 0
    ):toDeg():mul(-1, -1, 1)
  else
    cameraRot = vec(0, 0, 0)
  end
  cameraRot:sub(curr.offsetRot)

  -- Apply the camera position based on if the player is crawling

  local isCrawling = player:isGliding() or player:isVisuallySwimming()
  if isCrawling then
    -- Use vanilla eye height
    local vanillaHeight = 0.4 * curr.scale * CameraAPI.attributes.scale
    cameraPos = cameraOffset.x_z:add(0, vanillaHeight, 0)
  else
    -- Use camera part height
    cameraPos = cameraOffset
  end
end

-- Uses pre_render, or <ModelPart>.preRender if that doesn't exist

local function cameraRender(delta)
  if not curr then return end

  -- Calculate the eye offset

  local playerPos = player:getPos(delta)
  local cameraDir = client:getCameraDir()

  local eyeOffset = nil
  if curr.parentType == "PLAYER" and curr.doEyeOffset then
    local eyeHeight = vec(0, player:getEyeHeight(), 0)
    eyeOffset = cameraPos - eyeHeight

    if isHost and curr.doEyeRotation then
      local targeted = targetcast(cameraPos + playerPos, cameraDir)
      if targeted then
        local lookOffset = player:getLookDir() * (player:getVelocity():length() * 1.1)
        eyeOffset = targeted:sub(playerPos):sub(eyeHeight):sub(lookOffset)
      end
    end
  end

  avatar:store("eyePos", eyeOffset)
  renderer:eyeOffset(eyeOffset)

  if not isHost then return end -- Host only camera stuff

  local distAtt = CameraAPI.attributes.cameraDistance
  local scAtt = CameraAPI.attributes.scale
  local cameraScale = curr.scale * scAtt

  -- Calculate the camera rotation

  if curr.parentType == "WORLD" then
    cameraPos = curr.cameraPart:getTruePos():add(curr.cameraPart:getTruePivot()):div(16, 16, 16)
    if curr.unlockRot then
      cameraRot = curr.cameraPart:getTrueRot():mul(1, -1, 1)
    end
  end

  -- Offset camera rotation by player rotation if the camera hasn't changed

  local finalCameraRot = cameraRot or vec(0, 0, 0)
  if curr.unlockRot and last == curr then
    finalCameraRot = cameraRot - player:getRot(delta).xy_
  end
  last = curr

  -- Calculate the camera position, and lerp

  local finalCameraPos
  if curr.parentType == "PLAYER" then
    if curr.doLerpH or curr.doLerpV then
      local lerp = math.lerp(oldPos, newPos, delta)
      local lerpPosH = curr.doLerpH and lerp.x_z or cameraPos.x_z
      local lerpPosV = curr.doLerpV and lerp._y_ or cameraPos._y_

      finalCameraPos = lerpPosH:add(lerpPosV):add(playerPos)
    else
      finalCameraPos = cameraPos:copy():add(playerPos)
    end
  else
    finalCameraPos = cameraPos:copy():add(curr.offsetPos * curr.scale)
  end

  local offsetCameraPos = curr.offsetSpace == "CAMERA" and curr.offsetPos:copy() or vec(0, 0, 0)

  renderer:cameraPivot(finalCameraPos)
      :offsetCameraRot(finalCameraRot)
      :cameraPos(offsetCameraPos)

  lastCameraPos = finalCameraPos

  -- Set the camera matrix scale, and apply camera rolling

  local finalCameraScale = math.clamp(math.map(cameraScale, 0.0625, 0.00390625, 1, 10), 1, 10)
  if cameraMatVer then
    local cameraMat = matrices.mat3()
        :scale(finalCameraScale)
        :rotate(0, 0, finalCameraRot.z)
        :augmented()
    renderer:setCameraMatrix(cameraMat)
  end

  if renderer:isFirstPerson() then return end -- Third person render stuff

  -- Disable collisions in spectator mode

  local doCollisions = player:getGamemode() ~= "SPECTATOR" and curr.doCollisions

  -- Calculate, and apply, camera distance using boxcasting

  local vanillaDist = boxcast(finalCameraPos, cameraDir, distAtt * scAtt, 0.1)
  local desiredDist = (curr.distance or distAtt) * cameraScale
  if doCollisions then
    desiredDist = boxcast(finalCameraPos, cameraDir, desiredDist, 0.1 * cameraScale)
  end

  desiredDist = not renderer:isFirstPerson() and desiredDist or desiredDist
  local finalDist = desiredDist - vanillaDist
  renderer:setCameraPos(offsetCameraPos:add(0, 0, finalDist))
end

-- Determine which event to use, by checking if pre_render exists. Enable compatibility mode if it does not

function events.entity_init()
  if isHost and type(events.pre_render --[[@as Event]]) == "Event" then
    events.pre_render:register(cameraRender)
  else
    models:newPart("FOXCamera_preRender", isHost and "GUI" or nil).preRender = cameraRender
    if not logOnCompat then return end
    host:actionbar("§cFOXCamera running in compatibility mode!")
  end
end

--#ENDREGION

--#ENDREGION

return CameraAPI
