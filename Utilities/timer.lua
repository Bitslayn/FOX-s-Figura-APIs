--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Timer Utility v1.1.0
--]]

local t, timers, map = 0, {}, {}

function events.tick()
  t = t + 1
  for timer, queues in pairs(timers) do
    if timer <= t then
      for func, tbl in pairs(queues) do
        func()

        local newTimer = t + tbl.interval

        tbl.count = tbl.count - 1
        if tbl.count == 0 then
          tbl = nil
        end

        timers[newTimer] = timers[newTimer] or {}
        timers[newTimer][func] = tbl
        map[func] = newTimer
      end
      timers[timer] = nil
    end
  end
end

local timer = {}

---Creates a new timer
---
---If this function is run again for a function that already has a timer, resets that function's timer using the new interval and count
---@param interval number Interval to run the function in ticks
---@param func function The function to run
---@param count number? How many times to run the function before removing it. Defaults to -1 which makes the timer never get removed
function timer.new(interval, func, count)
  if not func then return end
  if map[func] then
    timers[map[func]] = nil
  end

  local newTimer = t + interval
  timers[newTimer] = timers[newTimer] or {}
  timers[newTimer][func] = { interval = interval, count = count or -1 }

  map[func] = newTimer
end

---Remove a timer by passing the timer's function
function timer.remove(func)
  if not map[func] then return end
  timers[map[func]][func] = nil
  map[func] = nil
end

return timer