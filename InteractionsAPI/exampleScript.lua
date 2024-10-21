-- Some example code
local interactions = require("InteractionsAPI")

interactions:create("Test")
    :setRegion(vec(-230, 63, 173), vec(-231, 64, 172), "Hitbox", 3)
    :setKey("key.mouse.right")
    :setColor("white")
    :setSwing("Every Tick")

function events.entity_init()
  interactions.Test:update()
end

function events.tick()
  if interactions.Test:getInteractors() then
    particles:newParticle("minecraft:bubble", -230.5, 63.5, 172.5)
  end
end
