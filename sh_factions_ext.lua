--[==[
    Author: regen
    Disclaimer: This is a library for developers, does not provide content on it's own, meant to be built upon.
    Important: Only put this in your schema/libs folder, this has to be loaded in a specific order before plugins.
    Probably unrelated but backup your schema config if you care, for some reason when I restarted my server earlier it went to default config, prob unrelated but who knows until it happens lol!, has not happened since and have done multiple restarts.

    This plugin adds metatables to (factions and classes), and adds methods of setting presistant data to them aswell, kinda figured this should have been in base helix idk why it was decided otherwise.
    Also adds hooks for post set and deletion of data, for whatever purpose.
]==]

ix.meta = ix.meta or {}

do 
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

        function FACTION:SetData(key, value, bGlobal, bNoSave)
            local uID = self:GetUniqueID()
            if (!uID) then return false, "Faction does not have a uniqueID." end

            ix.data.Set("faction_" .. uID .. "_" .. key, value, bGlobal, bNoSave)
            hook.Run("PostFactionSetData", uID, key, value, bGlobal, bNoSave)
        end
        
        function FACTION:GetData(key, default, bGlobal, bIgnoreMap)
            return ix.data.Get("faction_" .. self.uniqueID .. "_" .. key, default, bGlobal, bIgnoreMap)  
        end
    
        function FACTION:RemoveData(key, bGlobal)
            local uID = self:GetUniqueID()
            if (!uID) then return false, "Faction does not have a uniqueID." end

            ix.data.Remove("faction_" .. uID .. "_" .. key, bGlobal)
            hook.Run("PostFactionRemoveData", uID, key, bGlobal)
        end

        function Schema:PostFactionSetData(faction, key, value, bGlobal, bNoSave)
        end

        function Schema:PostFactionRemoveData(faction, key, bGlobal)
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

-- class meta
do 
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

        function CLASS:SetData(key, value, bGlobal, bNoSave)
            local faction = self:GetFaction() and self:GetFaction():GetUniqueID(); local uID = self:GetUniqueID();
            if !(faction) then return false, "Class does not have a faction." end
            if !(uID) then return false, "Class does not have a uniqueID." end

            ix.data.Set("class_" .. faction .. "_" .. uID .. "_" .. key, value, bGlobal, bNoSave)
            hook.Run("PostClassSetData", faction, uID, key, value, bGlobal, bNoSave )
        end
        
        function CLASS:GetData(key, default, bGlobal, bIgnoreMap)
            local faction = ix.faction.indices[self.faction] and ix.faction.indices[self.faction]:GetUniqueID()
            return ix.data.Get("class_" .. faction .. "_" .. self.uniqueID .. "_" .. key, default, bGlobal, bIgnoreMap)
        end

        function CLASS:RemoveData(key, bGlobal)
            local faction = self:GetFaction() and self:GetFaction():GetUniqueID(); local uID = self:GetUniqueID();
            if !(faction) then return false, "Class does not have a faction." end
            if !(uID) then return false, "Class does not have a uniqueID." end

            ix.data.Remove("class_" .. faction .. "_" .. uID .. "_" .. key, bGlobal)
            hook.Run("PostClassRemoveData", faction, uID, key, bGlobal)
        end

        function Schema:PostClassSetData(faction, uniqueID, key, value, bGlobal, bNoSave)
        end

        function Schema:PostClassRemoveData(faction, uniqueID, key, bGlobal)
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