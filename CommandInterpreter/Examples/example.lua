local function playFoxScreech()
  sounds:playSound("minecraft:entity.fox.screech", player:getPos())
end

-- Arguments can be passed through commands and read by the function. Arguments that are passed are in the form of a table
local function this(args)
  print(string.format("%s comes before %s", args[1], args[2]))
end

local function changePrefix(args)
  if args[1] then
    -- Changes the command prefix. Takes an optional boolean which, when true, saves the prefix to a config
    commands:setPrefix(args[1])
    print("Command prefix was set to " .. commands:getPrefix())
  else
    print("Command prefix cannot be made nil!")
  end
end

local function resetPrefix()
  commands:setPrefix()
  print("Prefix reset to " .. commands:getPrefix())
end

local function getPrefix()
  print("The current prefix is " .. commands:getPrefix())
end

local function never(args)
  print(args)
end

commands:command("fox", { sound = playFoxScreech })         -- Functions passed into a command get ran
commands:command("this-command-has-a-really-long-name", {}) -- You can pass empty tables into it and it won't error
commands:command("prefix", { __call = changePrefix, reset = resetPrefix, ["return"] = getPrefix })
commands:command("this", this)
commands:command("never", {
  __call = never, -- Even if a command has subcommands, setting "__call" will allow the command to run as a function
  gonna = {
    give = { you = { up = never } },
    let = { you = { down = never } },
    run = { around = { ["and"] = { desert = { you = never } } } },
    make = { you = { cry = never } },
    say = { goodbye = never },
    tell = { a = { lie = { ["and"] = { hurt = { you = never } } } } },
  },
})
