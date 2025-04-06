--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's PlayerScale v2.0.7

Revised 3 March, 2024

Changelog:
  Fixed trackpad scrolling leading to broken state

--]]

--[[==============================================================================================--
-- #REGION Setup
Locates pivots, the action wheel, and CommandLib for later functions to use
]] --=============================================================================================--

-- #REGION Pivots

---Search through a modelpart's children and returns a part by its name. Returns `nil` if nothing is found
---@param modelpart ModelPart
---@param name string
---@nodiscard
local function searchModel(modelpart, name)
  for _, part in pairs(modelpart:getChildren()) do
    if name == part:getName():lower() then
      return part
    else
      local result = searchModel(part, name)
      if result then
        return result
      end
    end
  end
  return nil
end

local scaledParts = { searchModel(models, "root"):getParent() }

local eyePivot, heightPivot, endHeightPivot
local heightLength, metricConversion

local function recalculatePivots()
  -- Locate eye pivot
  eyePivot = searchModel(scaledParts[1], "eyepivot")
  eyePivot = type(eyePivot) == "ModelPart" and eyePivot:getPivot().y or 28

  -- Locate upper height pivot
  heightPivot = searchModel(scaledParts[1], "heightpivot")
  heightPivot = type(heightPivot) == "ModelPart" and heightPivot:getPivot() or 32

  -- Locate lower height pivot
  endHeightPivot = searchModel(scaledParts[1], "endheightpivot")
  endHeightPivot = type(endHeightPivot) == "ModelPart" and endHeightPivot:getPivot() or
      type(heightPivot) == "Vector3" and heightPivot.x_z or vec(0, 0, 0)

  -- Calculate conversion from height length to metric/imperial
  heightLength = (heightPivot - endHeightPivot):length()
  metricConversion = (heightLength / 16 * 15) / 30 * 1.875
end
recalculatePivots()


-- #ENDREGION
-- #REGION Require

local FOXCommandLib, kattDynCross
local scripts = listFiles("/", true)
for _, path in pairs(scripts) do
  -- Look for scripts to require
  local search = {
    command = string.find(path, "CommandLib"),
    crosshair = string.find(path, "KattDynamicCrosshair"),
  }
  -- Assign require from search
  if search.command then
    FOXCommandLib = require(path)
  end
  if search.crosshair then
    kattDynCross = require(path)
  end
end

-- #ENDREGION
-- #REGION Config

---Save config from file. Does the same thing as `config:setName(file):save(name, value)` but also reverts the set file name so other configs aren't affected. Like setting the file name temporarily.
---@param file string
---@param name string
---@param value any
local function saveConfig(file, name, value)
  -- Store the name of the config file previously targeted
  local prevConfig = config:getName()
  -- Save to this library's config file
  config:setName(file):save(name, value)
  -- Restore the config file to its previous target for other scripts
  config:setName(prevConfig)
end

---Load config from file. Does the same thing as `config:setName(file):load(name)` but also reverts the set file name so other configs aren't affected. Like setting the file name temporarily.
---@param file string # The name of the file to load this configuration from
---@param name string # The name of the config to load
---@return any
---@nodiscard
local function loadConfig(file, name)
  -- Store the name of the config file previously targeted
  local prevConfig = config:getName()
  -- Load from this library's config file
  local load = config:setName(file):load(name)
  -- Restore the config file to its previous target for other scripts
  config:setName(prevConfig)
  -- Return the loaded value
  return load
end

-- #ENDREGION
-- #ENDREGION

--[[==============================================================================================--
-- #REGION Init
Actually initializes the library
]] --=============================================================================================--

local configFile = "PlayerScale"
local savedHeight = loadConfig(configFile, "playerScale") or 1
local height = savedHeight
local targetHeight = height
local startingHeight = height
local currentCameraMode = loadConfig(configFile, "cameraMode") or
    2                   -- Default to "Offset Camera Only"
if not kattDynCross and currentCameraMode == 2 then
  currentCameraMode = 1 -- Disable camera mode if camera mode is set to 2
  saveConfig(configFile, "cameraMode", currentCameraMode)
end

local lerpTimer = 0
local lerpEnd = 30
function events.tick()
  if lerpTimer ~= lerpEnd then
    lerpTimer = lerpTimer + 1
  end
