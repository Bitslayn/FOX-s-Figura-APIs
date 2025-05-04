--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Camera API v1.1.0 (0.1.5 Compatibility Version)

Recommended Figura 0.1.6 or Goofy Plugin
Supports 0.1.5 without pre_render with the built-in compatibility mode

It is HIGHLY recommended that you install Sumneko's Lua Language Server and GS Figura Docs
LLS: https://marketplace.visualstudio.com/items/?itemName=sumneko.lua
GS Docs: https://github.com/GrandpaScout/FiguraRewriteVSDocs

If you don't know modelpart indexing, you can view how to do that here: https://figura-wiki.pages.dev/tutorials/ModelPart%20Indexing

--]]

local logOnCompat = true -- Set this to false to disable compatibility warnings

--#REGION ˚♡ Important ♡˚

figuraMetatables.Vector3.__metatable = false

function assert(v, message, level)
  return v or error(message or "Assertion failed!", (level or 1) + 1)
end

---@type Camera
local curr

local otherContext = { OTHER = true, PAPERDOLL = true, FIGURA_GUI = true, MINECRAFT_GUI = true }
local playerContext = { RENDER = true, FIRST_PERSON = true }
local firstPersonContext = { OTHER = true, FIRST_PERSON = true }

--#ENDREGION
--#REGION ˚♡ API ♡˚

---Create a new camera by doing `<CameraAPI>.newCamera()`, giving it a modelpart, and optional configs or nil to use defaults
---
---Then apply your camera by doing `<CameraAPI>.setCamera()`
---
---The camera can be configured at any time to change things like what modelpart is hidden when you're in first person, enable moving the eye offset, setting the camera distance in third person, enabling camera collisions, and other configurations.
---
---```lua
---local CameraAPI = require("FOXCamera")
---
---local myCamera = CameraAPI.newCamera(
---  models.the.path.to.your.camera.part, -- (nil) cameraPart
---  nil, -- (nil) hiddenPart
---  nil, -- ("PLAYER") parentType
---  nil, -- (nil) distance
---  nil, -- (1) scale
---  nil, -- (false) unlockPos
---  nil, -- (false) unlockRot
---  nil, -- (true) doCollisions
---  nil, -- (false) doEyeOffset
---  nil, -- (true) doLerpH
---  nil, -- (true) doLerpV
---  nil, -- (vec(0, 0, 0)) offsetGlobalPos
---  nil, -- (vec(0, 0, 0)) offsetLocalPos
---  nil, -- (vec(0, 0, 0)) offsetRot
---)
---
---myCamera.hiddenPart = models.the.path.to.your.hidden.part
---myCamera.doEyeOffset = true
---myCamera.distance = 8
---
---CameraAPI.setCamera(myCamera)
---```
---
---Alternatively, you could create a table and plug that in. (Be sure to add the type annotation)
---
---```lua
---local CameraAPI = require("FOXCamera")
---
------@type Camera
---local myCamera = {
---  cameraPart = models.the.path.to.your.camera.part,
---  hiddenPart = models.the.path.to.your.hidden.part,
---  doEyeOffset = true,
---  distance = 8
---}
---
---CameraAPI.setCamera(myCamera)
---```
---@class CameraAPI
local CameraAPI = {}

