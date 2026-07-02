if _G.NPCKillTesterPro and _G.NPCKillTesterPro.Unload then
    _G.NPCKillTesterPro.Unload()
    task.wait(0.3)
end

_G.NPCKillTesterPro = {}

local rs = game:GetService("RunService")
local ws = game:GetService("Workspace")
local plrs = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local lp = plrs.LocalPlayer
local mouse = lp:GetMouse()
local ts = game:GetService("TweenService")

local selectedNPCs = {}
local currentNPC = nil
local connections = {}
local highlights = {}

local DeepAnalysisData = { CombatRemotes = {}, MapHazards = {}, DeathSignals = {}, WeaponRemotes = {}, TaggedKillBricks = {} }

local function track(name, con) if con then connections[name] = con end end
local function dis(name) if connections[name] then connections[name]:Disconnect(); connections[name] = nil end end

local highlight = Instance.new("Highlight")
highlight.Parent = lp
highlight.FillTransparency = 1
highlight.OutlineTransparency = 1

local function light(adornee, color)
    task.spawn(function()
        if not adornee then return end
        highlight.Adornee = adornee
        highlight.OutlineColor = color or Color3.fromRGB(255,255,255)
        ts:Create(highlight, TweenInfo.new(0.3), {OutlineTransparency = 0}):Play()
        task.wait(0.35)
        ts:Create(highlight, TweenInfo.new(0.4), {OutlineTransparency = 1}):Play()
    end)
end

