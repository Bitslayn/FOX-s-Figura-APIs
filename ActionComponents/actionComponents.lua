--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Action Components v1.0.0-dev

Features:
  Adds components which let you interact with the action wheel tooltip, currently only ""
  Adds a footer which displays below action wheel titles
  Adds labels which display in the action wheel below the icon
  Adds back functionality which lets you go back a page by pressing backspace
  Adds the ability to set an action's type
  Adds methods for getting an action's texture and item
  Adds "phantom toggling" letting you toggle an action without triggering its functions

Disclaimer:
  This library will not work if you don't have a system for loading scripts
  in priority. Using require will not suffice. Not following this will result
  in an error when using the action wheel.

  This library works best if you don't use paper doll and have action wheel
  tooltips enabled. This is not a requirement.

  It is recommended that you store this library in your data folder and load
  it using the FileAPI. This is not a requirement.

--]]

-- Label config (Yes you can change these values)

-- Set this to the scale you set in Figura Settings > Action Wheel > Action Wheel Size
local wheelSize = 1.0
-- Set this to the scale you wish labels to appear as
local textScale = 0.5
-- Set this to true if you wish for labels to be outlined
local textOutline = true
-- This is how far away from the center of the action wheel labels will be positioned
local dist = 41

-- Set this to true if you want labels to be displayed outside the action wheel instead of below action icons
local moveLabelsOutside = false
-- If the labels are moved outside, this distance will be used instead
local outsideDist = 70





-- IMPORTANT

-- This is not a script. Do not add any code, change any code, or remove any code from this library or I will boop you really hard.
-- If you genuinely know what you are doing then you may proceed.





---@diagnostic disable: redundant-parameter, missing-return, unused-local

--#REGION ˚♡ Important Variables ♡˚

local _ActionWheelAPI = figuraMetatables.ActionWheelAPI
local _ActionWheelAPI_index = _ActionWheelAPI.__index
local _Page = figuraMetatables.Page
local _Page_index = _Page.__index
local _Action = figuraMetatables.Action
local _Action_index = _Action.__index
local _Action_newindex = _Action.__newindex

local componentActions = {}
local actionMeta = {}

--#ENDREGION
--#REGION ˚♡ Define ActionWheelAPI Functions ♡˚

local runToggledFunc

local function clickAction(meta, action)
  if meta.isToggle and not meta.component.type then
    _Action_index(action, "toggled")(action, not _Action_index(action, "isToggled")(action))
  end
  local componentActionFunc = meta.component.functions.leftClick
  if componentActionFunc then componentActionFunc(meta) end
  local actionFunc = meta.leftClick
  if actionFunc then actionFunc(meta.action) end
  if runToggledFunc and not meta.component.type then
    runToggledFunc(meta)
  end
end

function events.key_press(button, state)
  if state ~= 1 then return end
  if not action_wheel:isEnabled() then return end
  if button >= 49 and button <= 56 then
    local action = action_wheel:getCurrentPage():getAction(button - 48)
    if not action then return end
    local meta = actionMeta[action]
    clickAction(meta, action)
    return true
  end
end

---@alias (partial) Action.toggleFunc fun(state?: boolean, self?: Action, selection?: number|nil)
function events.mouse_press(button, state)
  if state ~= 1 then return end
  if not action_wheel:isEnabled() then return end
  local action = action_wheel:getSelectedAction()
  if not action then return end
  local meta = actionMeta[action]
  if button == 0 then
    clickAction(meta, action)
  elseif button == 1 then
    local componentActionFunc = meta.component.functions.rightClick
    if componentActionFunc then componentActionFunc(meta) end
    local actionFunc = actionMeta[action].rightClick
    if actionFunc then actionFunc(meta.action) end
  end
  return true
end

---@alias (partial) Action.scrollFunc fun(dir?: number, self?: Action, selection?: number|nil)
function events.mouse_scroll(dir)
  if not action_wheel:isEnabled() then return end
  local action = action_wheel:getSelectedAction()
  if not action then return end
  local meta = actionMeta[action]
  local componentActionFunc = meta.component.functions.scroll
  if componentActionFunc then componentActionFunc(meta, dir) end
  local actionFunc = actionMeta[action].scroll
  if actionFunc then actionFunc(dir, meta.action, meta.component.hovered or nil) end
  return true
end

function events.key_press(key, state)
  if not action_wheel:isEnabled() then return end
  if key ~= 259 or state ~= 1 then return end -- Backspace
  action_wheel:back()
end

--#ENDREGION
--#REGION ˚♡ Helper functions ♡˚

local divider = "§r\n\n"

local function concatenate(action)
  local meta = actionMeta[action]
  if not (meta.title or meta.component.string or meta.footer) then return end
  meta.concat = string.format("%s%s%s%s%s",
    (meta.title or ""), ((meta.title and meta.component.string) and divider or ""),
    (meta.component.string and "%c" or ((meta.title and meta.footer) and divider or "")),
    ((meta.component.string and meta.footer) and divider or ""), (meta.footer or ""))
