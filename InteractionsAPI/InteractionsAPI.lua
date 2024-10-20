--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's InteractionsAPI v1.1.2

--]]

-- Configuration (Doesn't do anything yet)

-- Whether to allow interacting with to interactions that do not have a defined region (no hitbox or collision tracking)
-- (An undefined region makes an interaction interactable anywhere in the world)
local allowUndefinedRegions = true

-- #REGION Setup
-- ~================================================================================~

---@alias InteractionModes string
---| "Hitbox" # Activates when a player looks at this region
---| "Collider" # Activates when a player collides with this region
---@alias InteractionSwingFrequency string
---| "Never" # Never swing the player's arm
---| "Once" # Swing when the player interacts
---| "Every Tick" # Swing while player is interacting
---@class InteractionsAPI
---@field name string
---@field region table
---@field mode InteractionModes
---@field distance number
---@field key Minecraft.keyCode
---@field color string|Vector3
---@field swing InteractionSwingFrequency
local InteractionsAPI = {}

---@class interactions
---@field [string] InteractionsAPI
local interactions = {}


local version = "v1.1.2" -- DO NOT TOUCH
avatar:store("InteractionsAPI",
  { version = version, config = { allowUndefinedRegions = allowUndefinedRegions } })

-- Deep copy list
local function deepCopy(tbl)
  local copy
  if type(tbl) == "table" then
    copy = {}
    for k, v in next, tbl, nil do
      copy[deepCopy(k)] = deepCopy(v)
    end
  else
    copy = tbl
  end
  return copy
end

-- ~================================================================================~
-- #ENDREGION

-- #REGION Chained get/set functions
--   #REGION Set
-- ~================================================================================~
-- SET REGION

---Set the region vectors and mode for this interaction
---@param self InteractionsAPI
---@param fromVec Vector3 # First corner
---@param toVec Vector3 # Second corner
---@param mode InteractionModes
---@param distance? number # The raycast distance
function InteractionsAPI:setRegion(fromVec, toVec, mode, distance)
  self.region = self.region or {}
  self.region.fromVec = fromVec
  self.region.toVec = toVec
  self.mode = mode
  self.distance = distance or 3
  return self
end

-- ~========================================~
-- SET KEY

---Sets a key for this interaction
---@param self InteractionsAPI
---@param key Minecraft.keyCode
function InteractionsAPI:setKey(key)
  self.key = key
  return self
end

-- ~========================================~
-- SET COLOR

---Sets the interaction's color for use as a hitbox
---@param self InteractionsAPI
---@param color string|Vector3 # Color as a hex, string, or rgb vector
function InteractionsAPI:setColor(color)
  self.color = color
  return self
end

-- ~========================================~
-- SET SWING

---Sets swing frequency when interacting
---@param self InteractionsAPI
---@param swing InteractionSwingFrequency # If and how often the interactor should swing their arm
function InteractionsAPI:setSwing(swing)
  self.swing = swing
  return self
end

--   #ENDREGION

--   #REGION Get
-- ~================================================================================~
-- GET REGION

---Get the region vectors and the mode for this interaction
---@param self InteractionsAPI
---@return table
function InteractionsAPI:getRegion()
  return { region = self.region, mode = self.mode, distance = self.distance }
end

-- ~========================================~
-- GET KEY

---Get key defined for this interaction
---@param self InteractionsAPI
---@return Minecraft.keyCode
function InteractionsAPI:getKey()
  return self.key
end

-- ~========================================~
-- GET COLOR

---Gets the interaction's hitbox color
---@param self InteractionsAPI
---@return string|Vector3
function InteractionsAPI:getColor()
  return self.color
end

-- ~========================================~
-- GET NAME

---Gets the interaction's name
---@param self InteractionsAPI
---@return string
function InteractionsAPI:getName()
  return self.name
end

-- ~========================================~
-- GET SWING

---Gets swing frequency when interacting
---@param self InteractionsAPI
---@return InteractionSwingFrequency
function InteractionsAPI:getSwing()
  return self.swing
end

-- ~================================================================================~
--   #ENDREGION
-- #ENDREGION

-- #REGION Chained utility functions
-- ~================================================================================~
-- REMOVE

---Removes the interaction
---@param self InteractionsAPI
function InteractionsAPI:remove()
  -- If a player isn't loaded and avatar:store is updated, not all players will get the right table
  -- Throws an error if this happens
  if not player:isLoaded() then
    error(
      "§4§lInteractionsAPI:§r§4 \"" ..
      self.name .. "\" Interaction removed before player was loaded! Try running interaction." ..
      self.name .. ":remove() after events.entity_init()§c", -1)
    return
  end
  local avatarVars = player:getVariable()
  local tbl = deepCopy(avatarVars["InteractionsAPI"] or {})


  for i, t in pairs(tbl.interactions) do
    if t.name == self.name then
      tbl.interactions[i] = nil
    end
  end

  interactions[self.name] = nil

  avatar:store("InteractionsAPI", tbl)
end

-- ~========================================~
-- UPDATE

---Updates this interaction for everyone, storing it to avatar:store
---@param self InteractionsAPI
function InteractionsAPI:update()
  -- If a player isn't loaded and avatar:store is updated, not all players will get the right table
  -- Throws an error if this happens
  if not player:isLoaded() then
    error(
      "§4§lInteractionsAPI:§r§4 \"" ..
      self.name .. "\" Interaction registered before player was loaded! Try running interaction." ..
      self.name .. ":update() after events.entity_init()§c", -1)
    return
  end
  local avatarVars = player:getVariable()
  local tbl = deepCopy(avatarVars["InteractionsAPI"] or {})

  tbl.interactions = tbl.interactions or {}
  local position = #tbl.interactions + 1
  for i, t in pairs(tbl.interactions) do
    if t.name == self.name then
      position = i
    end
  end
  tbl.interactions[position] = interactions[self.name]

  avatar:store("InteractionsAPI", tbl)
end

-- ~================================================================================~
-- #ENDREGION

-- #REGION Create function
-- ~================================================================================~
-- CREATE

---Creates an interaction
---@param name string # Name of this interaction
---@return InteractionsAPI
function interactions:create(name)
  if not interactions[name] then
    self = setmetatable({
      name = name,
      region = nil,
      mode = nil,
      key = nil,
    }, {
      __index = InteractionsAPI,
      __call = function(t, ...)
        return self:getInteractors()
      end,
    })

    interactions[name] = self
  end

  return interactions[name]
end

---Creates an interaction
---Alias for create()
---@param name string # Name of this interaction
---@return InteractionsAPI
function interactions:newInteraction(name)
  interactions:create(name)
  return interactions[name]
end

-- ~================================================================================~
-- #ENDREGION

-- #REGION Logic
-- ~================================================================================~

-- debug
-- Locates GNlineLib if it exists and returns its functions
local GNlineLibParams = { path = nil, exists = nil }
local function GNlineLib()
  local lineLib
  if GNlineLibParams.exists == nil then
    -- Find GNlineLib
    local scripts = listFiles("/", true)
    for _, path in pairs(scripts) do
      local search = string.find(path, "GNlineLib")
      if search then
        GNlineLibParams.path = path
      end
    end
    if not GNlineLibParams.path then
      printJson(
        '["",{"text":"§lInteractionsAPI:§r An interaction requested the use of "},{"text":"GNlineLib","underlined":true,"color":"blue","clickEvent":{"action":"open_url","value":"https://github.com/lua-gods/GNs-Avatar-2/blob/main/libraries/GNlineLib.lua"}},{"text":" which wasn\'t found!\n"}]')
      GNlineLibParams.exists = false
    else
      GNlineLibParams.exists = true
    end
  end

  if GNlineLibParams.exists == true then
    lineLib = require(GNlineLibParams.path)
    return lineLib
  else
    return nil
  end
end

---comment
---@param v Vector3
---@param dv Vector3
---@param color? string|Vector3
---@return table
local function drawHitbox(v, dv, color)
  if host:isHost() then
    local lineLib = GNlineLib()
    -- Take a color of vector, hex, or string
    if type(color) == "string" then
      color = vectors.hexToRGB(color) or vec(1, 1, 1)
    elseif type(color) ~= "Vector3" then
      color = vec(1, 1, 1)
    end
    if lineLib then
      local lines = {
        lineLib:new():setAB(v.x, v.y, v.z, v.x + (dv.x - v.x), v.y, v.z),
        lineLib:new():setAB(v.x + (dv.x - v.x), v.y, v.z, v.x + (dv.x - v.x), v.y, v.z + (dv.z - v.z)),
        lineLib:new():setAB(v.x + (dv.x - v.x), v.y, v.z + (dv.z - v.z), v.x, v.y, v.z + (dv.z - v.z)),
        lineLib:new():setAB(v.x, v.y, v.z + (dv.z - v.z), v.x, v.y, v.z),

        lineLib:new():setAB(v.x, v.y + (dv.y - v.y), v.z, v.x + (dv.x - v.x), v.y + (dv.y - v.y), v
          .z),
        lineLib:new():setAB(v.x + (dv.x - v.x), v.y + (dv.y - v.y), v.z, v.x + (dv.x - v.x),
          v.y + (dv.y - v.y), v.z + (dv.z - v.z)),
        lineLib:new():setAB(v.x + (dv.x - v.x), v.y + (dv.y - v.y), v.z + (dv.z - v.z), v.x,
          v.y + (dv.y - v.y), v.z + (dv.z - v.z)),
        lineLib:new():setAB(v.x, v.y + (dv.y - v.y), v.z + (dv.z - v.z), v.x, v.y + (dv.y - v.y), v
          .z),

        lineLib:new():setAB(v.x, v.y, v.z, v.x, v.y + (dv.y - v.y), v.z),
        lineLib:new():setAB(v.x + (dv.x - v.x), v.y, v.z, v.x + (dv.x - v.x), v.y + (dv.y - v.y), v
          .z),
        lineLib:new():setAB(v.x + (dv.x - v.x), v.y, v.z + (dv.z - v.z), v.x + (dv.x - v.x),
          v.y + (dv.y - v.y), v.z + (dv.z - v.z)),
        lineLib:new():setAB(v.x, v.y, v.z + (dv.z - v.z), v.x, v.y + (dv.y - v.y), v.z + (dv.z - v.z)),
      }
      for _, line in pairs(lines) do
        line:setWidth(0.01):setColor(color):setDepth(-0.005) -- Depth is negative and half of width
      end
      return lines
    end
  end
  return {}
end

-- Pinging when a player interacts with an interaction
function pings.iapiPing(u, i, bool)
  if player:isLoaded() then
    local avatarVars = player:getVariable()
    local tbl = deepCopy(avatarVars["InteractionsAPI"] or {})

    tbl.pings = tbl.pings or {}
    tbl.pings[u] = tbl.pings[u] or {}
    tbl.pings[u][tostring(i)] = bool

    avatar:store("InteractionsAPI", tbl)
  end
end

-- Keys currently being pressed
local keypresses = {}
function events.mouse_press(button, action)
  keypresses[button] = ((action == 1 or action == 2) or nil)
end

function events.key_press(key, action)
  keypresses[key] = ((action == 1 or action == 2) or nil)
end

local prePing = {}
local debug = false
local kb = keybinds:newKeybind("InteractionsAPI - Debug Mode", "key.keyboard.right.control")
    :setOnPress(function()
      if GNlineLib() then
        debug = not debug
        printJson('["",{"text":"InteractionsAPI:","bold":true},{"text":" Debug mode ' ..
          (debug and "enabled" or "disabled") .. '\n"}]')
      else
        printJson(
          '["",{"text":"§lInteractionsAPI:§r Unable to enable debug mode! Please download "},{"text":"GNlineLib","underlined":true,"color":"blue","clickEvent":{"action":"open_url","value":"https://github.com/lua-gods/GNs-Avatar-2/blob/main/libraries/GNlineLib.lua"}},{"text":"!\n"}]')
      end
    end)
local lines = {}
local hitboxPos = {}

local function getKeyID(ID)
  local previousKey = kb:getKey()
  local key = kb:setKey(ID):enabled(false):getID()
  kb:setKey(previousKey):enabled(true)
  return key
end

-- Process interactions needing to be pinged
if host:isHost() then
  function events.tick()
    for u, t in pairs(world.avatarVars()) do
      for k, v in pairs(t) do
        if k == "InteractionsAPI" and v["interactions"] then
          for i, value in pairs(v["interactions"]) do
            local uint = tostring(client.uuidToIntArray(u))
            local currentPing = false

            if value.region then
              local rc
              local playerPos = player:getPos()
              local eyePos = playerPos + vec(0, player:getEyeHeight(), 0)
              local eyeEnd = eyePos + (player:getLookDir() * value.distance)
              local region = { { value.region.fromVec, value.region.toVec } }

              if value.mode == "Collider" then
                rc = raycast:aabb(playerPos, playerPos, region)
                currentPing = rc and (not value.key or keypresses[getKeyID(value.key)])
              elseif value.mode == "Hitbox" then
                rc = raycast:aabb(eyePos, eyeEnd, region)
                currentPing = rc and (not value.key or keypresses[getKeyID(value.key)])
              else
                error(
                  "§4§lInteractionsAPI:§r§4 \"" ..
                  value.name ..
                  "\" Mode definition error! Mode must be selected if a region is defined!§c", -1)
              end
              hbPos = (value.region.fromVec + value.region.toVec) / 2
              if not lines[value.name] and ((rc and value.color) or debug) then
                lines[value.name] = drawHitbox(value.region.fromVec, value.region.toVec, value.color)
                hitboxPos[value.name] = (value.region.fromVec + value.region.toVec) / 2
              elseif lines[value.name] and not (rc or debug) then
                for _, line in pairs(lines[value.name]) do
                  line:free()
                end
                lines[value.name] = nil
              elseif lines[value.name] and hbPos ~= hitboxPos[value.name] then
                for _, line in pairs(lines[value.name]) do
                  line:setAB(line.a + (hbPos - hitboxPos[value.name]),
                    line.b + (hbPos - hitboxPos[value.name]))
                end
                hitboxPos[value.name] = (value.region.fromVec + value.region.toVec) / 2
              end
              if debug and raycast:aabb(eyePos, eyePos + (player:getLookDir() * 8), region) then
                local username
                for _, p in pairs(world.getPlayers()) do
                  if p:getUUID() == u then
                    username = p:getName()
                  end
                end
                local diagonalLength = math.sqrt(
                  (math.abs(value.region.toVec.x - value.region.fromVec.x) ^ 2) +
                  (math.abs(value.region.toVec.z - value.region.fromVec.z) ^ 2)) + 0.1
                if not models[value.name .. "_debug"] then
                  models:newPart(value.name .. "_debug", "WORLD")
                      :newPart(value.name .. "_debug_text", "CAMERA")
                      :newText(value.name)
                      :setText("Owner: " ..
                        username ..
                        "\nName: " ..
                        value.name ..
                        "\n\nMode: " ..
                        value.mode .. "\nKey: " .. value.key .. "\nDistance: " .. value.distance)
                      :setBackgroundColor(vectors.hexToRGB("#00000040"))
                      :scale(0.2)
                else
                  models[value.name .. "_debug"]:setPos((
                    vectors.rotateAroundAxis(-client:getCameraRot().y + 180, (
                      (((diagonalLength / 2) * vec(1, 0, 0)))), vec(0, 1, 0)) +
                    (math.abs(value.region.toVec.y - value.region.fromVec.y) * vec(0, 0.5, 0))
                    + hitboxPos[value.name]) * 16)
                end
              elseif models[value.name .. "_debug"] then
                models[value.name .. "_debug"]:remove()
              end
            elseif value.key then
              currentPing = keypresses[getKeyID(value.key)]
            else
              error(
                "§4§lInteractionsAPI:§r§4 \"" ..
                value.name ..
                "\" Global definition error! An interaction without a region must have a key assigned!§c",
                -1)
            end

            if not prePing[uint] then
              prePing[uint] = {}
            end

            if not prePing[uint][i] then
              prePing[uint][i] = { lastPing = false, firstTime = true }
            end

            currentPing = currentPing or false

            if (currentPing and not prePing[uint][i].lastPing) or (not currentPing and prePing[uint][i].lastPing) then
              pings.iapiPing(uint, i, currentPing)
              if value.swing == "Once" and currentPing == true then
                host:swingArm()
              end
            end

            if prePing[uint][i].lastPing and player:getSwingTime() == 0 and value.swing == "Every Tick" then
              host:swingArm()
            end

            prePing[uint][i].lastPing = currentPing
            if prePing[uint][i].firstTime then
              prePing[uint][i].firstTime = false
            end
          end
        end
      end
    end
  end
end

local selfUUID
function events.entity_init()
  selfUUID = tostring(client.uuidToIntArray(player:getUUID()))
end

---Gets a list of players interacting with this interaction
---@param self InteractionsAPI
function InteractionsAPI:getInteractors()
  local id
  for i, t in pairs(player:getVariable()["InteractionsAPI"]["interactions"]) do
    if t.name == self.name then
      id = tostring(i)
    end
  end

  local players

  if id then
    for _, plr in pairs(world:getPlayers()) do
      for v, api in pairs(plr:getVariable()) do
        if v == "InteractionsAPI" and type(api.pings) == "table" then
          for u, t in pairs(api.pings) do
            if u == selfUUID and type(t) == "table" and t[id] then
              players = players or {}
              table.insert(players, plr)
            end
          end
        end
      end
    end
  else
    error(
      "§4§lInteractionsAPI:§r§4 \"" ..
      self.name ..
      "\" Cannot get interactors of unregistered interaction! Remember to run interaction." ..
      self.name .. ":update()§c", -1)
    return
  end
  return players
end

-- ~================================================================================~
-- #ENDREGION

return interactions
