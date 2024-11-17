--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Command Interpreter v0.9.4

A command interpreter with command suggestions just like Vanilla

Features
  Custom commands with a configurable prefix
  Command suggestions shown through an actual GUI
  Pressing arrow keys and tab to autocomplete

--]]

--============================================================--
-- Lib Functions
--============================================================--

local commandTable = {}
local prefix = config:load("prefix") or "."

---@meta _
---@class CommandLib
local CommandLib = {}

commands = CommandLib

---Create a new command or update an existing command
---@param cmd string|table
---@param val? table|function
function CommandLib:commandTable(cmd, val)
  if type(cmd) == "string" then
    commandTable[cmd] = val or {}
  else
    commandTable = cmd
  end
end

---Return the table or function of a command
---@param cmd? string
---@return table|function
---@nodiscard
function CommandLib:getCommandTable(cmd)
  return cmd and commandTable[cmd] or commandTable
end

---Removes a command
---@param cmd string
function CommandLib:removeCommandTable(cmd)
  commandTable[cmd] = nil
end

---Change the command prefix<br>Defaults to `.`
---@param pfx? string # The prefix to set
---@param persist? boolean # Should the prefix be persistent? (Save to config)
function CommandLib:setPrefix(pfx, persist)
  prefix = pfx or "."
  if persist then
    config:save("prefix", prefix)
  end
end

---Return the command prefix
---@nodiscard
function CommandLib:getPrefix()
  return prefix
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

      -- Run the command function
      if type(run) == "function" then
        -- Run function
        pcall(next(args) == nil and run or run(args))
      elseif type(run) == "table" then
        -- Run function in _func or [1] of table
        if run["_func"] then
          pcall(next(args) == nil and run["_func"] or run["_func"](args))
        elseif run[1] then
          pcall(next(args) == nil and run[1] or run[1](args))
        end
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

  local suggestionsLimit = 10
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
        gui.info.text:setText(commandSuggestions._desc or nil)

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

    gui.suggestionWindow.background:setVisible(suggestionVisibility)
    gui.suggestionWindow.divider.lower:setVisible(suggestionVisibility and suggestionsOffset ~= 0)
    gui.suggestionWindow.divider.upper:setVisible(suggestionVisibility and
      suggestionsOffset ~= logicalSuggestionOffsetTop)
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
        -client.getScaledWindowSize().y + suggestWindowSize.y + 14
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