end

local function reloadTitle(action)
  local meta = actionMeta[action]
  if meta.concat then
    _Action_index(action, "setTitle")(action, meta.concat:gsub("%%c", meta.component.string or ""))
  elseif meta.component.string then
    _Action_index(action, "setTitle")(action, meta.component.string)
  end
end

local concatQueue, titleQueue = {}, {}
function events.post_render()
  for action in pairs(concatQueue) do
    concatenate(action)
    concatQueue[action] = nil
  end
  for action in pairs(titleQueue) do
    reloadTitle(action)
    titleQueue[action] = nil
  end
end

local allFuncs = { "onScroll", "onToggle" }
local emptyFunc = function() end

local function setType(meta)
  for _, method in pairs(allFuncs) do _Action_index(meta.action, method)(meta.action, nil) end
  meta.isToggle = false
  if meta.type and not meta.toggle then
    local lower = meta.type:lower()
    if meta.action[lower] then
      _Action_index(meta.action,
        "on" .. lower:gsub("^%l", string.upper))(meta.action, emptyFunc)
      if lower == "toggle" then
        meta.isToggle = true
      end
    end
  else
    -- The scroll icon takes highest priority, the toggle icon second highest, then regular icon.
    if meta.scroll then
      _Action_index(meta.action, "onScroll")(meta.action, emptyFunc)
    elseif meta.toggle or meta.untoggle then
      _Action_index(meta.action, "onToggle")(meta.action, emptyFunc)
      meta.isToggle = true
    end
  end
end

function runToggledFunc(meta, state, selection)
  if state == nil then
    state = meta.action:isToggled(selection)
  end
  local toggleFunc = meta[meta.untoggle and (state and "toggle" or "untoggle") or "toggle"]
  if toggleFunc then
    toggleFunc(state, meta.action, selection or meta.component.hovered)
  end
end

local function setToggled(meta, state, selection, skipFunctions)
  local compMeta = meta.component
  if state == nil then
    state = not meta.action:isToggled()
  end
  if compMeta.selected and compMeta.maxSelections ~= 0 then
    selection = selection or compMeta.hovered
    if state then
      -- Select this option
      compMeta.selected[selection] = true
      if compMeta.maxSelections == 0 then return end
      table.insert(compMeta.history, selection)
      local selectionCount = #compMeta.history
      if selectionCount > compMeta.maxSelections and compMeta.maxSelections > -1 then
        local removed = table.remove(compMeta.history, 1)
        compMeta.selected[removed] = nil
        if not skipFunctions then
          runToggledFunc(meta, false, removed)
        end
      end
    else
      -- Deselect this option
      local selectionCount = #compMeta.history
      if selectionCount <= compMeta.minSelections then return end
      compMeta.selected[selection] = nil
      for key, value in pairs(compMeta.history) do
        if value == selection then
          table.remove(compMeta.history, key)
        end
      end
    end
  end
  if componentActions[compMeta.type] then
    componentActions[compMeta.type].buildComponent(meta)
  end
  _Action_index(meta.action, "toggled")(meta.action, state)
  if not skipFunctions then
    runToggledFunc(meta, state, selection)
  end
end

local function initializeAction(action)
  local meta = { component = { functions = {} }, action = action }
  actionMeta[action] = meta
end

local function minmax(component)
  component.min, component.max = math.huge, -math.huge
  for i in pairs(component.value) do
    if type(i) == "number" then
      component.min = math.min(component.min, i)
      component.max = math.max(component.max, i)
    end
  end
end

local function getAngles(n)
  local angles, index = {}, 1
  local left = math.floor(n / 2)
  local right = n - left

  for i = 1, right do
    angles[index] = (180 / right) * (i - 0.5)
    index = index + 1
  end

  for i = 1, left do
    angles[index] = 180 + (180 / left) * (i - 0.5)
    index = index + 1
  end

  return angles
end

local centerPart = models:newPart("_actionWheelCenter", "Gui"):setLight(15)
---@type ModelPart[]
local labelModelparts = {}
local labelTextTasks = {}

