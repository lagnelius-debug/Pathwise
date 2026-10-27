local addonName, Pathwise = ...

-- Key binding handlers. Bindings.xml can only call global functions, so
-- these are the only globals Pathwise defines besides saved variables,
-- slash commands and the BINDING_* names.

function PathwiseBinding_Next()
  Pathwise:GetModule("Waypoints"):Next()
end

function PathwiseBinding_Dungeon()
  Pathwise:GetModule("DungeonGuide"):Toggle()
end

function PathwiseBinding_Toggle()
  Pathwise:GetModule("NextStepsFrame"):Toggle()
end
