--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Player Scale v2.0.0-dev

Features
  Scaling straight from the action wheel or as a custom command
  Camera zooming dynamically with other fixes to prevent clipping the camera through solid blocks
  Eye level adjustment with 3 separate modes
  All other things that makes sense to scale with your avatar

Supports these libraries straight out of the box!
  FOX's InteractionsAPI v1.3.0 -- TODO
  FOX's Command Interpreter v1.0.0
  KattDynamicCrosshair v4.0

--]]

--============================================================--
-- Important Library Functions
--============================================================--
-- These functions are required for the library to be a library
local version = "v2.0.0"

---Prints a message with the API's name for errors and information
---@param notice string
---@alias severity string
---| "normal" # White API name and text
---| "info" # Yellow API name with white text, shown only when debug mode is enabled
---| "info (forced)" # Yellow API name with white text
---| "warning" # Dark red API name with light red text
---| "fatal" # Dark red API name with light red text, crashes the avatar
---@param severity severity
---@package
function APINotice(notice, severity)
  local api = "PlayerScale" -- The name of the API
  local hover = "FOX's Player Scale " .. version
  local styles = {
    normal = "§l[" .. api .. "]:§r",    -- White, bold API name with regular text
    info = "§e§l[" .. api .. "]:§r",    -- Bold yellow API name inside brackets with regular white text
    warning = "§4§l[" .. api .. "]:§r", -- Bold dark red API name with regular light red text
    fatal = "§4§l[" .. api .. "]:§r",   -- Bold dark red API name with regular light red text (Crashes)
  }
  if host:isHost() then                 -- Only the host should recieve prints
    local gnURL = "https://github.com/lua-gods/GNs-Avatar-2/blob/main/libraries/GNlineLib.lua"
    notice = notice:gsub("GNlineLib",
      '"},{"text":"§9§nGNlineLib§r","clickEvent":{"action":"open_url","value":"' ..
      gnURL .. '"},"hoverEvent":{"action":"show_text","contents":"' .. gnURL .. '"}},{"text":"')
    local style = styles[severity]:gsub("%[" .. api .. "%]:",
      "[" .. api .. ']:","hoverEvent":{"action":"show_text","contents":"' ..
      hover .. '"}},{"text":"')
    -- Print according to the style
    printJson('["",{"text":"' ..
      style ..
      ' "},{"text":"' ..
      ((severity == "warning" or severity == "fatal") and "§c" or "") ..
      notice .. "\n" ..
      (severity == "fatal" and "\n" or "") .. '"}]')
  end
  if severity == "fatal" then
    error(
      styles[severity] .. "§c " .. notice:gsub("\\", ""), -1)
  end
end

--==============================--

---Save config from file. Does the same thing as `config:setName(file):save(name, value)` but also reverts the set file name so other configs aren't affected. Like setting the file name temporarily.
---@param file string
---@param name string
---@param value any
local function saveConfig(file, name, value)
  -- Store the name of the config file previously targeted
  local prevConfig = config:getName()
  -- Save to this library's config file
  local save = config:setName(file):save(name, value)
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

--============================================================--
-- Init
--============================================================--

local modelRoot = models.models.model.root
local configFile = "PlayerScale"
local savedScale = loadConfig(configFile, "playerScale")
local scale = savedScale or 1
local targetScale = scale
local normalsNegative = false

function pings.scale(_scale)
  scale = _scale
end

pings.scale(scale)

--============================================================--
-- Invert model normals functions
--============================================================--

-- Find all the children of the model
local listOfChildren = {}
local function getChildren(model)
  for _, modelpart in pairs(model:getChildren()) do
    local name = modelpart:getName():lower()
    if modelpart:getChildren()[1] then
      getChildren(modelpart)
    else
      table.insert(listOfChildren, modelpart)
    end
  end
end
getChildren(modelRoot)

local function invertNormals(part)
  for _, vg in pairs(part:getAllVertices()) do
    ---@param v Vertex
    for _, v in ipairs(vg) do
      v:setNormal(v:getNormal() * -1)
    end
  end
end

--============================================================--
-- Change the player's visual scale
--============================================================--

