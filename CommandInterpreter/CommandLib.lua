--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Command Interpreter v0.9.5

A command interpreter with command suggestions just like Vanilla

Features
  Custom commands with a configurable prefix
  Command suggestions shown through an actual GUI
  Pressing arrow keys and tab to autocomplete

--]]

--============================================================--
-- API Config handler
--============================================================--

local configFile = "CommandLib"

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

--============================================================--
-- Lib Functions
--============================================================--

local commandTable = {}
local prefix = loadConfig(configFile, "commandPrefix") or "."
local suggestionsLimit = 10

---@meta _
---@class CommandLib
local CommandLib = {
  __path = nil, -- The command path, used with non-table oriented functions. *Not to be referenced outside the API*
}
CommandLib.__index = CommandLib

---Advanced functions that modify the command registry directly
---@type CommandLib.tables
CommandLib.tables = {}

commands = CommandLib

---@class CommandLib.tables
local tables = {}

---Create a new command or update an existing command
---@param p1 string|table # Either the name of a table entry or a table itself. Setting this to a table will overwrite all other commands!
---@param p2? function|table # Table of subcommands and or fields, or a function
function tables:commandTable(p1, p2)
  if type(p1) == "string" then
    commandTable[p1] = p2 or {}
  else
    commandTable = p1
  end
end

---Return the table or function of a command
---@param p1? string # Name of table entry (command), returns entire table of all commands if nothing is entered here
---@return function|table
---@nodiscard
function tables:getCommandTable(p1)
  return p1 and commandTable[p1] or commandTable
end

---Removes a command
---@param p1 string # Name of table entry (command)
function tables:removeCommandTable(p1)
  commandTable[p1] = nil
end

CommandLib.tables = tables

--====================-

-- Commands

---Creates a command, can be chained to create subcommands
---@param name string
---@return CommandLib
function CommandLib:createCommand(name)
  local this -- Localize self

  -- Localized path
  if not self.__path then
    -- If there is no path (The first command in the tree)
    this = setmetatable({
      __path = { name },
    }, CommandLib)
  else
    -- If there is a path
    this = setmetatable({
      __path = { table.unpack(self.__path) },
    }, CommandLib)
    -- Insert into path
    table.insert(this.__path, name)
  end

  -- Modify command table
  local tablePath = commandTable
  for _, value in pairs(this.__path) do
    if tablePath[value] then
      tablePath = tablePath[value]
    else
      tablePath[value] = {}
      tablePath = tablePath[value]
    end
  end

  return this -- Return localized self for chaining
end

---Returns a command's table
---@return table
---@nodiscard
function CommandLib:getCommand()
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for i, value in pairs(self.__path) do
      tablePath = tablePath[value]
    end
    return tablePath
  else
    error("Could not return the command nil", 2)
  end
end

---Removes a command
function CommandLib:removeCommand()
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for i, value in pairs(self.__path) do
      if i ~= #self.__path then
        tablePath = tablePath[value]
      else
        -- Remove the command
        tablePath[value] = nil
      end
    end

    -- Clear the path
    self.__path = nil
  else
    error("Could not remove the command nil", 2)
  end
end

-- Functions

---Sets the function of a command
---@param fun function
---@param packed? boolean # Whether or not to pack arguments into a table before running the function. Unpacked arguments takes as many arguments as the function can take. `Defaults to false`
---@return CommandLib
function CommandLib:setFunction(fun, packed)
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for _, value in pairs(self.__path) do
      tablePath = tablePath[value]
    end

    -- Set the function for this command
    tablePath._func = fun

    -- Set whether arguments passed into this function are packed into a table
    tablePath._args = tablePath._args or {}
    tablePath._args._packed = packed or false
  else
    error("Could not assign a function to nil", 2)
  end
  return self -- Return self for chaining
end

---Return the function assigned to this command
---@return function|nil
---@nodiscard
function CommandLib:getFunction()
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for _, value in pairs(self.__path) do
      tablePath = tablePath[value]
    end

    -- Return the function
    return tablePath._func
  else
    error("Could not return function of command nil", 2)
  end
