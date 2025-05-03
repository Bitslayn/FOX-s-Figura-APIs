--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Camera API v1.0.0 (0.1.5 Compatibility Version)

Recommended Figura 0.1.6 or Goofy Plugin
Supports 0.1.5 without pre_render with the built-in compatibility mode

It is HIGHLY recommended that you install Sumneko's Lua Language Server and GS Figura Docs
LLS: https://marketplace.visualstudio.com/items/?itemName=sumneko.lua
GS Docs: https://discord.com/channels/1129805506354085959/1144132395906388038

If you don't know modelpart indexing, you can view how to do that here: https://figura-wiki.pages.dev/tutorials/ModelPart%20Indexing

--]]

local logOnCompat = true           -- Set this to false to disable compatibility warnings
local doCompatibilityChecks = true -- Set this to false to disable checking if the pre_render that exists is compatible. Does not disable checking if it exists

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
---@field distance number? `nil` The absolute distance to move the camera out in third person. When set to nil, uses the attribute distance
---@field scale number? `1` The camera's scale, used for camera collisions. Uses the player's scale attribute if not defined
---@field unlockPos boolean? `false` Unlocks the camera's horizontal movement to follow the modelpart's position
---@field unlockRot boolean? `false` Unlocks the camera's rotation to follow the modelpart's rotation
---@field doCollisions boolean? `true` Prevents the camera from passing through solid blocks in third person. This is always disabled for viewers
---@field doEyeOffset boolean? `false` Moves the player's eye offset with the camera
---@alias Camera.parentType
---| "PLAYER"
---| "WORLD"