---@class Camera
---@field cameraPart ModelPart The modelpart which the camera will follow. You would usually want this to be a pivot inside your body positioned at eye level
---@field hiddenPart ModelPart? The modelpart which will become hidden in first person. You would usually want this to be your head group
---@field parentType Camera.parentType? `"PLAYER"` What the camera is following. This should be set to "WORLD" if the camera isn't meant to follow the player, or isn't attached to the player model
---@field distance number? `nil` The distance to move the camera out in third person
---@field scale number? `1` The camera's scale, used for camera collisions, and position offsets
---@field unlockPos boolean? `false` Unlocks the camera's horizontal movement to follow the modelpart's position
---@field unlockRot boolean? `false` Unlocks the camera's rotation to follow the modelpart's rotation
---@field doCollisions boolean? `true` Prevents the camera from passing through solid blocks in third person. This is always disabled for viewers
---@field doEyeOffset boolean? `false` Moves the player's eye offset with the camera
---@field doLerpH boolean? `true` If the camera's horizontal position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@field doLerpV boolean? `true` If the camera's vertical position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@field offsetGlobalPos Vector3? `vec(0, 0, 0)` Offsets the camera relative to the world. Uses world coordinates. Applied even if unlockPos is set to false.
---@field offsetLocalPos Vector3? `vec(0, 0, 0)` Offsets the camera relative to the modelpart. Uses blockbench coordinates. Applied even if unlockPos is set to false.
---@field offsetRot Vector3? `vec(0, 0, 0)` Offsets the camera rotation. Applied even if unlockRot is set to false.
---@alias Camera.parentType
---| "PLAYER"
---| "WORLD"

---Generates a camera table to use in `<CameraAPI>.setCamera()`
---@param cameraPart ModelPart The modelpart which the camera will follow. You would usually want this to be a pivot inside your body positioned at eye level
---@param hiddenPart ModelPart? The modelpart which will become hidden in first person. You would usually want this to be your head group
---@param parentType Camera.parentType? `"PLAYER"` What the camera is following. This should be set to "WORLD" if the camera isn't meant to follow the player, or isn't attached to the player model
---@param distance number? `nil` The distance to move the camera out in third person
---@param scale number? `1` The camera's scale, used for camera collisions, and position offsets
---@param unlockPos boolean? `false` Unlocks the camera's horizontal movement to follow the modelpart's position
---@param unlockRot boolean? `false` Unlocks the camera's rotation to follow the modelpart's rotation
---@param doCollisions boolean? `true` Prevents the camera from passing through solid blocks
---@param doEyeOffset boolean? `false` Moves the player's eye offset with the camera
---@param doLerpH boolean? `true` If the camera's horizontal position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@param doLerpV boolean? `true` If the camera's vertical position is lerped to the modelpart. Only applied with the PLAYER camera parent type
---@param offsetGlobalPos Vector3? `vec(0, 0, 0)` Offsets the camera relative to the world. Uses world coordinates. Applied even if unlockPos is set to false.
---@param offsetLocalPos Vector3? `vec(0, 0, 0)` Offsets the camera relative to the modelpart. Uses blockbench coordinates. Applied even if unlockPos is set to false.
---@param offsetRot Vector3? `vec(0, 0, 0)` Offsets the camera rotation. Applied even if unlockRot is set to false.
---@return Camera
function CameraAPI.newCamera(cameraPart, hiddenPart, parentType, distance, scale, unlockPos,
                             unlockRot, doCollisions, doEyeOffset, doLerpH, doLerpV, offsetLocalPos,
                             offsetGlobalPos, offsetRot)
  return {
    cameraPart      = cameraPart,
    hiddenPart      = hiddenPart,
    parentType      = parentType,
    distance        = distance,
    scale           = scale,
    unlockPos       = unlockPos,
    unlockRot       = unlockRot,
    doCollisions    = doCollisions,
    doEyeOffset     = doEyeOffset,
    doLerpH         = doLerpH,
    doLerpV         = doLerpV,
    offsetGlobalPos = offsetGlobalPos,
    offsetLocalPos  = offsetLocalPos,
    offsetRot       = offsetRot,
  }
end