---@param actions? Action[]
local function createLabels(actions)
  -- Recenter pivot modelpart
  local x1, y1 = client.getScaledWindowSize():div(2, 2):unpack()
  centerPart:setPos(-x1, -y1, 0)
  -- Remove previous labels
  for _, texttask in pairs(labelTextTasks) do texttask:remove() end
  for _, modelpart in pairs(labelModelparts) do modelpart:remove() end
  -- Create new labels
  if not actions then return end
  local count = #actions
  local angles = getAngles(count)
  for i = 1, count do
    local label = actionMeta[actions[i]].label
    if label then
      local iString = tostring(i)
      local x2, _, y2 = vectors.angleToDir(0, angles[i]):unpack()
      local tex, _, _, _, _, sca = actions[i]:getTexture()
      labelModelparts[i] = centerPart
          :newPart("_actionWheel-label-" .. iString)
          :setPos(math.round(x2 * (moveLabelsOutside and outsideDist or dist) * wheelSize),
            math.round((y2 * (moveLabelsOutside and outsideDist or dist) - (((tex or actions[i]:getItem()) and not moveLabelsOutside) and
              2 + 8 * (sca or 1) or -(client.getTextDimensions(label, 80, true).y / 2 * textScale)
            )) * wheelSize))
      labelTextTasks[i] = labelModelparts[i]
          :newText(string.format("_actionWheel-label-%s-texttask", iString))
          :alignment(moveLabelsOutside and (angles[i] < 180 and "LEFT" or "RIGHT") or "CENTER")
          :setText(label)
          :setWidth(not moveLabelsOutside and 80 or nil)
          :setScale(textScale * wheelSize)
          :setOutline(textOutline)
    end
  end
end

local currentPage, currentGroup
local function checkPageChange()
  local page = action_wheel:getCurrentPage()
  local group = page:getSlotsShift()
  local actions = page:getActions(group)
  if currentPage ~= page or currentGroup ~= group then
    createLabels(actions)
    currentPage = page
    currentGroup = group
  end
end

local wasActionWheelOpen
local function actionToggle()
  local isActionWheelOpen = action_wheel:isEnabled()
  if wasActionWheelOpen == isActionWheelOpen then return end
  wasActionWheelOpen = isActionWheelOpen
  if isActionWheelOpen then
    local page = action_wheel:getCurrentPage()
    if not page then return end
    local group = page:getSlotsShift()
    local actions = page:getActions(group)
    createLabels(actions)
    events.tick:register(checkPageChange)
  else
    createLabels()
    events.tick:remove(checkPageChange)
  end
end

local isToggle
local tick = 0
local function checkActionToggle()
  tick = tick + 1
  if tick < 2 then return end
  isToggle = action_wheel:isEnabled()
  events.tick:register(actionToggle)
  events.tick:remove(checkActionToggle)
end

keybinds:fromVanilla("figura.config.action_wheel_button")
    :setOnPress(function()
      if isToggle then return end
      local page = action_wheel:getCurrentPage()
      if not page then return end
      local group = page:getSlotsShift()
      local actions = page:getActions(group)
      createLabels(actions)
      events.tick:register(checkPageChange)
    end)
    :setOnRelease(function()
      if isToggle then return end
      events.tick:register(checkActionToggle)
      createLabels()
      events.tick:remove(checkPageChange)
    end)

local function findFormatting(pattern)
  pattern = pattern:match("(.-)%%s")
  local result = ""
  if not pattern then return result end
  for formatting in string.gmatch(pattern, "§%w") do
    result = result .. formatting
  end
  return result
end


--#ENDREGION
--#REGION ˚♡ Components ♡˚

--#REGION ˚♡ Selection Component ♡˚

componentActions.selection = {}
componentActions.horizontal_selection = componentActions.selection
componentActions.vertical_selection = componentActions.selection

function componentActions.selection.buildComponent(meta)
  ---@type SelectionComponent
  local compMeta = meta.component

  local maxRows = math.clamp(compMeta.maxRows, compMeta.buffer * 2 + 1,
    math.abs(compMeta.max - compMeta.min) + 1)
  if compMeta.hovered < compMeta.scroll + compMeta.buffer then
    compMeta.scroll = compMeta.hovered - compMeta.buffer
  elseif compMeta.hovered > compMeta.scroll + maxRows - 1 - compMeta.buffer then
    compMeta.scroll = compMeta.hovered - maxRows + 1 + compMeta.buffer
  end
  compMeta.scroll = math.clamp(compMeta.scroll, compMeta.min, compMeta.max - maxRows + 1)

  if compMeta.min == math.huge or compMeta.max == -math.huge then
    compMeta.string = "§c  Error: Could not index table!\n  Reason: Table is empty"
  else
    compMeta.string = ""
    for i = compMeta.scroll, compMeta.scroll + maxRows - 1 do
      local isHovered = compMeta.hovered == i
      local isSelected = compMeta.selected and compMeta.selected[i]
      local isOverflow = (i == compMeta.scroll and compMeta.scroll ~= compMeta.min) or
          (i == compMeta.scroll + maxRows - 1 and compMeta.scroll + maxRows - 1 ~= compMeta.max)

      local formatIndex = isOverflow and 5 or (isHovered and 2 or 1) + (isSelected and 2 or 0)
      local stringValue = tostring(compMeta.value[i])
      compMeta.string = compMeta.string .. (compMeta.horizontal and "§r" or "\n§r") ..
          compMeta.formatting[formatIndex]:format(stringValue):gsub("\n", "\n§r" ..
            compMeta.formatting[6] .. findFormatting(compMeta.formatting[formatIndex])
          )
    end
    if not compMeta.horizontal then
      compMeta.string = compMeta.string:match("\n(.*)")
    end
  end
