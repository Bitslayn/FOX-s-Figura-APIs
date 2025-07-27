--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Raytrace Utility v1.0.0

Adds raycast:aabbTraced(), raycast:blockTraced(), and raycast:entityTraced() functions which trace rays and aabbs

Not annotated, they're the same exact parameters
--]]

--==============================================================================================================================
--#REGION ˚♡ Raytrace ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Raytrace - Configs ♡˚
------------------------------------------------------------------------------------------------

---@type {[string]: {lifetime: number, color: Vector3|Vector4}}
local configs = {
  -- Line drawn from startpos to endpos
  ray = {
    lifetime = 5,
    color = vec(1, 1, 1),
  },
  --Outline drawn for each aabb
  aabb = {
    lifetime = 5,
    color = vec(0, 0, 0, 0.4),
  },
}

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Raytrace - Handler ♡˚
------------------------------------------------------------------------------------------------

local line = require("Scripts.Utilities.line")
---@type {[string]: {startOpacity: number, oldOpacity: number, newOpacity: number, lastTime: number}}
local traced = {}

---@param points [Vector3, Vector3]
---@param isOutline boolean?
local function new(points, isOutline)
  local id = tostring(points[1]) .. tostring(points[2])
  if traced[id] then
    traced[id].oldOpacity = 1
    traced[id].newOpacity = 1
    return
  end

  local func = line[isOutline and "newOutline" or "newLine"]
  local object = func(table.unpack(points)) --[[@as FOXLine|FOXOutline]]
  local config = configs[isOutline and "aabb" or "ray"]
  object.color = config.color

  traced[id] = {
    startOpacity = config.color --[[@as Vector4]].a or 1,
    oldOpacity = 1,
    newOpacity = 1,
    lastTime = world.getTime(),
  }

  function object.model.midRender(delta)
    local self = traced[id]
    object.color = object.color.xyz:augmented(math.lerp(self.oldOpacity, self.newOpacity, delta) * self.startOpacity)

    local time = world.getTime()
    if self.lastTime == time then return end
    self.lastTime = time

    self.oldOpacity = self.newOpacity
    self.newOpacity = self.newOpacity - 1 / config.lifetime
    if self.newOpacity <= 0 then
      object.model:remove()
      traced[id] = nil
    end
  end
end

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ RaycastAPI ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ RaycastAPI - Helper ♡˚
------------------------------------------------------------------------------------------------

local function parseVectors(params)
  local vectors = {}

  -- Steps through parameters to find its vectors from ...number|Vector3
  -- Stores the vector in the vectors table at vecIndex

  local step, vecIndex = 1, 1
  while vecIndex <= 2 do
    local t = type(params[step])
    vectors[vecIndex] = t == "number" and vec(table.unpack(params, step, step + 2)) or params[step]
    step = step + (t == "number" and 3 or 1)
    vecIndex = vecIndex + 1
  end

  return vectors
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ RaycastAPI - Functions ♡˚
------------------------------------------------------------------------------------------------

---@class RaycastAPI
local RaycastAPI = figuraMetatables.RaycastAPI.__index

---Same as `raycast:aabb()` funtion
---
---Draws the ray and aabbs
function RaycastAPI:aabbTraced(...)
  local params = { ... }
  local points = parseVectors(params)
  local aabbs = params[#params]

  new(points)
  for _, aabb in ipairs(aabbs) do
    new(aabb, true)
  end

  return RaycastAPI.aabb(self, ...)
end

---Same as `raycast:block()` funtion
---
---Draws the ray
function RaycastAPI:blockTraced(...)
  local params = { ... }
  local points = parseVectors(params)

  new(points)

  return RaycastAPI.block(self, ...)
end

---Same as `raycast:entity()` funtion
---
---Draws the ray
function RaycastAPI:entityTraced(...)
  local params = { ... }
  local points = parseVectors(params)

  new(points)

  return RaycastAPI.entity(self, ...)
end

--#ENDREGION

--#ENDREGION
