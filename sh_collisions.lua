local PLUGIN =  PLUGIN

PLUGIN.name = "Collision Handler"
PLUGIN.author = "regen"
PLUGIN.description = "Handles collisions between entities."
PLUGIN.bInEmergency = false

PLUGIN.entity_list = PLUGIN.entity_list or 
{
    ["ix_item"] = true,
    ["ix_container"] = true,
    ["ix_money"] = true,
    ["ix_vendor"] = true,
    ["ix_shipment"] = true,

    ["prop_physics"] = true,
    ["prop_dynamic"] = true,
    ["prop_ragdoll"] = true,
    ["prop_door_rotating"] = true,
    ["prop_door_rotating_direcional"] = true,
    ["func_useableladder"] = true,
    ["func_breakable"] = true,
}

PLUGIN.hook_list = PLUGIN.hook_list or
{
    "CanTool",
    "OnPhysgunReload",
    "PhysgunPickup",
    "PlayerSpawnRagdoll",
    "PlayerGiveSWEP",
    "PlayerSpawnSWEP",
    "PlayerSpawnEffect",
    "PlayerSpawnNPC",
    "PlayerSpawnObject",
    "PlayerSpawnProp",
    "PlayerSpawnSENT",
    "PlayerSpawnVehicle"
}

ix.chat.Register("server", {
    format = "[SERVER] %s",
    color = Color(202, 1, 1),
    CanHear = function(self, speaker, listener)
        return true
    end,
    OnChatAdd = function(self, speaker, text)
        chat.AddText(self.color, text)
    end,
    prefix = {"/", "!"},
    CanSay = function(self, speaker, text)
        return speaker and false or true
    end,
})

ix.config.Add("maxCollisions", 25, "The maximum amount of collisions allowed before the server freezes entities.", nil, {
    data = {min = 1, max = 100},
    category = "Collision Handler"
})

function PLUGIN:CheckCollisions()
    local count = 0

    for _, ent in ipairs(ents.GetAll()) do
        if (self.entity_list[ent:GetClass()]) then
            local phys_count = ent:GetPhysicsObjectCount()

            if (phys_count > 1) then
                for i = 1, phys_count do
                    local phys_obj = ent:GetPhysicsObjectNum(i)

                    if (IsValid(phys_obj) and phys_obj:IsPenetrating()) then
                        count = count + 1
                        break
                    end
                end
            else
                local phys_obj = ent:GetPhysicsObject()

                if (IsValid(phys_obj) and phys_obj:IsPenetrating()) then
                    count = count + 1
                end
            end
        end
    end

    local max = ix.config.Get("maxCollisions", 50)
    print("Collision count: " .. count .. "/" .. max .. ".")
    return count
end

function PLUGIN:FreezeEntites(entities, bMotion)
    for _, ent in ipairs(entities) do
        local phys_count = ent:GetPhysicsObjectCount()

        if (phys_count > 1) then
            for i = 1, phys_count do
                local phys_obj = ent:GetPhysicsObjectNum(i)

                if (IsValid(phys_obj)) then
                    phys_obj:Sleep()
                    phys_obj:EnableMotion(bMotion)
                end
            end
        else
            local phys_obj = ent:GetPhysicsObject()

            if (IsValid(phys_obj)) then
                phys_obj:Sleep()
                phys_obj:EnableMotion(bMotion)
            end
        end
    end
end

function PLUGIN:AntiPen(bShouldAnnounce)
    local count = 0
    local pen_list = {}; local owner_list = {};

    for _, ent in ipairs(ents.GetAll()) do
        if (self.entity_list[ent:GetClass()]) then
            local phys_count = ent:GetPhysicsObjectCount()

            local bIsPen = false
            if (phys_count > 1) then
                for i = 1, phys_count do
                    local phys_obj = ent:GetPhysicsObjectNum(i)

                    if (bIsPen) then
                        phys_obj:Sleep()
                    elseif (IsValid(phys_obj) and phys_obj:IsPenetrating()) then
                        bIsPen = true
                        phys_obj:Sleep()

                        break
                    end
                end
            else
                local phys_obj = ent:GetPhysicsObject()

                if (IsValid(phys_obj) and phys_obj:IsPenetrating()) then
                    bIsPen = true
                    phys_obj:Sleep()
                end
            end

            if (bIsPen) then
                count = count + 1
                pen_list[count] = ent

                local owner = (ent:IsWorld() and "world") or (IsValid(ent:GetOwner()) and ent:GetOwner()) or ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) and ent:CPPIGetOwner() or ent.Owner or "unknown"

                if (owner ~= "") then
                    owner_list[owner] = (owner_list[owner] or 0) + 1
                end
            end
        end
    end

    if (bShouldAnnounce and count > 0) then
        local biggest, owner = 0
        for k, v in pairs(owner_list) do
            if (v > biggest) then
                biggest = v
                owner = k
            end
        end

        if (biggest >= 1) then
            local name = owner
            if (isentity(owner) and owner:IsPlayer()) then name = owner:Nick() end
            ix.chat.Send(nil, "server", "Anti-Pen determined that '"..name.."' was the main cause of lag, with "..biggest.." entities out of "..count.." penetrating.")
        end
    end
end

function PLUGIN:TogglePen(bToggle, delay)
    local hooks = hook.GetTable()
    local think = hooks["Think"] or {}

    if (bToggle) then
        if (think["AntiPen"] == nil) then
            self:AntiPen(true)
            hook.Add("Think", "AntiPen", function() self:AntiPen() end)
        end

        if (delay) then
            timer.Simple(delay, function()
                if (think["AntiPen"] ~= nil) then
                    hook.Remove("Think", "AntiPen")
                end
            end)
        end

        ix.chat.Send(nil, "server", "Anti-Pen enabled.")
    else
        if (think["AntiPen"] ~= nil) then
            hook.Remove("Think", "AntiPen")
        end

        ix.chat.Send(nil, "server", "Anti-Pen disabled.")
    end

end

function PLUGIN:ToggleBuilding(bToggle)
    if (bToggle) then
        for _, v in ipairs(self.hook_list) do
            hook.Add(v, "ToggleBuilding", function() return false end)
        end

        ix.chat.Send(nil, "server", "Anti-Building enabled.")
    else
        for _, v in ipairs(self.hook_list) do
            hook.Remove(v, "ToggleBuilding")
        end

        self:TogglePen(false)
        ix.chat.Send(nil, "server", "Anti-Building disabled.")
    end
end

function PLUGIN:FreezeAllMovement(delay)
    self:FreezeEntites(ents.GetAll(), false)
    self:TogglePen(true, delay or 1)
end

function PLUGIN:EmergencyFreeze(delay)
    if (self.bInEmergency) then return end
    ix.chat.Send(nil, "server", "Emergency freeze enabled; all entities are frozen for 10 seconds and building is disabled.")
    self.bInEmergency = true

    self:FreezeAllMovement(delay or 1)
    self:ToggleBuilding(true)
    timer.Simple(delay or 1, function() 
        self:ToggleBuilding(false) 
        self.bInEmergency = false
    end)
end

function PLUGIN:Think()
    if (self.nextThink and CurTime() < self.nextThink) then return end
    self.nextThink = CurTime() + 0.1

    local count = self:CheckCollisions()
    local max = ix.config.Get("maxCollisions", 50)

    if (count >= max * 1.2) then
        self:EmergencyFreeze(10)
    elseif (count >= max) then
        self:FreezeAllMovement(10)
    end

end