end

---@class Action.Component.Selection
local SelectionMethods = {}

function componentActions.selection.initializeComponent(_type)
  ---@class SelectionComponent
  local component = {
    type = "selection",
    value = {},
    min = math.huge,
    max = -math.huge,
    scroll = 1,
    hovered = 1,
    maxRows = 8,
    buffer = 1,
    loopAround = false,
    horizontal = _type:lower():find("horizontal"),
    minSelections = 0,
    maxSelections = 3,
    formatting = {
      "§7  %s  ", -- Normal
      "§f► %s  ", -- Highlighted
      "§7  §l%s  ", -- Toggled
      "§f► §l%s  ", -- Highlighted and toggled
      "§8  ···  ", -- More
      "  ", -- Blank (Newline)
    },
    history = {},
    selected = {},
  }

  component.functions = {
    scroll = function(meta, dir)
      dir = dir > 0 and 1 or -1
      if component.loopAround then
        component.hovered = (component.hovered - dir - component.min) %
            (component.max - component.min + 1) + component.min
      else
        component.hovered = math.clamp(component.hovered - dir, component.min, component.max)
      end
      if component.maxSelections ~= 0 then
        _Action_index(meta.action, "toggled")(meta.action, component.selected[component.hovered])
      end
      componentActions[component.type].buildComponent(meta)
      titleQueue[meta.action] = true
    end,
    leftClick = function(meta)
      if component.maxSelections ~= 0 then
        setToggled(meta, not component.selected[component.hovered], component.hovered)
      else
        runToggledFunc(meta)
      end
      componentActions[component.type].buildComponent(meta)
      titleQueue[meta.action] = true
    end,
  }

  return setmetatable(SelectionMethods, component)
end

local selectionSetFunc = {
  table = function(component, tbl)
    component.value = tbl
    minmax(component)
  end,
  hovered = function(component, pos) component.hovered = pos end,
  minSelections = function(component, number) component.minSelections = number end,
  maxSelections = function(component, number) component.maxSelections = number end,
  maxRows = function(component, number) component.maxRows = number end,
  buffer = function(component, number) component.buffer = number end,
  loops = function(component, boolean) component.loopAround = boolean end,
  orientation = function(component, orientation) component.horizontal = orientation == "horizontal" end,
  normalFormatting = function(component, string) component.formatting[1] = string or "§7  %s  " end,
  highlightedFormatting = function(component, string) component.formatting[2] = string or "§f► %s  " end,
  toggledFormatting = function(component, string) component.formatting[3] = string or "§7  §l%s  " end,
  highlightedToggledFormatting = function(component, string)
    component.formatting[4] = string or "§f► §l%s  "
  end,
  moreFormatting = function(component, string) component.formatting[5] = string or "§8  ···  " end,
  newlineFormatting = function(component, string) component.formatting[6] = string or "  " end,
}

local selectionGetFunc = {
  table = function(component) return component.value end,
  hovered = function(component) return component.hovered end,
  minSelections = function(component) return component.minSelections end,
  maxSelections = function(component) return component.maxSelections end,
  maxRows = function(component) return component.maxRows end,
  buffer = function(component) return component.buffer end,
  loops = function(component) return component.loopAround end,
  orientation = function(component) return component.horizontal and "horizontal" or "vertical" end,
  normalFormatting = function(component) return component.formatting[1] end,
  highlightedFormatting = function(component) return component.formatting[2] end,
  toggledFormatting = function(component) return component.formatting[3] end,
  highlightedToggledFormatting = function(component) return component.formatting[4] end,
  moreFormatting = function(component) return component.formatting[5] end,
  newlineFormatting = function(component) return component.formatting[6] end,
}

local selectionGenericFunc = {
  refresh = function(component) minmax(component) end,
}

for key, func in pairs(selectionSetFunc) do
  local newFunc = function(self, ...)
    func(getmetatable(self), ...)
    return self
  end
  SelectionMethods[key] = newFunc
  SelectionMethods["set" .. key:gsub("^%l", string.upper)] = newFunc
end

for key, func in pairs(selectionGetFunc) do
  local newFunc = function(self, ...) return func(getmetatable(self), ...) end
  SelectionMethods["get" .. key:gsub("^%l", string.upper)] = newFunc
end

for key, func in pairs(selectionGenericFunc) do
  local newFunc = function(self)
    func(getmetatable(self))
    return self
  end
  SelectionMethods[key] = newFunc
end

--#ENDREGION

--#ENDREGION
--#REGION ˚♡ Overwrite ActionWheelAPI Methods ♡˚

local pageHistory, historyIndex = {}, 0