end

local cameraLerpTimer = 0
local cameraLerpEnd = 4
function events.tick()
  if cameraLerpTimer ~= cameraLerpEnd then
    cameraLerpTimer = cameraLerpTimer + 1
  end
end

-- Ping scale to others, defining whether it should be lerped or not
function pings.scale(_height, lerp)
  if (host:isHost() and height == targetHeight) or not host:isHost() then
    if lerp then
      startingHeight = height
      targetHeight = _height
      lerpTimer = 0
    else
      height = _height
    end
    if player:isLoaded() then
      avatar:store("patpat.boundingBox", player:getBoundingBox() * (math.abs(targetHeight)))
    end
  end
end

pings.scale(savedHeight, false)

-- Ping configuration from the camera setting, whether or not the eye pivot is used
local useEyePivot = currentCameraMode or false
function pings.useEyePivot(bool)
  useEyePivot = bool
end

-- Fractions to display with the imperial measurement
local fractions = { " ¹/₁₆", " ¹/₈", " ³/₁₆", " ¹/₄", " ⁵/₁₆", " ³/₈", " ⁷/₁₆", " ¹/₂", " ⁹/₁₆",
  " ⁵/₈", " ¹¹/₁₆", " ³/₄", " ¹³/₁₆", " ⁷/₈", " ¹⁵/₁₆" }

local measurementSystems = { "generic", "metric", "imperial", "pixels" }
local measurementSystemsUppercase = { "Generic", "Metric", "Imperial", "Pixels" }
local preferredSystem = loadConfig(configFile, "preferredSystem") or 2

-- Fetches the scale string in the preferred system/unit
local function recalculateUnit(raw, system, scale)
  system = system or preferredSystem
  scale = scale or height

  local conversionFunctions = {
    generic = function()
      return string.format("%sx", scale)
    end,
    metric = function()
      local metric = math.abs(scale) * metricConversion
      if raw then return metric end
      if metric < 1 then
        return string.format("%s%.1fcm", scale >= 0 and "" or "-", metric * 100)
      end
      return string.format("%s%.2fm", scale >= 0 and "" or "-", metric)
    end,
    imperial = function()
      local imperial = math.abs(scale) * metricConversion * 39.37
      local feet = math.floor(imperial / 12)
      local inch = math.floor(imperial % 12)
      local fraction = math.floor((imperial % 1) * 15 + 0.5)
      if raw then return imperial end
      return string.format("%s%.0f\'%.0f\"%s",
        scale >= 0 and "" or "-", feet, inch, fractions[fraction] or ""
      )
    end,
    pixels = function()
      local px = math.abs(scale) * metricConversion * 16
      if raw then return px end
      return string.format("%s%.2fpx", scale >= 0 and "" or "-", px)
    end,
  }

  -- Switch function
  local _, result = pcall(function()
    local run = conversionFunctions[system]
    return run()
  end)

  return result
end

-- #ENDREGION

--[[==============================================================================================--
-- #REGION Model
Scales the player on render
]] --=============================================================================================--
-- Formulas for easing
local function easeInOutQuad(t)
  return t < 0.5 and
      2 * t * t or
      1 - (-2 * t + 2) ^ 2 / 2
end
local function easeInOutCrouch(t)
  return t < 0.5 and
      4 * t ^ 3 or
      1 - (-2 * t + 2) ^ 3 / 2
end

