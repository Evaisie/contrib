﻿-- This file is subject to copyright - contact swampservers@gmail.com for more information.
SWEP.Spawnable = false
SWEP.UseHands = true
SWEP.DrawAmmo = true
SWEP.CSSWeapon = true
SWEP.DropOnGround = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false
SWEP.CSMuzzleFlashes = true
SWEP.Primary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Ammo = -1
-- match css
-- CSS uses 0.75
SWEP.CrouchSpreadMultiplier = 0.75
-- CSS uses 1.4, use lower value so crouching spray isnt too controlled (since it also gets reduced by CrouchSpreadMultiplier)
SWEP.CrouchSprayDecayMultiplier = 1.2
-- TODO: change crouch decay multiplier to a gain multiplier instead
SWEP.KickUBase = 0
SWEP.KickUSpray = 0
SWEP.KickLBase = 0
SWEP.KickLSpray = 0
SWEP.CrouchKickMultiplier = 0.9
SWEP.MoveKickMultiplier = 1.5
-- SWEP.KickDirChance = 1 / 8
-- SWEP.CrouchKickDanceMultiplier = 8 / 9
-- SWEP.MoveKickDanceMultiplier = 8 / 7
-- avg dir changes per second
SWEP.KickDance = 1.25
SWEP.CrouchKickDanceMultiplier = 0.85
SWEP.MoveKickDanceMultiplier = 1.2
-- SWEP.KickDanceMinInterval = 0.3
SWEP.KickDanceMinSpray = 0.3
SWEP.SpreadUnscoped = 0
SWEP.HeadshotMultiplier = 3
SWEP.LegshotMultiplier = 0.8
SWEP.ViewModelFOV = 60
SWEP.PelletSpread = 0
SWEP.NumPellets = 1
-- DELETE THIS
SWEP.SpraySaturation = 2
-- handled by deploy
SWEP.m_WeaponDeploySpeed = 1000

-- Works on server too 
hook.Add("EntityNetworkedVarChanged", "SetNetworkedProperty", function(ent, name, oldval, newval)
    if name:StartWith("NP_") then
        timer.Simple(0, function()
            if not IsValid(ent) then return end

            if isstring(newval) and name:EndsWith("_json") then
                ent[name:sub(4, -6)] = util.JSONToTable(newval)
            else
                ent[name:sub(4)] = newval
            end
        end)
    end
end)

function SWEP:Standingness()
    local cur = self.Owner:GetCurrentViewOffset()
    local stand = self.Owner:GetViewOffset()
    local duck = self.Owner:GetViewOffsetDucked()

    return math.Clamp((cur.z - duck.z) / (stand.z - duck.z), 0, 1)
end

-- SWEP.SpreadBase = 0.001
-- SWEP.SpreadUnscoped = 0
-- SWEP.SpreadStand = 0.001
-- SWEP.SpreadMove = 0.01
-- SWEP.SprayStand = 0.1
-- SWEP.SprayCrouch = 0.1
-- SWEP.SprayExponent = 1
-- SWEP.SprayIncrement = 0.5
-- SWEP.SprayDecay = 0.4
function SWEP:GetPrintName()
    return self:GetNWString("PrintName", self.PrintName or "unknown")
end

function SWEP:GetInterval()
    return self.CycleTime / self:GetNWFloat("rof", 1)
end

function SWEP:GetControl()
    return self:GetNWFloat("control", 1)
end

-- reload and deploy speed
function SWEP:GetHandling()
    return self:GetNWFloat("handling", 1)
end

-- movespeed and moving spread
function SWEP:GetMobility()
    return self:GetNWFloat("mobility", 1)
end

function CalculateRolledSpread(accuracy_roll, spreadbase)
    accuracy_roll = accuracy_roll * 2

    return (2 - accuracy_roll) * spreadbase + (math.max(1 - accuracy_roll, 0) ^ 2) * 0.001
end

function SWEP:GetBasedSpread()
    -- return ((self.SpreadBase or 0) / self:GetNWFloat("accuracy", 1)) + self:GetNWFloat("extraspread", 0)
    return CalculateRolledSpread(self:GetNWFloat("accuracy", 0.5), self.SpreadBase or 0)
end

function SWEP:GetSpray(curtime, firetime)
    -- local recoverytime = (self:GetOwner():Crouching() and self.RecoveryTimeCrouch or self.RecoveryTimeStand)
    -- recoverytime = recoverytime * (self.SprayMax / self.SprayIncrement)
    -- / recoverytime)
    local spraydecay = self:GetControl() * self.SprayDecay * Lerp(self:Standingness(), self.CrouchSprayDecayMultiplier, 1)

    return math.max(0, self:GetLastShotSpray() - math.max(0, (curtime or CurTime()) - (firetime or self:GetLastFire())) * spraydecay)
end

-- function SWEP:GetMaxClip1()
--     return self.Primary.ClipSize
-- end
-- function SWEP:GetMaxClip2()
--     return self.Secondary.ClipSize
-- end
function SWEP:PrimaryAttack()
    self:GunFire()

    if self.UseShellReload then
        self:SetSpecialReload(0)
    end

    if self.UnscopeOnShoot and self:IsScoped() then
        self:SetFOVRatio(1, 0)
    end
end

