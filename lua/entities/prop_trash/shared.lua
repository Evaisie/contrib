﻿-- This file is subject to copyright - contact swampservers@gmail.com for more information.
-- INSTALL: CINEMA
AddCSLuaFile()
DEFINE_BASECLASS("base_anim")
ENT.Type = "anim"
local Entity = FindMetaTable("Entity")

function Entity:GetTrashClass()
    local tc = self:GetNW2String("trc")

    if tc == "" then
        if self:GetClass():StartWith("prop_trash") then return self:GetClass() end
    else
        return tc
    end
end

if CLIENT then
    -- hook.Add("OnEntityCreated","CreatedTrashProp",function(ent)
    --     -- if ent:GetClass()=="prop_physics" then print("TC1", ent:GetTrashClass(),  ent:GetModel()) end
    -- end)
    hook.Add("NetworkEntityCreated", "CreatedTrashProp", function(ent)
        -- if ent:GetClass()=="prop_physics" then print("TC2", ent:GetTrashClass(),  ent:GetModel()) end
        if ent:GetClass() == "prop_physics" and ent:GetTrashClass() and not ent.SetupTrashAlready then
            ent.SetupTrashAlready = true
            ent:SetTrashClass(ent:GetTrashClass())
            ent:InstallDataTable()
            ent:SetupDataTables()
            ent:Initialize()
        end
    end)

    hook.Add("EntityNetworkedVarChanged", "CreatedTrashProp", function(ent, name, oldval, newval)
        if ent:GetClass() == "prop_physics" and name == "trc" and ent:GetModel() and not ent.SetupTrashAlready then
            ent.SetupTrashAlready = true
            ent:SetTrashClass(newval)
            ent:InstallDataTable()
            ent:SetupDataTables()
            ent:Initialize()
        end
    end)
end

local function copyentitytable(self, class)
    local t = scripted_ents.GetStored(class)

    if t.Base and t.Base ~= "base_anim" then
        copyentitytable(self, t.Base)
    end

    local mytab = self:GetTable()

    for k, v in pairs(t.t) do
        mytab[k] = v
    end
end

if SERVER then
    function Entity:SetTrashClass(tc)
        self:SetNW2String("trc", tc)
        copyentitytable(self, tc)
    end
else
    function Entity:SetTrashClass(tc)
        copyentitytable(self, tc)
    end
end

PropTrashLightData = PropTrashLightData or {
    ["models/props_interiors/furniture_lamp01a.mdl"] = {
        untaped = false,
        size = 500,
        brightness = 2,
        style = 0,
        pos = Vector(0, 0, 27)
    },
    ["models/maxofs2d/light_tubular.mdl"] = {
        untaped = false,
        size = 300,
        brightness = 2,
        style = -1,
        pos = Vector(0, 0, 0)
    },
    ["models/light/cagedlight.mdl"] = {
        untaped = false,
        size = 300,
        brightness = 2,
        style = 0,
        pos = Vector(0, 0, 0)
    },
    ["models/brian/flare.mdl"] = {
        untaped = true,
        size = 300,
        brightness = 2,
        style = 6,
        pos = Vector(0, 0, 8)
    }
}

PropTrashDoors = {
    ["models/staticprop/props_c17/door01_left.mdl"] = true
}

function ENT:SetupDataTables()
    -- Use instead of Health so we can monitor it
    self:NetworkVar("Float", 0, "Strength")

    if SERVER then
        self:SetStrength(1)
    else
        self:NetworkVarNotify("Strength", function(ent, name, old, new)
            DAMAGED_TRASH[ent] = (ent:GetTrashClass() and name == "Strength" and new < 1) and true or nil
        end)
    end

    --
    self:NetworkVar("String", 0, "MaterialData")

    if CLIENT then
        self:NetworkVarNotify("MaterialData", function(ent, name, old, new)
            ent:ApplyMaterialData(new)
        end)
    end

    --
    self:NetworkVar("String", 1, "OwnerID")
    self:NetworkVar("Bool", 0, "Taped")
    self:NetworkVar("Int", 0, "Rating")

    if SERVER then
        self:SetRating(4)
    end

    self:NetworkVar("Int", 1, "ItemID")
end

ENT.CanChangeTrashOwner = true

function ENT:CanChangeOwner()
    return true
end

-- function ENT:GetLocation()
--     if (self.LastLocationCoords == nil) or (self:GetPos():DistToSqr(self.LastLocationCoords) > 1) then
--         self.LastLocationCoords = self:GetPos()
--         self.LastLocationIndex = Location.Find(self)
--     end
--     return self.LastLocationIndex
-- end
function TrashLocationClass(locid)
    local ln = Locations[locid].Name
    if TrashLocationOverrides[ln] then return TrashLocationOverrides[ln] end
    local t = theater.GetByLocation(locid)

    if t then
        if t:IsPrivate() and not IsValid(t:GetOwner()) then return TRASHLOC_NOBUILD end

        return TRASHLOC_NOSPAWN
    end

    return TRASHLOC_NOBUILD
end

function ENT:GetLocationClass()
    return TrashLocationClass(self:GetLocation())
end

function TrashLocationOwner(locid, pos)
    local class = TrashLocationClass(locid)
    local t = theater.GetByLocation(locid)

    if t and t:IsPrivate() then
        if t._PermanentOwnerID then return t._PermanentOwnerID end
        if IsValid(t:GetOwner()) then return t:GetOwner():SteamID() end
    end

    if class ~= TRASHLOC_BUILD then return nil end -- The only way to own a non build area is with a theater. Not a field.

    -- print(table.Count(Ents.prop_trash_zone))
    for k, v in pairs(Ents.prop_trash_zone) do
        if v:Protects(pos) then return v:GetOwnerID() end
    end

    return nil
end

function ENT:GetLocationOwner()
    return TrashLocationOwner(self:GetLocation(), self:GetPos())
end

--NOMINIFY
-- MIGHT BE A FILE RUN ORDER ISSUE
if HumanTeamName then
    function ENT:CanExist()
        return true
    end
else
    function ENT:CanExist()
        -- local vec = self:GetPos()
        -- vec.x = math.abs(vec.x)
        -- if vec:DistToSqr(Vector(160,160,80)) < 65536 then return false end --theater enterance
        -- someone sitting in the seat
        if IsValid((self.UseTable or {})[1]) then return true end

        return not (self:GetLocationClass() == TRASHLOC_NOSPAWN and self:GetOwnerID() ~= self:GetLocationOwner())
    end
end

function ENT:CanEdit(userid)
    if (self:GetOwnerID() == userid) or (self:GetLocationOwner() == userid) then return true end
    local ply = player.GetBySteamID(self:GetOwnerID())
    if IsValid(ply) and (ply.TrashFriends or {})[player.GetBySteamID(userid) or ""] then return true end

    return false
end

function ENT:CanTape(userid)
    if self:GetRating() == 1 then return false end
    if HumanTeamName ~= nil then return self:CanEdit(userid) end

    for k, v in ipairs(TrashNoFreezeNodes) do
        if self:GetPos():Distance(v[1]) < v[2] then return false end
    end

    local lown, lcl = self:GetLocationOwner(), self:GetLocationClass()
    if ((self:GetOwnerID() == userid) and (lown == nil) and ((lcl == TRASHLOC_BUILD) or (self:GetRating() == 8 and lcl == TRASHLOC_NOBUILD))) or (lown == userid and userid ~= nil) then return true end
    local ply = player.GetBySteamID(self:GetOwnerID())
    if IsValid(ply) and (ply.TrashFriends or {})[player.GetBySteamID(userid) or ""] then return true end

    return false
end
