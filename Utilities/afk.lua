--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's AFK Nameplate v1.0.3

Requires FOX's Custom Placeholders: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/placeholders.lua
--]]
--#REGION ˚♡ Vars ♡˚

--[[
HEY! Everything with a ---@ or -- in front, or inside is an annotation, not actual code. DO NOT MODIFY ANNOTATIONS
If you want to modify configs in-file, meaning not by requiring this script, you can do so inside the
config table if you scroll below. Please ask for help if you don't know what you are doing
]]

--[[Time placeholder cheatsheet

Seconds
	0 - 59 : ${s}
	00 - 59 : ${ss}
	0 - inf : ${S}
	00 - inf : ${SS}

Minutes
	0 - 59 : ${m}
	00 - 59 : ${mm}
	0 - inf : ${M}
	00 - inf : ${MM}

Hours
	0 - 23 : ${h}
	00 - 23 : ${hh}
	0 - inf : ${H}
	00 - inf : ${HH}
]]

---@class FOXAFK2
---@field isAFK boolean
---@field isForcedAFK boolean
---@field AFKTime integer
---@field config FOXAFK2.configs
local afk = {
	---@class FOXAFK2.configs
	---@field timeUntilAFK integer
	---@field active string
	---@field short string
	---@field long string
	---@field altActive string
	---@field alt string
	config = {
		-- Amount of time in seconds the player must idle for in order to go AFK
		timeUntilAFK = 300,

		-- Recommended to use these with tab list and entity nameplates, and are applied with ${afk}
		-- Short is applied when AFK for less than an hour, long is applied for longer AFK times

		-- ${afk} text to display when the player ISN'T AFK
		active = "",
		-- ${afk} text to display when the player has been AFK for less than an hour
		short = " [AFK ${m}:${ss}]",
		-- ${afk} text to display when the player has been AFK for over an hour
		long = " [AFK ${H}:${mm}:${ss}]",

		-- Recommended for use with chat nameplate. Applied with ${afk_alt}

		-- ${afk_alt} text to display when the player ISN'T AFK
		altActive = "",
		-- ${afk_alt} text to display when the player is AFK
		alt = " [AFK]",
	},

	-- If the user is AFK. They're AFK if `afk.AFKTime` is greater than `afk.config.timeUntilAFK`
	isAFK = false,
	-- If the player is forced AFK. They can only be forced AFK by running `pings.afk()`
	isForcedAFK = false,
	-- The amount of seconds the player has been idle for
	AFKTime = 0,
}

local cfg = afk.config
local lastAction = client.getSystemTime()
local forceAFK = false

--#ENDREGION
--#REGION ˚♡ Nameplate placeholder ♡˚

-- All the functions required to format and update the placeholder

local clamps = { s = 60, m = 60, h = 24 }

---@param string string
---@param timings table
---@return string, integer
local function timeFormat(string, timings)
	---@param s string
	return string:gsub("%${(%w+)}", function(s)
		local modulo = s:byte() > 96
		local key = s:sub(1, 1):lower()

		local timing = timings[key]
		if not timing then return end
		local clamp = clamps[key]

		if modulo then timing = timing % clamp end

		return ("%0" .. #s .. "d"):format(timing)
	end)
end

---@type FOXPlaceholders
local placeholders = require("./placeholders")
local function updatePlaceholder()
	local ms = client.getSystemTime() - lastAction
	local s = math.floor(ms / 1000)
	local m = math.floor(s / 60)
	local h = math.floor(m / 60)

	local timings = { s = s, m = m, h = h }

	afk.isAFK = s >= afk.config.timeUntilAFK or forceAFK
	afk.isForcedAFK = forceAFK
	afk.AFKTime = s

	placeholders.afk = timeFormat(afk.isAFK and cfg[h < 1 and "short" or "long"] --[[@as string]] or cfg.active, timings)
	placeholders.afk_alt = timeFormat(afk.isAFK and cfg.alt or cfg.altActive, timings)
end

--#ENDREGION
--#REGION ˚♡ Ping handler ♡˚

-- Ping function and repings

local function afkFunc(time, forced)
	if not (time or forced) then
		forceAFK = true
		return
	end

	lastAction = time and client.getSystemTime() - time or lastAction
	forceAFK = forced
end

---Sets the AFK time in ms, and allows you to force AFK
---
---If no arguments are passed, the timer will not change and the player will be forced into AFK. This is the same as passing nil for the time and true for forced.
---
---If just the time is provided, if the player is forced into AFK, they will no longer be force AFKed
---
---Run `pings.afk(0)` to reset the AFK timer and disable forcing AFK
---@param time number?
---@param forced boolean?
function pings.afk(time, forced)
	afkFunc(time, forced)
end

if host:isHost() then
	local repingTimer = 1
	function events.tick()
		repingTimer = repingTimer % 800 + 1 -- Reping every 40 seconds
		if repingTimer > 1 then return end
		if forceAFK then
			pings.afk(client.getSystemTime() - lastAction, true)
		else
			pings.afk(client.getSystemTime() - lastAction)
		end
	end
end

--#ENDREGION
--#REGION ˚♡ AFK checker ♡˚

-- Checks if the player is idle

---Function to run to get out of AFK when an action is made
local function action()
	if afk.isAFK then
		if host:isHost() then
			pings.afk(0)
		else
			afkFunc(0)
		end
	else
		lastAction = client.getSystemTime()
	end
end

-- Check movement actions

function events.entity_init()
	function events.key_press()
		if host:isChatOpen() or host:getScreen() or action_wheel:isEnabled() then return end
		if player:getVelocity():lengthSquared() < 0.01 then return end
		action()
	end
end

-- Check camera turn actions

local lastTilt
local function checkAction()
	local tilt = player:getRot().x
	if lastTilt == tilt then return end

	lastTilt = tilt
	action()
end

--#ENDREGION
--#REGION ˚♡ AFK ticker ♡˚

-- Main function to run other functions while the player is unloaded. Runs every 1/4 seconds

local lastTick
local function run()
	pcall(function()
		local thisTick = math.floor(world.getTime() / 5)
		if lastTick == thisTick then return end
		lastTick = thisTick

		if player:isLoaded() then checkAction() end
		updatePlaceholder()

		if not host:isHost() then return end
		if not (client.isWindowFocused() or afk.isAFK) then
			pings.afk()
		end
	end)
end

models:newPart("afk", "Portrait").midRender = run
events.tick = run
events.on_play_sound = run
events.skull_render = run

--#ENDREGION

return afk