function events.render(delta, context)
  -- Scale the player in-world differently from in inventories
  if context == "MINECRAFT_GUI" or context == "PAPERDOLL" or context == "FIGURA_GUI" then
    -- Keep the player scale as 1 in inventories
    for _, part in pairs(scaledParts) do
      part:setScale(1)
    end
  else
    local smoothTimer = (lerpTimer + (lerpTimer < lerpEnd and delta or 0))
    height = math.lerp(startingHeight, targetHeight, easeInOutQuad(smoothTimer / lerpEnd))
    if height ~= targetHeight or scaledParts[1] ~= targetHeight then
      -- Set the player's model scale
      for _, part in pairs(scaledParts) do
        part:setScale(math.abs(height))
      end

      -- Flip the player if the scale is negative
      renderer:setUpsideDown(height < 0)

      -- Fix dinnerbone pivot
      for _, part in pairs(scaledParts) do
        part:setPivot(
          0,
          height < 0 and 32.41 or 0,
          0
        )
      end

      -- Scale the player's shadow
      renderer:setShadowRadius(0.5 * height)

      -- Reposition the player's nameplate
      nameplate.ENTITY:setPivot(0, ((2 * math.abs(height)) + 0.3), 0)

      -- Display scale in action bar
      if math.abs(targetHeight - height) > 10 ^ -4 then -- Make sure to only show action bar text when the scale is actively changing
        host:actionbar(tostring(recalculateUnit(false, measurementSystems[preferredSystem])))
        if host:isHost() then
          updateScaleActionTitle()
        end
      end
    end
    -- Fix crouching
    local isCrouching = vanilla_model.BODY:getOriginRot().x ~= 0
    for _, part in pairs(scaledParts) do
      part:setPos(0, (isCrouching and 2.135 or 0), 0)
    end
  end
end

-- #ENDREGION

--[[==============================================================================================--
-- #REGION KattCamera
Does raycasts for camera collisions with blocks
]] --=============================================================================================--

---Using the given position and rotation, calculate the maximum distance the camera can go back without colliding into block, to a maximum of `distance`.
---`distance` defaults to the vanilla value of 4 if not specified.
---@param position Vector3
---@param rotation Vector3
---@param distance number?
local function CalculateCameraZoom(position, rotation, distance)
  local rotationMatrix = matrices.rotation4(rotation * vec(1, -1, 1))
  local forward = rotationMatrix:apply(0, 0, 1)
  if renderer:isCameraBackwards() then
    forward = rotationMatrix:apply(0, 0, -1)
  end
  distance = distance or 4
  for x = -1, 1, 2 do
    for y = -1, 1, 2 do
      for z = -1, 1, 2 do
        local offset = vec(x, y, z) * 0.1
        local from = position + offset
        local to = position - (forward * distance) + offset
        local _, blockPos = raycast:block(from, to, "COLLIDER")
        if blockPos then
          local newDistance = (blockPos - position):length()
          if newDistance < distance then
            distance = newDistance
          end
        end
      end
    end
  end
  return distance
end

-- #ENDREGION

--[[==============================================================================================--
-- #REGION Camera
Positions the camera relative to the player scale
]] --=============================================================================================--


-- Find's vanilla's scale value
local vanillaScale = 1
function events.render(_, context)
  if context == "FIRST_PERSON" or context == "RENDER" then
    -- Find the vanilla scale from NBT data
    if player:getNbt()["attributes"] then
      for _, attribute in pairs(player:getNbt()["attributes"]) do
        if attribute.id == "minecraft:generic.scale" then
          vanillaScale = attribute.base
        end
      end
    end
  end
end

-- Find the camera pivot based on the player's pose
local cameraPivot
local lastPose
local startingCameraPivot, targetCameraPivot = vec(0, 0, 0), vec(0, 0, 0)
function events.entity_init()
  local pose = 1.62
  cameraPivot = vec(0, (eyePivot / 16) / math.worldScale * height * vanillaScale, 0)
  function events.tick()
    if useEyePivot then
      pose = player:getEyeHeight()
    end
    -- Non-host eye pivot calculation
    if not host:isHost() then
      cameraPivot = vec(0, (eyePivot / 16) / math.worldScale * height * vanillaScale, 0)
      avatar:store("eyePos", vec(0, useEyePivot and (cameraPivot.y - pose) or 0, 0))
    end
  end

  -- Set absolute camera position to player
  if host:isHost() then
    function events.world_render(delta)
      if currentCameraMode ~= 1 then
        pose = player:getEyeHeight()
        if pose ~= lastPose then
          cameraLerpTimer = 0
        end
        if pose ~= lastPose or height ~= targetHeight then
          startingCameraPivot = cameraPivot
          targetCameraPivot = vec(0,
            (eyePivot / 16) / math.worldScale * math.abs(height) * (pose / 1.62) * vanillaScale, 0)
          lastPose = pose
        end

        local renderPivot = player:getPos(delta) + (cameraPivot or 0)
        local renderRot = player:getRot(delta).xy_

        local vanillaMaxZoom = CalculateCameraZoom(renderPivot, renderRot, 4)
        local maxZoom = CalculateCameraZoom(renderPivot, renderRot, 4 * math.abs(height))
        local trueDistance = maxZoom - vanillaMaxZoom

        renderer:setCameraPivot(renderPivot)
        renderer:setCameraPos(0, 0, not renderer:isFirstPerson() and trueDistance or 0)
        if currentCameraMode == 3 then
          renderer:setEyeOffset(0, (cameraPivot.y - pose), 0)
        else
          renderer:setEyeOffset()
        end
        avatar:store("eyePos", renderer:getEyeOffset())

        -- Crouching
        local smoothCameraTimer = (cameraLerpTimer + (cameraLerpTimer < cameraLerpEnd and delta or 0))
        cameraPivot = math.lerp(startingCameraPivot, targetCameraPivot,
          easeInOutCrouch(smoothCameraTimer / cameraLerpEnd))
      else
        renderer:setCameraPivot()
        renderer:setCameraPos()
        renderer:setEyeOffset()
      end
    end
  end