function SWEP:SecondaryAttack()
    if not self.ScopeLevels then return end
    local ply = self:GetOwner()

    -- if (self:GetZoomFullyActiveTime() > CurTime() or self:GetNextPrimaryFire() > CurTime()) then
    --     self:SetNextSecondaryFire(self:GetZoomFullyActiveTime() + 0.15)
    --     return
    -- end
    if self:IsScoped() then
        local nextlevel = 2

        for i = 2, #self.ScopeLevels do
            if math.abs(self.ScopeLevels[i] - self:GetTargetFOVRatio()) < 0.0001 then
                nextlevel = i + 1
            end
        end

        if nextlevel > #self.ScopeLevels then
            self:SetFOVRatio(1, 0.1)
        else
            self:SetFOVRatio(self.ScopeLevels[nextlevel], 0.08)
        end
    else
        self:SetFOVRatio(self.ScopeLevels[1], 0.15)
        self:SetNextPrimaryFire(math.max(CurTime() + 0.1, self:GetNextPrimaryFire()))
    end

    self:EmitSound("Default.Zoom", nil, nil, nil, CHAN_AUTO)
    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:Holster()
    self:SetInReload(false)

    return true
end

function SWEP:WeaponSound(soundtype)
    local sndname = (self.SoundData or {})[soundtype] or self.ShootSound

    if sndname then
        self:EmitSound(sndname, nil, nil, nil, CHAN_AUTO)
    end
end

--up_base, lateral_base, up_modifier, lateral_modifier, up_max, lateral_max, direction_change)
function SWEP:DoKickBack()
    -- if true then return end
    -- local up_base, lateral_base, up_modifier, lateral_modifier, up_max, lateral_max, direction_change = unpack(self.KickStanding)
    local mfac = self:MovementPenalty()
    local sfac = self:Standingness()
    local multiplier = Lerp(mfac, 1, self.MoveKickMultiplier) * Lerp(sfac, self.CrouchKickMultiplier, 1)
    local spraymodifier = self:GetSpray()
    local flKickUp = multiplier * (self.KickUBase + spraymodifier * self.KickUSpray) / self:GetControl()
    local flKickLateral = multiplier * (self.KickLBase + spraymodifier * self.KickLSpray) / self:GetControl()
    --[[
		Jvs:
			I implemented the shots fired and direction stuff on the cs base because it would've been dumb to do it
			on the player, since it's reset on a gun basis anyway
	]]
    -- This is the first round fired
    -- if self:GetShotsFired() == 1 then
    --     flKickUp = up_base
    --     flKickLateral = lateral_base
    -- else
    --     flKickUp = up_base + self:GetShotsFired() * up_modifier
    --     flKickLateral = lateral_base + self:GetShotsFired() * lateral_modifier
    -- end
    -- dont need these
    -- lateral_max, up_max = 10000000, 10000000
    local angle = self:GetOwner():GetViewPunchAngles()
    -- local orig = Angle(angle)
    -- angle.x = math.max(-up_max, angle.x - flKickUp)
    -- if self:GetDirection() == 1 then
    --     angle.y = math.min(lateral_max, angle.y + flKickLateral)
    -- else
    --     angle.y = math.max(-lateral_max, angle.y - flKickLateral)
    -- end
    angle.x = angle.x - flKickUp
    -- angle.y =  angle.y +  math.sin(CurTime()*5)*flKickLateral -- (self:GetKickLeft() and flKickLateral or -flKickLateral)
    angle.y = angle.y + (self:GetKickLeft() and flKickLateral or -flKickLateral)

    -- vel.x = vel.x - flKickUp
    if spraymodifier > self.KickDanceMinSpray and util.SharedRandom("KickBack", 0, 1) < ((self:GetInterval() * self.KickDance) * Lerp(mfac, 1, self.MoveKickDanceMultiplier) * Lerp(sfac, self.CrouchKickDanceMultiplier, 1)) then
        self:SetKickLeft(not self:GetKickLeft())
    end

    self:GetOwner():SetViewPunchAngles(angle)
    -- local vel = self:GetOwner():GetViewPunchVelocity()
    -- -- vel.p = vel.p - flKickUp
    -- -- print(vel, flKickUp)
    -- vel.p = vel.p*0.5
    -- self:GetOwner():SetViewPunchVelocity(vel)
    -- if CLIENT and IsFirstTimePredicted() then self:GetOwner():SetEyeAngles(self:GetOwner():EyeAngles() + angle - orig) end
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:SetDelayFire(true)
    self:SetSpecialReload(0)
    -- self:SetWeaponType(self.WeaponTypeToString[self.WeaponType])
    self:SetLastFire(CurTime())
    self:SetActualLastFire(CurTime())
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "LastShotSpray")
    self:NetworkVar("Float", 1, "SprayUpdateTime")
    -- self:NetworkVar("Float", 2, "Accuracy")
    -- self:NetworkVar("Float", 4, "NextDecreaseShotsFired")
    self:NetworkVar("Int", 0, "WeaponType")
    -- self:NetworkVar("Int", 1, "ShotsFired")
    self:NetworkVar("Int", 2, "Direction")
    self:NetworkVar("Int", 3, "WeaponID")
    self:NetworkVar("Int", 4, "SpecialReload")
    self:NetworkVar("Int", 5, "BurstFires") --goes from X to 0, how many burst fires we're going to do
    self:NetworkVar("Bool", 0, "InReload")
    self:NetworkVar("Bool", 1, "KickLeft")
    self:NetworkVar("Bool", 2, "DelayFire")
    --Jvs: stuff that is scattered around all the weapons code that I'm going to try and unify here
    -- self:NetworkVar("Float", 5, "ZoomFullyActiveTime")
    -- self:NetworkVar("Float", 6, "ZoomLevel")
    -- self:NetworkVar("Float", 7, "NextBurstFire") --when the next burstfire is gonna happen, same as nextprimaryattack
    -- self:NetworkVar("Float", 9, "BurstFireDelay") --the speed of the burst fire itself, 0.5 means two shots every second etc
    self:NetworkVar("Float", 10, "LastFire")
    self:NetworkVar("Float", 18, "ActualLastFire")
    self:NetworkVar("Float", 14, "PreviousTargetFOVRatio")
    self:NetworkVar("Float", 11, "TargetFOVRatio")
    self:NetworkVar("Float", 12, "TargetFOVStartTime")
    self:NetworkVar("Float", 13, "TargetFOVEndTime")
    self:NetworkVar("Float", 15, "NextIdle")
    -- self:NetworkVar("Float", 15, "StoredFOVRatio")
    -- self:NetworkVar("Float", 16, "LastZoom")
    -- self:NetworkVar("Bool", 5, "ResumeZoom")
    -- self:NetworkVar("Int", 5, "MaxBurstFires")