local ActionWheelAPI = {
  setPage = function(self, page) -- Just builds the page history
    historyIndex = historyIndex + 1
    pageHistory[historyIndex] = page
    return _ActionWheelAPI_index(action_wheel, "setPage")(self, page)
  end,
  back = function(self)
    if historyIndex <= 1 then return self end
    local page = pageHistory[historyIndex - 1]
    pageHistory[historyIndex] = nil
    historyIndex = historyIndex - 1
    return _ActionWheelAPI_index(action_wheel, "setPage")(self, page)
  end,
}

local apiNewFunc = {
  component = function(_, type)
    local componentFunctions = componentActions[type:lower()]
    assert(componentFunctions, "Could not create component with type " .. type)
    local component = componentFunctions.initializeComponent(type)
    return component
  end,
}

for key, func in pairs(apiNewFunc) do
  local newFunc = function(self, ...)
    return func(self, ...)
  end
  ActionWheelAPI[key] = newFunc
  ActionWheelAPI["new" .. key:gsub("^%l", string.upper)] = newFunc
end

--#ENDREGION
--#REGION ˚♡ Overwrite Page Methods ♡˚

---@class Page
local Page = {}

---@param index? integer
function Page:newAction(index)
  local page = self
  ---@type Action
  local action = _Page_index(page, "newAction")(page, index)
  initializeAction(action)
  return action
end

--#ENDREGION
--#REGION ˚♡ Overwrite Action Methods ♡˚

local Action = {
  leftClick = function(self, func)
    actionMeta[self].leftClick = func
    setType(actionMeta[self])
  end,
  rightClick = function(self, func)
    actionMeta[self].rightClick = func
    setType(actionMeta[self])
  end,
  scroll = function(self, func)
    actionMeta[self].scroll = func
    setType(actionMeta[self])
  end,
  toggle = function(self, func)
    actionMeta[self].toggle = func
    setType(actionMeta[self])
  end,
  untoggle = function(self, func)
    actionMeta[self].untoggle = func
    setType(actionMeta[self])
  end,
  isToggled = function(self, index)
    local meta = actionMeta[self]
    return meta.component.selected and meta.component.selected[index] or
        _Action_index(meta.action, "isToggled")(meta.action)
  end,
  refresh = function(self)
    concatenate(self)
    reloadTitle(self)
  end,
}

local setFunc = {
  item = function(meta, item)
    meta.item = item
    _Action_index(meta.action, "item")(meta.action, item)
  end,
  texture = function(meta, ...)
    local args = { ... }
    meta.texture = args
    _Action_index(meta.action, "texture")(meta.action, table.unpack(args))
  end,
  type = function(meta, type)
    meta.type = type
    setType(meta)
  end,
  label = function(meta, label) meta.label = label end,
  title = function(meta, title) meta.title = title end,
  component = function(meta, component)
    component = getmetatable(component)
    meta.component = component
    if component.type == "selection" then
      meta.type = "TOGGLE"
      setType(meta)
    end
    componentActions[component.type].buildComponent(meta)
  end,
  footer = function(meta, footer) meta.footer = footer end,
  onLeftClick = function(meta, func)
    meta.leftClick = func
    setType(meta)
  end,
  onRightClick = function(meta, func)
    meta.rightClick = func
    setType(meta)
  end,
  onScroll = function(meta, func)
    meta.scroll = func
    setType(meta)
  end,
  onToggle = function(meta, func)
    meta.toggle = func
    setType(meta)
  end,
  onUntoggle = function(meta, func)
    meta.untoggle = func
    setType(meta)
  end,
  toggled = function(meta, state, selection, skipFunctions)
    setToggled(meta, state, selection, skipFunctions)
  end,
}

local getFunc = {
  item = function(meta) return meta.item end,
  texture = function(meta)
    if not meta.texture then return end
    return table.unpack(meta.texture)
  end,
  type = function(meta) return meta.type end,
  label = function(meta) return meta.label end,
  title = function(meta) return meta.title end,
  footer = function(meta) return meta.footer end,
  toggled = function(meta) return meta.component.selected end,
}

local _, fileName = ...
for key, func in pairs(setFunc) do
  local newFunc = function(self, ...)
    local meta = actionMeta[self]
    assert( -- Do not comment out this line, if you don't error here, you WILL error later.
      meta,
      string.format("§4Failed to initialize an action! Is %s.lua running first?§c",
        fileName or "actionComponents"))
    func(meta, ...)
    concatQueue[self] = true
    titleQueue[self] = true
    return self
  end
  Action[key] = newFunc
  Action["set" .. key:gsub("^%l", string.upper)] = newFunc
end

for key, func in pairs(getFunc) do
  local newFunc = function(self, ...)
    local meta = actionMeta[self]
    return func(meta, ...)
  end
  Action["get" .. key:gsub("^%l", string.upper)] = newFunc
end

--#ENDREGION
--#REGION ˚♡ Proxy Custom Methods ♡˚

function _ActionWheelAPI:__index(key) return ActionWheelAPI[key] or _ActionWheelAPI_index(self, key) end

