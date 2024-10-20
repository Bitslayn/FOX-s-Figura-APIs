--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's InteractionsAPI v1.0.2

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
---@class InteractionsAPI
---@field name string
---@field region table
---@field mode InteractionModes
---@field key Minecraft.keyCode
local InteractionsAPI = {}

---@class interactions
---@field [string] InteractionsAPI
local interactions = {}


local version = "v1.0.2" -- DO NOT TOUCH
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
function InteractionsAPI:setRegion(fromVec, toVec, mode)
  self.region = self.region or {}
  self.region.fromVec = fromVec
  self.region.toVec = toVec
  self.mode = mode
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

--   #ENDREGION

--   #REGION Get
-- ~================================================================================~
-- GET REGION

---Get the region vectors and the mode for this interaction
---@param self InteractionsAPI
---@return table
function InteractionsAPI:getRegion()
  return { region = self.region, mode = self.mode }
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
-- GET NAME

---Gets the interaction's name
---@param self InteractionsAPI
---@return string
function InteractionsAPI:getName()
  return self.name
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
  table.insert(tbl.interactions, interactions[self.name])

  avatar:store("InteractionsAPI", tbl)
end

-- ~================================================================================~
-- #ENDREGION

-- #REGION Create function
-- ~================================================================================~
-- CREATE

---Creates an interaction with optional parameters
---@param name string # Name of this interaction
---@param fromVec? Vector3 # First corner
---@param toVec? Vector3 # Second corner
---@param mode? InteractionModes
---@param key? Minecraft.keyCode
---@return InteractionsAPI
function interactions:create(name, fromVec, toVec, mode, key)
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

    -- Store the interaction to table
    interactions[name] = self
  end

  -- Set values
  if fromVec and toVec and mode then
    interactions[name]:setRegion(fromVec, toVec, mode)
  end
  if key then
    interactions[name]:setKey(key)
  end

  return interactions[name]
end

-- ~================================================================================~
-- #ENDREGION

-- #REGION Logic
-- ~================================================================================~

-- Pinging when a player interacts with an interaction
function pings.iapiPing(u, i, bool)
  local avatarVars = player:getVariable()
  local tbl = deepCopy(avatarVars["InteractionsAPI"] or {})

  tbl.pings = tbl.pings or {}
  tbl.pings[u] = tbl.pings[u] or {}
  tbl.pings[u][tostring(i)] = bool

  avatar:store("InteractionsAPI", tbl)
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
local kb = keybinds:newKeybind(""):enabled(false)

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
              local playerPos = player:getPos()
              local eyePos = playerPos + vec(0, player:getEyeHeight(), 0)
              local eyeEnd = eyePos + (player:getLookDir() * 20)
              local region = { { value.region.fromVec, value.region.toVec } }

              if value.mode == "Collider" then
                currentPing = raycast:aabb(playerPos, playerPos, region) and
                    (not value.key or keypresses[kb:setKey(value.key):getID()])
              elseif value.mode == "Hitbox" then
                currentPing = raycast:aabb(eyePos, eyeEnd, region) and
                    (not value.key or keypresses[kb:setKey(value.key):getID()])
              else
                error(
                  "§4§lInteractionsAPI:§r§4 \"" ..
                  value.name ..
                  "\" Mode definition error! Mode must be selected if a region is defined!§c", -1)
              end
            elseif value.key then
              currentPing = keypresses[kb:setKey(value.key):getID()]
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