end

-- function SWEP:SetHoldType(ht)
--     self.keepht = ht
--     return BaseClass.SetHoldType(self, ht)
-- end
function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    self:SetDelayFire(false)
    -- self:SetZoomFullyActiveTime(-1)
    -- self:SetAccuracy(0.2)
    self:SetBurstFires(self.BurstFire or 0)
    -- self:SetCurrentFOVRatio(1)
    self:SetPreviousTargetFOVRatio(1)
    self:SetTargetFOVRatio(1)
    -- self:SetStoredFOVRatio(1)
    self:SetTargetFOVStartTime(0)
    self:SetTargetFOVEndTime(0)
    -- self:SetResumeZoom(false)
    -- if self.keepht then
    --     self:SetHoldType(self.keepht)
    -- end
    -- self:SetNextDecreaseShotsFired(CurTime())
    -- self:SetShotsFired(0)
    self:SetInReload(false)
    self:SendWeaponAnim(self:TranslateViewModelActivity(ACT_VM_DRAW))
    self.Owner:GetViewModel():SetPlaybackRate(self:GetHandling())
    self:SetNextPrimaryFire(CurTime() + (self:SequenceDuration() / self:GetHandling()))
    self:SetNextSecondaryFire(CurTime() + (self:SequenceDuration() / self:GetHandling()))

    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:GetOwner():SetFOV(0)
    end

    return true
end

-- --Jvs : this function handles the zoom smoothing and decay
-- function SWEP:HandleZoom()
--     --GOOSEMAN : Return zoom level back to previous zoom level before we fired a shot. This is used only for the AWP.
--     -- And Scout.
--     local ply = self:GetOwner()
--     if not ply:IsValid() then return end
--     if ((self:GetNextPrimaryFire() <= CurTime()) and self:GetResumeZoom()) then
--         if (self:GetFOVRatio() == self:GetLastZoom()) then
--             -- return the fade level in zoom.
--             self:SetResumeZoom(false)
--             return
--         end
--         self:SetFOVRatio(self:GetLastZoom(), 0.05)
--         self:SetNextPrimaryFire(CurTime() + 0.05)
--         self:SetZoomFullyActiveTime(CurTime() + 0.05) -- Make sure we think that we are zooming on the server so we don't get instant acc bonus
--     end
-- end
-- function SWEP:FOVThink()
--     local fovratio
--     local deltaTime = (CurTime() - self:GetTargetFOVStartTime()) / self:GetTargetFOVTime()
--     if (deltaTime > 1 or self:GetTargetFOVTime() == 0) then
--         fovratio = self:GetTargetFOVRatio()
--     else
--         fovratio = Lerp(math.Clamp(deltaTime, 0, 1), self:GetStoredFOVRatio(), self:GetTargetFOVRatio())
--     end
--     self:SetCurrentFOVRatio(fovratio)
-- end
function SWEP:SetFOVRatio(fov, time)
    -- if (self:GetFOVRatio() ~= self:GetStoredFOVRatio()) then
    --     self:SetStoredFOVRatio(self:GetFOVRatio())
    -- end
    self:SetPreviousTargetFOVRatio(self:GetTargetFOVRatio())
    self:SetTargetFOVRatio(fov)
    self:SetTargetFOVStartTime(CurTime())
    self:SetTargetFOVEndTime(CurTime() + time)
end

function SWEP:GetCurrentFOVRatio()
    local st = self:GetTargetFOVStartTime()

    return Lerp(math.Clamp((CurTime() - st) / (self:GetTargetFOVEndTime() - st), 0, 1), self:GetPreviousTargetFOVRatio(), self:GetTargetFOVRatio())
end

function SWEP:TranslateFOV(fov)
    return fov * self:GetCurrentFOVRatio()
end

--NOMINIFY
function SWEP:ShellReload()
    local ply = self.Owner
    if not IsValid(ply) then return end
    if ply:GetAmmoCount(self.Primary.Ammo) <= 0 or self:Clip1() >= self.Primary.ClipSize then return end
    if self:GetNextPrimaryFire() > CurTime() then return end

    if self:GetSpecialReload() == 0 then
        ply:SetAnimation(PLAYER_RELOAD)
        self:SendWeaponAnim(ACT_SHOTGUN_RELOAD_START)
        self:SetSpecialReload(1)
        self:SetNextPrimaryFire(CurTime() + 0.5)
        self:SetNextIdle(CurTime() + 0.5)
        -- DoAnimationEvent( PLAYERANIMEVENT_RELOAD_START ) - Missing event

        return true
    elseif self:GetSpecialReload() == 1 then
        if self:GetNextIdle() > CurTime() then return true end
        self:SetSpecialReload(2)
        self:SendWeaponAnim(ACT_VM_RELOAD)
        self:SetNextIdle(CurTime() + 0.5)

        if self:Clip1() >= self:GetMaxClip1() - 1 then
            ply:DoAnimationEvent(PLAYERANIMEVENT_RELOAD_END)
        else
            ply:DoAnimationEvent(PLAYERANIMEVENT_RELOAD_LOOP)
        end
    else
        self:SetClip1(self:Clip1() + 1)
        ply:DoAnimationEvent(PLAYERANIMEVENT_RELOAD)
        ply:RemoveAmmo(1, self.Primary.Ammo)
        self:SetSpecialReload(1)
    end

    return true