---Sets the active camera
---@param camera Camera?
function CameraAPI.setCamera(camera)
  if curr and curr.hiddenPart then
    curr.hiddenPart:setVisible(true)
  end
  curr = camera
  if camera then
    assert(type(camera.cameraPart) == "ModelPart",
      "Unexpected type for cameraPart, expected ModelPart", 2)
    curr.renderPart = curr.cameraPart.renderValidator or curr.cameraPart:newPart("renderValidator")
    curr.parentType = curr.parentType or "PLAYER"
    assert(curr.parentType == "PLAYER" or curr.parentType == "WORLD",
      'The parentType must be "PLAYER" or "WORLD"', 2)
    curr.doCollisions = curr.doCollisions == nil and true or curr.doCollisions
    curr.scale = curr.scale or 1
    assert(type(curr.scale) == "number", "Unexpected type for scale, expected number", 2)
    curr.doLerpH = curr.doLerpH == nil and true or curr.doLerpH
    curr.doLerpV = curr.doLerpV == nil and true or curr.doLerpV
    curr.offsetGlobalPos = curr.offsetGlobalPos or vec(0, 0, 0)
    curr.offsetLocalPos = curr.offsetLocalPos or vec(0, 0, 0)
    curr.offsetRot = curr.offsetRot or vec(0, 0, 0)
  else
    renderer:setCameraPivot():setCameraPos():setEyeOffset():setOffsetCameraRot()
  end
end

---Gets the camera currently active
---@return Camera? camera
function CameraAPI.getCamera()
  return curr
end

--#ENDREGION
--#REGION ˚♡ Library ♡˚

--#REGION ˚♡ Helpers ♡˚

--#REGION ˚♡ Eular ♡˚

--[[
Written by Katt
https://discord.com/channels/1129805506354085959/1234218592187453452/1304526475503861770
]]

---@param dirVec Vector3
---@return Vector3
local function directionToEulerDegree(dirVec)
  local yaw = math.atan2(dirVec.x, dirVec.z)
  local pitch = math.atan2(dirVec.y, dirVec.xz:length())
  return vec(-math.deg(pitch), -math.deg(yaw), 0)
end

--#ENDREGION
--#REGION ˚♡ Boxcast function ♡˚

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

--#ENDREGION
--#REGION ˚♡ Attributes (and crouch offset fix) ♡˚

local renderedOther
function events.render(_, context)
  if otherContext[context] then
    renderedOther = true
  end
end

-- Will apply to versions 1.21.2 and before
local crouchOffsetVer = client.compareVersions(client:getVersion(), "1.21.2") ~= 1
local scAtt = 1
local crouchOffset = 0
local scPartA = models:newPart("FOXCamera_scaleA"):setPos(0, 16 / math.playerScale, 0)
local scPartB = models:newPart("FOXCamera_scaleB")
function events.entity_init()
  function events.post_render(_, context)
    if not (curr and playerContext[context]) then return end
    crouchOffset = not renderedOther and crouchOffsetVer and player:isCrouching() and
        renderer:isFirstPerson() and 0.125 * scAtt or 0
    renderedOther = false
    local scMatA = scPartA:partToWorldMatrix()
    if scMatA.v11 ~= scMatA.v11 then return end -- NaN check
    local scMatB = scPartB:partToWorldMatrix()
    scAtt = scMatA:sub(scMatB):apply():length()
  end
end

local distAtt = 4 -- TODO Make this take the distance attribute added in 1.21.6

--#ENDREGION

--#ENDREGION
--#REGION ˚♡ Camera ModelPart ♡˚

local doLerp = true
local cameraPos = vec(0, 1.62, 0)
local cameraRot = vec(0, 0, 0)
local oldPos, newPos = cameraPos, cameraPos
function events.tick()
  if not (curr and doLerp) then return end
  oldPos = newPos
  newPos = math.lerp(newPos, cameraPos, 0.5)
end