end

-- #ENDREGION

--[[==============================================================================================--
-- #REGION API Functions
Function calls to set things up
]] --=============================================================================================--

---@meta _
---@class PlayerScale
local PlayerScale = {}

scale = PlayerScale

---Sets the models that will be scaled. Your first mod
---@param ... ModelPart
function PlayerScale.setModelParts(...)
  scaledParts = table.pack(...)
  scaledParts.n = nil
  recalculatePivots()
end

local dynamicLerpTimer, dynamicLerpTimerEnd = 0, 1
function events.tick()
  if dynamicLerpTimer ~= 5 then
    dynamicLerpTimer = dynamicLerpTimer + 1
    if host:isHost() then
      updateScaleActionTitle()
    end
    if dynamicLerpTimer == 5 then
      PlayerScale.reping()
    end
  end
end

function events.render(delta)
  if dynamicLerpTimer < dynamicLerpTimerEnd then
    host:actionbar(tostring(recalculateUnit(false, measurementSystems[preferredSystem])))
    local smoothDynamicTimer = (dynamicLerpTimer + (dynamicLerpTimer < dynamicLerpTimerEnd and delta or 0))
    height = math.lerp(startingHeight, targetHeight, (smoothDynamicTimer / dynamicLerpTimerEnd))
  end
end

-- Eye Pivot ping spam prevention
local scalePingTickMax = 20
local scalePingTick = scalePingTickMax
function events.tick()
  if scalePingTick ~= scalePingTickMax then
    scalePingTick = scalePingTick + 1
    if scalePingTick == scalePingTickMax then
      pings.scale(targetHeight, true)
    end
  end
end

local repingDelay = 200
local reping = 0
-- Set the player's scale by taking metric, imperial, pixel, or generic scale measurements
function PlayerScale.setScale(args, lerp)
  local scale
  reping = repingDelay

  local str = table.concat(args, " ")
  if str:match("px") then
    local px = tonumber(str:match("([%d%.]+)px"))
    if px then
      local s = ((px or 0) / 16) / metricConversion
      scale = s
    end
  elseif tonumber(str) or str:match("x") then
    local num = tonumber(str:match("([%d%.]+)x")) or tonumber(str)
    if num then
      scale = num
    end
  elseif str:match("m") then
    local m, cm = tonumber(str:match("([%d%.]+)m")), tonumber(str:match("([%d%.]+)cm"))
    local met = (m or 0) + ((cm or 0) / 100)
    local s = met / metricConversion
    if m or cm then
      scale = s
    end
  elseif str:match("\'") or str:match("\"") or str:match("ft") or str:match("in") then
    local ft, inch =
        tonumber(str:match("([%d%.]+)ft")) or tonumber(str:match("([%d%.]+)'")),
        tonumber(str:match("([%d%.]+)in")) or tonumber(str:match('([%d%.]+)"'))
    local imp = (ft or 0) + ((inch or 0) / 12)
    local s = (imp / 3.281) / metricConversion
    if ft or inch then
      scale = s
    end
  end

  if scalePingTick == scalePingTickMax then
    pings.scale(scale or targetHeight, true)
  else
    startingHeight = height
    targetHeight = scale or targetHeight
    lerpTimer = 0
  end
  scalePingTick = 0
end

