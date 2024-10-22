-- Written by FOX using FOX's InteractionsAPI v1.2.0
local interactions = require("InteractionsAPI")

-- Function that summons particles at a player
local function compactSeeds(u)
  local t = 0
  function events.tick()
    if t < 40 then
      -- Summon a particle for 40 ticks (2 seconds)
      particles:newParticle("minecraft:dust 0.93 0.89 0.75 4",
        world.getPlayers()[u]:getPos() + world.getPlayers()[u]:getLookDir() * 0.5 +
        (world.getPlayers()[u]:getEyeHeight() * vec(0, 1, 0)),
        vec(0, -2, 0))
    else
      return
    end
  end

  -- Count up every tick
  function events.tick()
    t = t + 1
  end
end

-- Locations of all corndogs in the Figura Plaza
local corndogs = {
  vec(-238, 63, 161),
  vec(-239, 63, 160),
  vec(-238, 63, 158),
  vec(-237, 64, 159),
  vec(-246, 63, 160),
  vec(-231, 63, 157),
  vec(-230, 64, 159),
  vec(-229, 63, 158),
}

-- Create an interaction for every corndog
for i, coord in pairs(corndogs) do
  interactions:newInteraction("Corndog" .. i)
      :setRegion(
        vec(coord.x + 0.5 - (1 / 16), coord.y, coord.z + 0.5 - (1 / 16)),
        vec(coord.x + 0.5 + (1 / 16), coord.y + (6 / 16), coord.z + 0.5 + (1 / 16)),
        "Hitbox")
      :setKey("key.mouse.right"):setColor("white"):setSwing("Once")
end

-- Register every interaction
function events.entity_init()
  for i in pairs(corndogs) do
    interactions["Corndog" .. i]:update()
  end
end

-- Loop through all the corndog interactions, get their interactors, and create particles when interacted with
function events.tick()
  for i in pairs(corndogs) do
    if interactions["Corndog" .. i]:getInteractors() then
      for _, p in pairs(interactions["Corndog" .. i]:getInteractors()) do
        compactSeeds(p:getName())
      end
    end
  end
end
