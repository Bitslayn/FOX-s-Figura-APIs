--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Line Utility v1.0.0

Lines and outlines render in the world using the line render type. They are useful for debugging, visualizing aabbs, and other purposes.
You can easily be color, move and size lines and outlines.

Create an outline by calling newOutline after requiring. Create a line with newLine.

```lua
local line = require("line")
local myOutline = line.newOutline()
```

Lines and outlines don't use functions like other APIs. They update when you set their fields.
This makes the script small while keeping useful features.

For example, setting an outline's color

```lua
myOutline.color = vectors.hexToRGB("red")
```

You can access the line's and outline's group by indexing the model. This is also how you remove a line or outline.

```lua
myOutline.model:remove()
```
--]]

local lib = {}
local world = models:newPart("FOX_lutil", "World"):scale(16)

--==============================================================================================================================
--#REGION ˚♡ Outline ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Outline > Class ♡˚
------------------------------------------------------------------------------------------------

---@class FOXOutline
---@field package [1] FOXOutline
---@field a Vector3 Corner A position
---@field b Vector3 Corner B position
---@field ab [Vector3, Vector3] A table with both outline point positions. Stable reference even after set and be used as an AABB
---@field color Vector3|Vector4 Line color
---@field model ModelPart Group containing sprite tasks
---@field pos Vector3 Outline position. Setting this moves the ab corner positions
---@field size Vector3 Outline size. Setting this moves the ab corner positions
---@type {[string]: fun(self: FOXOutline, value: any)}
local outClass = {
  color = function(self, color)
    for _, task in pairs(self[1].model:getTask()) do task --[[@as SpriteTask]]:color(color) end
    self[1].color = color
  end,
  pos = function(self, pos)
    local data = self[1]
    data.pos = pos

    data.model:pos(pos + 0.5 --[[@as Vector3]])

    data.ab[1] = pos - (data.size - 1) / 2
    data.ab[2] = data.ab[1] + data.size
  end,
  ab = function(self, ab)
    local data = self[1]
    local a, b = ab[1], ab[2]

    data.ab[1] = a
    data.ab[2] = b
    data.pos = math.lerp(a, b, 0.5) --[[@as Vector3]]
    data.size = a - b

    data.model:pos(data.pos):scale(data.size)
  end,
  size = function(self, size)
    local data = self[1]
    local scale = size

    data.ab[1] = data.pos + scale / 2 + 0.5
    data.ab[2] = data.pos - scale / 2 + 0.5
    data.size = size

    data.model:scale(scale)
  end,
}
---@param self FOXOutline
function outClass.a(self, a) outClass.ab(self, { a, self[1].ab[2] }) end

---@param self FOXOutline
function outClass.b(self, b) outClass.ab(self, { self[1].ab[1], b }) end

local outMeta = {
  __index = function(self, key) return self[1][key] or self[1].ab[key:byte() - 96] end,
  __newindex = function(self, key, value) outClass[key](self, value) end,
  __type = "FOXOutline",
}

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Outline > Matrix ♡˚
------------------------------------------------------------------------------------------------

---Stores generated matrices
---
---Run `buildOutline()`, don't index this table directly
---@type Matrix4[]
local matCache = {}

---Builds the outline matrices meant for the LINES render type
---
---The outline generated is scaled 1axax pixels, center aligned
---
---Caches all matrices and returns the cached matrices if they've been cached
---@return Matrix4[]
local function outlineMatrices()
  if matCache[12] then return matCache end

  --[[
  Axis: Sets the direction of the entire tube
  (0 = up-down, 1 = north-south, 2 = east-west)

  Rot: Just forms the faces of the tube
  (0 = 0, 1 = 90, 2 = 180, 3 = 270)

  Turn: Used strictly to turn the north-south tube
    east-west when making horizontal tubes
  (axis > 1 and 1 or 0)
  ]]

  local index = 0
  for axis = 0, 2 do
    for rot = 0, 3 do
      local turn = math.floor(axis / 2)
      local mat = matrices.mat4()
          -- Create tube (Translates and rotates to form sides of tube)
          :translate(0.5, 0, -0.5) -- *Change y to separate tubes*
          :rotate(0, rot * 90)

          -- Overlap tubes
          :translate(turn * -0.5, axis * 0.5 - turn * 0.5, axis * 0.5 - turn)
          -- Rotate horizontal tubes
          :rotate(axis * 90, 0, turn * 90)
          -- Uniform transform entire outline (This is done since the outline would currently be inside the floor)
          :translate(0, 0.5)

      index = index + 1
      matCache[index] = mat
    end
  end

  return matCache
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Outline > Object ♡˚
------------------------------------------------------------------------------------------------