-- Save the scale to the config
function PlayerScale.saveScale()
  saveConfig(configFile, "playerScale", height)
  if player:isLoaded() and host:isHost() then
    updateSaveLoadActionTitle()
  end
end

-- Load the scale from the config
function PlayerScale.loadScale()
  PlayerScale.setScale({ loadConfig(configFile, "playerScale") or 1 },
    true)
end

-- Reping the scale
function PlayerScale.reping() pings.scale(targetHeight, true) end

-- Reping loop
function events.tick()
  if not host:isHost() then return end
  if reping == 0 and lerpTimer == lerpEnd and #client.getTabList().players ~= 1 then
    PlayerScale.reping()
    pings.useEyePivot(useEyePivot)
  end
  reping = reping > 0 and reping - 1 or repingDelay
end

-- Eye Pivot ping spam prevention
local eyePivotTickMax = 5
local eyePivotTick = eyePivotTickMax
function events.tick()
  if not host:isHost() then return end
  if eyePivotTick ~= eyePivotTickMax then
    eyePivotTick = eyePivotTick + 1
    if eyePivotTick == eyePivotTickMax then
      pings.useEyePivot(currentCameraMode == 3)
    end
  end
end

function PlayerScale.setCameraMode(mode)
  currentCameraMode = mode
  eyePivotTick = 0

  -- Save the current scroll to the config
  saveConfig(configFile, "cameraMode", currentCameraMode)
  -- Set the action's title, description, and icon
  if host:isHost() then
    updateCameraModeActionTitle()
  end
  if kattDynCross then
    kattDynCross.setEnabled(currentCameraMode == 2)
  end
  if currentCameraMode ~= 2 then
    renderer:setCrosshairOffset()
  end
end

function PlayerScale.setPreferredMeasurement(system)
  preferredSystem = system
  -- Save the current preferred system to the config
  saveConfig(configFile, "preferredSystem", system)
  -- Set the action's title
  if host:isHost() then
    updatePreferredMeasurementActionTitle()
  end
end

function PlayerScale.getScale()
  return targetHeight
end

-- #ENDREGION

--[[==============================================================================================--
-- #REGION Chat Commands
Registers commands that can be run in chat
]] --=============================================================================================--

