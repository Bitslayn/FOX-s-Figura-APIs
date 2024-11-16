--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Command Interpreter v0.9.3

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
  }

  -- Create textures
  local texture = {
    suggestionWindow = {
      background = textures:newTexture("_FOX_CL-t-sb", 1, 1)
          :setPixel(0, 0, color.suggestionWindow.background),
      divider = textures:newTexture("_FOX_CL-t-sd", 2, 1)
          :setPixel(0, 0, color.suggestionWindow.divider),
    },
    info = {
      background = textures:newTexture("_FOX_CL-t-ib", 1, 1),
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
            :setTexture(texture.suggestionWindow.divider),
        upper = guiPivot.front:newSprite("_FOX_CL-s-sdu")
            :setTexture(texture.suggestionWindow.divider),
      },
    },
    chat = {
      suggestion = guiPivot.back:newText("_FOX_CL-x-cs"):setShadow(true),
    },
    info = {
      text = guiPivot.back:newText("_FOX_CL-x-it"):setShadow(true),
      background = guiPivot.back:newSprite("_FOX_CL-s-ib")
          :setTexture(texture.info.background),
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
        -- Run function in __call or [1] of table
        if run["__call"] then
          pcall(next(args) == nil and run["__call"] or run["__call"](args))
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

  local highlighted = 0
  local lastChatText
  local lastSuggestionsPath

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

        -- Detect if suggestions path has changed
        if lastSuggestionsPath ~= suggestionsPath then
          lastSuggestionsPath = suggestionsPath
          -- Reset the highlighted suggestion
          highlighted = 0
        end

        -- Append new command suggestions based on what's typed into chat
        ---@param value string
        for _, value in pairs(table.sortAlphabetically(commandSuggestions)) do
          if not (value:match("^__") or tonumber(value)) then
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


        -- Highlight currently selected command
        gui.chat.suggestion:setText(
          #gui.suggestionWindow.suggestions ~= 0 and
          gui.suggestionWindow.suggestions[highlighted + 1] and       -- If there are any command suggestions
          gui.suggestionWindow.suggestions[highlighted + 1]:getText() -- Get the texttask text
          :gsub('{"text":"', ""):gsub('","color":"#......"}', "")     -- Strip the json from the returned text
          :gsub("^" .. (path[#path] or ""), "")                       -- Gsub from the beginning of the command at the end of the path
          or "")
      elseif #gui.suggestionWindow.suggestions ~= 0 then
        -- If there are any suggestions displayed but the chat is closed then remove suggestions
        for _, line in pairs(gui.suggestionWindow.suggestions) do
          line:remove()
        end
        gui.suggestionWindow.suggestions = {}
        gui.chat.suggestion:setText("")
        lastSuggestionsPath = nil
      end
    end
  end

  --============================================================--
  -- Keypress Handler
  --============================================================--

  local function scroll(s)
    if (host:getChatText() or ""):sub(#prefix, #prefix) == prefix then
      highlighted = (highlighted - s) % #gui.suggestionWindow.suggestions
      lastChatText = nil
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
    end
    -- Down arrow
    if action ~= 0 and key == 264 then
      scroll(-1)
    end
  end

  -- Cancel pressing the up or down arrows when typing a command
  keybinds:newKeybind("Up Arrow", "key.keyboard.up", true):setOnPress(function()
    return #gui.suggestionWindow.suggestions ~= 0
  end)
  keybinds:newKeybind("Down Arrow", "key.keyboard.down", true):setOnPress(function()
    return #gui.suggestionWindow.suggestions ~= 0
  end)

  --============================================================--
  -- GUI Render
  --============================================================--

  function events.render()
    -- Dynamically position all gui elements
    for i, line in pairs(gui.suggestionWindow.suggestions) do
      line:setPos(
        -client.getTextWidth(host:getChatText() and host:getChatText():gsub("%s", "..") or "") - 4,
        -client.getScaledWindowSize().y + client.getTextHeight(line:getText()) + 16 +
        ((#gui.suggestionWindow.suggestions - i) * 12)
      ):setText(line:getText():gsub("#......",
        (i == highlighted + 1 and color.suggestionWindow.suggestions.selected or color.suggestionWindow.suggestions.deselected))) -- Set text and color of command suggestions
    end
    local width = 0
    for _, value in pairs(gui.suggestionWindow.suggestions) do
      width = math.max(width, client.getTextWidth(value:getText()) + 1)
    end
    gui.suggestionWindow.background:setSize(width, (12 * #gui.suggestionWindow.suggestions) + 2) -- Scale based on suggestion lines
        :setPos(
          -client.getTextWidth(host:getChatText() and host:getChatText():gsub("%s", "..") or "") - 3,
          -client.getScaledWindowSize().y + gui.suggestionWindow.background:getSize().y + 14
        )
    gui.chat.suggestion:setPos(
      -client.getTextWidth(host:getChatText() and host:getChatText():gsub("%s", "..") or "") - 4,
      -client.getScaledWindowSize().y + 12
    )

    local visibility = host:isChatOpen() and #gui.suggestionWindow.suggestions ~= 0

    -- Set the visibility of all gui elements
    gui.suggestionWindow.background:setVisible(visibility)
    gui.chat.suggestion:setVisible(visibility)
  end
end

return commands