-- ==================== АВТОМАТИЧЕСКИЙ СУПЕР-АНАЛИЗАТОР ИГРЫ (С ФИЛЬТРОМ БАНОВ) ====================
local function indexObject(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = string.lower(obj.Name)
            local fnm = obj.Parent and string.lower(obj.Parent.Name) or ""
            local isHoneypot = string.find(nm, "ban") or string.find(nm, "kick") or string.find(nm, "admin") or string.find(nm, "anticheat") or string.find(nm, "ac_") or string.find(nm, "log") or string.find(nm, "report") or string.find(nm, "detect") or string.find(nm, "security") or string.find(nm, "flag") or string.find(fnm, "ban") or string.find(fnm, "kick") or string.find(fnm, "admin") or string.find(fnm, "anticheat")
            if not isHoneypot then
                if string.find(nm, "attack") or string.find(nm, "damage") or string.find(nm, "hit") or string.find(nm, "combat") or string.find(nm, "kill") or string.find(nm, "strike") or string.find(fnm, "remote") or string.find(fnm, "event") or string.find(fnm, "net") or string.find(fnm, "skill") then
                    if not table.find(DeepAnalysisData.CombatRemotes, obj) then table.insert(DeepAnalysisData.CombatRemotes, obj) end
                end
            end
        end
        if obj:IsA("BasePart") then
            local nm = string.lower(obj.Name)
            local hasTouch = obj:FindFirstChildOfClass("TouchTransmitter") ~= nil
            if string.find(nm, "kill") or string.find(nm, "lava") or string.find(nm, "hazard") or string.find(nm, "spike") or string.find(nm, "acid") or string.find(nm, "death") or string.find(nm, "void") or (hasTouch and string.find(nm, "trap")) then
                if not table.find(DeepAnalysisData.MapHazards, obj) then table.insert(DeepAnalysisData.MapHazards, obj) end
            end
        end
        if obj:IsA("Tool") or obj:IsA("HopperBin") then
            for _,rem in ipairs(obj:GetDescendants()) do
                if (rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction") or rem:IsA("BindableEvent")) and not table.find(DeepAnalysisData.WeaponRemotes, rem) then
                    table.insert(DeepAnalysisData.WeaponRemotes, rem)
                end
            end
        end
    end)
end

local function runFullAnalysis()
    DeepAnalysisData = { CombatRemotes = {}, MapHazards = {}, DeathSignals = {}, WeaponRemotes = {}, TaggedKillBricks = {} }
    for _,o in ipairs(rep:GetDescendants()) do indexObject(o) end
    for _,o in ipairs(ws:GetDescendants()) do indexObject(o) end
    for _,p in ipairs(plrs:GetPlayers()) do
        local bp = p:FindFirstChild("Backpack")
        if bp then for _,o in ipairs(bp:GetDescendants()) do indexObject(o) end end
    end
    pcall(function()
        for _,tag in ipairs({"KillBrick", "Hazard", "Lava", "Spike", "DamageZone", "Deadly", "KillZone"}) do
            for _,tagged in ipairs(CollectionService:GetTagged(tag)) do
                if tagged:IsA("BasePart") and not table.find(DeepAnalysisData.TaggedKillBricks, tagged) then table.insert(DeepAnalysisData.TaggedKillBricks, tagged) end
            end
        end
    end)
    print("[🤖 AUTO ANALYZER] Безопасная база обновлена! Ремоутов без банов:", #DeepAnalysisData.CombatRemotes, "| Ловушек:", #DeepAnalysisData.MapHazards)
end

ws.DescendantAdded:Connect(indexObject); rep.DescendantAdded:Connect(indexObject)

-- ==================== ПАРАМЕТРИЧЕСКОЕ ОБНАРУЖЕНИЕ БЕЗ СЛОВ И БЕЗ ЛАГОВ ====================

local function getRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart 
            or obj:FindFirstChild("HumanoidRootPart") 
            or obj:FindFirstChild("Torso") 
            or obj:FindFirstChild("UpperTorso") 
            or obj:FindFirstChild("Root") 
            or obj:FindFirstChild("Body") 
            or obj:FindFirstChild("Main")
            or obj:FindFirstChild("Hitbox")
            or obj:FindFirstChild("Head")
            or obj:FindFirstChildOfClass("BasePart")
    elseif obj:IsA("Folder") or obj:IsA("Configuration") then
        return obj:FindFirstChild("HumanoidRootPart", true)
            or obj:FindFirstChild("Torso", true)
            or obj:FindFirstChild("Root", true)
            or obj:FindFirstChild("Body", true)
            or obj:FindFirstChild("Main", true)
            or obj:FindFirstChildOfClass("BasePart", true)
    end
    return nil
end

local function isParametricCreature(model)
    if not model or not model:IsA("Model") then return false end
    if model == ws or model == lp.Character then return false end
    if plrs:GetPlayerFromCharacter(model) ~= nil then return false end
    
    local partsCount = 0
    for _, child in ipairs(model:GetChildren()) do if child:IsA("BasePart") then partsCount = partsCount + 1 end end
    if partsCount == 0 and not model:FindFirstChildOfClass("Model") then return false end
    if partsCount > 350 then return false end
    
    if model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("ControllerManager") then return true end
    if model:FindFirstChildOfClass("Bone", true) then return true end
    if model:FindFirstChild("Health", true) or model:FindFirstChild("HP", true) or model:FindFirstChild("MaxHealth", true) or model:GetAttribute("Health") or model:GetAttribute("HP") or model:GetAttribute("Enemy") or model:GetAttribute("Boss") then return true end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("Motor6D") or desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") or desc:IsA("AlignPosition") or desc:IsA("RigidConstraint") then return true end
    end
    return false
end

local function getAllValidEntities()
    local rawCandidates = {}
    for _, obj in ipairs(ws:GetDescendants()) do
        if obj:IsA("Model") and obj ~= lp.Character and not plrs:GetPlayerFromCharacter(obj) then
            if isParametricCreature(obj) then table.insert(rawCandidates, obj) end
        end
    end
    local finalEntities = {}
    for _, cand in ipairs(rawCandidates) do
        local isContainer = false
        for _, other in ipairs(rawCandidates) do
            if cand ~= other and other:IsDescendantOf(cand) then isContainer = true; break end
        end
        if not isContainer then table.insert(finalEntities, cand) end
    end
    return finalEntities
end

local function analyzeEntity(obj)
    local root = getRootPart(obj); if not root then return false, nil, nil, false, nil end
    local isAnchored = root.Anchored
    local hum = obj:FindFirstChildOfClass("Humanoid") or (obj:IsA("Folder") and obj:FindFirstChildOfClass("Humanoid", true))
    local anim = obj:FindFirstChildOfClass("AnimationController") or (obj:IsA("Folder") and obj:FindFirstChildOfClass("AnimationController", true))
    local valHP = obj:FindFirstChild("Health", true) or obj:FindFirstChild("HP", true) or obj:FindFirstChild("MaxHealth", true)
    local attrHP = obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("Enemy") or obj:GetAttribute("IsEnemy") or obj:GetAttribute("Boss")
    
    local nameLower = string.lower(obj.Name)
    local isBoss = string.find(nameLower, "boss") or string.find(nameLower, "killer") or string.find(nameLower, "thanos")
    local isRobot = string.find(nameLower, "robot") or string.find(nameLower, "bot") or string.find(nameLower, "droid") or string.find(nameLower, "mech") or string.find(nameLower, "робот") or string.find(nameLower, "бот")

    local entityType = "Unknown"; local hpText = "N/A"
    if hum then
        entityType = isBoss and "[👑 Boss Hum]" or (isRobot and "[🤖 Робот/Humanoid]" or "[🚶 Humanoid]")
        hpText = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    elseif anim then
        entityType = isBoss and "[👑 Boss Anim]" or (isRobot and "[🤖 Робот/Anim Rig]" or "[🤖 AnimCtrl]")
        if valHP and (valHP:IsA("NumberValue") or valHP:IsA("IntValue")) then hpText = tostring(valHP.Value).." (Val)"
        elseif attrHP then hpText = tostring(attrHP).." (Attr)" else hpText = "No HP Bar" end
    elseif valHP or attrHP then
        entityType = isBoss and "[👑 Boss Stat]" or "[📊 Value/Attr]"
        if valHP and (valHP:IsA("NumberValue") or valHP:IsA("IntValue")) then hpText = tostring(valHP.Value).." (Val)"
        else hpText = tostring(attrHP).." (Attr)" end
    else
        entityType = isBoss and "[👑 Boss Rig]" or (isRobot and "[🤖 Робот/Entity]" or "[🦾 Custom Rig]")
        hpText = "Rig/Timer"
    end
    return true, entityType, hpText, isAnchored, root
end

local function checkOwnership(part)
    if not part or not part:IsA("BasePart") then return "[NO PART]" end
    if part.Anchored then return "[⚓ ANCHORED]" end
    local ok, owner = pcall(function() return part:IsNetworkOwner() end)
    if ok and owner then return "[✅ ME]" else return "[🌐 SERVER/OTHER]" end
end

local function getTargets()
    local t = {}
    for obj,_ in pairs(selectedNPCs) do
        if obj and obj.Parent then table.insert(t, obj) else selectedNPCs[obj] = nil end
    end
    if #t == 0 and currentNPC and currentNPC.Parent then table.insert(t, currentNPC) end
    return t
end

-- ЩАДЯЩИЙ ЗАХВАТ ВЛАДЕНИЯ (SBBF SAFE CLAIM): Без взрывного буста радиуса до 1e15, который агрит античит SBBF!
local function claimFE(obj)
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(lp, "SimulationRadius", 1000) -- Безопасный радиус 1000 стадов!
            sethiddenproperty(lp, "MaximumSimulationRadius", 1000)
        end
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") and not p.Anchored then pcall(function() p:SetNetworkOwner(lp) end) end
        end
    end)
end

-- ==================== АРСЕНАЛ ВНУТРЕННИХ МЕТОДОВ ====================

local function kill_1_SimpleHP(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
    if hum then pcall(function() hum.Health = 0; hum:TakeDamage(999999) end) end
end

local function kill_2_RagdollStateDead(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead); hum:ChangeState(Enum.HumanoidStateType.FallingDown); hum.PlatformStand = true; hum.Sit = true; hum.WalkSpeed = 0; hum.JumpPower = 0 end) end
end

local function kill_3_BreakJointsMotorsLoop(obj)
    claimFE(obj); task.spawn(function()
        for i=1,28 do
            if not obj or not obj.Parent then break end
            pcall(function() if obj.BreakJoints then obj:BreakJoints() end end)
            for _,v in ipairs(obj:GetDescendants()) do
                if v:IsA("Motor6D") or v:IsA("Motor") or v:IsA("Weld") or v:IsA("ManualWeld") or v:IsA("Snap") or v:IsA("JointInstance") then pcall(function() v:Destroy() end) end
            end
            local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
            if hum and i % 3 == 0 then pcall(function() hum.Health = 0; hum:TakeDamage(999999) end) end
            task.wait(0.022)
        end
    end)
end

local function kill_4_ValueAttrZero(obj)
    claimFE(obj); for _,val in ipairs(obj:GetDescendants()) do
        if val:IsA("NumberValue") or val:IsA("IntValue") or val:IsA("DoubleConstrainedValue") then
            local nm = string.lower(val.Name)
            if string.find(nm, "hp") or string.find(nm, "health") or string.find(nm, "life") or string.find(nm, "shield") then pcall(function() val.Value = 0 end) end
        end
    end
    for attr, _ in pairs(obj:GetAttributes()) do
        local nm = string.lower(attr)
        if string.find(nm, "hp") or string.find(nm, "health") or string.find(nm, "life") then pcall(function() obj:SetAttribute(attr, 0) end) end
    end
end

local function kill_5_DecapitateHeadTorso(obj)
    claimFE(obj); for _,part in ipairs(obj:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name == "Head" or part.Name == "Torso" or part.Name == "UpperTorso") then
            pcall(function()
                for _,w in ipairs(part:GetChildren()) do if w:IsA("JointInstance") or w:IsA("Weld") or w:IsA("Motor6D") or w:IsA("WeldConstraint") then w:Destroy() end end
                part.AssemblyLinearVelocity = Vector3.new(math.random(-50000,50000), 100000, math.random(-50000,50000))
            end)
        end
    end
end

local function kill_6_SafePulseExplosion(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    pcall(function()
        local exp = Instance.new("Explosion")
        exp.Position = root.Position; exp.BlastRadius = 35; exp.BlastPressure = 0; exp.DestroyJointRadiusPercent = 0
        exp.ExplosionType = Enum.ExplosionType.NoCraters
        exp.Hit:Connect(function(part, distance)
            if part:IsDescendantOf(lp.Character) or (part.Parent and plrs:GetPlayerFromCharacter(part.Parent)) then return end
            if part:IsDescendantOf(obj) or part == root then
                pcall(function()
                    part.AssemblyLinearVelocity = Vector3.new(0, 50000, 0)
                    if part:IsA("JointInstance") or part:IsA("Weld") or part:IsA("Motor6D") then part:Destroy() end
                end)
                local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
                if hum then pcall(function() hum:TakeDamage(999999); hum.Health = 0 end) end
            end
        end)
        exp.Parent = ws
    end)
end

local function kill_7_CustomConstraintShatter(obj)
    claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("WeldConstraint") or v:IsA("RigidConstraint") or v:IsA("AlignPosition") or v:IsA("AlignOrientation") or v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("RodConstraint") or v:IsA("PrismaticConstraint") or v:IsA("CylindricalConstraint") or v:IsA("UniversalConstraint") or v:IsA("SpringConstraint") or v:IsA("NoCollisionConstraint") then pcall(function() v:Destroy() end) end
    end
end

local function kill_8_SkinnedMeshBoneShatter(obj)
    claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Bone") then pcall(function() v.Transform = CFrame.new(math.random(-50,50), math.random(-50,50), math.random(-50,50)) * CFrame.Angles(math.random(-3,3), math.random(-3,3), math.random(-3,3)) end)
        elseif v:IsA("Attachment") and v.Name ~= "RootAttachment" then pcall(function() v:Destroy() end) end
    end
end

local function kill_9_KineticBodyTear(obj)
    claimFE(obj); local parts = {}
    for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts, p) end end
    for i,p in ipairs(parts) do
        pcall(function() p.CanCollide = true; local dir = Vector3.new(math.sin(i*99)*100000, math.cos(i*77)*100000, math.sin(i*33)*100000); p.AssemblyLinearVelocity = dir; p.AssemblyAngularVelocity = dir end)
    end
end

-- 💥 МЕТОД №10: SPIN-TEAR (ВОЙДЕТ В 4-Ю КНОПКУ ПУСТОТЫ И ФЛИНГА!)
local function kill_10_AssemblyAngularSpinTear(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    pcall(function()
        root.AssemblyAngularVelocity = Vector3.new(1e6, 1e6, 1e6)
        for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") and p ~= root then pcall(function() p.AssemblyLinearVelocity = Vector3.new(0, 100000, 0) end) end end
    end)
end

local function kill_11_TakeDamageLoop(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
    if hum then task.spawn(function() for i=1,15 do if not obj or not obj.Parent then break end; pcall(function() hum:TakeDamage(math.huge); hum.Health = 0 end); task.wait(0.03) end end) end
end

local function kill_12_NaNInfinityMathCrash(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") then local nm = string.lower(val.Name) if string.find(nm, "hp") or string.find(nm, "health") then pcall(function() val.Value = 0/0 end) end end end
    for attr, _ in pairs(obj:GetAttributes()) do if string.find(string.lower(attr), "health") or string.find(string.lower(attr), "hp") then pcall(function() obj:SetAttribute(attr, 0/0) end) end end
end

local function kill_13_DoubleOverflow1e308(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") or val:IsA("DoubleConstrainedValue") then local nm = string.lower(val.Name) if string.find(nm, "hp") or string.find(nm, "health") or string.find(nm, "damage") then pcall(function() val.Value = 1e308 end) end end end
end

local function kill_14_AttrValNegativeInversion(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") or val:IsA("IntValue") then local nm = string.lower(val.Name) if string.find(nm, "hp") or string.find(nm, "health") then pcall(function() val.Value = -999999 end) end end end
    for attr, _ in pairs(obj:GetAttributes()) do if string.find(string.lower(attr), "health") or string.find(string.lower(attr), "hp") then pcall(function() obj:SetAttribute(attr, -999999) end) end end
end

local function kill_15_StripShieldsImmortality(obj)
    for _,ff in ipairs(obj:GetDescendants()) do if ff:IsA("ForceField") then pcall(function() ff:Destroy() end) end end
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") or val:IsA("IntValue") or val:IsA("BoolValue") then local nm = string.lower(val.Name) if string.find(nm, "shield") or string.find(nm, "armor") or string.find(nm, "defense") or string.find(nm, "immortal") or string.find(nm, "god") or string.find(nm, "invuln") then pcall(function() if val:IsA("BoolValue") then val.Value = false else val.Value = 0 end end) end end end
    for attr, _ in pairs(obj:GetAttributes()) do local nm = string.lower(attr) if string.find(nm, "shield") or string.find(nm, "armor") or string.find(nm, "defense") or string.find(nm, "immortal") or string.find(nm, "god") then pcall(function() obj:SetAttribute(attr, 0) end) end end
end

local function kill_16_SafeMaxHealthShrink(obj)
    if obj == lp.Character or (obj:IsA("Model") and plrs:GetPlayerFromCharacter(obj)) then return end
    local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
    if hum then pcall(function() hum.MaxHealth = 1; hum.Health = 0; hum:TakeDamage(999999) end) end
    for _,val in ipairs(obj:GetDescendants()) do if (val:IsA("NumberValue") or val:IsA("IntValue")) and string.find(string.lower(val.Name), "max") then if not val:IsDescendantOf(lp.Character) then pcall(function() val.Value = 1 end) end end end
end

local function kill_17_OfficialWeaponOverdrive(obj)
    local char = lp.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not tool then return end
    if tool.Parent ~= char then tool.Parent = char end
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart"); local root = getRootPart(obj)
    task.spawn(function()
        for i=1,15 do
            if not obj or not obj.Parent then break end
            pcall(function() tool:Activate() end)
            if handle and root and firetouchinterest then pcall(function() handle.Size = Vector3.new(35, 35, 35); handle.Massless = true; handle.CanCollide = false; firetouchinterest(handle, root, 0); task.wait(); firetouchinterest(handle, root, 1) end) end
            task.wait(0.03)
        end
        if handle then pcall(function() handle.Size = Vector3.new(1,4,1) end) end
    end)
end

local function kill_18_SafeRemoteBruteForce(obj)
    if #DeepAnalysisData.CombatRemotes == 0 then runFullAnalysis() end
    task.spawn(function()
        for i=1,6 do
            if not obj or not obj.Parent then break end
            for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
                pcall(function()
                    if rem:IsA("RemoteEvent") then
                        rem:FireServer(obj); rem:FireServer(obj, 100); rem:FireServer("Attack", obj); rem:FireServer(getRootPart(obj))
                    elseif rem:IsA("RemoteFunction") then task.spawn(function() rem:InvokeServer(obj) end) end
                end)
            end
            task.wait(0.06)
        end
    end)
end

local function kill_19_WeaponRemoteHijack(obj)
    if #DeepAnalysisData.WeaponRemotes == 0 then runFullAnalysis() end
    for _,rem in ipairs(DeepAnalysisData.WeaponRemotes) do
        pcall(function()
            if rem:IsA("RemoteEvent") then rem:FireServer(obj); rem:FireServer(getRootPart(obj), 999999); rem:FireServer(mouse.Hit.Position, obj)
            elseif rem:IsA("RemoteFunction") then task.spawn(function() rem:InvokeServer(obj, 999999) end)
            elseif rem:IsA("BindableEvent") then rem:Fire(obj); rem:Fire(999999) end
        end)
    end
end

local function kill_20_BindableSignalTrigger(obj)
    for _,desc in ipairs(obj:GetDescendants()) do
        if desc:IsA("BindableEvent") or desc:IsA("BindableFunction") then
            local nm = string.lower(desc.Name)
            if string.find(nm, "die") or string.find(nm, "dead") or string.find(nm, "kill") or string.find(nm, "death") or string.find(nm, "damage") or string.find(nm, "hit") or string.find(nm, "destroy") or string.find(nm, "reward") then
                pcall(function() if desc:IsA("BindableEvent") then desc:Fire(); desc:Fire(999999); desc:Fire(lp) elseif desc:IsA("BindableFunction") then task.spawn(function() desc:Invoke(999999) end) end end)
            end
        end
    end
end

local function kill_21_AttributeTagExecution(obj)
    local root = getRootPart(obj); local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true); local list = {obj, root, hum}
    for _,item in ipairs(list) do if item then pcall(function() item:SetAttribute("Dead", true); item:SetAttribute("IsDead", true); item:SetAttribute("Killed", true); item:SetAttribute("Dying", true); item:SetAttribute("State", "Dead"); item:SetAttribute("Status", "Dead"); item:SetAttribute("Health", 0); item:SetAttribute("HP", 0); item:SetAttribute("State", 0) end) end end
end

local function kill_22_MapHazardTouchAbuse(obj)
    if not firetouchinterest then return end
    if #DeepAnalysisData.MapHazards == 0 and #DeepAnalysisData.TaggedKillBricks == 0 then runFullAnalysis() end
    local root = getRootPart(obj); if not root then return end
    local allHazards = {}
    for _,h in ipairs(DeepAnalysisData.MapHazards) do table.insert(allHazards, h) end
    for _,h in ipairs(DeepAnalysisData.TaggedKillBricks) do if not table.find(allHazards, h) then table.insert(allHazards, h) end end
    if #allHazards == 0 then return end
    task.spawn(function() for i=1,10 do if not obj or not obj.Parent then break end; for _,hazard in ipairs(allHazards) do pcall(function() firetouchinterest(root, hazard, 0); task.wait(); firetouchinterest(root, hazard, 1) end) end; task.wait(0.04) end end)
end

local function kill_23_TouchTransmitterHijack(obj)
    if not firetouchinterest then return end
    local root = getRootPart(obj); if not root then return end
    for _,desc in ipairs(ws:GetDescendants()) do if desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent:IsA("BasePart") and desc.Parent ~= root then pcall(function() firetouchinterest(root, desc.Parent, 0); firetouchinterest(root, desc.Parent, 1) end) end end
end

local function kill_24_ToolGripDropHijack(obj)
    local tool = lp.Backpack:FindFirstChildOfClass("Tool") or (lp.Character and lp.Character:FindFirstChildOfClass("Tool")); local root = getRootPart(obj); if not tool or not root then return end
    pcall(function() tool.Parent = ws; local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart") if handle then handle.CFrame = root.CFrame end end)
end

local function kill_25_DisarmBossHitboxes(obj)
    for _,v in ipairs(obj:GetDescendants()) do if v:IsA("BasePart") or v:IsA("TouchTransmitter") or v:IsA("Tool") then local nm = string.lower(v.Name) if string.find(nm, "hitbox") or string.find(nm, "weapon") or string.find(nm, "sword") or string.find(nm, "knife") or string.find(nm, "kill") or string.find(nm, "touch") or string.find(nm, "damage") or string.find(nm, "gauntlet") or string.find(nm, "blade") then pcall(function() v:Destroy() end) end end end
end

local function kill_26_RemoteTableInjection(obj)
    if #DeepAnalysisData.CombatRemotes == 0 then runFullAnalysis() end
    for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
        if rem:IsA("RemoteEvent") then
            pcall(function() rem:FireServer({Target = obj, Damage = 999999, Type = "Heavy"}) end)
            pcall(function() rem:FireServer({Enemy = obj, Dmg = math.huge}) end)
            pcall(function() rem:FireServer(obj, {Damage = 999999}) end)
        end
    end
end

local function kill_27_JointNulling(obj)
    claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("ManualWeld") or v:IsA("JointInstance") then pcall(function() v.Part0 = nil; v.Part1 = nil end) end
    end
end

local function kill_28_ProximityClickExecute(obj)
    local root = getRootPart(obj); if not root then return end
    for _,desc in ipairs(ws:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Parent and desc.Parent:IsA("BasePart") then
            if (desc.Parent.Position - root.Position).Magnitude < 70 then pcall(function() fireproximityprompt(desc) end) end
        elseif desc:IsA("ClickDetector") and desc.Parent and desc.Parent:IsA("BasePart") then
            if (desc.Parent.Position - root.Position).Magnitude < 70 then pcall(function() fireclickdetector(desc) end) end
        end
    end
end

-- 💥 МЕТОД №29: SUPERSONIC LAUNCH (ВОЙДЕТ В 4-Ю КНОПКУ ПУСТОТЫ И ФЛИНГА!)
local function kill_29_SupersonicLaunch(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    print("[💥 SUPERSONIC 29] Отстрел со скоростью 10^9 в космос для:", obj.Name)
    pcall(function() root.CanCollide = false; root.CFrame = root.CFrame + Vector3.new(0, 50, 0); root.AssemblyLinearVelocity = Vector3.new(1000000000, 1000000000, -1000000000) end)
end

-- 💥 МЕТОД №30: PIVOT STOMP LOOP (ВОЙДЕТ В 4-Ю КНОПКУ ПУСТОТЫ!)
local function kill_30_PivotStompLoop(obj)
    claimFE(obj); task.spawn(function()
        for i=1,15 do if not obj or not obj.Parent then break end; pcall(function() obj:PivotTo(CFrame.new(0, -1500, 0)) end); task.wait(0.04) end
    end)
end

-- 💥 МЕТОД №31: PHYSICS SLEEP DESYNC (ВОЙДЕТ В 4-Ю КНОПКУ ПУСТОТЫ!)
local function kill_31_PhysicsSleepDesync(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    task.spawn(function()
        for i=1,15 do if not obj or not obj.Parent then break end; pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, math.sin(i)*1000, 0); root.CFrame = root.CFrame + Vector3.new(0, 0.05, 0) end); task.wait(0.02) end
        pcall(function() if obj.BreakJoints then obj:BreakJoints() end; root.CFrame = CFrame.new(0, -1500, 0) end)
    end)
end

local function kill_32_FloorMaterialRaceCondition(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true); local root = getRootPart(obj); if not hum or not root then return end
    task.spawn(function()
        for i=1,20 do if not obj or not obj.Parent then break end; pcall(function() hum.PlatformStand = true; hum.Sit = true; root.AssemblyLinearVelocity = Vector3.new(0, -500, 0); hum:ChangeState(Enum.HumanoidStateType.FallingDown); hum:ChangeState(Enum.HumanoidStateType.Dead) end); task.wait(0.02) end
    end)
end

-- 💥 МЕТОД №33: ASSEMBLY MASS OVERDRIVE (ВОЙДЕТ В 4-Ю КНОПКУ ПУСТОТЫ!)
local function kill_33_AssemblyMassOverdrive(obj)
    claimFE(obj); pcall(function()
        for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then p.CustomPhysicalProperties = PhysicalProperties.new(100, 0, 0, 100, 100); p.AssemblyLinearVelocity = Vector3.new(0, -50000, 0) end end
    end)
end

local function kill_34_CollectionServiceTagFlood(obj)
    pcall(function()
        for _,tag in ipairs({"Dead", "Killed", "KillBrick", "Lava", "Spike", "Despawn", "Garbage", "Remove", "Destroy", "Deadly", "DamageZone"}) do
            CollectionService:AddTag(obj, tag); local root = getRootPart(obj); if root then CollectionService:AddTag(root, tag) end
        end
    end)
end

-- 💥 МЕТОД №35: SEAT WELD HIJACK (ВОЙДЕТ В 4-Ю КНОПКУ ПУСТОТЫ!)
local function kill_35_SeatWeldHijack(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true); local root = getRootPart(obj); if not hum or not root then return end
    task.spawn(function()
        local seat = Instance.new("Seat"); seat.Name = "_EngineHijackSeat"; seat.Transparency = 1; seat.CanCollide = false; seat.CFrame = root.CFrame; seat.Parent = ws
        pcall(function() seat:Sit(hum) end); task.wait(0.08)
        pcall(function() seat.CFrame = CFrame.new(0, -1500, 0); seat.AssemblyLinearVelocity = Vector3.new(0, -100000, 0); if obj.BreakJoints then obj:BreakJoints() end end); task.wait(0.4)
        pcall(function() seat:Destroy() end)
    end)
end

local function kill_36_AnimationStateCrash(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true); local anim = obj:FindFirstChildOfClass("AnimationController") or obj:FindFirstChildOfClass("AnimationController", true); local target = hum or anim
    if not target then return end
    pcall(function() for _, track in ipairs(target:GetPlayingAnimationTracks()) do track:Stop(0); track:Destroy() end end)
end

local function kill_37_MatrixWeaponTouch(obj)
    if not firetouchinterest then return end
    local char = lp.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not tool then return end
    if tool.Parent ~= char then tool.Parent = char end
    local toolParts = {}; for _,p in ipairs(tool:GetDescendants()) do if p:IsA("BasePart") then table.insert(toolParts, p) end end
    local npcParts = {}; for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(npcParts, p) end end
    if #toolParts == 0 or #npcParts == 0 then return end
    task.spawn(function()
        for i=1,5 do
            if not obj or not obj.Parent then break end
            pcall(function() tool:Activate() end)
            for _,tp in ipairs(toolParts) do for _,np in ipairs(npcParts) do pcall(function() firetouchinterest(tp, np, 0); firetouchinterest(tp, np, 1) end) end end
            task.wait(0.04)
        end
    end)
end

local function kill_38_GyroscopicImpulseDestab(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    pcall(function()
        root.CanCollide = true
        if root.ApplyImpulseAtPosition then root:ApplyImpulseAtPosition(Vector3.new(0, -1e8, 0), root.Position + Vector3.new(10, 10, 10)); root:ApplyAngularImpulse(Vector3.new(1e8, 1e8, 1e8))
        else root.AssemblyAngularVelocity = Vector3.new(500000, 500000, 500000) end
    end)
end

local function kill_39_ElasticDismember(obj)
    claimFE(obj)
    for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("ManualWeld") then
            pcall(function()
                local p0, p1 = v.Part0, v.Part1; v:Destroy()
                if p0 and p1 then
                    local att0 = Instance.new("Attachment", p0); local att1 = Instance.new("Attachment", p1)
                    local bsc = Instance.new("BallSocketConstraint", p0); bsc.Attachment0 = att0; bsc.Attachment1 = att1
                    bsc.LimitsEnabled = true; bsc.UpperAngle = 180
                    p1.AssemblyLinearVelocity = Vector3.new(math.random(-5000,5000), 20000, math.random(-5000,5000))
                end
            end)
        end
    end
end

local function kill_40_PathfindingLinkSabotage(obj)
    for _,v in ipairs(obj:GetDescendants()) do if v:IsA("PathfindingModifier") or v:IsA("PathfindingLink") or v.Name == "Waypoints" or v.Name == "Path" then pcall(function() v:Destroy() end) end end
    local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
    if hum then pcall(function() hum:MoveTo(hum.RootPart and hum.RootPart.Position or Vector3.zero); hum.AutoRotate = false end) end
end

-- ==================== 10 СОВЕРШЕННО НОВЫХ МЕТОДОВ ДЛЯ ТЕСТА (№77 – №86) ====================
-- Нацелены на SBBF, приклеенные к рукам кастомные оружия, античит-сейф и щиты!

local function kill_77_CustomWeldedWeaponOverdrive(obj)
    -- Атака приклеенным к руке оружием (SBBF style): ищет приваренные к рукам модели и детали,
    -- увеличивает их хитбоксы и сталкивает с боссом!
    local char = lp.Character; if not char then return end
    local root = getRootPart(obj); if not root then return end
    print("[💥 NEW 77 SBBF] Атака приваренным к руке кастомным оружием по:", obj.Name)
    for _,part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part ~= char.PrimaryPart and not string.find(part.Name, "Leg") and not string.find(part.Name, "Head") and not string.find(part.Name, "Torso") then
            if part.Size.Magnitude > 1.5 or part:FindFirstChildOfClass("TouchTransmitter") then
                task.spawn(function()
                    for i=1,10 do
                        if not obj or not obj.Parent then break end
                        pcall(function()
                            if firetouchinterest then firetouchinterest(part, root, 0); firetouchinterest(part, root, 1) end
                            part.AssemblyLinearVelocity = (root.Position - part.Position).Unit * 100
                        end)
                        task.wait(0.04)
                    end
                end)
            end
        end
    end
end

local function kill_78_SBBFSafeAttributeDrain(obj)
    -- SBBF-Сейф сброс статов: ставит атрибуты здоровья в 1 (не 0, не отрицательные и не NaN!) с паузой 0.15с
    print("[💥 NEW 78 STEALTH] Ювелирный безопасный сброс атрибутов ХП в 1 для:", obj.Name)
    local root = getRootPart(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    for _,item in ipairs({obj, root, hum}) do
        if item then
            for _,attr in ipairs({"Health", "HP", "Shield", "Armor", "BossHealth", "EnemyHealth"}) do
                if item:GetAttribute(attr) ~= nil then pcall(function() item:SetAttribute(attr, 1) end); task.wait(0.15) end
            end
        end
    end
end

local function kill_79_CharacterRemoteHijack(obj)
    -- Взлом ремоутов ВНУТРИ персонажа: в файтингах пульты атак лежат прямо внутри lp.Character!
    local char = lp.Character; if not char then return end
    print("[💥 NEW 79 HIJACK] Активация боевых пультов внутри персонажа по:", obj.Name)
    for _,rem in ipairs(char:GetDescendants()) do
        if rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction") or rem:IsA("BindableEvent") then
            local nm = string.lower(rem.Name)
            if string.find(nm, "attack") or string.find(nm, "slash") or string.find(nm, "hit") or string.find(nm, "combat") or string.find(nm, "skill") or string.find(nm, "dmg") then
                pcall(function()
                    if rem:IsA("RemoteEvent") then rem:FireServer(obj); rem:FireServer(getRootPart(obj), 500)
                    elseif rem:IsA("RemoteFunction") then task.spawn(function() rem:InvokeServer(obj, 500) end)
                    elseif rem:IsA("BindableEvent") then rem:Fire(obj); rem:Fire(500) end
                end)
            end
        end
    end
end

local function kill_80_InvisibleHitboxExpansion(obj)
    -- Незримое увеличение хитбокса самого босса до 50х50х50 (CanCollide=false, Transparency=1)
    local root = getRootPart(obj); if not root then return end
    print("[💥 NEW 80 EXPAND] Увеличение хитбокса босса до 50 стадов для легкого удара:", obj.Name)
    pcall(function()
        root.Size = Vector3.new(50, 50, 50)
        root.CanCollide = false
        root.Transparency = 1
    end)
end

local function kill_81_Motor6DSilentDisconnect(obj)
    -- Бесшумный срыв суставов без Destroy() (ставит Enabled = false или CurrentAngle = 999)
    claimFE(obj); print("[💥 NEW 81 SILENT] Бесшумное отключение Motor6D без удаления для:", obj.Name)
    for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Motor6D") then pcall(function() v.Enabled = false; v.CurrentAngle = 999 end) end
    end
end

local function kill_82_CustomShieldPartVaporizer(obj)
    -- Уничтожение физических щитов, барьеров и вращающихся сфер вокруг босса
    print("[💥 NEW 82 SHIELD] Удаление физических щитов и барьеров у:", obj.Name)
    for _,p in ipairs(obj:GetDescendants()) do
        if p:IsA("BasePart") and (string.find(string.lower(p.Name), "shield") or string.find(string.lower(p.Name), "barrier") or string.find(string.lower(p.Name), "protect") or string.find(string.lower(p.Name), "aura") or string.find(string.lower(p.Name), "block")) then
            pcall(function() p:Destroy() end)
        end
    end
end

local function kill_83_SimulationRadiusSafeClaim(obj)
    -- Щадящий законный захват владения: ставит SimulationRadius = 1000 стадов без аномалий в 1e15!
    print("[💥 NEW 83 SAFE CLAIM] Законный захват владения (SimulationRadius 1000) для:", obj.Name)
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(lp, "SimulationRadius", 1000)
            sethiddenproperty(lp, "MaximumSimulationRadius", 1000)
        end
        local root = getRootPart(obj)
        if root and lp.Character and getRootPart(lp.Character) then
            -- Микро-подход на 0.05 сек для передачи физики сервером
            local oldCF = getRootPart(lp.Character).CFrame
            getRootPart(lp.Character).CFrame = root.CFrame + Vector3.new(2, 0, 0)
            task.wait(0.05)
            getRootPart(lp.Character).CFrame = oldCF
        end
    end)
end

local function kill_84_AnimatorStateMachineStop(obj)
    -- Принудительная остановка объекта Animator внутри Humanoid (блокирует каст скиллов босса)
    print("[💥 NEW 84 ANIMATOR] Остановка объекта Animator для блокировки атак:", obj.Name)
    for _,animator in ipairs(obj:GetDescendants()) do
        if animator:IsA("Animator") then
            pcall(function() for _,t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0); t:Destroy() end end)
        end
    end
end

local function kill_85_AlignOrientationSpinLock(obj)
    -- Скручивание шеи и торса вниз головой констрейнтом AlignOrientation
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    print("[💥 NEW 85 SPIN LOCK] Скручивание торса вниз головой для:", obj.Name)
    pcall(function()
        local att = Instance.new("Attachment", root)
        local ao = Instance.new("AlignOrientation", root)
        ao.Attachment0 = att; ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.CFrame = CFrame.Angles(math.pi, 0, 0); ao.MaxTorque = math.huge; ao.Responsiveness = 200
        task.delay(1.5, function() pcall(function() ao:Destroy(); att:Destroy() end) end)
    end)
end

local function kill_86_AnticheatBypassTakeDamage(obj)
    -- Легальный чистый урон TakeDamage(500) каждые 0.1с (античит видит нормальный игровой ДПС!)
    local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true); if not hum then return end
    print("[💥 NEW 86 LEGAL DPS] Легальный чистый ДПС TakeDamage(500) для:", obj.Name)
    task.spawn(function()
        for i=1,15 do
            if not obj or not obj.Parent then break end
            pcall(function() hum:TakeDamage(500) end)
            task.wait(0.1)
        end
    end)
end


-- ============================================================================
-- 👑 ВОТ НАША ГЛАВНАЯ, ОГРОМНАЯ, СИЛЬНЕЙШАЯ ФУНКЦИЯ УБИЙСТВА (30-ТИКОВЫЙ ЦИКЛ!)
-- ============================================================================
-- Именно здесь объединены все 38 чистых методов. Она работает волнами в 30 тиков
-- и автоматически включает щадящий протокол, если у босса нет Humanoid!
-- ============================================================================
local function MASTER_SAFE_OMNI_KILL(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    
    local isStealthBoss = obj:FindFirstChildOfClass("Humanoid") == nil
    print("[🌟 ГЛАВНАЯ СИЛЬНЕЙШАЯ ФУНКЦИЯ 🌟] Запуск 30-тикового цикла для:", obj.Name, "| Stealth Boss:", isStealthBoss)
    
    task.spawn(function()
        for tick = 1, 30 do
            if not obj or not obj.Parent then break end
            
            -- ВОЛНА 1 (Каждый тик): Системный урон и безопасная математика
            pcall(function()
                local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
                if hum then hum:TakeDamage(math.huge); hum.Health = 0; hum:ChangeState(Enum.HumanoidStateType.Dead); hum.Sit = true; hum.PlatformStand = true end
            end)
            kill_4_ValueAttrZero(obj); kill_16_SafeMaxHealthShrink(obj); kill_21_AttributeTagExecution(obj)
            
            -- ВОЛНА 2 (Каждые 2 тика): Анатомия, кости, суставы и новое приваренное оружие
            if tick % 2 == 0 then
                kill_7_CustomConstraintShatter(obj); kill_8_SkinnedMeshBoneShatter(obj); kill_25_DisarmBossHitboxes(obj); kill_27_JointNulling(obj)
                kill_77_CustomWeldedWeaponOverdrive(obj); kill_79_CharacterRemoteHijack(obj); kill_80_InvisibleHitboxExpansion(obj)
                pcall(function() if obj.BreakJoints then obj:BreakJoints() end end)
            end
            
            -- ВОЛНА 3 (Каждые 3 тика): Сетевые Ремоуты без банов, Ивенты и Ловушки карты
            if tick % 3 == 0 then
                if not isStealthBoss then
                    kill_18_SafeRemoteBruteForce(obj); kill_26_RemoteTableInjection(obj); kill_17_OfficialWeaponOverdrive(obj); kill_19_WeaponRemoteHijack(obj)
                    kill_22_MapHazardTouchAbuse(obj); kill_23_TouchTransmitterHijack(obj); kill_20_BindableSignalTrigger(obj); kill_28_ProximityClickExecute(obj)
                else
                    -- В стелс-режиме используем только щадящие легальные методы без спама!
                    kill_78_SBBFSafeAttributeDrain(obj); kill_86_AnticheatBypassTakeDamage(obj); kill_82_CustomShieldPartVaporizer(obj)
                end
            end
            
            task.wait(0.02)
        end
    end)
end
-- ============================================================================


-- 🟥 КНОПКА №2: 💥 ЛОМАЮЩИЙ СЕРВЕР / МЕТОДЫ 10 И 29 💥
local function MASTER_SERVER_BREAKER_KILL(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[💥 SERVER-BREAKER 💥] Запуск методов 10 (Spin) и 29 (Launch 10^9) для:", obj.Name)
    task.spawn(function() kill_10_AssemblyAngularSpinTear(obj) end)
    task.spawn(function() kill_29_SupersonicLaunch(obj) end)
end

-- 🛡️ КНОПКА №3: АНТИЧИТ-СЕЙФ (БЕЗ ИВЕНТОВ И РЕМОУТОВ!) 🛡️
local function MASTER_NO_REMOTES_KILL(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[🛡️ АНТИЧИТ-СЕЙФ №3 🛡️] Чистая физическая аннигиляция без сетевых пакетов для:", obj.Name)
    task.spawn(function()
        for tick = 1, 25 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
                if hum then hum:TakeDamage(math.huge); hum.Health = 0; hum:ChangeState(Enum.HumanoidStateType.Dead); hum.Sit = true; hum.PlatformStand = true end
            end)
            kill_4_ValueAttrZero(obj); kill_16_SafeMaxHealthShrink(obj)
            if tick % 2 == 0 then
                kill_3_BreakJointsMotorsLoop(obj); kill_7_CustomConstraintShatter(obj); kill_8_SkinnedMeshBoneShatter(obj); kill_9_KineticBodyTear(obj)
                kill_27_JointNulling(obj); kill_33_AssemblyMassOverdrive(obj); kill_38_GyroscopicImpulseDestab(obj); kill_81_Motor6DSilentDisconnect(obj)
            end
            task.wait(0.025)
        end
    end)
end

-- 🕳️ КНОПКА №4: ФЛИНГ И ПУСТОТА (FLING & VOID - ОТКИДЫВАНИЕ UNDERGROUND!) 🕳️
local function MASTER_FLING_VOID_KILL(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[🕳️ ФЛИНГ И ПУСТОТА №4 🕳️] Запуск всех физических откидываний, торнадо и бездн для:", obj.Name)
    task.spawn(function() kill_10_AssemblyAngularSpinTear(obj) end)
    task.spawn(function() kill_29_SupersonicLaunch(obj) end)
    task.spawn(function() kill_30_PivotStompLoop(obj) end)
    task.spawn(function() kill_31_PhysicsSleepDesync(obj) end)
    task.spawn(function() kill_33_AssemblyMassOverdrive(obj) end)
    task.spawn(function() kill_35_SeatWeldHijack(obj) end)
    task.spawn(function() kill_41_MotorWeldCFrameCrush(obj) end)
end

-- ==================== ГРАФИЧЕСКИЙ ИНТЕРФЕЙС (GUI v30.0 4 BUTTONS + 10 TESTS) ====================
local sg = Instance.new("ScreenGui")
sg.Name = "NPCKillTesterPro_v30_GUI"
sg.ResetOnSpawn = false
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = lp:WaitForChild("PlayerGui") end

local mf = Instance.new("Frame", sg)
mf.Size = UDim2.new(0, 720, 0, 780)
mf.Position = UDim2.new(0.5, -360, 0.5, -390)
mf.BackgroundColor3 = Color3.fromRGB(16,16,20)
mf.BorderSizePixel = 0
mf.Active = true
mf.Draggable = true
Instance.new("UICorner", mf).CornerRadius = UDim.new(0,14)

local title = Instance.new("TextLabel", mf)
title.Size = UDim2.new(1, -80, 0, 38)
title.Text = "  👑 NPC KILL TESTER v30.0 (4 СУПЕР-КНОПКИ + ТЕСТ SBBF КАСТОМ-ОРУЖИЯ)"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.BackgroundColor3 = Color3.fromRGB(10,10,12)
Instance.new("UICorner", title).CornerRadius = UDim.new(0,14)

local minBtn = Instance.new("TextButton", mf)
minBtn.Size = UDim2.new(0, 36, 0, 36); minBtn.Position = UDim2.new(1, -74, 0, 1)
minBtn.Text = "-"; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 20
minBtn.TextColor3 = Color3.fromRGB(255,255,255); minBtn.BackgroundColor3 = Color3.fromRGB(35,35,45)
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0,10)

local unloadBtn = Instance.new("TextButton", mf)
unloadBtn.Size = UDim2.new(0, 36, 0, 36); unloadBtn.Position = UDim2.new(1, -37, 0, 1)
unloadBtn.Text = "X"; unloadBtn.Font = Enum.Font.GothamBold; unloadBtn.TextSize = 16
unloadBtn.TextColor3 = Color3.fromRGB(255,180,180); unloadBtn.BackgroundColor3 = Color3.fromRGB(90,25,25)
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0,10)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        mf:TweenSize(UDim2.new(0,720,0,38), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minBtn.Text = "+"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=false end end
    else
        mf:TweenSize(UDim2.new(0,720,0,780), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minBtn.Text = "-"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=true end end
    end
end)

-- СЕКЦИЯ 4 ГЕНЕРАЛЬНЫХ СУПЕР-КНОПОК И ИХ KILL ALL (ВЕРХ, ВЫСОТА 130 PX)
local actionSection = Instance.new("Frame", mf)
actionSection.Size = UDim2.new(1, -20, 0, 130)
actionSection.Position = UDim2.new(0, 10, 0, 42)
actionSection.BackgroundColor3 = Color3.fromRGB(24,24,30)
Instance.new("UICorner", actionSection).CornerRadius = UDim.new(0,10)

-- 4 Главные кнопки (ряд 1)
local superBtn1 = Instance.new("TextButton", actionSection)
superBtn1.Size = UDim2.new(0.24, -4, 0, 56); superBtn1.Position = UDim2.new(0, 6, 0, 6)
superBtn1.Text = "🌟 №1: ЧИСТОЕ\n(30-ТИКОВЫЙ ЦИКЛ)"
superBtn1.Font = Enum.Font.GothamBold; superBtn1.TextSize = 10; superBtn1.TextColor3 = Color3.fromRGB(255,255,255); superBtn1.BackgroundColor3 = Color3.fromRGB(10,130,50)
Instance.new("UICorner", superBtn1).CornerRadius = UDim.new(0,6)
superBtn1.MouseButton1Click:Connect(function()
    local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
    for _,obj in ipairs(targets) do task.spawn(function() MASTER_SAFE_OMNI_KILL(obj) end) end
end)

local superBtn2 = Instance.new("TextButton", actionSection)
superBtn2.Size = UDim2.new(0.24, -4, 0, 56); superBtn2.Position = UDim2.new(0.25, 2, 0, 6)
superBtn2.Text = "💥 №2: ЛОМАЮЩИЙ\n(SPIN 1e6 + LAUNCH)"
superBtn2.Font = Enum.Font.GothamBold; superBtn2.TextSize = 10; superBtn2.TextColor3 = Color3.fromRGB(255,255,0); superBtn2.BackgroundColor3 = Color3.fromRGB(160,30,0)
Instance.new("UICorner", superBtn2).CornerRadius = UDim.new(0,6)
superBtn2.MouseButton1Click:Connect(function()
    local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
    for _,obj in ipairs(targets) do task.spawn(function() MASTER_SERVER_BREAKER_KILL(obj) end) end
end)

local superBtn3 = Instance.new("TextButton", actionSection)
superBtn3.Size = UDim2.new(0.24, -4, 0, 56); superBtn3.Position = UDim2.new(0.50, -2, 0, 6)
superBtn3.Text = "🛡️ №3: АНТИЧИТ\n(СТРОГО БЕЗ РЕМОУТОВ)"
superBtn3.Font = Enum.Font.GothamBold; superBtn3.TextSize = 10; superBtn3.TextColor3 = Color3.fromRGB(150,255,255); superBtn3.BackgroundColor3 = Color3.fromRGB(0,90,140)
Instance.new("UICorner", superBtn3).CornerRadius = UDim.new(0,6)
superBtn3.MouseButton1Click:Connect(function()
    local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
    for _,obj in ipairs(targets) do task.spawn(function() MASTER_NO_REMOTES_KILL(obj) end) end
end)

local superBtn4 = Instance.new("TextButton", actionSection)
superBtn4.Size = UDim2.new(0.24, -6, 0, 56); superBtn4.Position = UDim2.new(0.75, -2, 0, 6)
superBtn4.Text = "🕳️ №4: ФЛИНГ/ПУСТОТА\n(ОТКИДЫВАЕТ UNDERGROUND)"
superBtn4.Font = Enum.Font.GothamBold; superBtn4.TextSize = 9; superBtn4.TextColor3 = Color3.fromRGB(255,180,255); superBtn4.BackgroundColor3 = Color3.fromRGB(90,20,110)
Instance.new("UICorner", superBtn4).CornerRadius = UDim.new(0,6)
superBtn4.MouseButton1Click:Connect(function()
    local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
    for _,obj in ipairs(targets) do task.spawn(function() MASTER_FLING_VOID_KILL(obj) end) end
end)

-- 4 Кнопки Kill All (ряд 2)
local killAll1 = Instance.new("TextButton", actionSection)
killAll1.Size = UDim2.new(0.24, -4, 0, 48); killAll1.Position = UDim2.new(0, 6, 0, 68)
killAll1.Text = "⚡ ALL №1\n(ЧИСТОЕ)"
killAll1.Font = Enum.Font.GothamBold; killAll1.TextSize = 10; killAll1.TextColor3 = Color3.fromRGB(150,255,150); killAll1.BackgroundColor3 = Color3.fromRGB(20,80,30)
Instance.new("UICorner", killAll1).CornerRadius = UDim.new(0,6)
killAll1.MouseButton1Click:Connect(function()
    for _,o in ipairs(getAllValidEntities()) do task.spawn(function() MASTER_SAFE_OMNI_KILL(o) end) end
end)

local killAll2 = Instance.new("TextButton", actionSection)
killAll2.Size = UDim2.new(0.24, -4, 0, 48); killAll2.Position = UDim2.new(0.25, 2, 0, 68)
killAll2.Text = "🚀 ALL №2\n(ЛОМАЮЩИЙ)"
killAll2.Font = Enum.Font.GothamBold; killAll2.TextSize = 10; killAll2.TextColor3 = Color3.fromRGB(255,200,100); killAll2.BackgroundColor3 = Color3.fromRGB(110,20,0)
Instance.new("UICorner", killAll2).CornerRadius = UDim.new(0,6)
killAll2.MouseButton1Click:Connect(function()
    for _,o in ipairs(getAllValidEntities()) do task.spawn(function() MASTER_SERVER_BREAKER_KILL(o) end) end
end)

local killAll3 = Instance.new("TextButton", actionSection)
killAll3.Size = UDim2.new(0.24, -4, 0, 48); killAll3.Position = UDim2.new(0.50, -2, 0, 68)
killAll3.Text = "🛡️ ALL №3\n(БЕЗ РЕМОУТОВ)"
killAll3.Font = Enum.Font.GothamBold; killAll3.TextSize = 9; killAll3.TextColor3 = Color3.fromRGB(180,240,255); killAll3.BackgroundColor3 = Color3.fromRGB(0,60,100)
Instance.new("UICorner", killAll3).CornerRadius = UDim.new(0,6)
killAll3.MouseButton1Click:Connect(function()
    for _,o in ipairs(getAllValidEntities()) do task.spawn(function() MASTER_NO_REMOTES_KILL(o) end) end
end)

local killAll4 = Instance.new("TextButton", actionSection)
killAll4.Size = UDim2.new(0.24, -6, 0, 48); killAll4.Position = UDim2.new(0.75, -2, 0, 68)
killAll4.Text = "🕳️ ALL №4\n(ФЛИНГ/ПУСТОТА)"
killAll4.Font = Enum.Font.GothamBold; killAll4.TextSize = 9; killAll4.TextColor3 = Color3.fromRGB(255,200,255); killAll4.BackgroundColor3 = Color3.fromRGB(70,10,90)
Instance.new("UICorner", killAll4).CornerRadius = UDim.new(0,6)
killAll4.MouseButton1Click:Connect(function()
    for _,o in ipairs(getAllValidEntities()) do task.spawn(function() MASTER_FLING_VOID_KILL(o) end) end
end)

-- ПРОСТОРНАЯ СЕКЦИЯ ТЕСТОВ НА 160 PX (10 НОВЫХ МЕТОДОВ ДЛЯ SBBF И КАСТОМНОГО ОРУЖИЯ №77 – №86)!
local testSection = Instance.new("Frame", mf)
testSection.Size = UDim2.new(1, -20, 0, 160)
testSection.Position = UDim2.new(0, 10, 0, 178)
testSection.BackgroundColor3 = Color3.fromRGB(22,22,28)
Instance.new("UICorner", testSection).CornerRadius = UDim.new(0,10)

local tsTitle = Instance.new("TextLabel", testSection)
tsTitle.Size = UDim2.new(1, 0, 0, 22); tsTitle.Text = "  🧪 ТЕСТ SBBF КАСТОМ-ОРУЖИЯ И АНТИЧИТ-СЕЙФА (№77 – №86): ПРОСТОРНАЯ СЕТКА!"
tsTitle.Font = Enum.Font.GothamBold; tsTitle.TextSize = 11; tsTitle.TextColor3 = Color3.fromRGB(255,200,100); tsTitle.TextXAlignment = Enum.TextXAlignment.Left
tsTitle.BackgroundTransparency = 1

local tsGridF = Instance.new("ScrollingFrame", testSection)
tsGridF.Size = UDim2.new(1, -10, 1, -26); tsGridF.Position = UDim2.new(0, 5, 0, 24)
tsGridF.BackgroundTransparency = 1; tsGridF.ScrollBarThickness = 5; tsGridF.AutomaticCanvasSize = Enum.AutomaticSize.Y

local tsGrid = Instance.new("UIGridLayout", tsGridF)
tsGrid.CellSize = UDim2.new(0, 218, 0, 36); tsGrid.CellPadding = UDim2.new(0, 5, 0, 5)

local function makeTestBtn(parent, text, desc, col, fn)
    local b = Instance.new("TextButton", parent)
    b.Text = ""; b.BackgroundColor3 = col; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    
    local t1 = Instance.new("TextLabel", b)
    t1.Size = UDim2.new(1,-8,0,16); t1.Position = UDim2.new(0,4,0,2); t1.Text = text
    t1.Font = Enum.Font.GothamBold; t1.TextSize = 11; t1.TextColor3 = Color3.fromRGB(255,255,255); t1.BackgroundTransparency = 1
    
    local t2 = Instance.new("TextLabel", b)
    t2.Size = UDim2.new(1,-8,0,14); t2.Position = UDim2.new(0,4,0,19); t2.Text = desc
    t2.Font = Enum.Font.SourceSans; t2.TextSize = 10; t2.TextColor3 = Color3.fromRGB(210,210,210); t2.BackgroundTransparency = 1
    
    b.MouseButton1Click:Connect(function()
        local targets = getTargets()
        if #targets == 0 then print("[WARN] Выберите цель!"); return end
        print("[NEW SBBF LAB] Проверка метода:", text, "на", #targets, "целей")
        for _,obj in ipairs(targets) do task.spawn(function() fn(obj) end) end
    end)
    return b
end

-- 10 СОВЕРШЕННО НОВЫХ КНОПОК ТЕСТА НА SBBF И КАСТОМНОЕ ОРУЖИЕ
makeTestBtn(tsGridF, "77. Welded Weapon Overdrive", "Атака приклеенным к руке оружием", Color3.fromRGB(150,30,80), kill_77_CustomWeldedWeaponOverdrive)
makeTestBtn(tsGridF, "78. SBBF Attribute Drain", "Сброс атрибутов ХП в 1 без киков", Color3.fromRGB(0,110,140), kill_78_SBBFSafeAttributeDrain)
makeTestBtn(tsGridF, "79. Character Remotes", "Пульты внутри вашего персонажа", Color3.fromRGB(20,120,70), kill_79_CharacterRemoteHijack)
makeTestBtn(tsGridF, "80. Invisible Hitbox 50х", "Увеличение хитбокса самого босса", Color3.fromRGB(140,50,110), kill_80_InvisibleHitboxExpansion)
makeTestBtn(tsGridF, "81. Motor6D Silent Stop", "Бесшумный срыв суставов (SBBF)", Color3.fromRGB(80,40,100), kill_81_Motor6DSilentDisconnect)
makeTestBtn(tsGridF, "82. Shield Vaporizer", "Удаление физических щитов и сфер", Color3.fromRGB(130,20,60), kill_82_CustomShieldPartVaporizer)
makeTestBtn(tsGridF, "83. Safe SimRadius Claim", "Законный захват (SimRadius 1000)", Color3.fromRGB(0,120,90), kill_83_SimulationRadiusSafeClaim)
makeTestBtn(tsGridF, "84. Animator State Stop", "Срыв аниматора внутри Humanoid", Color3.fromRGB(160,40,80), kill_84_AnimatorStateMachineStop)
makeTestBtn(tsGridF, "85. AlignOrient Spin Lock", "Скручивание торса вниз головой", Color3.fromRGB(180,70,0), kill_85_AlignOrientationSpinLock)
makeTestBtn(tsGridF, "86. Legal TakeDamage DPS", "Легальный чистый ДПС TakeDamage(500)", Color3.fromRGB(40,110,80), kill_86_AnticheatBypassTakeDamage)

-- СЕКЦИЯ ТАБЛИЦЫ NPC (НИЖНЯЯ ЧАСТЬ)
local listSection = Instance.new("Frame", mf)
listSection.Size = UDim2.new(1, -20, 0, 420)
listSection.Position = UDim2.new(0, 10, 0, 348)
listSection.BackgroundColor3 = Color3.fromRGB(20,20,26)
Instance.new("UICorner", listSection).CornerRadius = UDim.new(0,10)

local lsHeader = Instance.new("Frame", listSection)
lsHeader.Size = UDim2.new(1, 0, 0, 32); lsHeader.BackgroundColor3 = Color3.fromRGB(28,28,38)
Instance.new("UICorner", lsHeader).CornerRadius = UDim.new(0,10)

local function makeColLabel(parent, text, pos, size, col)
    local l = Instance.new("TextLabel", parent)
    l.Size = size; l.Position = pos; l.Text = text; l.Font = Enum.Font.GothamBold
    l.TextSize = 11; l.TextColor3 = col or Color3.fromRGB(220,220,220); l.BackgroundTransparency = 1; l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

makeColLabel(lsHeader, "  ИМЯ (ПАРАМЕТРИЧЕСКИЙ СКАНЕР)", UDim2.new(0,0,0,0), UDim2.new(0.38,0,1,0), Color3.fromRGB(255,255,150))
makeColLabel(lsHeader, "ТИП / КЛАССИФИКАЦИЯ", UDim2.new(0.39,0,0,0), UDim2.new(0.26,0,1,0), Color3.fromRGB(150,220,255))
makeColLabel(lsHeader, "ЗДОРОВЬЕ/ТРАЙ", UDim2.new(0.66,0,0,0), UDim2.new(0.18,0,1,0), Color3.fromRGB(150,255,150))
makeColLabel(lsHeader, "ВЛАДЕНИЕ (FE)", UDim2.new(0.85,0,0,0), UDim2.new(0.14,0,1,0), Color3.fromRGB(255,180,255))

local selAllBtn = Instance.new("TextButton", lsHeader)
selAllBtn.Size = UDim2.new(0, 80, 0, 22); selAllBtn.Position = UDim2.new(1, -170, 0, 5)
selAllBtn.Text = "✅ Выбрать всех"; selAllBtn.Font = Enum.Font.SourceSansBold; selAllBtn.TextSize = 11
selAllBtn.BackgroundColor3 = Color3.fromRGB(40,90,40); selAllBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", selAllBtn).CornerRadius = UDim.new(0,4)

local deselBtn = Instance.new("TextButton", lsHeader)
deselBtn.Size = UDim2.new(0, 80, 0, 22); deselBtn.Position = UDim2.new(1, -85, 0, 5)
deselBtn.Text = "❌ Сбросить"; deselBtn.Font = Enum.Font.SourceSansBold; deselBtn.TextSize = 11
deselBtn.BackgroundColor3 = Color3.fromRGB(90,40,40); deselBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", deselBtn).CornerRadius = UDim.new(0,4)

local npcS = Instance.new("ScrollingFrame", listSection)
npcS.Size = UDim2.new(1, -10, 1, -40); npcS.Position = UDim2.new(0, 5, 0, 36)
npcS.BackgroundTransparency = 1; npcS.ScrollBarThickness = 5; npcS.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", npcS).Padding = UDim.new(0, 3)

selAllBtn.MouseButton1Click:Connect(function()
    for _,obj in ipairs(getAllValidEntities()) do
        selectedNPCs[obj] = true
        if not obj:FindFirstChild("_NPCKillHL") then
            local hl = Instance.new("Highlight", obj)
            hl.Name = "_NPCKillHL"; hl.FillColor = Color3.fromRGB(0,255,0); hl.OutlineColor = Color3.fromRGB(0,255,0); hl.FillTransparency = 0.65
            highlights[obj] = hl
        end
    end
end)

deselBtn.MouseButton1Click:Connect(function()
    for obj,_ in pairs(selectedNPCs) do if obj and obj.Parent then local hl = obj:FindFirstChild("_NPCKillHL") if hl then hl:Destroy() end end end
    selectedNPCs = {}; currentNPC = nil
end)

local npcButtons = {}

local function refreshTable()
    for _,c in ipairs(npcS:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end
    npcButtons = {}
    local entities = getAllValidEntities()
    
    for _,obj in ipairs(entities) do
        local valid, entityType, hpText, isAnchored, root = analyzeEntity(obj)
        if valid and root then
            local b = Instance.new("TextButton", npcS)
            b.Size = UDim2.new(1, -6, 0, 26); b.Text = ""
            b.BackgroundColor3 = selectedNPCs[obj] and Color3.fromRGB(20,90,30) or Color3.fromRGB(32,32,42)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)

            makeColLabel(b, "  "..obj.Name, UDim2.new(0,0,0,0), UDim2.new(0.38,0,1,0), Color3.fromRGB(255,255,255))
            makeColLabel(b, entityType, UDim2.new(0.39,0,0,0), UDim2.new(0.26,0,1,0), Color3.fromRGB(180,220,255))
            local hp = makeColLabel(b, hpText, UDim2.new(0.66,0,0,0), UDim2.new(0.18,0,1,0), Color3.fromRGB(150,255,150))
            local ow = makeColLabel(b, checkOwnership(root), UDim2.new(0.85,0,0,0), UDim2.new(0.14,0,1,0), Color3.fromRGB(200,200,200))

            b.MouseButton1Click:Connect(function()
                if selectedNPCs[obj] then
                    selectedNPCs[obj] = nil; b.BackgroundColor3 = Color3.fromRGB(32,32,42)
                    local hl = obj:FindFirstChild("_NPCKillHL") if hl then hl:Destroy() end
                else
                    selectedNPCs[obj] = true; currentNPC = obj; b.BackgroundColor3 = Color3.fromRGB(20,90,30)
                    if not obj:FindFirstChild("_NPCKillHL") then
                        local hl = Instance.new("Highlight", obj)
                        hl.Name = "_NPCKillHL"; hl.FillColor = Color3.fromRGB(0,255,0); hl.OutlineColor = Color3.fromRGB(0,255,0); hl.FillTransparency = 0.65
                        highlights[obj] = hl
                    end
                end
            end)
            table.insert(npcButtons, {obj, b, hp, ow, root})
        end
    end
    title.Text = "  👑 NPC KILL TESTER v30.0 (ЦЕЛЬНЫХ СУЩЕСТВ В ИГРЕ: "..#entities..")"
end

task.spawn(function()
    while true do
        task.wait(0.5)
        for _,data in ipairs(npcButtons) do
            local obj, b, hpLbl, owLbl, root = unpack(data)
            if obj and obj.Parent and b and b.Parent and root and root.Parent then
                b.BackgroundColor3 = selectedNPCs[obj] and Color3.fromRGB(20,90,30) or Color3.fromRGB(32,32,42)
                local valid, _, hpText = analyzeEntity(obj)
                if valid then
                    hpLbl.Text = hpText
                    if string.find(hpText, "0") or string.find(hpText, "-") then hpLbl.TextColor3 = Color3.fromRGB(255,100,100) else hpLbl.TextColor3 = Color3.fromRGB(150,255,150) end
                end
                local owText = checkOwnership(root)
                owLbl.Text = owText
                if string.find(owText, "ME") then owLbl.TextColor3 = Color3.fromRGB(100,255,100) elseif string.find(owText, "ANCHORED") then owLbl.TextColor3 = Color3.fromRGB(255,180,0) else owLbl.TextColor3 = Color3.fromRGB(255,100,100) end
            end
        end
    end
end)

local function boostAuth()
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(lp, "SimulationRadius", 100000000000)
            sethiddenproperty(lp, "MaxSimulationRadius", 100000000000)
        end
    end)
end
rs.RenderStepped:Connect(boostAuth); rs.Heartbeat:Connect(boostAuth)

task.spawn(function() while true do pcall(refreshTable); task.wait(3.5) end end)
pcall(refreshTable)
runFullAnalysis()

local function unloadAll()
    for _,c in pairs(connections) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,hl in pairs(highlights) do pcall(function() if hl and hl.Parent then hl:Destroy() end end) end
    for _,o in ipairs(ws:GetDescendants()) do if o.Name == "_NPCKillHL" then pcall(function() o:Destroy() end) end end
    if sg and sg.Parent then sg:Destroy() end
    if highlight and highlight.Parent then highlight:Destroy() end
    _G.NPCKillTesterPro = nil
end

_G.NPCKillTesterPro.Unload = unloadAll
unloadBtn.MouseButton1Click:Connect(unloadAll)

print("[KILL LAB v30.0 FINAL] Загружены 4 Супер-Кнопки, просторная сетка на 10 тестов и SBBF!")