---Generates a camera table to use in `<CameraAPI>.setCamera()`
---@param cameraPart ModelPart The modelpart which the camera will follow. You would usually want this to be a pivot inside your body positioned at eye level
---@param hiddenPart ModelPart? The modelpart which will become hidden in first person. You would usually want this to be your head group
---@param parentType Camera.parentType? `"PLAYER"` What the camera is following. This should be set to "WORLD" if the camera isn't meant to follow the player, or isn't attached to the player model
---@param distance number? `nil` The absolute distance to move the camera out in third person. When set to nil, uses the attribute distance
---@param scale number? `1` The camera's scale, used for camera collisions. Uses the player's scale attribute if not defined
---@param unlockPos boolean? `false` Unlocks the camera's horizontal movement to follow the modelpart's position
---@param unlockRot boolean? `false` Unlocks the camera's rotation to follow the modelpart's rotation
---@param doCollisions boolean? `true` Prevents the camera from passing through solid blocks
---@param doEyeOffset boolean? `false` Moves the player's eye offset with the camera
---@return Camera
function CameraAPI.newCamera(cameraPart, hiddenPart, parentType, distance, scale, unlockPos,
                             unlockRot, doCollisions, doEyeOffset)
  return {
    cameraPart   = cameraPart,
    hiddenPart   = hiddenPart,
    parentType   = parentType,
    distance     = distance,
    scale        = scale,
    unlockPos    = unlockPos,
    unlockRot    = unlockRot,
    doCollisions = doCollisions,
    doEyeOffset  = doEyeOffset,
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
    curr.doCollisions = type(curr.doCollisions) == "nil" and true or curr.doCollisions
    curr.scale = curr.scale or 1
    assert(type(curr.scale) == "number", "Unexpected type for scale, expected number", 2)
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
local oldPos, newPos = cameraPos, cameraPos
function events.tick()
  if not (curr and doLerp) then return end
  oldPos = newPos
  newPos = math.lerp(newPos, cameraPos, 0.5)
end

local lastMat
local cameraOffset = vec(0, 0, 0)
function events.entity_init()
  function events.post_render(delta, context)
    if not (curr and playerContext[context]) then return end

    local partMatrix = curr.cameraPart:partToWorldMatrix()
    if partMatrix.v11 ~= partMatrix.v11 then return end -- NaN check
    doLerp = curr.parentType == "PLAYER"
    cameraPos = partMatrix:apply()
    if curr.parentType == "WORLD" then return end

    local thisMat = curr.renderPart:setPos(math.random()):partToWorldMatrix()
    if thisMat ~= lastMat then
      lastMat = thisMat
      local xz = curr.unlockPos and 1 or 0
      cameraOffset = (cameraPos - player:getPos(delta)):add(0, crouchOffset, 0):mul(xz, 1, xz)
    end

    local isCrawling = player:isGliding() or player:isVisuallySwimming()
    cameraPos = isCrawling and vec(cameraOffset.x, 0.4 * curr.scale * scAtt, cameraOffset.z) or
        cameraOffset
  end

  function events.render(_, context)
    if not (curr and curr.hiddenPart) then return end
    curr.hiddenPart:setVisible(not firstPersonContext[context])
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
local checkPos
local isHost = host:isHost()

local function cameraRender(delta)
  if not curr then return end

  local playerPos = player:getPos(delta)
  local cameraRot = curr.unlockRot and curr.cameraPart:getTrueRot() or nil
  local cameraDir = client:getCameraDir()
  local cameraScale = curr.scale * scAtt

  local cPartPos = curr.parentType == "PLAYER" and math.lerp(oldPos, newPos, delta) + playerPos or
      cameraPos
  checkPos = cPartPos

  local eyeOffset = nil
  if curr.parentType == "PLAYER" and curr.doEyeOffset then
    local eyeHeight = vec(0, player:getEyeHeight(), 0)
    eyeOffset = cameraPos - eyeHeight
  end

  local cameraScaleMap = math.clamp(math.map(cameraScale, 0.0625, 0.00390625, 1, 10), 1, 10)

  avatar:store("eyePos", eyeOffset)
  renderer:setCameraPivot(cPartPos):setOffsetCameraRot(cameraRot):setEyeOffset(eyeOffset)
      :setCameraPos()

  if not isHost then return end

  local cameraMat = matrices.mat3():scale(cameraScaleMap):augmented()
  renderer:setCameraMatrix(cameraMatVer and cameraMat or nil)

  if renderer:isFirstPerson() then return end

  local doCollisions = player:getGamemode() ~= "SPECTATOR" and curr.doCollisions
  local counterDist = boxcast(cPartPos, cameraDir, distAtt * scAtt, 0.1)
  local finalDist = (curr.distance or distAtt) * cameraScale
  finalDist = doCollisions and boxcast(cPartPos, cameraDir, finalDist, 0.1 * cameraScale) or
      finalDist

  renderer:setCameraPos(0, 0, finalDist - counterDist)
end

local function compatCheck()
  if not (checkPos and renderer:isFirstPerson()) or (checkPos - client:getCameraPos()):length() == 0 then return end
  events.pre_render:remove(cameraRender)
  models:newPart("FOXCamera_preRender", "GUI").preRender = cameraRender
  if logOnCompat then
    local disableMessage = "§4FOXCamera running in compatibility mode!\n§c%s§r\n"
    printJson(disableMessage:format(
      "events.pre_render is incompatible!\n\nThis could be because the event that does exists runs too late in the render thread. Try updating your Figura version or reporting this as an issue."))
  end
  events.render:remove(compatCheck)
end

function events.entity_init()
  if isHost and type(events.pre_render) == "Event" then
    events.pre_render:register(cameraRender)
    if not (isHost and doCompatibilityChecks) then return end
    events.render:register(compatCheck)
  else
    models:newPart("FOXCamera_preRender", isHost and "GUI" or nil).preRender = cameraRender
    if not (isHost and logOnCompat) then return end
    local disableMessage = "§4FOXCamera running in compatibility mode!\n§c%s§r\n"
    printJson(disableMessage:format(
      "events.pre_render could not be found!\n\nThis could be because Figura isn't updated or Goofy plugin isn't installed."))
  end
end

--#ENDREGION

--#ENDREGION

return CameraAPI