end

function SWEP:Reload()
    if self:GetMaxClip1() == -1 then return end
    if self.UseShellReload then return self:ShellReload() end

    if not self:GetInReload() and self:GetNextPrimaryFire() < CurTime() then
        -- self:SetShotsFired(0)
        local owner = self:GetOwner()
        if owner:GetAmmoCount(self:GetPrimaryAmmoType()) <= 0 then return false end
        if not (self:GetMaxClip1() ~= -1 and self:GetMaxClip1() > self:Clip1() and owner:GetAmmoCount(self:GetPrimaryAmmoType()) > 0) then return end
        self:WeaponSound("reload")
        self:SendWeaponAnim(self:TranslateViewModelActivity(ACT_VM_RELOAD))
        -- vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_PRIMARYATTACK))
        self.Owner:GetViewModel():SetPlaybackRate(self:GetHandling())
        owner:DoReloadEvent()
        local endtime = CurTime() + (self:SequenceDuration() / self:GetHandling())
        self:SetNextPrimaryFire(endtime)
        self:SetNextSecondaryFire(endtime)
        self:SetInReload(true)

        if self:IsScoped() then
            self:SetFOVRatio(1, 0.05)
        end
    end
end

function SWEP:Think()
    local ply = self:GetOwner()

    if self.UseShellReload then
        if self:GetNextIdle() < CurTime() then
            -- if self:Clip1() == 0 and self:GetSpecialReload() == 0 and ply:GetAmmoCount(self.Primary.Ammo) ~= 0 then
            --     self:ShellReload()
            -- else
            if self:GetSpecialReload() ~= 0 then
                if self:Clip1() ~= self:GetMaxClip1() and ply:GetAmmoCount(self.Primary.Ammo) ~= 0 then
                    self:ShellReload()
                else
                    self:SendWeaponAnim(ACT_SHOTGUN_RELOAD_FINISH)
                    self:SetSpecialReload(0)
                    self:SetNextIdle(CurTime() + 1)
                end
                -- else
                --     self:SendWeaponAnim(ACT_VM_IDLE)
            end
        end

        return
    end

    -- self:FOVThink()
    -- self:UpdateWorldModel()
    -- self:HandleZoom()
    --[[
		Jvs:
			this is where the reload actually ends, this might be moved into its own function so other coders
			can add other behaviours ( such as cs:go finishing the reload with a different delay, based on when the
			magazine actually gets inserted )
	]]
    if self:GetInReload() and self:GetNextPrimaryFire() <= CurTime() then
        -- complete the reload.
        --Jvs TODO: shotgun reloading here
        local j = math.min(self:GetMaxClip1() - self:Clip1(), ply:GetAmmoCount(self:GetPrimaryAmmoType()))
        -- Add them to the clip
        self:SetClip1(self:Clip1() + j)
        ply:RemoveAmmo(j, self:GetPrimaryAmmoType())
        self:SetInReload(false)
    end

    if CLIENT and game.SinglePlayer() then return end
    local plycmd = ply:GetCurrentCommand()

    -- if not plycmd:KeyDown(IN_ATTACK) and not plycmd:KeyDown(IN_ATTACK2) then
    --     -- no fire buttons down
    --     -- The following code prevents the player from tapping the firebutton repeatedly
    --     -- to simulate full auto and retaining the single shot accuracy of single fire
    --     if self:GetDelayFire() then
    --         self:SetDelayFire(false)
    --         if self:GetShotsFired() > 15 then
    --             self:SetShotsFired(15)
    --         end
    --         self:SetNextDecreaseShotsFired(CurTime() + 0.4)
    --     end
    --     -- REMOVED?
    --     -- if self:IsPistol() then
    --     --     self:SetShotsFired(0)
    --     -- else
    --     if self:GetShotsFired() > 0 and self:GetNextDecreaseShotsFired() < CurTime() then
    --         self:SetNextDecreaseShotsFired(CurTime() + 0.0225)
    --         self:SetShotsFired(self:GetShotsFired() - 1)
    --     end
    --     -- end
    --     -- there are no idle animations
    --     -- if CurTime() > self:GetNextIdle() and self:GetNextPrimaryFire() <= CurTime() and self:GetNextSecondaryFire() <= CurTime() and self:Clip1() ~= 0 then
    --     --     self:SetNextIdle(CurTime() + self.IdleInterval)
    --     --     self:SendWeaponAnim(self:TranslateViewModelActivity(ACT_VM_IDLE))
    --     -- end
    -- end
    -- if not self:GetInReload() and self.BurstFire and self:GetNextBurstFire() < CurTime() and self:GetNextBurstFire() ~= -1 then
    --     if self:GetBurstFires() < (self.BurstFire - 1) then
    --         if self:Clip1() <= 0 then
    --             self:SetBurstFires(self.BurstFire)
    --         else
    --             self:SetNextPrimaryFire(CurTime() - 1)
    --             self:PrimaryAttack()
    --             self:SetNextPrimaryFire(CurTime() + 0.5) --this artificial delay is inherited from the glock code
    --             self:SetBurstFires(self:GetBurstFires() + 1)
    --         end
    --     else
    --         if self:GetNextBurstFire() < CurTime() and self:GetNextBurstFire() ~= -1 then
    --             self:SetBurstFires(0)
    --             self:SetNextBurstFire(-1)
    --         end
    --     end
    -- end
    if not self:GetInReload() and self.BurstFire then
        if self:GetBurstFires() < self.BurstFire and self:GetNextPrimaryFire() < CurTime() then
            self:PrimaryAttack()
        end
    end
