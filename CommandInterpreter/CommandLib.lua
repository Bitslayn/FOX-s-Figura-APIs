--[[
 ___  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Command Interpreter v0.9.1

A command interpreter with command suggestions just like Vanilla

--]]

--============================================================--
-- Lib Functions
--============================================================--

-- local config = config:setName("commandlib")
local commandTable = {}
local prefix = config:load("prefix") or "."

---@meta _
---@class CommandLib
local CommandLib = {}

commands = CommandLib

---Create a new command or update an existing command
---@param cmd string|table
---@param val? table|function
function CommandLib:command(cmd, val)
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
function CommandLib:getCommand(cmd)
  return cmd and commandTable[cmd] or commandTable
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

---Return entries sorted in alphabetical order
---@param list? table
function table.sortAlphabetically(list)
  local entries = {}
  -- Build a table of strings
  for key in pairs(list) do
    table.insert(entries, key)
  end

  -- Sort the table
  table.sort(entries)
  return entries
end

--============================================================--
-- Setup
--============================================================--

if host:isHost() then
  local guiPivot = models:newPart("_hud", "Hud"):setPos(0, 0, -3 * 100)

  -- Create the gui sprites
  local texture = {
    background = textures:newTexture("_background", 195, 122),
    divider = textures:newTexture("_divider", 2, 1),
  }

  -- Texture the gui sprites
  local size = texture.background:getDimensions()
  texture.background:fill(0, 0, size.x, size.y, vectors.hexToRGB("#00000040"))
  texture.divider:setPixel(0, 0, vectors.hexToRGB("#ffffff"))

  -- Create the gui elements
  local gui = {
    suggestedCommand = guiPivot:newText("_suggested"):setShadow(true),
    ---@type table<integer, TextTask>
    suggestions = {},
    suggestionsBackground = {
      background = guiPivot:newSprite("_background")
          :setTexture(texture.background):setRenderType("TRANSLUCENT"),
      dividers = {
        lower = guiPivot:newSprite("_lowerDivider"),
        upper = guiPivot:newSprite("_upperDivider"),
      },
    },
  }

  --============================================================--
  -- Command Interpretation
  --============================================================--

  -- Handle sending custom chat commands
  function events.chat_send_message(msg)
    if msg:sub(#prefix, #prefix) == prefix then
      -- Run the command function
      local run = commandTable
      local args = {}
      for value in string.gmatch(msg:sub(#prefix + 1, #msg), "([^" .. "%s" .. "]+)") do
        if type(run) == "table" and run[value] then
          run = run[value]
        else
          table.insert(args, value)
        end
      end
      if type(run) == "function" then
        pcall(args == {} and run or run(args))
      end
      if type(run) == "table" and run["__call"] then
        pcall(args == {} and run["__call"] or run["__call"](args))
      end

      -- The command did send, add it to the chat history
      host:appendChatHistory(msg)
      -- Don't send command to chat
      return nil
    end
    return msg
  end

  local highlighted = 0
  local lastChatText

  -- Evaluate command suggestions based on what's typed into chat
  function events.render()
    -- Run this only when the chat changes
    if host:getChatText() ~= lastChatText then
      lastChatText = host:getChatText()
      -- Run this only with the prefix
      if host:isChatOpen() and host:getChatText():match("^[" .. prefix .. "]") then
        -- Clear the last command suggestions
        for _, line in pairs(gui.suggestions) do
          line:remove()
        end
        gui.suggestions = {}

        -- Split the chat text at each space
        local path = {}
        for str in string.gmatch(lastChatText:sub(#prefix + 1, #lastChatText), "([^" .. "%s" .. "]+)") do
          table.insert(path, str)
        end

        -- Suggest subcommands
        local commandSuggestions = commandTable
        for _, value in pairs(path) do
          -- If the command has subcommands
          if commandSuggestions[value] then
            if type(commandSuggestions[value]) == "table" then
              if lastChatText:sub(#lastChatText, #lastChatText):match("%s") then
                commandSuggestions = commandSuggestions[value]
              end
            else
              commandSuggestions = {}
            end
          end
        end

        -- Append new command suggestions
        ---@param value string
        for _, value in pairs(table.sortAlphabetically(commandSuggestions)) do
          if value ~= "__call" then
            if string.match(value, "^" .. (lastChatText:sub(#lastChatText, #lastChatText):match("%s") and "" or (path[#path] or ""):gsub("%-", "%%-"))) then
              table.insert(gui.suggestions,
                guiPivot:newText("_suggestion" .. #gui.suggestions):setShadow(true):setText(value))
            end
          end
        end

        -- Highlight currently selected command
        gui.suggestedCommand:setText(#gui.suggestions ~= 0 and
          gui.suggestions[(highlighted or 0) + 1] and
          gui.suggestions[(highlighted or 0) + 1]:getText():gsub("§.", ""):gsub(
            (path[#path] or ""):gsub("%-", "%%-"), "") or "")
      elseif #gui.suggestions ~= 0 then
        -- If there are any suggestions displayed but the chat is closed then remove suggestions
        for _, line in pairs(gui.suggestions) do
          line:remove()
        end
        gui.suggestions = {}
        gui.suggestedCommand:setText("")
      end
    end
  end

  --============================================================--
  -- Handle Keypresses
  --============================================================--

  local function scroll(s)
    if (host:getChatText() or ""):sub(#prefix, #prefix) == prefix then
      highlighted = ((highlighted or 0) + s) % #gui.suggestions
      lastChatText = nil
    end
  end

  function events.key_press(key, action)
    -- Prefix button
    if action == 1 and key == string.byte(prefix) and not host:isChatOpen() then
      highlighted = 0
    end
    -- Tab
    if action == 1 and key == 258 then
      if gui.suggestions[(highlighted or 0) + 1] then
        host:setChatText(host:getChatText() .. gui.suggestedCommand:getText())
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
    return #gui.suggestions ~= 0
  end)
  keybinds:newKeybind("Down Arrow", "key.keyboard.down", true):setOnPress(function()
    return #gui.suggestions ~= 0
  end)

  --============================================================--
  -- GUI Render
  --============================================================--

  function events.render()
    if (highlighted or 0) + 1 > #gui.suggestions or highlighted == nil then
      highlighted = 0
    end
    -- Dynamically position all gui elements
    for i, line in pairs(gui.suggestions) do
      line:setPos(
        -client.getTextWidth(host:getChatText() and host:getChatText():gsub("%s", "..") or "") - 4,
        -client.getScaledWindowSize().y + client.getTextHeight(line:getText()) + 16 +
        ((i - 1) * 12)
      ):setText((i == (highlighted or 0) + 1 and "§e" or "§7") .. line:getText())
    end
    local width = 0
    for _, value in pairs(gui.suggestions) do
      width = math.max(width, client.getTextWidth(value:getText()) + 1)
    end
    gui.suggestionsBackground.background:setSize(width, (12 * #gui.suggestions) + 2) -- Scale based on suggestion lines
        :setPos(
          -client.getTextWidth(host:getChatText() and host:getChatText():gsub("%s", "..") or "") - 3,
          -client.getScaledWindowSize().y + gui.suggestionsBackground.background:getSize().y + 14
        )
    gui.suggestedCommand:setPos(
      -client.getTextWidth(host:getChatText() and host:getChatText():gsub("%s", "..") or "") - 4,
      -client.getScaledWindowSize().y + 12
    )

    -- Set the visibility of all gui elements
    gui.suggestionsBackground.background:setVisible(host:isChatOpen() and #gui.suggestions ~= 0)
    gui.suggestedCommand:setVisible(host:isChatOpen() and host:getChatText() ~= "")
  end
end
