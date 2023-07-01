local PLUGIN = PLUGIN

PLUGIN.name = "Edict Handler + Cleanup"
PLUGIN.author = "regen"
PLUGIN.description = "Handles edict limits. and item cleanup."

PLUGIN.nextCleanup = 0
PLUGIN.isCleaning = false
PLUGIN.maxSafe = 8050 -- edit at your own risk crackhead

-- whitelist for items that should be cleaned up
PLUGIN.cleanup_whitelist = {
    ["ix_item"] = true,
    ["ix_money"] = true,
}

do
    ix.chat.Register("server", {
        format = "%s",
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

    ix.config.Add("shouldCleanup", true, "Should the server cleanup entities without hitting max edict?", nil, {
        category = PLUGIN.name
    })

    ix.config.Add("entityCleanupInterval", 600, "How often in seconds to cleanup entities", nil, {
        data = {min = 60, max = 3600},
        category = PLUGIN.name
    })

    ix.command.Add("cleanup", {
        description = "Run a cleanup of entities",
        adminOnly = true,
        OnRun = function(self, client)
            PLUGIN:Cleanup(0)
        end
    })
end


if !(SERVER) then return end

do
    ix.log.AddType("edict", function(client, ...)
        local arg = {...}
        local count = arg[1]

        return string.format("SERVER reached the edict limit of %d", count)
    end)

    ix.log.AddType("edict_cleanup", function(client, ...)
        local arg = {...}
        local count = arg[1]

        return string.format("SERVER removed up %d entities", count)
    end)
end

do
    function PLUGIN:Cleanup(delay)
        if (self.isCleaning) then return end
        delay = math.max(delay, 30)

        ix.chat.Send(nil, "server", "Entity cleanup in " .. delay .. " seconds!", true)
        timer.Simple(delay, function()
            local count = 0

            for i = 1, table.Count(self.cleanup_whitelist) do
                local class = table.GetKeys(self.cleanup_whitelist)[i]
                local entities = ents.FindByClass(class)

                for k = 1, #entities do
                    local entity = entities[k]

                    if (IsValid(entity)) then
                        entity:Remove()
                        count = count + 1
                    end
                end
            end

            ix.log.Add(nil, "edict_cleanup", count)
            self.isCleaning = false
        end)
    end

    function PLUGIN:Think()
        if (!ix.config.Get("shouldCleanup", true)) then return end
        
        local cur_time = CurTime()
        if (cur_time < self.nextCleanup) then return end

        self.nextCleanup = cur_time + math.max(ix.config.Get("entityCleanupInterval", 600), 30)
        self:Cleanup(0)
    end
end

do
    ents.CreateOld = ents.CreateOld or ents.Create

    function ents.Create(class, ...)
        local count = ents.GetEdictCount()

        if (count >= PLUGIN.maxSafe) then
            ix.log.Add(nil, "edict", count)
            PLUGIN:Cleanup(0)

            return NULL
        end

        if (class == "prop_vehicle_jeep_old") then class = "prop_vehicle_jeep" end

        return ents.CreateOld(class, ...)
    end
end