function _Page:__index(key) return Page[key] or _Page_index(self, key) end

function _Action:__index(key) return Action[key] or _Action_index(self, key) end

function _Action:__newindex(key, value)
  if Action[key] then
    Action[key](self, value)
  else
    _Action_newindex(self, key, value)
  end
end

--#ENDREGION
--#REGION ˚♡ Annotations ♡˚

if false then -- Make sure none of this code actually runs but it's sent to the LLS
  ---@class ActionWheelAPI
  ActionWheelAPI = ActionWheelAPI

  ---Returns you back to the previous page in the `setPage` history.
  ---@generic self
  ---@param self self
  ---@return self
  function ActionWheelAPI:back() end

  ---@alias Action.types
  ---| "NORMAL"
  ---| "SCROLL"
  ---| "TOGGLE"
  ---@class Action
  Action = Action

  ---Gets the item used in the icon of this action.
  ---
  ---Returns `nil` if the item has not been set or has been reset.
  ---@return string?
  function Action:getItem() end

  ---Gets the texture used in the icon of this action.
  ---
  ---Returns `nil` if the item has not been set or has been reset.
  ---@return Texture? texture
  ---@return number? u
  ---@return number? v
  ---@return integer? width
  ---@return integer? height
  ---@return number? scale
  function Action:getTexture() end

  --#REGION ˚♡ Label ♡˚

  ---Sets the label that appears below the action texture or item.
  ---
  ---If `label` is `nil`, it will default to `""`.
  ---@param label string
  ---@return Action
  function Action:label(label) end

  ---Sets the label that appears below the action texture or item.
  ---
  ---If `label` is `nil`, it will default to `""`.
  ---@param label string
  ---@return Action
  function Action:setLabel(label) end

  ---Gets the label that appears below the action texture or item.
  ---
  ---Returns `nil` if the label has not been set or has been reset.
  ---@return string?
  ---@nodiscard
  function Action:getLabel() end

  --#ENDREGION
  --#REGION ˚♡ Footer ♡˚

  ---Sets the footer that appears below the action title and component when it is hovered over.
  ---
  ---If `footer` is `nil`, it will default to `""`.
  ---@param footer string
  ---@return Action
  function Action:footer(footer) end

  ---Sets the footer that appears below the action title and component when it is hovered over.
  ---
  ---If `footer` is `nil`, it will default to `""`.
  ---@param footer string
  ---@return Action
  function Action:setFooter(footer) end

  ---Gets the footer that appears below the action title and component when it is hovered over.
  ---
  ---Returns `nil` if the footer has not been set or has been reset.
  ---@return string?
  ---@nodiscard
  function Action:getFooter() end

  --#ENDREGION
  --#REGION ˚♡ Component ♡˚

  ---Sets the component that appears between the title and footer when this action is hovered over.
  ---
  ---Only one component can be created at a time.
  ---
  ---If either the type or value are `nil`, the component will be removed.
  ---@param component Action.Component.Selection
  ---@return Action
  function Action:component(component) end

  ---Sets the component that appears between the title and footer when this action is hovered over.
  ---
  ---Only one component can be created at a time.
  ---
  ---If either the type or value are `nil`, the component will be removed.
  ---@param component Action.Component.Selection
  ---@return Action
  function Action:setComponent(component) end

  ---Gets the component that appears between the title and footer when this action is hovered over.
  ---
  ---Returns `nil` if the component has not been set or has been reset.
  ---@return string? type
  ---@nodiscard
  function Action:getComponent() end

  ---@alias Action.Component.Selection.Types
  ---| "SELECTION" # Displays a number-indexed table's values with each value being selectable. Displays each entry vertically.
  ---| "HORIZONTAL_SELECTION" # Displays a number-indexed table's values with each value being selectable. Displays each entry horizontally.
  ---| "VERTICAL_SELECTION" # Alias for SELECTION. Displays a number-indexed table's values with each value being selectable. Displays each entry vertically.

  ---@param type Action.Component.Selection.Types
  ---@return Action.Component.Selection
  ---@nodiscard
  function ActionWheelAPI:newComponent(type) end

  --#ENDREGION
  --#REGION ˚♡ Selection Component ♡˚

  ---Sets this selection component's table to show in the action wheel.
  ---@param tbl table
  ---@return Action.Component.Selection
  function SelectionMethods:table(tbl) end

  ---Sets this selection component's table to show in the action wheel.
  ---@param tbl table
  ---@return Action.Component.Selection
  function SelectionMethods:setTable(tbl) end

  ---Gets the selection component's table.
  ---@return table
  ---@nodiscard
  function SelectionMethods:getTable() end

  ---Sets the hovered position in the table.
  ---
  ---Defaults to `1`
  ---@param pos number
  ---@return Action.Component.Selection
  function SelectionMethods:hovered(pos) end

  ---Sets the hovered position in the table.
  ---
  ---Defaults to `1`
  ---@param pos number
  ---@return Action.Component.Selection
  function SelectionMethods:setHovered(pos) end

  ---Gets the hovered position in the table.
  ---@return number
  ---@nodiscard
  function SelectionMethods:getHovered() end

  ---Sets this selection component's minimum selection count, preventing less than this number of options from being toggled.
  ---
  ---Defaults to `0`
  ---@param min number
  ---@return Action.Component.Selection
  function SelectionMethods:minSelections(min) end

  ---Sets this selection component's minimum selection count, preventing less than this number of options from being toggled.
  ---
  ---Defaults to `0`
  ---@param min number
  ---@return Action.Component.Selection
  function SelectionMethods:setMinSelections(min) end

  ---Gets the selection component's minimum selection count.
  ---@return number
  ---@nodiscard
  function SelectionMethods:getMinSelections() end

  ---Sets this selection component's maximum selection count, preventing more than this number of options from being toggled.
  ---
  ---If this is a **negative number**, the maximum selections is infinite. If this is `0` then no selections can be toggled.
  ---
  ---Defaults to `3`
  ---@param max number
  ---@return Action.Component.Selection
  function SelectionMethods:maxSelections(max) end

  ---Sets this selection component's maximum selection count, preventing more than this number of options from being toggled.
  ---
  ---If this is a **negative number**, the maximum selections is infinite. If this is `0` then no selections can be toggled.
  ---
  ---Defaults to `3`
  ---@param max number
  ---@return Action.Component.Selection
  function SelectionMethods:setMaxSelections(max) end

  ---Gets the selection component's maximum selection count.
  ---@return number
  ---@nodiscard
  function SelectionMethods:getMaxSelections() end

  ---Sets the maximum number of rows that can be displayed of the table.
  ---
  ---Defaults to `8`
  ---@param rows number
  ---@return Action.Component.Selection
  function SelectionMethods:maxRows(rows) end

  ---Sets the maximum number of rows that can be displayed of the table.
  ---
  ---Defaults to `8`
  ---@param rows number
  ---@return Action.Component.Selection
  function SelectionMethods:setMaxRows(rows) end

  ---Gets the maximum number of rows that can be displayed of the table.
  ---@return number
  ---@nodiscard
  function SelectionMethods:getMaxRows() end

  ---Sets the number of rows to scroll ahead when scrolling.
  ---
  ---Defaults to `1`
  ---@param buffer number
  ---@return Action.Component.Selection
  function SelectionMethods:buffer(buffer) end

  ---Sets the number of rows to scroll ahead when scrolling.
  ---
  ---Defaults to `1`
  ---@param buffer number
  ---@return Action.Component.Selection
  function SelectionMethods:setBuffer(buffer) end

  ---Gets the number of rows to scroll ahead when scrolling.
  ---@return number
  ---@nodiscard
  function SelectionMethods:getBuffer() end

  ---Sets whether scrolling past the top or bottom of the table loops around.
  ---
  ---Defaults to `false`
  ---@param loops boolean
  ---@return Action.Component.Selection
  function SelectionMethods:loops(loops) end

  ---Sets whether scrolling past the top or bottom of the table loops around.
  ---
  ---Defaults to `false`
  ---@param loops boolean
  ---@return Action.Component.Selection
  function SelectionMethods:setLoops(loops) end

  ---Gets whether scrolling past the top or bottom of the table loops around.
  ---@return boolean
  ---@nodiscard
  function SelectionMethods:getLoops() end

  ---Sets the orientation to display the component table.
  ---
  ---Defaults to `"vertical"`
  ---@param orientation "horizontal"|"vertical"
  ---@return Action.Component.Selection
  function SelectionMethods:orientation(orientation) end

  ---Sets the orientation to display the component table.
  ---
  ---Defaults to `"vertical"`
  ---@param orientation "horizontal"|"vertical"
  ---@return Action.Component.Selection
  function SelectionMethods:setOrientation(orientation) end

  ---Gets the orientation this component table is displayed in.
  ---@return "horizontal"|"vertical"
  ---@nodiscard
  function SelectionMethods:getOrientation() end

  ---Sets the formatting when a table entry is not highlighted or toggled.
  ---
  ---Defaults to `"§7  %s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:normalFormatting(formatting) end

  ---Sets the formatting when a table entry is not highlighted or toggled.
  ---
  ---Defaults to `"§7  %s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:setNormalFormatting(formatting) end

  ---Gets the formatting when a table entry is not highlighted or toggled.
  ---@return string
  ---@nodiscard
  function SelectionMethods:getNormalFormatting() end

  ---Sets the formatting when a table entry is highlighted but not toggled.
  ---
  ---Defaults to `"§f► %s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:highlightedFormatting(formatting) end

  ---Sets the formatting when a table entry is highlighted but not toggled.
  ---
  ---Defaults to `"§f► %s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:setHighlightedFormatting(formatting) end

  ---Gets the formatting when a table entry is highlighted but not toggled.
  ---@return string
  ---@nodiscard
  function SelectionMethods:getHighlightedFormatting() end

  ---Sets the formatting when a table entry is toggled but not highlighted.
  ---
  ---Defaults to `"§7  §l%s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:toggledFormatting(formatting) end

  ---Sets the formatting when a table entry is toggled but not highlighted.
  ---
  ---Defaults to `"§7  §l%s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:setToggledFormatting(formatting) end

  ---Gets the formatting when a table entry is toggled but not highlighted.
  ---@return string
  ---@nodiscard
  function SelectionMethods:getToggledFormatting() end

  ---Sets the formatting when a table entry is both highlighted and toggled.
  ---
  ---Defaults to `"§f► §l%s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:highlightedToggledFormatting(formatting) end

  ---Sets the formatting when a table entry is both highlighted and toggled.
  ---
  ---Defaults to `"§f► §l%s  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:setHighlightedToggledFormatting(formatting) end

  ---Gets the formatting when a table entry is both highlighted and toggled.
  ---@return string
  ---@nodiscard
  function SelectionMethods:getHighlightedToggledFormatting() end

  ---Sets the formatting for when there are more table entries.
  ---
  ---Defaults to `"§8  ···  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:moreFormatting(formatting) end

  ---Sets the formatting for when there are more table entries.
  ---
  ---Defaults to `"§8  ···  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:setMoreFormatting(formatting) end

  ---Gets the formatting for when there are more table entries.
  ---@return string
  ---@nodiscard
  function SelectionMethods:getMoreFormatting() end

  ---Sets the formatting for when a value has a new line.
  ---
  ---Defaults to `"  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:newLineFormatting(formatting) end

  ---Sets the formatting for when a value has a new line.
  ---
  ---Defaults to `"  "`
  ---@param formatting string
  ---@return Action.Component.Selection
  function SelectionMethods:setNewLineFormatting(formatting) end

  ---Gets the formatting for when a value has a new line.
  ---@return string
  ---@nodiscard
  function SelectionMethods:getNewLineFormatting() end

  ---Forces this component to re-index the table. Use this if you plan on adding or removing table entries without running `table` or `setTable`.
  ---@return Action.Component.Selection
  function SelectionMethods:refresh() end

  --#ENDREGION
  --#REGION ˚♡ Type ♡˚

  ---Sets what icon to show next to this action. The icon is the 3x3 symbol inside the action wheel.
  ---Setting the type to `"TOGGLE"` will make this action toggleable.
  ---
  ---If this is set to `nil` then the type is chosen based on this action's functions.
  ---@param type? Action.types
  ---@return Action
  function Action:type(type) end

  ---Sets what icon to show next to this action. The icon is the 3x3 symbol inside the action wheel.
  ---Setting the type to `"TOGGLE"` will make this action toggleable.
  ---
  ---If this is set to `nil` then the type is chosen based on this action's functions.
  ---@param type? Action.types
  ---@return Action
  function Action:setType(type) end

  ---Gets the action type that was set with `:setType()`.
  ---
  ---Returns `nil` if the type has not been set or has been reset.
  ---@return Action.types?
  ---@nodiscard
  function Action:getType() end

  --#ENDREGION
  --#REGION ˚♡ Toggled ♡˚

  ---Sets the toggle state of this action.
  ---
  ---If `state` is `nil`, it will default to `false`.
  ---If an index is provided, will set the toggle state of that selection.
  ---If `skipFunctions` is true, any `onToggle` or `onUntoggle` defined will not be called.
  ---@param state? boolean
  ---@param selection? number
  ---@param skipFunctions? boolean
  ---@return Action
  function Action:toggled(state, selection, skipFunctions) end

  ---Sets the toggle state of this action.
  ---
  ---If `state` is `nil`, it will default to `false`.
  ---If an index is provided, will set the toggle state of that selection.
  ---If `skipFunctions` is true, any `onToggle` or `onUntoggle` defined will not be called.
  ---@param state? boolean
  ---@param selection? number
  ---@param skipFunctions? boolean
  ---@return Action
  function Action:setToggled(state, selection, skipFunctions) end

  ---Gets the table of toggled selections by index.
  ---@return table?
  ---@nodiscard
  function Action:getToggled() end

  ---Gets if this action is toggled on.
  ---
  ---If an index is provided, will check if that selection is toggled.
  ---@param index? number
  ---@return boolean?
  ---@nodiscard
  function Action:isToggled(index) end

  --#ENDREGION
  --#REGION ˚♡ Refresh ♡˚

  ---Forces this action to refresh its title, footer, and component.
  ---
  ---Useful when you're changing these or the component formatting. Not useful for when you change a component's value.
  function Action:refresh() end

  --#ENDREGION
end

--#ENDREGION