end

---Removes a command's function
---@return CommandLib
function CommandLib:removeFunction()
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for _, value in pairs(self.__path) do
      tablePath = tablePath[value]
    end

    -- Remove function
    tablePath._func = nil
  else
    error("Could not remove function of the command nil", 2)
  end
  return self -- Return self for chaining
end

---Sets this command's info to display in the status box
---@param info any
---@return CommandLib
function CommandLib:setInfo(info)
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for _, value in pairs(self.__path) do
      tablePath = tablePath[value]
    end

    -- Set the info for this command
    tablePath._info = info
  else
    error("Could not assign a function to nil", 2)
  end
  return self -- Return self for chaining
end

---Return the command's info
---@return string
---@nodiscard
function CommandLib:getInfo()
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for _, value in pairs(self.__path) do
      tablePath = tablePath[value]
    end

    -- Return the info
    return tablePath._info
  else
    error("Could not return function of command nil", 2)
  end
end

---Removes a command's info
---@return CommandLib
function CommandLib:removeInfo()
  -- Check if path exists
  if self.__path then
    -- Locate command table for this command
    local tablePath = commandTable
    for _, value in pairs(self.__path) do
      tablePath = tablePath[value]
    end

    -- Remove info
    tablePath._info = nil
  else
    error("Could not remove info of the command nil", 2)
  end
  return self -- Return self for chaining
end

--====================-

---Change the command prefix<br>Defaults to `.`
---@param pfx? string # The prefix to apply
---@param persist? boolean # Should the prefix be saved to the config?
function CommandLib:setPrefix(pfx, persist)
  prefix = pfx or "."
  if persist then
    saveConfig(configFile, "commandPrefix", pfx)
  end
end

---Return the command prefix
---@nodiscard
function CommandLib:getPrefix()
  return prefix
end

---Sets the maximum amount of commands that can be displayed at once<br>Defaults to 10
---@param num? number # The number of suggestions
---@param persist? boolean # Should this save to the config?
function CommandLib:setMaxSuggestions(num, persist)
  suggestionsLimit = math.max(num or 10, 0)
  if persist then
    saveConfig(configFile, "maxSuggestions", num)
  end
end

---Returns the number of suggestions that can be displayed at once
---@nodiscard
function CommandLib:getMaxSuggestions()
  return suggestionsLimit
end

--============================================================--
-- GUI Customization
--============================================================--