function events.render(_, context)
  -- Scale the player in-world differently from in inventories
  if context == "MINECRAFT_GUI" or context == "PAPERDOLL" or context == "FIGURA_GUI" then
    -- Set the player scale to 1 in inventories
    modelRoot:setScale(1)
    -- Fix the vertical position in inventories if the player is upside down
    modelRoot:setPos((scale < 0 and 32 or 0) * vec(0, 1, 0))
  else
    -- Set the player's model scale
    modelRoot:setScale(math.abs(scale) * vec(scale < 0 and -1 or 1, 1, 1))

    -- Flip the player's model if the scale is negative
    modelRoot:setRot(0, 0, scale < 0 and -180 or 0)
    -- Offset the player's model position so it's not inside the ground with negative scales
    modelRoot:setPos(0, scale < 0 and
      (models.models.model.MaxPivot:getPivot().y / 16 * math.playerScale * models.models.model.root:getScale().y) *
      16 or 0, 0)

    -- Invert the normals of the player model (The player normals are flipped when scaling negatively, this fixes that)
    if normalsNegative ~= (scale < 0) then
      normalsNegative = (scale < 0)
      for _, value in pairs(listOfChildren) do
        invertNormals(value)
      end
    end
  end

  -- Scale the player's shadow
  renderer:setShadowRadius(0.5 * scale)

  cast = raycast:block(player:getPos() - vec(0, 1, 0), player:getPos() - vec(0, 1, 0), "VISUAL")

  -- Reposition the player's nameplate
  nameplate.ENTITY:setPivot((((cast:getOpacity() < 15 or #cast:getCollisionShape() == 0) and scale < 0) and -0.6 or ((2 * math.abs(scale)) + 0.3)) * vec(0, 1, 0))
end

--============================================================--
-- Custom commands
--============================================================--

local FOXCommandLib, SlymeCandler
local scripts = listFiles("/", true)
for _, path in pairs(scripts) do
  -- Look for scripts to require
  local search = { fox = string.find(path, "CommandLib"), slyme = string.find(path, "candler") }
  -- Assign require from search
  if search.fox then
    FOXCommandLib = require(path)
  end
  if search.slyme then
    SlymeCandler = require(path)
  end
end
if FOXCommandLib and SlymeCandler then
  APINotice("You're using.. both supported command interpretation libraries?", "fatal")
end

-- FOX's Command Interpreter
if FOXCommandLib then
  ---@diagnostic disable-next-line: undefined-global
  commands:command("scale",
    {
      __call = function(args) -- .scale <number>
        if not args[1] then
          APINotice("Please enter a scale", "warning")
        else
          if type(args[1]) == "number" then
            pings.scale(args[1])
            APINotice("Set your scale to " .. args[1], "info")
          else
            APINotice("Cannot set scale to " .. type(args[1]), "warning")
          end
        end
      end,
      set = function(args) -- .scale set <number>
        if not args[1] then
          APINotice("Please enter a scale", "warning")
        else
          if type(args[1]) == "number" then
            pings.scale(args[1])
            APINotice("Set your scale to " .. args[1], "info")
          else
            APINotice("Cannot set scale to " .. type(args[1]), "warning")
          end
        end
      end,
      load = function() -- .scale load
        pings.scale(savedScale)
        APINotice("Loaded the scale " .. savedScale, "info")
      end,
      save = function() -- .scale save
        savedScale = scale
        saveConfig(configFile, "playerScale", scale)
        APINotice("Scale saved as " .. savedScale, "info")
      end,
      flip = function() -- .scale flip
        pings.scale(-scale)
      end,
    })
end

-- Slyme's Candler
if SlymeCandler then
  ---@diagnostic disable-next-line: undefined-global
  candler.lib.newCategory("PlayerScale", {
    description = "Scale your player's scale",
    author = "FOX",
    version = version,
  })

  ---@diagnostic disable-next-line: undefined-global
  candler.lib.setCommand("PlayerScale", "scale", {
    description = "Set the player's scale",
    arguments = {
      {
        name = "subcommand",
        description = "This command's subcommand. Can be set, load, save, or flip.",
        required = true,
      },
      {
        name = "scale",
        description = "The player's scale",
        required = false,
      },
    },
  }, function(args)
    if args[1] == "set" then -- .scale set <scale>
      if not args[2] then
        APINotice("Please enter a scale", "warning")
      else
        if tonumber(args[2]) then
          pings.scale(tonumber(args[2]))
          APINotice("Set your scale to " .. tonumber(args[2]), "info")
        else
          APINotice("Cannot set scale to string", "warning")
        end
      end
    elseif args[1] == "load" then -- .scale load
      pings.scale(savedScale)
      APINotice("Loaded the scale " .. savedScale, "info")
    elseif args[1] == "save" then -- .scale save
      savedScale = scale
      saveConfig(configFile, "playerScale", scale)
      APINotice("Scale saved as " .. savedScale, "info")
    elseif args[1] == "flip" then -- .scale flip
      pings.scale(-scale)
    end
  end)
end