---@overload fun(a: Vector3, b: Vector3): FOXOutline
---@overload fun(pos: Vector3): FOXOutline
function lib.newOutline(...)
  local param = { ... }
  local a, b = param[1] or vec(0, 0, 0), param[2]
  local size = vec(1, 1, 1)

  local outline = world:newPart("outline")
  for i, mat in ipairs(outlineMatrices()) do
    ---@diagnostic disable-next-line: param-type-mismatch
    outline:newSprite(i)
        :setTexture(textures:getTextures()[1])
        :size(1, 1)
        :matrix(mat)
        :renderType("LINES")
        :color(vec(0, 0, 0, 0.4))
  end

  ---@type FOXOutline
  local self = setmetatable({ {
    model = outline,
    ab = { a, b },
    pos = math.lerp(a, b or a, 0.5) --[[@as Vector3]],
    size = size,
    color = vec(0, 0, 0, 0.4),
  } }, outMeta)
  if b then
    self.ab = { a, b }
  else
    self.pos = a
  end

  return self
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Outline > Annotations ♡˚
------------------------------------------------------------------------------------------------

if false then
  ---Creates a new outline using sprite tasks
  ---@param a Vector3
  ---@param b Vector3
  ---@return FOXOutline
  ---@diagnostic disable-next-line: missing-return, unused-local
  function lib.newOutline(a, b) end

  ---Creates a new outline using sprite tasks
  ---@param pos Vector3
  ---@return FOXOutline
  ---@diagnostic disable-next-line: missing-return, unused-local
  function lib.newOutline(pos) end
end

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Line ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Line > Class ♡˚
------------------------------------------------------------------------------------------------

---@class FOXLine
---@field package [1] FOXLine
---@field a Vector3 Point A position
---@field b Vector3 Point B position
---@field ab [Vector3, Vector3] A table with both line point positions. Stable reference even after set
---@field color Vector3|Vector4 Line color
---@field model ModelPart Group containing sprite tasks
---@type {[string]: fun(self: FOXLine, value: any)}
local lineClass = {
  color = function(self, color)
    for _, task in pairs(self[1].model:getTask()) do task --[[@as SpriteTask]]:color(color) end
    self[1].color = color
  end,
  ab = function(self, ab)
    local data = self[1]
    local a, b = ab[1], ab[2]

    data.ab[1] = a
    data.ab[2] = b

    local dir = (a - b):normalize()
    local eular = vec(
      -math.deg(math.atan2(dir.y, dir.xz:length())),
      math.deg(math.atan2(dir.x, dir.z)),
      0
    )

    local i = 0
    for _, task in pairs(self[1].model:getTask()) do
      i = i + 1
      local mat = matrices.mat4()
          :scale((a - b):length(), 1, 1)
          :rotate(0, 270, i * 90)
          :rotate(eular)
          :translate(a)

      task --[[@as SpriteTask]]:matrix(mat)
    end
  end,
}
---@param self FOXLine
function lineClass.a(self, a) lineClass.ab(self, { a, self[1].ab[2] }) end

---@param self FOXLine
function lineClass.b(self, b) lineClass.ab(self, { self[1].ab[1], b }) end

local lineMeta = {
  __index = function(self, key) return self[1][key] or self[1].ab[key:byte() - 96] end,
  __newindex = function(self, key, value) lineClass[key](self, value) end,
  __type = "FOXLine",
}

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Line > Object ♡˚
------------------------------------------------------------------------------------------------

---Creates a new line using sprite tasks
---@param a Vector3
---@param b Vector3
---@return FOXLine
function lib.newLine(a, b)
  local line = world:newPart("line")
  for i = 0, 1 do
    ---@diagnostic disable-next-line: param-type-mismatch
    line:newSprite(i)
        :setTexture(textures:getTextures()[1])
        :size(1, 0)
        :renderType("LINES")
  end

  ---@type FOXLine
  local self = setmetatable({ {
    model = line,
    ab = { a, b },
    color = vec(1, 1, 1, 1),
  } }, lineMeta)
  self.ab = { a, b }

  return self
end

--#ENDREGION

--#ENDREGION

return lib