local lastCameraPos, lastMat = vec(0, 0, 0), nil
local cameraOffset = vec(0, 0, 0)
function events.entity_init()
  function events.post_render(delta, context)
    if not (curr and playerContext[context]) then return end

    local partMatrix = curr.cameraPart:partToWorldMatrix()
    if partMatrix.v11 ~= partMatrix.v11 then return end -- NaN check
    doLerp = curr.parentType == "PLAYER"
    cameraPos = partMatrix:apply()
    local offsetPos = partMatrix:apply(curr.offsetLocalPos) - cameraPos
    cameraRot = curr.unlockRot and directionToEulerDegree(partMatrix:applyDir(0, 0, -1))
        :sub(player:getRot(delta).xy_) or vec(0, 0, 0)

    if curr.parentType == "WORLD" then return end

    local thisMat = curr.renderPart:setPos(math.random()):partToWorldMatrix()
    if thisMat ~= lastMat then
      lastMat = thisMat
      local xz = curr.unlockPos and 1 or 0
      cameraOffset = (cameraPos - player:getPos(delta)):add(0, crouchOffset, 0):mul(xz, 1, xz)
          :add(offsetPos)
    end

    local isCrawling = player:isGliding() or player:isVisuallySwimming()
    cameraPos = isCrawling and vec(cameraOffset.x, 0.4 * curr.scale * scAtt, cameraOffset.z) or
        cameraOffset
  end

  function events.render(_, context)
    if not (curr and curr.hiddenPart) then return end
    curr.hiddenPart:setVisible(not firstPersonContext[context] or
    (lastCameraPos - client:getCameraPos()):length() > 0.5)
    if curr.parentType == "WORLD" then
      renderer:renderLeftArm(false):renderRightArm(false)
    else
      renderer:renderLeftArm():renderRightArm()
    end
  end
end

--#ENDREGION
--#REGION ˚♡ Camera ♡˚

-- Will apply to versions 1.20.6 and above
local cameraMatVer = client.compareVersions(client:getVersion(), "1.20.6") ~= -1
local isHost = host:isHost()

local function cameraRender(delta)
  if not curr then return end

  local playerPos = player:getPos(delta)
  local cameraDir = client:getCameraDir()
  local cameraScale = curr.scale * scAtt

  local lerp = math.lerp(oldPos, newPos, delta)
  local lerpPosH = curr.doLerpH and lerp.x_z or cameraPos.x_z
  local lerpPosV = curr.doLerpV and lerp._y_ or cameraPos._y_
  local lerpPos = (lerpPosH + lerpPosV):add(playerPos)

  local finalCameraPos = (curr.parentType == "PLAYER" and lerpPos or cameraPos:copy())
  finalCameraPos:add(curr.offsetGlobalPos * curr.scale)

  lastCameraPos = finalCameraPos

  local eyeOffset = nil
  if curr.parentType == "PLAYER" and curr.doEyeOffset then
    local eyeHeight = vec(0, player:getEyeHeight(), 0)
    eyeOffset = cameraPos - eyeHeight
  end

  local cameraScaleMap = math.clamp(math.map(cameraScale, 0.0625, 0.00390625, 1, 10), 1, 10)

  avatar:store("eyePos", eyeOffset)
  renderer:setCameraPivot(finalCameraPos):setOffsetCameraRot(cameraRot):setEyeOffset(eyeOffset)
      :setCameraPos()

  if not isHost then return end

  local cameraMat = matrices.mat3():scale(cameraScaleMap):augmented()
  renderer:setCameraMatrix(cameraMatVer and cameraMat or nil)

  if renderer:isFirstPerson() then return end

  local doCollisions = player:getGamemode() ~= "SPECTATOR" and curr.doCollisions
  local counterDist = boxcast(finalCameraPos, cameraDir, distAtt * scAtt, 0.1)
  local finalDist = (curr.distance or distAtt) * cameraScale
  finalDist = doCollisions and boxcast(finalCameraPos, cameraDir, finalDist, 0.1 * cameraScale) or
      finalDist

  renderer:setCameraPos(0, 0, finalDist - counterDist)
end

function events.entity_init()
  if isHost and type(events.pre_render) == "Event" then
    events.pre_render:register(cameraRender)
  else
    models:newPart("FOXCamera_preRender", isHost and "GUI" or nil).preRender = cameraRender
    if not logOnCompat then return end
    host:actionbar("§4FOXCamera running in compatibility mode!")
  end
end

--#ENDREGION

--#ENDREGION

return CameraAPI