end

function SWEP:DoFireEffects()
    if CLIENT and self:IsCarriedByLocalPlayer() and not self:GetOwner():ShouldDrawLocalPlayer() then return end
    --Jvs NOTE: prediction should already prevent this from sending the effect to the owner's client side
    local data = EffectData()
    data:SetFlags(0)
    data:SetEntity(self)
    data:SetAttachment(self:LookupAttachment("muzzle"))
    data:SetScale(self.CSMuzzleFlashScale)
    util.Effect(self.CSMuzzleX and "CS_MuzzleFlash_X" or "CS_MuzzleFlash", data)
end

function SWEP:TranslateViewModelActivity(act)
    return act
end

function SWEP:AdjustMouseSensitivity()
    local r = self:GetCurrentFOVRatio()
    if r < 1 then return r * GetConVar("zoom_sensitivity_ratio"):GetFloat() end
end

function SWEP:IsScoped()
    return self:GetCurrentFOVRatio() < 1
end

function SWEP:GunFire()
    local scoped = self:IsScoped()
    local ply = self:GetOwner()
    -- print("GF",cycletime)
    -- cycletime=cycletime*10 
    self:SetDelayFire(true)

    -- self:SetShotsFired(self:GetShotsFired() + 1)
    -- -- These modifications feed back into flSpread eventually.
    -- if pCSInfo.AccuracyDivisor ~= -1 then
    -- 	local iShotsFired = self:GetShotsFired()
    -- 	if pCSInfo.AccuracyQuadratic then
    -- 		iShotsFired = iShotsFired * iShotsFired
    -- 	else
    -- 		iShotsFired = iShotsFired * iShotsFired * iShotsFired 
    -- 	end
    -- 	self:SetAccuracy(( iShotsFired / pCSInfo.AccuracyDivisor) + pCSInfo.AccuracyOffset )
    -- 	if self:GetAccuracy() > pCSInfo.MaxInaccuracy then
    -- 		self:SetAccuracy( pCSInfo.MaxInaccuracy )
    -- 	end
    -- end
    -- Out of ammo?
    if self:Clip1() <= 0 then
        self:EmitSound((self.GunType == "pistol" or self.GunType == "heavypistol") and "Default.ClipEmpty_Pistol" or "Default.ClipEmpty_Rifle", nil, nil, nil, CHAN_AUTO)
        self:SetNextPrimaryFire(CurTime() + 0.2)

        return false
    end

    self:SendWeaponAnim(self:TranslateViewModelActivity(ACT_VM_PRIMARYATTACK))
    -- if self.Owner:SteamID() ~= "STEAM_0:0:38422842" then
    self:SetClip1(self:Clip1() - 1)

    -- end
    if SERVER and (ply.GetLocationName and ply:GetLocationName() == "Weapons Testing Range") then
        ply:GiveAmmo(1, self:GetPrimaryAmmoType())
    end

    -- player "shoot" animation
    ply:DoAttackEvent()
    spread = self:GetSpread()
    -- self:FireCSSBullet(ply:GetAimVector():Angle() + 2 * ply:GetViewPunchAngles(), primarymode, spread)
    -- >1 is good cuz the bullets will always appear below the crosshair otherwise (cuz the kick happens after the shot)
    local recoil_factor = 1.5
    local ang = ply:EyeAngles() + ply:GetViewPunchAngles() * recoil_factor
    --use "special1" for silenced m4 and usp
    self:WeaponSound("single_shot")
    local a = util.SharedRandom("SpreadAngle", 0, 2 * math.pi)
    local r = spread * (util.SharedRandom("SpreadRadius", 0, 1) ^ 0.5)
    local x = nil
    local y = nil
    dir = ang:Forward() + math.sin(a) * r * ang:Right() + math.cos(a) * r * ang:Up()
    dir:Normalize()
    -- self:PenetrateBullet(dir, ply:GetShootPos(), self.Range, self.Penetration, self.Damage, self.RangeModifier) --, self:GetPenetrationFromBullet())
    -- flCurrentDistance = flCurrentDistance or 0
    local hdd = self.HalfDamageDistance * self:GetNWFloat("range", 1)
    local dist = hdd * 4

    self:GetOwner():FireBullets({
        Num = self.NumPellets,
        AmmoType = self.Primary.Ammo,
        Distance = dist,
        Tracer = 1,
        Damage = self.Damage,
        Src = ply:GetShootPos(),
        Dir = dir,
        Spread = Vector(self.PelletSpread, self.PelletSpread, 0),
        Callback = function(hitent, trace, dmginfo)
            dmginfo:SetInflictor(self)
            local scale = 1

            if hdd > 0 then
                scale = scale * math.pow(0.5, (trace.Fraction * dist) / hdd)
            end

            if trace.HitGroup == HITGROUP_HEAD then
                scale = scale * (self.HeadshotMultiplier or 1)
            end

            if trace.HitGroup == HITGROUP_LEFTLEG or trace.HitGroup == HITGROUP_RIGHTLEG then
                scale = scale * (self.LegshotMultiplier or 1)
            end

            dmginfo:SetDamage(math.Round(scale * self.Damage))
        end
    })

    self:DoFireEffects()
    local correctedcurtime = CurTime()
    local ti = engine.TickInterval()

    -- its been within the full auto number of ticks
    if CurTime() - self:GetActualLastFire() < math.ceil(self:GetInterval() / ti) * ti + 0.001 then
        -- print("CORRECT", correctedcurtime-self:GetLastFire())
        correctedcurtime = self:GetLastFire() + self:GetInterval()
    else
    end

    -- print("NOCORRECT", correctedcurtime - self:GetLastFire())
    self:SetNextPrimaryFire(correctedcurtime + self:GetInterval() - ti / 4)
    self:SetNextSecondaryFire(correctedcurtime + self:GetInterval() - ti / 4)

    if self.BurstFire then
        -- if self:Clip1()==0 then self:SetBurstFires(self.BurstFire)
        self:SetBurstFires(self:GetBurstFires() - 1)

        if self:GetBurstFires() <= 0 or self:Clip1() == 0 then
            self:SetNextPrimaryFire(correctedcurtime + self.BurstFireInterval)
            self:SetBurstFires(self.BurstFire)
        end
    end

    -- self:SetNextIdle(CurTime() + self.TimeToIdle)
    -- if self.BurstFire then
    --     self:SetNextBurstFire(CurTime() + self.BurstFireDelay)
    -- else
    --     self:SetNextBurstFire(-1)
    -- end
    local curspray = self:GetSpray(correctedcurtime)

    -- if self.Owner:SteamID() == "STEAM_0:0:38422842" then
    --     print("SPRAY", curspray)
    -- end
    -- make sure initial shots are always to the right
    if curspray == 0 then
        -- self:SetDanceTime(CurTime()+self.KickDanceMinInterval)
        self:SetKickLeft(false)
    end

    -- print("SS", curspray, self.SpraySaturation)
    self:DoKickBack()
    -- if self.KickSimple then
    --     local a = self:GetOwner():GetViewPunchAngles()
    --     a.p = a.p - self.KickSimple
    --     self:GetOwner():SetViewPunchAngles(a)
    -- elseif self:GetOwner():GetAbsVelocity():Length2DSqr() > 25 or not self:GetOwner():OnGround() then
    --     self:DoKickBack(unpack(self.KickMoving))
    -- elseif self:GetOwner():Crouching() then
    --     self:DoKickBack(unpack(self.KickCrouching))
    -- else
    --     self:DoKickBack(unpack(self.KickStanding))
    -- end
    -- spray affects kickback, so update after
    -- TODO: change to self:GetSpray() + (self.SprayIncrement * (1-self:GetSpray()))
    -- self:SetLastShotSpray(math.min(1, self:GetSpray() + self.SprayIncrement))
    -- self:SetLastShotSpray(math.min(1, curspray + (self.SprayIncrement * (1-self:GetSpray()))  ))
    self:SetLastShotSpray(curspray + (self.SprayIncrement / (self.SpraySaturation ^ curspray)))
    self:SetLastFire(correctedcurtime) --CurTime())
    self:SetActualLastFire(CurTime())

    if CLIENT and IsFirstTimePredicted() then
        self.LastFireSysTime = SysTime()
    end

    --     self.realstuff = {self:GetLastShotSpray(), self:GetLastFire(), self:GetActualLastFire()}
    -- else
    --     self:SetLastShotSpray(self.realstuff[1])
    --     self:SetLastFire(self.realstuff[2])
    --     self:SetActualLastFire(self.realstuff[3])
    -- end
    -- print(CurTime())
    if IsFirstTimePredicted() and self.Owner:SteamID() == "STEAM_0:0:38422842" then
        self.SPS = (self.SPS or 0) + 1
        -- print(engine.TickCount() - (self.LTC or 0))
        self.LTC = engine.TickCount()

        if math.floor(correctedcurtime) > (self.LastShotSecond or 0) then
            print("SPS", self.SPS)
            self.SPS = 0
            self.LastShotSecond = math.floor(correctedcurtime)
        end
    end

    return true