if host:isHost() then
  -- Create element anchors
  local guiPivot = {
    front = models:newPart("_FOX_CL-m-f", "Hud"):setPos(0, 0, -3 * 100), -- GUI elements which display on top of the vanilla HUD
    back = models:newPart("_FOX_CL-m-b", "Hud"):setPos(0, 0, 3 * 100),   -- GUI elements which display behind the vanilla HUD
  }

  local lang = {
    errors = {
      unknownCommand = client.getTranslatedString("command.unknown.command"),
      executionError = client.getTranslatedString("command.failed"),
      notationHere = client.getTranslatedString("command.context.here"),
      notationError = "[error]",
    },
  }

  -- Assign colors
  local color = {
    suggestionWindow = {
      -- Takes color as string
      suggestions = {
        deselected = "#A8A8A8",
        selected = "#FCFC00",
      },
      -- Takes color as vector
      background = vectors.hexToRGB("#000000"),
      divider = vectors.hexToRGB("#ffffff"),
    },
    chat = {
      -- Takes color as string
      suggestion = "#ffffff", -- Unused
    },
    info = {
      -- Takes color as string
      text = "#ffffff", -- Unused
      -- Takes color as vector
      background = vectors.hexToRGB("#000000"),
    },
    transparent = vec(0, 0, 0, 0),
  }

  -- Create textures
  local texture = {
    suggestionWindow = {
      background = textures:newTexture("_FOX_CL-t-sb", 1, 1)
          :setPixel(0, 0, color.suggestionWindow.background),
      divider = textures:newTexture("_FOX_CL-t-sd", 2, 1)
          :setPixel(0, 0, color.suggestionWindow.divider)
          :setPixel(1, 0, color.transparent),
    },
    info = {
      background = textures:newTexture("_FOX_CL-t-ib", 1, 1)
          :setPixel(0, 0, color.info.background),
    },
  }

  -- Create elements
  local gui = {
    suggestionWindow = {
      ---@type table<integer, TextTask>
      suggestions = {},
      background = guiPivot.front:newSprite("_FOX_CL-s-sb")
          :setTexture(texture.suggestionWindow.background),
      divider = {
        lower = guiPivot.front:newSprite("_FOX_CL-s-sdl")
            :setTexture(texture.suggestionWindow.divider, 2, 1),
        upper = guiPivot.front:newSprite("_FOX_CL-s-sdu")
            :setTexture(texture.suggestionWindow.divider, 2, 1),
      },
    },
    chat = {
      suggestion = guiPivot.back:newText("_FOX_CL-x-cs"):setShadow(true),
    },
    info = {
      text = guiPivot.front:newText("_FOX_CL-x-it"):setShadow(true),
      background = guiPivot.front:newSprite("_FOX_CL-s-ib")
          :setTexture(texture.info.background)
          :setSize(client.getScaledWindowSize().x, 12),
    },
  }

  -- Rendering of the GUI is at the bottom. Rendering should always happen after the command suggestion flow

  --============================================================--
  -- Command Handler
  --============================================================--

  -- Handle sending custom chat commands
  function events.chat_send_message(msg)
    if msg:sub(#prefix, #prefix) == prefix then
      local run = commandTable
      local args = {}

      -- Find arguments
      for value in string.gmatch(msg:sub(#prefix + 1, #msg), "[^%s]*") do
        if type(run) == "table" and run[value] then
          run = run[value]
        else
          -- Return the correct type argument
          table.insert(args, tonumber(value) or value)
        end
      end

      -- Find _args
      local argsMeta
      if type(run) == "table" and run._args then
        argsMeta = run._args
      end
      local pack = (argsMeta and argsMeta._packed) and argsMeta._packed or false

      local status, res

      -- Find function
      if type(run) == "table" then
        run = run["_func"] or run[1]
      end

      -- Run the command function
      if type(run) == "function" then
        -- Run with arguments packed or unpacked
        if pack then
          status, res = table.pack(pcall(run, args))
        else
          status, res = table.pack(pcall(run, table.unpack(args)))
        end
      end

      -- Print error to chat
      if status ~= nil then
        if not status then
          printJson(toJson(
            {
              { text = lang.errors.executionError .. "\n" .. lang.errors.notationError, color = "red" },
              { text = " " .. player:getName() .. " ",                                  color = "white" },
              { text = ": " .. res .. "\n",                                             color = "red" },
            }
          ))
        end
      else
        -- Unknown or incomplete command
        printJson(toJson(
          {
            { text = lang.errors.unknownCommand .. "\n",                       color = "red" },
            { text = host:getChatText():sub(#prefix + 1, #host:getChatText()), underlined = true },
            { text = lang.errors.notationHere,                                 underlined = false, italic = true },
          }
        ))
      end

      -- The command did send, add it to the chat history
      host:appendChatHistory(msg)
      -- Don't send command to chat
      return nil
    end
    return msg
  end

  --============================================================--
  -- Command Interpretation
  --============================================================--

  ---Return entries sorted in alphabetical order
  ---@param list? table
  function table.sortAlphabetically(list)
    local entries = {}
    -- Build a table of strings
    for key in pairs(list) do
      table.insert(entries, tostring(key))
    end

    -- Sort the table
    table.sort(entries)
    return entries
  end

  local suggestionsOffset = 0
  local logicalSuggestionOffset = 0
  local logicalSuggestionOffsetTop = 0
  local highlighted = 0
  local lastChatText
  local lastSuggestionsPath
  local lastSuggestionsCount = 0

  local rawPath

  -- Evaluate command suggestions based on what's typed into chat
  function events.render()
    -- Run this only when the chat changes
    if host:getChatText() ~= lastChatText then
      lastChatText = host:getChatText()
      -- Set the chat color
      host:setChatColor(vectors.hexToRGB((host:isChatOpen() and host:getChatText():match("^[" .. prefix .. "]")) and
        "Gray" or "White"))
      -- Run this only with the prefix
      if host:isChatOpen() and host:getChatText():match("^[" .. prefix .. "]") then
        -- Clear the last command suggestions
        for _, line in pairs(gui.suggestionWindow.suggestions) do
          line:remove()
        end
        gui.suggestionWindow.suggestions = {}

        -- Return the literal string for lua patterns
        function literal(str)
          return str:gsub(".", function(char)
            -- If special character then add %
            if char:match("[%p%c%s]") then
              return "%" .. char
            else
              return char
            end
          end)
        end

        -- Split the chat text at each space
        local path = {}
        for str in string.gmatch(lastChatText:sub(#prefix + 1, #lastChatText), "[^%s]*") do
          rawPath = str
          str = literal(str) -- Replace everything in path with literals
          table.insert(path, str)
        end
        if path[#path] == "" then -- If the last entry is blank then set it to nil
          path[#path] = nil
        end

        -- Suggest subcommands
        local suggestionsPath = ""
        local commandSuggestions = commandTable
        for _, value in pairs(path) do
          -- If the command has subcommands
          if commandSuggestions[value] then
            suggestionsPath = suggestionsPath .. " " .. value
            if type(commandSuggestions[value]) == "table" then
              commandSuggestions = commandSuggestions[value]
            else
              commandSuggestions = {}
            end
          elseif not commandSuggestions[path[#path]] and lastChatText:sub(#lastChatText, #lastChatText) == " " then
            commandSuggestions = {}
          end
        end
        gui.info.text:setText(commandSuggestions._info or nil)

        -- Detect if suggestions path has changed
        if lastSuggestionsPath ~= suggestionsPath then
          lastSuggestionsPath = suggestionsPath
          -- Reset the highlighted suggestion and remove all texttasks
          highlighted = 0
        end

        -- Append new command suggestions based on what's typed into chat
        ---@param value string
        for _, value in pairs(table.sortAlphabetically(commandSuggestions)) do
          if not (value:match("^_") or tonumber(value)) then
            if string.match(value, "^" .. (lastChatText:sub(#lastChatText, #lastChatText):match("%s") and "" or (path[#path] or ""):gsub("%-", "%%-"))) then
              table.insert(gui.suggestionWindow.suggestions,
                guiPivot.front:newText("_FOX_CL-x-ss" .. #gui.suggestionWindow.suggestions)
                :setShadow(true)
                :setText(
                  '{"text":"' ..
                  value .. '","color":"' .. color.suggestionWindow.suggestions.deselected .. '"}'))
            end
          end
        end

        -- Detect if list of suggestions displayed is less than before
        if #gui.suggestionWindow.suggestions < lastSuggestionsCount then
          -- Reset the highlighted suggestion
          highlighted = 0
        end
        lastSuggestionsCount = #gui.suggestionWindow.suggestions

        -- Reset the offset
        if highlighted == 0 then
          suggestionsOffset = #gui.suggestionWindow.suggestions -
              math.min(suggestionsLimit, #gui.suggestionWindow.suggestions)
          logicalSuggestionOffsetTop = suggestionsOffset
        elseif highlighted + 1 == #gui.suggestionWindow.suggestions then
          suggestionsOffset = 0
        end

        logicalSuggestionOffset = logicalSuggestionOffsetTop - suggestionsOffset

        -- Highlight currently selected command
        gui.chat.suggestion:setText(
          #gui.suggestionWindow.suggestions ~= 0 and
          gui.suggestionWindow.suggestions[highlighted + 1] and       -- If there are any command suggestions
          gui.suggestionWindow.suggestions[highlighted + 1]:getText() -- Get the texttask text
          :gsub('{"text":"', ""):gsub('","color":"#......"}', "")     -- Strip the json from the returned text
          :gsub("^" .. (path[#path] or ""), "")                       -- Gsub from the beginning of the command at the end of the path
          or "")
      end
    end
    if (not host:isChatOpen() or host:getChatText() == "") and #gui.suggestionWindow.suggestions ~= 0 then
      -- If there are any suggestions displayed but the chat is closed then remove suggestions
      for _, line in pairs(gui.suggestionWindow.suggestions) do
        line:remove()
      end
      gui.suggestionWindow.suggestions = {}
      gui.chat.suggestion:setText("")
      lastSuggestionsPath = nil
    end
    if host:getChatText() == "" and gui.info.text:getText() ~= nil then
      gui.info.text:setText(nil)
    end
  end

  --============================================================--
  -- Keypress Handler
  --============================================================--

  local function scroll(delta)
    if (host:getChatText() or ""):sub(#prefix, #prefix) == prefix then
      highlighted = (highlighted - delta) % #gui.suggestionWindow.suggestions
      lastChatText = nil
    end
  end

  local function getHovered()
    local mousePos = -(client.getMousePos() / client.getWindowSize()) * client.getScaledWindowSize()
    local corner1 = gui.suggestionWindow.background:getPos().xy
    local corner2 = gui.suggestionWindow.background:getPos().xy -
        gui.suggestionWindow.background:getSize()
    if corner1 > mousePos and mousePos > corner2 then
      local hovered = math.ceil(-(-((corner2.y + 1 - mousePos.y) / 12) - math.min(suggestionsLimit, #gui.suggestionWindow.suggestions)) +
        logicalSuggestionOffset - 1)
      if gui.suggestionWindow.suggestions[hovered + 1] and gui.suggestionWindow.suggestions[hovered + 1]:isVisible() then -- Make sure suggestion is actually visible
        return hovered
      end
    end
  end

  function events.mouse_move()
    highlighted = getHovered() or highlighted
    lastChatText = nil
  end

  function events.mouse_scroll(delta)
    if getHovered() ~= nil then
      if suggestionsOffset + delta < logicalSuggestionOffsetTop + 1 and suggestionsOffset + delta > -1 then
        suggestionsOffset = suggestionsOffset + delta
        lastChatText = nil
      end
    end
  end

  function events.key_press(key, action)
    -- Tab
    if action == 1 and key == 258 then
      if gui.suggestionWindow.suggestions[highlighted + 1] then
        host:setChatText(host:getChatText() ..
          gui.chat.suggestion:getText():gsub('{"text":"', ""):gsub('","color":"#......"}', ""))
      end
    end
    -- Up arrow
    if action ~= 0 and key == 265 then
      scroll(1)
      if highlighted - logicalSuggestionOffset + 1 < 1 then
        suggestionsOffset = suggestionsOffset + 1
      end
    end
    -- Down arrow
    if action ~= 0 and key == 264 then
      scroll(-1)
      if highlighted - logicalSuggestionOffset + 1 > suggestionsLimit then
        suggestionsOffset = suggestionsOffset - 1
      end
    end
  end

  function events.mouse_press(button, action)
    -- Left mouse button
    if action == 1 and button == 0 then
      if getHovered() ~= nil then
        host:setChatText(host:getChatText() ..
          gui.chat.suggestion:getText():gsub('{"text":"', ""):gsub('","color":"#......"}', ""))
      end
    end
  end

  -- Cancel pressing the up or down arrows when typing a command
  keybinds:newKeybind("Up Arrow", "key.keyboard.up", true):setOnPress(function()
    return #gui.suggestionWindow.suggestions ~= 0
  end)
  keybinds:newKeybind("Down Arrow", "key.keyboard.down", true):setOnPress(function()
    return #gui.suggestionWindow.suggestions ~= 0
  end)

  -- Cancel clicking or scrolling when hovering over command suggestions
  keybinds:newKeybind("Left Mouse Button", "key.mouse.left", true):setOnPress(function()
    return #gui.suggestionWindow.suggestions ~= 0 and getHovered() ~= nil
  end)

  --============================================================--
  -- GUI Render
  --============================================================--

  function events.render()
    -- Set the visibility of everything
    local suggestionVisibility = host:isChatOpen() and #gui.suggestionWindow.suggestions ~= 0
    local infoVisibility = host:isChatOpen() and gui.info.text:getText() ~= nil

    gui.suggestionWindow.background:setVisible(suggestionVisibility and
      suggestionsLimit > 0)
    gui.suggestionWindow.divider.lower:setVisible(suggestionVisibility and
      suggestionsOffset ~= 0 and
      suggestionsLimit > 0)
    gui.suggestionWindow.divider.upper:setVisible(suggestionVisibility and
      suggestionsOffset ~= logicalSuggestionOffsetTop and
      suggestionsLimit > 0)
    gui.chat.suggestion:setVisible(suggestionVisibility)
    gui.info.background:setVisible(infoVisibility)
    gui.info.text:setVisible(infoVisibility)

    -- Set the position and scale of everything
    if host:isChatOpen() then
      -- Find position of chat caret
      local chatCaretPos = client.getTextWidth(host:getChatText() and
        host:getChatText():gsub("%s", "..") or "")

      -- Find width of longest chat suggestion
      local maxWidth = 0
      for _, value in pairs(gui.suggestionWindow.suggestions) do
        maxWidth = math.max(maxWidth, client.getTextWidth(value:getText()) + 1)
      end

      --==========--

      -- Command suggestion window background
      gui.suggestionWindow.background:setSize(maxWidth,
        math.min((12 * #gui.suggestionWindow.suggestions), (12 * suggestionsLimit)) + 2) -- Scale to fit with the maximum width of all command suggestions

      -- Find the suggestion window size
      local suggestWindowSize = gui.suggestionWindow.background:getSize()

      gui.suggestionWindow.background:setPos(
        -chatCaretPos - 3 + client.getTextWidth(rawPath or ""),
        -client.getScaledWindowSize().y + suggestWindowSize.y +
        14 + (gui.info.background:isVisible() and 13 or 0)
      )

      -- Find the suggestion window position
      local suggestWindowPos = gui.suggestionWindow.background:getPos()

      -- Command suggestion window text
      for i, line in pairs(gui.suggestionWindow.suggestions) do
        -- Every command suggestion texttask in the suggestion window
        line:setPos(
          suggestWindowPos.x - 1,
          suggestWindowPos.y - suggestWindowSize.y + 11 +
          ((#gui.suggestionWindow.suggestions - i - suggestionsOffset) * 12))
            :setText(line:getText():gsub("#......",
              (i == highlighted + 1 and color.suggestionWindow.suggestions.selected or color.suggestionWindow.suggestions.deselected))) -- Set text and color of command suggestions
            :setVisible(i < (suggestionsLimit + 1) + logicalSuggestionOffset and
              i > logicalSuggestionOffset)
      end

      -- Command suggestion window dividers
      gui.suggestionWindow.divider.lower:setSize(maxWidth, 1):setRegion(maxWidth, 1)
          :setPos(suggestWindowPos + vec(
            0,
            -suggestWindowSize.y + 1,
            -1 -- Layer above command suggestion window
          ))
      gui.suggestionWindow.divider.upper:setSize(maxWidth, 1):setRegion(maxWidth, 1)
          :setPos(suggestWindowPos + vec(
            0,
            0,
            -1 -- Layer above command suggestion window
          ))

      --==========--

      -- Command suggestion in chat
      gui.chat.suggestion:setPos(
        -chatCaretPos - 4,
        -client.getScaledWindowSize().y + 12
      )

      --==========--

      -- Command info bar
      gui.info.background:setPos(
        0,
        -client.getScaledWindowSize().y + 27,
        1                   -- Layer below command suggestion window
      )
      gui.info.text:setPos( -- Text anchored to background
        gui.info.background:getPos() + vec(0, -2, 0)
      )
    end
  end
end

return commands
