-- Some example code
local interactions = require("scripts.interactionsAPI")

function events.entity_init()
  interactions:create("Test"):setRegion(-230, 63, 173, -231, 64, 172):setMode("Hitbox"):setKey("key.mouse.right"):update()
end

function events.tick()
  if interactions.Test:getInteractors() then
    particles:newParticle("minecraft:bubble", -230.5, 63.5, 172.5)
  end
end