if host:isHost() and FOXCommandLib then
  -- Helper function to set commands with optional arguments
  ---@param command CommandLib
  local function setCommand(command, name, func, packed)
    return command:createCommand(name):setFunction(func, packed)
  end

  -- Create the main scale command
  local scaleCommand = commands:createCommand("scale")
  setCommand(scaleCommand, nil, function(args) PlayerScale.setScale(args, true) end, true)

  -- Subcommands for scale
  setCommand(scaleCommand, "flip", function()
    PlayerScale.setScale({ -targetHeight }, true)
  end, true)
  setCommand(scaleCommand, "load", PlayerScale.loadScale)
  setCommand(scaleCommand, "save", PlayerScale.saveScale)
  setCommand(scaleCommand, "set", function(args) PlayerScale.setScale(args, true) end, true)

  -- Print commands
  local heightString = "Current height is %s\n"
  local printCommand = scaleCommand:createCommand("print"):setFunction(function()
    printJson(string.format(heightString, recalculateUnit(false, measurementSystems[preferredSystem])))
  end)

  -- Measurement systems for print
  for _, system in ipairs(measurementSystems) do
    setCommand(printCommand, system, function()
      printJson(string.format(heightString, recalculateUnit(false, system)))
    end)
  end

  -- Config command
  local configCommand = scaleCommand:createCommand("config")

  -- Camera configuration commands
  local cameraConfigCommand = configCommand:createCommand("camera")
  setCommand(cameraConfigCommand, "disable", function() PlayerScale.setCameraMode(1) end)
  if kattDynCross then
    setCommand(cameraConfigCommand, "kattcrosshair", function() PlayerScale.setCameraMode(2) end)
  end
  setCommand(cameraConfigCommand, "enable", function() PlayerScale.setCameraMode(3) end)

  -- Preferred measurement system commands
  local preferredConfigCommand = configCommand:createCommand("measurement")
  for i, system in ipairs(measurementSystems) do
    setCommand(preferredConfigCommand, system, function()
      PlayerScale.setPreferredMeasurement(i)
      updateScaleActionTitle()
      updateSaveLoadActionTitle()
    end)
  end

  -- Help command
  -- Commands and descriptions table
  local helpDescriptions = {
    { "§7scale help §8<page>",                      "§fShows this page." },
    { "§7scale §8<scale>,§7 scale set §8[<scale>]", "§fSets the player's scale. Can also take metric, imperial, and pixel measurements." },
    { "§7scale flip",                               "§fInverts the player's scale, turning the model upside down." },
    { "§7scale save",                               "§fSaves the player's current scale." },
    { "§7scale load",                               "§fLoads the scale that's been saved." },
    { "§7scale print §8<system>",                   "§fPrints your current scale. Defaults to the preferred measurement system." },
    { "§7scale config camera §8[<mode>]",           "§fSet the current camera adjustment mode." },
    { "§7scale config measurement §8[<system>]",    "§fSets preferred measurement system." },
  }

  local linesPerPage = 6
  local helpPages = {}
  local currentPage = {}
  for i, desc in ipairs(helpDescriptions) do
    table.insert(currentPage, string.format("%s §8— %s", desc[1], desc[2]))
    if #currentPage == linesPerPage or i == #helpDescriptions then
      table.insert(helpPages, table.concat(currentPage, "\n"))
      currentPage = {}
    end
  end

  -- Add the help command
  setCommand(scaleCommand, "help", function(page)
    page = math.max(1, math.min(tonumber(page) or 1, #helpPages))
    printJson(
      string.format("§6§lFOX's PlayerScale Commands (Page %d of %d)\n%s",
        page, #helpPages, helpPages[page])
    )
  end)
end

-- #ENDREGION

--[[==============================================================================================--
-- #REGION Action Wheel
Creates an action wheel page and buttons
]] --=============================================================================================--

-- Entity init because this needs to run after other scripts has had the chance to create the action wheel
function events.entity_init()
  if not host:isHost() then return end

  local actionWheel = action_wheel:getCurrentPage() or action_wheel:newPage("Main Page")
  if not action_wheel:getCurrentPage() then
    action_wheel:setPage("Main Page")
  end

  -- Create page
  local scalePage = action_wheel:newPage("PlayerScale")

  -- Create action on main page to go to created page
  actionWheel:newAction()
      :setTitle("PlayerScale")
      :setItem("minecraft:flower_pot")
      :setOnLeftClick(function()
        sounds:playSound("minecraft:ui.button.click", player:getPos(), 0.2, 1)
        action_wheel:setPage("PlayerScale")
      end)

  -- #REGION KattDynamicCrosshair
  local cameraModeAction = scalePage:newAction()

  -- Create a spyglass texture that's grayscale
  local grayscaleSpyglass = textures:fromVanilla("grayscaleSpyglass", "textures/item/spyglass.png")
  local grayscaleSpyglassDimensions = grayscaleSpyglass:getDimensions()
  local grayscaleFilterMatrix = matrices.mat4(
    vec(0.333, 0.333, 0.33, 0),
    vec(0.333, 0.333, 0.33, 0),
    vec(0.333, 0.333, 0.33, 0),
    vec(0, 0, 0, 1)
  )
  grayscaleSpyglass:applyMatrix(0, 0, grayscaleSpyglassDimensions.x, grayscaleSpyglassDimensions.y,
    grayscaleFilterMatrix)

  -- Define crosshair offset modes
  local cameraModes = {
    { name = "No Offset",               desc = "Don't offset your camera to match your avatar's height",                                      texture = grayscaleSpyglass },
    { name = "Offset Crosshair",        desc = "Offset the camera, and shift your crosshair to match where you're aiming",                    item = "minecraft:spyglass" },
    { name = "Offset Camera & Raycast", desc = "Offset both the camera and your raycast\n§4§lCAUTION:§r§c Can trigger server anti-cheats!§r", item = "minecraft:spyglass" },
  }

  if not kattDynCross then
    cameraModes[2].desc = string.format("§8§m%s\n§r§4§lKattDynamicCrosshair wasn't found in avatar!",
      cameraModes[2].desc)
  end

  -- Function to set the action wheel title and icon
  function updateCameraModeActionTitle()
    cameraModeAction:setTitle(string.format(
    -- Each line, set the dot to either white or dark gray depending on the mode
      (currentCameraMode == 1 and "§f" or "§8") .. "•§r §l%s\n" ..
      (currentCameraMode == 2 and "§f" or "§8") .. "• \n" ..
      (currentCameraMode == 3 and "§f" or "§8") .. "• §7%s",
      cameraModes[currentCameraMode].name, cameraModes[currentCameraMode].desc))
    if cameraModes[currentCameraMode].item then
      cameraModeAction:setItem(cameraModes[currentCameraMode].item)
    elseif cameraModes[currentCameraMode].texture then
      cameraModeAction:setItem()
      cameraModeAction:setTexture(cameraModes[currentCameraMode].texture)
    end
  end

  updateCameraModeActionTitle()

  if kattDynCross then
    kattDynCross.setEnabled(currentCameraMode == 2)
  end


  ---Calls the provided function every time one full unit is scrolled, passing the direction (1 or -1) of the scroll.
  ---Accumulates sub-unit scrolls, so if scrolls aren't always integers (i.e. when using a trackpad), users will still be able to scroll through the options.
  ---@param action Action
  ---@param callback fun(dir: integer) - called with a value of 1 or -1
  local function registerIntegerScrollable(action, callback)
    local acc = 0
    action:setOnScroll(function(dir)
      dir = dir + acc
      local whole = math.floor(dir)
      acc = dir - whole
      if whole ~= 0 then
        callback(whole)
      end
    end)
  end

  -- Define scroll
  registerIntegerScrollable(cameraModeAction, function(dir)
    -- Scroll through, 1 to 3
    PlayerScale.setCameraMode(((currentCameraMode - 1 - dir) % #cameraModes) + 1)
    -- Play a sound
    sounds:playSound("minecraft:ui.button.click", player:getPos(), 0.2,
      1 + (currentCameraMode * 0.1) - 0.1)
  end)

  -- #ENDREGION
  -- #REGION Preferred Measurement
  local preferredMeasurementAction = scalePage:newAction()
      :setItem("minecraft:string")

  -- Function to set the action wheel title
  function updatePreferredMeasurementActionTitle()
    preferredMeasurementAction:setTitle(string.format(
      "§lMeasurement System\n" ..
      (preferredSystem == 1 and "§f► §l" or "§8  ") .. "%s\n" ..
      (preferredSystem == 2 and "§f► §l" or "§8  ") .. "%s\n" ..
      (preferredSystem == 3 and "§f► §l" or "§8  ") .. "%s\n" ..
      (preferredSystem == 4 and "§f► §l" or "§8  ") .. "%s",
      table.unpack(measurementSystemsUppercase)))
  end

  updatePreferredMeasurementActionTitle()

  -- Define scroll
  registerIntegerScrollable(preferredMeasurementAction, function(dir)
    -- Scroll through, 1 to 4
    PlayerScale.setPreferredMeasurement(((preferredSystem - 1 - dir) % #measurementSystems) + 1)
    -- Play a sound
    sounds:playSound("minecraft:ui.button.click", player:getPos(), 0.2,
      1 + (preferredSystem * 0.1) - 0.1)
    updateScaleActionTitle()
    updateSaveLoadActionTitle()
  end)

  -- #ENDREGION
  -- #REGION Back button
  -- Create action on created page to go back to main page
  scalePage:newAction()
      :setTitle("Back")
      :setItem("minecraft:barrier")
      :setHoverColor(1, 0, 0)
      :setOnLeftClick(function()
        sounds:playSound("minecraft:ui.button.click", player:getPos(), 0.2, 1)
        action_wheel:setPage(actionWheel)
      end)

  -- #ENDREGION
  -- #REGION Save/Load action
  local saveLoadAction = scalePage:newAction()
      :setItem("minecraft:bundle")

  local saveLoadOption = 1

  -- Function to set the action wheel title
  function updateSaveLoadActionTitle()
    saveLoadAction:setTitle(string.format(
      "§lSave & Load Scale\n§7Saved scale: %s\n\n" ..
      (saveLoadOption == 1 and "§f► §l" or "§8  ") .. "Save\n" ..
      (saveLoadOption == 2 and "§f► §l" or "§8  ") .. "Load\n" ..
      (saveLoadOption == 3 and "§f► §l" or "§8  ") .. "Reset",
      recalculateUnit(false, measurementSystems[preferredSystem],
        loadConfig(configFile, "playerScale") or 1)))
  end

  -- Define scroll
  registerIntegerScrollable(saveLoadAction, function(dir)
    -- Scroll through, 1 to 4
    saveLoadOption = ((saveLoadOption - 1 - dir) % 3) + 1
    -- Play a sound
    sounds:playSound("minecraft:ui.button.click", player:getPos(), 0.2,
      1 + (saveLoadOption * 0.1) - 0.1)
    updateSaveLoadActionTitle()
  end)

  -- Define click
  function saveLoadAction.leftClick()
    if saveLoadOption == 1 then
      PlayerScale.saveScale()
    elseif saveLoadOption == 2 then
      PlayerScale.loadScale()
    elseif saveLoadOption == 3 then
      PlayerScale.setScale({ 1 }, true)
    end
    sounds:playSound("minecraft:ui.button.click", player:getPos(), 0.2, 1)
    updateSaveLoadActionTitle()
  end

  updateSaveLoadActionTitle()
  -- #ENDREGION
  -- #REGION Scale Scroller
  local scaleAction = scalePage:newAction()
      :setItem("minecraft:piston")

  -- How much to scale when holding down a modifier key and scrolling the scale
  local scaleMultipliers = {
    -- Generic
    {
      -- None
      -- Shift
      -- Ctrl
      [0] = { 1, "1x" },
      [1] = { 0.1, "0.1x" },
      [2] = { 0.01, "0.01x" },
    },
    -- Metric
    {
      [0] = { math.worldScale / 2 * (32 / heightLength), "1m" },
      [1] = { math.worldScale / 2 / 10 * (32 / heightLength), "10cm" },
      [2] = { math.worldScale / 2 / 100 * (32 / heightLength), "1cm" },
    },
    -- Imperial
    {
      [0] = { math.worldScale / 2 * 0.3048 * (32 / heightLength), "1ft" },
      [1] = { math.worldScale / 2 * 0.3048 / 12 * (32 / heightLength), "1in" },
      [2] = { math.worldScale / 2 * 0.3048 / 12 / 16 * (32 / heightLength), "¹/₁₆in" },
    },
    -- Pixels
    {
      [0] = { math.worldScale / 32 * 10 * (32 / heightLength), "10px" },
      [1] = { math.worldScale / 32 * (32 / heightLength), "1px" },
      [2] = { math.worldScale / 32 / 10 * (32 / heightLength), "0.1px" },
    },
  }

  local modifiers
  local multiplier
  function events.key_press(_, _, mod)
    modifiers = mod
  end

  -- Function to set the action wheel title
  function updateScaleActionTitle()
    scaleAction:setTitle(string.format("%s\n\n§7None: ±%s\nShift: ±%s\nCtrl:  ±%s",
      (preferredSystem == 1 and
        "Scale = " .. recalculateUnit(true, "generic", targetHeight) or
        "Height " .. recalculateUnit(false, measurementSystems[preferredSystem], targetHeight)),
      (scaleMultipliers[preferredSystem] and scaleMultipliers[preferredSystem][1]) and
      scaleMultipliers[preferredSystem][0][2] or "nil",
      (scaleMultipliers[preferredSystem] and scaleMultipliers[preferredSystem][1]) and
      scaleMultipliers[preferredSystem][1][2] or "nil",
      (scaleMultipliers[preferredSystem] and scaleMultipliers[preferredSystem][2]) and
      scaleMultipliers[preferredSystem][2][2] or "nil"
    ))
  end

  updateScaleActionTitle()

  -- Define scroll
  registerIntegerScrollable(scaleAction, function(dir)
    multiplier = (scaleMultipliers[preferredSystem] and scaleMultipliers[preferredSystem][modifiers]) and
        scaleMultipliers[preferredSystem][modifiers][1] or 0
    PlayerScale.setScale({ targetHeight + (multiplier * dir) }, true)
  end)

  -- #ENDREGION
end

-- #ENDREGION

return scale

--[[
This is a library! If you are trying to copy and paste this into your script.lua, that's not how you install this!
Just drag this library into your avatar and use a require! Don't edit this file unless you know what you're doing!
]]
