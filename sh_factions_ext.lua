--[==[
    Author: regen
    This plugin adds metatables to (factions and classes), and adds methods of setting presistant data to them aswell, kinda figured this should have been in base helix idk why it was decided otherwise.
    Also adds hooks for pre and post set / removal of data used interally, returning false on prehooks will prevent data from being changed.

    
    READ IF YOU PLAN TO USE THIS:

    Important: Only put this in your schema/libs folder, this has to be loaded in a specific order before plugins.
    Probably unrelated but backup your schema config if you care, for some reason when I restarted my server earlier it went to default config, prob unrelated but who knows until it happens lol!, has not happened since and have done multiple restarts.

    Disclaimer: This is a library for developers, does not provide content on it's own, meant to be built upon.
    The downside to using this currently is that it only saves to a local JSON file, (doesn't support cross-server data)
    
    Only use if you know what you are doing, report any bugs / overhead directly to me in DMs (discord == 1337regen)

    TODO: convert to mysql (anyone is free to rewrite to mysql, contact me if you do this prior to me doing it)
    TODO: clean variable naming
]==]

ix.meta = ix.meta or {}

local SyncData
if (SERVER) then 
    util.AddNetworkString("ixFacDataSync") 
    SyncData = function(bFaction, sync_type, data)
        net.Start("ixFacDataSync")
            net.WriteBool(bFaction)
            net.WriteString(sync_type)
            net.WriteTable(data)
        net.Broadcast()
    end
end

function ix.class.GetKey(key)
    for k, v in ipairs(ix.class.list) do
        if (v.uniqueID == key) then
            return k
        end
    end

    return nil
end

do -- faction meta
    local FACTION = {}
    FACTION.__index = FACTION
    FACTION.__call = FACTION

    do -- fill out default functions here for factions or edit ix.meta.faction in any plugin
        function FACTION:GetName()
            return self:GetData("name", self.name)
        end

        function FACTION:GetDescription()
            return self:GetData("description", self.description)
        end

        function FACTION:IsDefault()
            return self:GetData("default", self.isDefault)
        end

        function FACTION:GetColor()
            return self:GetData("color", self.color)
        end

        function FACTION:GetPay()
            return self:GetData("pay", self.pay)
        end

        function FACTION:GetWeight() -- non default, for my stuff
            return self:GetData("weight", self.weight)
        end

        function FACTION:GetModels()
            return self:GetData("models", self.models)
        end

        function FACTION:GetIndex()
            return self:GetData("index", self.index)
        end

        function FACTION:GetPlugin()
            return self:GetData("plugin", self.plugin)
        end

        function FACTION:GetUniqueID()
            return self:GetData("uniqueID", self.uniqueID)
        end

        function FACTION:GetDataTable()
            local uID = self:GetUniqueID()
            if !(uID) then return false end
            local data = {}

            for i,v in next, (self) do
                local fData = ix.data.Get("faction_" .. uID .. "_" .. tostring(i), nil)
                if (fData) then
                    data[#data + 1] = {uID = uID, key = tostring(i), value = fData}
                end
            end

            return data
        end

        function FACTION:SetData(key, value, bNoSave, bSync)
            local uID = self:GetUniqueID()
            if (!uID) then return false, "Faction does not have a uniqueID." end
            
            local can, err = hook.Run("PreFactionSetData", uID, key, value, bNoSave)
            if (!can) then return false, err end
            
            self[key] = value
            ix.data.Set("faction_" .. uID .. "_" .. key, value, false, bNoSave)

            if (SERVER) then
                local data = {
                    uID = uID,
                    key = key,
                    value = value,
                    bNoSave = bNoSave or false,
                }

                SyncData(true, "set", data)
            end
            
            hook.Run("PostFactionSetData", uID, key, value, bNoSave)
        end
        
        function FACTION:GetData(key, default, bIgnoreMap)
            return ix.data.Get("faction_" .. self.uniqueID .. "_" .. key, default, false, bIgnoreMap)  
        end
    
        function FACTION:RemoveData(key)
            local uID = self:GetUniqueID()
            if (!uID) then return false, "Faction does not have a uniqueID." end

            local can, err = hook.Run("PreFactionRemoveData", uID, key)
            if (!can) then return false, err end

            self[key] = nil
            ix.data.Remove("faction_" .. uID .. "_" .. key)

            if (SERVER) then
                local data = {
                    uID = uID,
                    key = key,
                }

                SyncData(true, "remove", data)
            end
        
            hook.Run("PostFactionRemoveData", uID, key)
        end

        function Schema:PreFactionSetData(uID, key, value, bNoSave)
        end

        function Schema:PostFactionSetData(faction, key, value, bNoSave)
        end

        function Schema:PreFactionRemoveData(faction, key)
        end

        function Schema:PostFactionRemoveData(faction, key)
        end
    end

    do
        local oldFLFD = ix.faction.LoadFromDir
        function ix.faction.LoadFromDir(dir)
            oldFLFD(dir)

            for _, fac in ipairs(ix.faction.indices) do
                if !(getmetatable(fac)) then
                    fac = setmetatable(fac, FACTION)
                end
            end
        end
    end

    ix.meta.faction = FACTION
end

do -- class meta
    local CLASS = {}
    CLASS.__index = CLASS
    CLASS.__call = CLASS

    do -- fill out default functions here for classes or edit ix.meta.class in any plugin
        function CLASS:GetName()
            return self:GetData("name", self.name)
        end

        function CLASS:GetFactionIndex()
            return self:GetData("faction", self.faction)
        end

        function CLASS:GetFaction()
            return ix.faction.indices[self:GetFactionIndex()]
        end

        function CLASS:IsDefault()
            return self:GetData("default", self.isDefault)
        end

        function CLASS:GetWeight() -- non default, for my stuff
            return self:GetData("weight", self.weight)
        end

        function CLASS:GetIndex()
            return self:GetData("index", self.index)
        end

        function CLASS:GetUniqueID()
            return self:GetData("uniqueID", self.uniqueID)
        end

        function CLASS:GetLimit()
            return self:GetData("limit", self.limit)
        end

        function CLASS:GetDataTable()
            local faction = self:GetFaction() and self:GetFaction():GetUniqueID(); local uID = self:GetUniqueID()
            if !(faction) then return false, "Class does not have a faction." end
            if !(uID) then return false, "Class does not have a uniqueID" end

            local data = {}

            for i,v in next, (self) do
                local cData = ix.data.Get("class_" .. faction .. "_" .. uID .. "_" .. tostring(i), nil)
                if (cData) then
                    data[#data + 1] = {faction = faction, uID = uID, key = tostring(i), value = cData}
                end
            end

            return data
        end

        function CLASS:SetData(key, value, bNoSave)
            local faction = self:GetFaction() and self:GetFaction():GetUniqueID(); local uID = self:GetUniqueID();
            if !(faction) then return false, "Class does not have a faction." end
            if !(uID) then return false, "Class does not have a uniqueID." end

            local can, err = hook.Run("PreClassSetData", faction, uID, key, value, bNoSave)
            if (!can) then return false, err end

            self[key] = value
            ix.data.Set("class_" .. faction .. "_" .. uID .. "_" .. key, value, false, bNoSave)

            if (SERVER) then
                local data = {
                    faction = faction,
                    uID = uID,
                    key = key,
                    value = value,  
                    bNoSave = bNoSave or false,
                }

                SyncData(false, "set", data)
            end

            hook.Run("PostClassSetData", faction, uID, key, value, bNoSave )
        end
        
        function CLASS:GetData(key, default, bIgnoreMap)
            local faction = ix.faction.indices[self.faction] and ix.faction.indices[self.faction]:GetUniqueID()
            return ix.data.Get("class_" .. faction .. "_" .. self.uniqueID .. "_" .. key, default, false, bIgnoreMap)
        end

        function CLASS:RemoveData(key)
            local faction = self:GetFaction() and self:GetFaction():GetUniqueID(); local uID = self:GetUniqueID();
            if !(faction) then return false, "Class does not have a faction." end
            if !(uID) then return false, "Class does not have a uniqueID." end
            
            local can, err = hook.Run("PreClassRemoveData", faction, uID, key)
            if (!can) then return false, err end
            
            self[key] = nil
            ix.data.Remove("class_" .. faction .. "_" .. uID .. "_" .. key)

            if (SERVER) then
                local data = {
                    faction = faction,
                    uID = uID,
                    key = key,
                }

                SyncData(false, "remove", data)
            end

            hook.Run("PostClassRemoveData", faction, uID, key)
        end

        function Schema:PreClassSetData(factionID, uID, key, value, bNoSave)
        end

        function Schema:PostClassSetData(factionID, uID, key, value, bNoSave)
        end

        function Schema:PreClassRemoveData(factionID, uID, key)
        end

        function Schema:PostClassRemoveData(factionID, uID, key)
        end
    end

    do
        local oldCLFD = ix.class.LoadFromDir
        function ix.class.LoadFromDir(dir)
            oldCLFD(dir)

            for _, cls in ipairs(ix.class.list) do
                if !(getmetatable(cls)) then
                    cls = setmetatable(cls, CLASS)
                end
            end
        end
    end

    ix.meta.class = CLASS
end

if (SERVER) then -- server state
    function Schema:PlayerInitialSpawn(ply)
        local cache = {}

        for _, v in ipairs(ix.faction.indices) do
            local data = v:GetDataTable()

            if (data) then
                table.insert(cache, {bFaction = true, data = data})
            end
        end
        
        for _, v in ipairs(ix.class.list) do
            local data = v:GetDataTable()

            if (data) then
                table.insert(cache, {bFaction = false, data = data})
            end
        end

        -- send cache in 1 network to client
        SyncData(_, "set_all", cache)
    end
else -- client state
    -- function for recieving data from the server, ix.data.Set is shared so we can run it on the client state
    net.Receive("ixFacDataSync", function()
        local faction_or_class = net.ReadBool()
        local update_type = net.ReadString()
        local data = net.ReadTable()
    
        if (update_type == "set_all") then -- multiple factions and or classes were sent with full data
            for _, v in ipairs(data) do
                if (v.bFaction) then
                    for _, d in ipairs(v.data) do
                        local fac = ix.faction.Get(d.uID).index
                        ix.data.Set("faction_" .. d.uID .. "_" .. d.key, d.value, false, d.bNoSave)
                        ix.faction.indices[fac][d.key] = d.value
                    end
                else
                    for _, d in ipairs(v.data) do
                        local class = ix.class.GetKey(d.uniqueID).index
                        ix.data.Set("class_" .. d.faction .. "_" .. d.uniqueID .. "_" .. d.key, d.value, false, d.bNoSave)
                        ix.class.list[class][d.key] = d.value
                    end
                end
            end
        elseif (faction_or_class) then -- faction (singular key value) was sent
            if update_type == "set" then
                ix.data.Set("faction_" .. data.uID .. "_" .. data.key, data.value, false, data.bNoSave)

                data.uID = ix.faction.Get(data.uID).index
                ix.faction.indices[data.uID][data.key] = data.value
            elseif update_type == "remove" then
                ix.data.Remove("faction_" .. data.uID .. "_" .. data.key)

                data.uID = ix.faction.Get(data.uID).index
                ix.faction.indices[data.uID][data.key] = nil
            end
        else -- class (singular key value) was sent
            if update_type == "set" then
                ix.data.Set("class_" .. data.faction .. "_" .. data.uniqueID .. "_" .. data.key, data.value, false, data.bNoSave)
                
                data.uID = ix.class.GetKey(data.faction).index
                ix.class.list[data.uID][data.key] = data.value
            elseif update_type == "remove" then
                ix.data.Remove("class_" .. data.faction .. "_" .. data.uniqueID .. "_" .. data.key)

                data.uID = ix.class.GetKey(data.faction).index
                ix.class.list[data.uID][data.key] = nil
            end
        end
    end)    
end    
