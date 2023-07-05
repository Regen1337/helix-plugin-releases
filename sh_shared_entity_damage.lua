local PLUGIN = PLUGIN

PLUGIN.name = "Shared Entity Damage"
PLUGIN.author = "regen"
PLUGIN.description = "Shares the EntityTakeDamage (CTakeDamgeInfo) to the client."

if SERVER then
    util.AddNetworkString("ixSharedEntityTakeDamage")
    ix.log.AddType("WriteCTakeInfoInvalidType", function(dmgInfo)
        return string.format("WriteCTakeInfo: type(dmgInfo) is not CTakeDamageInfo, it is %s", type(dmgInfo))
    end)

    function PLUGIN:WriteCTakeInfo(dmgInfo)
        if not type(dmgInfo) == "CTakeDamageInfo" then ix.log.Add(nil, "WriteCTakeInfoInvalidType", dmgInfo) return end
    
        net.WriteUInt(dmgInfo:GetDamage(), 32)
        net.WriteUInt(dmgInfo:GetDamageType(), 32)
        net.WriteUInt(dmgInfo:GetMaxDamage(), 32)
        net.WriteUInt(dmgInfo:GetAmmoType(), 32)
    
        net.WriteVector(dmgInfo:GetDamageForce())
        net.WriteVector(dmgInfo:GetDamagePosition())
        net.WriteVector(dmgInfo:GetReportedPosition())
    
        net.WriteEntity(dmgInfo:GetAttacker())
        net.WriteEntity(dmgInfo:GetInflictor())
    end

    function PLUGIN:SendCTakeInfo(target, dmgInfo)
        net.Start("ixSharedEntityTakeDamage")
            net.WriteEntity(target)
            self:WriteCTakeInfo(dmgInfo)
        net.Broadcast()
    end

    function PLUGIN:EntityTakeDamage(target, dmgInfo, ...)
        local can = GAMEMODE.BaseClass:EntityTakeDamage(target, dmgInfo, ...)
        if can then return true end

        can = target:IsPlayer() or target:IsNPC() or target:IsNextBot() or (target.IsBot and target:IsBot())
        if not can then return end

        hook.Run("PreSharedEntityTakeDamage", target, dmgInfo, ...)
        self:SendCTakeInfo(target, dmgInfo)
        hook.Run("PostSharedEntityTakeDamage", target, dmgInfo, ...)
    end
    
else
    function PLUGIN:ReadCTakeInfo()
        local dmgInfo = DamageInfo()
        dmgInfo:SetDamage(net.ReadUInt(32))
        dmgInfo:SetDamageType(net.ReadUInt(32))
        dmgInfo:SetMaxDamage(net.ReadUInt(32))
        dmgInfo:SetAmmoType(net.ReadUInt(32))
    
        dmgInfo:SetDamageForce(net.ReadVector())
        dmgInfo:SetDamagePosition(net.ReadVector())
        dmgInfo:SetReportedPosition(net.ReadVector())
    
        local attacker = net.ReadEntity()
        local inflictor = net.ReadEntity()
        
        if IsValid(attacker) then dmgInfo:SetAttacker(attacker) end
        if IsValid(inflictor) then dmgInfo:SetInflictor(inflictor) end  
    
        return dmgInfo
    end

    function PLUGIN.ReceiveCTakeInfo()
        local target = net.ReadEntity()
        local dmgInfo = PLUGIN:ReadCTakeInfo()

        if (target.PostSharedEntityTakeDamage) then
            target:PostSharedEntityTakeDamage(target, dmgInfo)
        end
        
    end

    net.Receive("ixSharedEntityTakeDamage", PLUGIN.ReceiveCTakeInfo)
end

if (SERVER) then return end
local META = FindMetaTable("Entity")

function META:PostSharedEntityTakeDamage(target, dmgInfo)
    -- your code here, eg: hit number effects etc
end

-- alternatively you can set this directly on the entity