end

function SWEP:MovementPenalty(clientsmoothing)
    -- softplus: ln(1+exp x)
    local x = (self.Owner:OnGround() or self.Owner:GetMoveType() == MOVETYPE_NOCLIP) and math.Clamp((self:GetOwner():GetAbsVelocity():Length2D() - 10) / 100, 0, 1) or 1

    if clientsmoothing then
        local t = engine.TickInterval()
        self.RunningAverageMovementPenalties = self.RunningAverageMovementPenalties or {}

        table.insert(self.RunningAverageMovementPenalties, {x, CurTime()})

        while self.RunningAverageMovementPenalties[1][2] <= CurTime() - engine.TickInterval() do
            table.remove(self.RunningAverageMovementPenalties, 1)
        end

        local sum = 0

        for i, v in ipairs(self.RunningAverageMovementPenalties) do
            sum = sum + v[1]
        end

        return sum / (#self.RunningAverageMovementPenalties)
    end

    return x
end

-- Note: self.SpreadStand only applies when unscoped
function SWEP:GetSpread(clientsmoothing)
    local mobilitymod = 2 ^ (self:GetMobility() - 0.5)
    local spread = self:GetBasedSpread() + self:MovementPenalty(clientsmoothing) * (self.SpreadMove or 0) / mobilitymod

    if not self:IsScoped() then
        spread = spread + (self.SpreadUnscoped or 0)
    end

    local spray = clientsmoothing and self:GetSpray(SysTime(), self.LastFireSysTime or 0) or self:GetSpray()
    -- crouch spread multiplier is NOT applied to spray, because spray decay handles it

    return (Lerp(self:Standingness(), self.CrouchSpreadMultiplier, 1) * spread) + (self.Spray * (spray ^ self.SprayExponent))
end

function SWEP:GetSpeedRatio()
    local spd = self.MoveSpeed or 1

    if self:IsScoped() then
        spd = spd * (self.ScopedSpeedRatio or 0.5)
    end

    local mobilityloss = 2 * (1 - self:GetMobility())

    return 1 - ((1 - spd) * mobilityloss)
end

function SWEP:SetupMove(ply, mv, cmd)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * self:GetSpeedRatio())
end
-- function SWEP:GetSpread(clientsmoothing)
--     local ply = self:GetOwner()
--     if not ply:IsValid() then return end
--     -- local spread
--     local movepenalty = self:MovementPenalty(clientsmoothing)
--     --added
--     if self.WeaponType == "Rifle" or self.WeaponType == "SniperRifle" then
--         movepenalty = movepenalty * 2
--     end
--     --and not self:GetBurstFireEnabled()) then
--     if not self:IsScoped() then
--         spread = self.Spread + (ply:Crouching() and self.InaccuracyCrouch or self.InaccuracyStand)
--         if (ply:GetMoveType() == MOVETYPE_LADDER) then
--             spread = spread + self.InaccuracyLadder
--         end
--         -- if (ply:GetAbsVelocity():Length2D() > 50) then
--         spread = spread + self.InaccuracyMove * movepenalty
--         -- end
--         if (not ply:IsOnGround()) then
--             spread = spread + self.InaccuracyJump
--         end
--     else
--         spread = self.SpreadAlt + (ply:Crouching() and self.InaccuracyCrouchAlt or not ply:IsOnGround() and self.InaccuracyJumpAlt or self.InaccuracyStandAlt)
--         if (ply:GetMoveType() == MOVETYPE_LADDER) then
--             spread = spread + self.InaccuracyLadderAlt
--         end
--         -- if (ply:GetAbsVelocity():Length2D() > 50) then
--         spread = spread + self.InaccuracyMoveAlt * movepenalty
--         -- end
--         if (not ply:IsOnGround()) then
--             spread = spread + self.InaccuracyJumpAlt
--         end
--     end
--     --added
--     spread = spread * 1.5
--     -- local accuracy = 0.2
--     -- -- These modifications feed back into flSpread eventually.
--     -- if self.AccuracyDivisor ~= -1 then
--     --     local iShotsFired = self:GetShotsFired()
--     --     if self.AccuracyQuadratic then
--     --         iShotsFired = iShotsFired * iShotsFired
--     --     else
--     --         iShotsFired = iShotsFired * iShotsFired * iShotsFired
--     --     end
--     --     accuracy = math.min((iShotsFired / self.AccuracyDivisor) + self.AccuracyOffset, self.MaxInaccuracy)
--     -- end
--     -- -- print("AC9", accuracy, spread)
--     -- if self.GunType == "pistol" or self.GunType == "sniper" then
--     --     accuracy = (1 - accuracy)
--     -- end
--     --(1 - self:GetAccuracy())
--     -- print("SPRAY", self:GetSpray(), self.SprayMax)
--     local sprayfactor = ((self:GetSpray() ^ self.SprayExponent) * (self.SprayMax - self.SprayMin)) + self.SprayMin
--     -- print("NEW")
--     -- sprayfactor = accuracy
--     -- print("SPR", self.SprayMax, self.SprayIncrement, self.AccuracyDivisor)
--     return spread * sprayfactor
-- end 
-- -- OLD
-- function SWEP:BuildSpread()
--     -- local ply = self:GetOwner()
--     -- if not ply:IsValid() then return end
--     -- local spread
--     -- --and not self:GetBurstFireEnabled() and not self:IsSilenced()) then
--     -- if (not self:IsScoped()) then
--     --     spread = self.Spread + (ply:Crouching() and self.InaccuracyCrouch or self.InaccuracyStand)
--     --     if (ply:GetMoveType() == MOVETYPE_LADDER) then
--     --         spread = spread + self.InaccuracyLadder
--     --     end
--     --     if (ply:GetAbsVelocity():Length2D() > 5) then
--     --         spread = spread + self.InaccuracyMove
--     --     end
--     --     if (not ply:IsOnGround()) then
--     --         spread = spread + self.InaccuracyJump
--     --     end
--     -- else
--     --     spread = self.SpreadAlt + (ply:Crouching() and self.InaccuracyCrouchAlt or not ply:IsOnGround() and self.InaccuracyJumpAlt or self.InaccuracyStandAlt)
--     --     if (ply:GetMoveType() == MOVETYPE_LADDER) then
--     --         spread = spread + self.InaccuracyLadderAlt
--     --     end
--     --     if (ply:GetAbsVelocity():Length2D() > 5) then
--     --         spread = spread + self.InaccuracyMoveAlt
--     --     end
--     --     if (not ply:IsOnGround()) then
--     --         spread = spread + self.InaccuracyJumpAlt
--     --     end
--     -- end
--     -- return spread * (1 - self:GetAccuracy())
--     return 0
-- end
-- function SWEP:GetPenetrationFromBullet()
--     local iBulletType = self.Primary.Ammo
--     local fPenetrationPower, flPenetrationDistance
--     if iBulletType == "BULLET_PLAYER_50AE" then
--         fPenetrationPower = 30
--         flPenetrationDistance = 1000.0
--     elseif iBulletType == "BULLET_PLAYER_762MM" then
--         fPenetrationPower = 39
--         flPenetrationDistance = 5000.0
--     elseif iBulletType == "BULLET_PLAYER_556MM" or iBulletType == "BULLET_PLAYER_556MM_BOX" then
--         fPenetrationPower = 35
--         flPenetrationDistance = 4000.0
--     elseif iBulletType == "BULLET_PLAYER_338MAG" then
--         fPenetrationPower = 45
--         flPenetrationDistance = 8000.0
--     elseif iBulletType == "BULLET_PLAYER_9MM" then
--         fPenetrationPower = 21
--         flPenetrationDistance = 800.0
--     elseif iBulletType == "BULLET_PLAYER_BUCKSHOT" then
--         fPenetrationPower = 0
--         flPenetrationDistance = 0.0
--     elseif iBulletType == "BULLET_PLAYER_45ACP" then
--         fPenetrationPower = 15
--         flPenetrationDistance = 500.0
--     elseif iBulletType == "BULLET_PLAYER_357SIG" then
--         fPenetrationPower = 25
--         flPenetrationDistance = 800.0
--     elseif iBulletType == "BULLET_PLAYER_57MM" then
--         fPenetrationPower = 30
--         flPenetrationDistance = 2000.0
--     else
--         assert(false)
--         fPenetrationPower = 0
--         flPenetrationDistance = 0.0
--     end
--     return fPenetrationPower, flPenetrationDistance
-- end
-- function SWEP:TraceToExit(start, dir, endpos, stepsize, maxdistance)
--     local flDistance = 0
--     local last = start
--     while (flDistance < maxdistance) do
--         flDistance = flDistance + stepsize
--         endpos:Set(start + flDistance * dir)
--         if bit.band(util.PointContents(endpos), MASK_SOLID) == 0 then return true, endpos end
--     end
--     return false
-- end
-- -- TODO: Make this not do this????
-- local PenetrationValues = {}
-- local function set(values, ...)
--     for i = 1, select("#", ...) do
--         PenetrationValues[select(i, ...)] = values
--     end
-- end
-- -- flPenetrationModifier, flDamageModifier
-- -- flDamageModifier should always be less than flPenetrationModifier
-- set({0.3, 0.1}, MAT_CONCRETE, MAT_METAL)
-- set({0.8, 0.7}, MAT_FOLIAGE, MAT_SAND, MAT_GRASS, MAT_DIRT, MAT_FLESH, MAT_GLASS, MAT_COMPUTER, MAT_TILE, MAT_WOOD, MAT_PLASTIC, MAT_SLOSH, MAT_SNOW)
-- set({0.5, 0.45}, MAT_FLESH, MAT_ALIENFLESH, MAT_ANTLION, MAT_BLOODYFLESH, MAT_SLOSH, MAT_CLIP)
-- set({1, 0.99}, MAT_GRATE)
-- set({0.5, 0.45}, MAT_DEFAULT)
-- function SWEP:ImpactTrace(tr)
--     local e = EffectData()
--     e:SetOrigin(tr.HitPos)
--     e:SetStart(tr.StartPos)
--     e:SetSurfaceProp(tr.SurfaceProps)
--     e:SetDamageType(DMG_BULLET)
--     e:SetHitBox(0)
--     if CLIENT then
--         e:SetEntity(game.GetWorld())
--     else
--         e:SetEntIndex(0)
--     end
--     util.Effect("Impact", e)
-- end
-- function SWEP:PenetrateBullet(dir, vecStart, flDistance, iPenetration, iDamage, flRangeModifier, fPenetrationPower, flPenetrationDistance, flCurrentDistance)
--     flCurrentDistance = flCurrentDistance or 0
--     self.HalfDamageDistance 
--     self:GetOwner():FireBullets{
--         AmmoType = self.Primary.Ammo,
--         Distance = flDistance,
--         Tracer = 1,
--         Damage = iDamage,
--         Src = vecStart,
--         Dir = dir,
--         Spread = vector_origin,
--         Callback = function(hitent, trace, dmginfo)
--             dmginfo:SetInflictor(self)
--             if self.HalfDamageDistance > 0 then
--                 dmginfo:ScaleDamage( math.pow(0.5, (trace.Fraction * flDistance) / self.HalfDamageDistance ) )
--             end
--             if trace.HitGroup == HITGROUP_HEAD then
--                 dmginfo:ScaleDamage(self.HeadshotMultiplier or 1)
--             end
--         end
--     }
--     -- if (trace.Fraction == 1) then return end
--     -- -- TODO: convert this to physprops? there doesn't seem to be a way to get penetration from those
--     -- local flPenetrationModifier, flDamageModifier = unpack(PenetrationValues[trace.MatType] or PenetrationValues[MAT_DEFAULT])
--     -- flCurrentDistance = flCurrentDistance + trace.Fraction * (trace.HitPos - vecStart):Length()
--     -- iDamage = iDamage * flRangeModifier ^ (flCurrentDistance / 500)
--     -- if (flCurrentDistance > flPenetrationDistance and iPenetration > 0) then
--     --     iPenetration = 0
--     -- end
--     -- if iPenetration == 0 and not trace.MatType == MAT_GRATE then return end
--     -- if iPenetration < 0 then return end
--     -- local penetrationEnd = Vector()
--     -- if not self:TraceToExit(trace.HitPos, dir, penetrationEnd, 24, 128) then return end
--     -- local hitent_already = false
--     -- local tr = util.TraceLine{
--     --     start = penetrationEnd,
--     --     endpos = trace.HitPos,
--     --     mask = MASK_SHOT,
--     --     filter = function(e)
--     --         local ret = e:IsPlayer()
--     --         if (ret and not hitent_already) then
--     --             hitent_already = true
--     --             return false
--     --         end
--     --         return true
--     --     end
--     -- }
--     -- bHitGrate = tr.MatType == MAT_GRATE and bHitGrate
--     -- local iExitMaterial = tr.MatType
--     -- if (iExitMaterial == trace.MatType) then
--     --     i
