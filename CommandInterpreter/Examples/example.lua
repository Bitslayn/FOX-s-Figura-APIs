if host:isHost() then -- It is recommended to register commands in a host:isHost(), though it's not required
  -- Make sure CommandLib runs before attempting to register commands
  require("myLibraries.CommandLib")

  -- THIS EXAMPLE SCRIPT IS AN EXAMPLE, DO NOT USE OR BAD THINGS WILL HAPPEN LOL
  -- (It overwrites all commands later in the script)

  -- Prefix functions
  local setPrefix = function(prfx, bool)
    commands:setPrefix(prfx, bool)
    printJson(string.format("Prefix changed to %s\n", prfx or "."))
  end

  local getPrefix = function()
    printJson(string.format("Current prefix is %s\n", commands:getPrefix()))
  end

  -- Prefix commands

  -- .prefix (Returns the current prefix if no subcommand is called)
  local prefixCommand = commands:createCommand("prefix")
      :setInfo("Set the prefix used to run commands"):setFunction(getPrefix)
  -- .prefix set <pfx> <bool>
  prefixCommand:createCommand("set"):setFunction(setPrefix)
  -- .prefix get
  prefixCommand:createCommand("get"):setFunction(getPrefix)

  -- Print commands

  local printCommand = commands:createCommand("print")
  -- .print unpacked <arg>
  printCommand:createCommand("unpacked"):setFunction(print)
  -- .print packed <args ...>
  printCommand:createCommand("packed"):setFunction(printTable, true)

  --==========--
  -- Register commands with a table (This does exactly the same as above)

  -- Prefix commands

  -- .prefix
  commands.tables:commandTable("prefix", {
    -- Function can either be assigned to [1] or _func
    -- .prefix (Returns the current prefix if no subcommand is called)
    function()
      printJson(string.format("Current prefix is %s\n", commands:getPrefix()))
    end,
    -- .prefix set <pfx> <bool>
    set = {
      _func = function(prfx, bool)
        commands:setPrefix(prfx, bool)
        printJson(string.format("Prefix changed to %s\n", prfx or "."))
      end,
      _info = "Set the prefix used to run commands", -- Shows an info message
    },
    -- .prefix get
    get = function()
      printJson(string.format("Current prefix is %s\n", commands:getPrefix()))
    end,
  })

  -- Print commands

  commands.tables:commandTable("print", {
    -- .print unpacked <arg>
    unpacked = print, -- _packed = false; each argument passes individually
    -- .print packed <args ...>
    packed = {
      printTable,                 -- _packed = true; one arguments are passed as a single table
      _args = { _packed = true }, -- Sets the args metadata
    },
  })

  -- Example of replacing entire command table
  local function never(arg)
    print(arg)
  end

  commands.tables:commandTable(
    {
      never = {
        _func = never,
        gonna = {
          give = { you = { up = never } },
          let = { you = { down = never } },
          run = { around = { ["and"] = { desert = { you = never } } } },
          make = { you = { cry = never } },
          say = { goodbye = never },
          tell = { a = { lie = { ["and"] = { hurt = { you = never } } } } },
        },
      },
      you = {
        lost = {
          the = {
            game = {
              _func = never,
            },
          },
        },
      },
    }
  )
end
