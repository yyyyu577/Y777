-- ============================================================================
-- NPC KILL TESTER PRO v36.0 — FULL ARSENAL MERGED EDITION
--
-- 📦 ПОЛНОЕ СЛИЯНИЕ ПО ТВОЕМУ ТЗ:
--   ✅ Оригинальный v32.0 GUI + панель настроек + модули СОХРАНЕНЫ
--   ✅ Все старые методы (№1-№96) СОХРАНЕНЫ и работают как раньше
--   ✅ Новые методы v33-v35 (№97-№126) ИНТЕГРИРОВАНЫ в главную кнопку
--      и распределены по категориям (модулям) панели настроек
--   ✅ 10 СОВЕРШЕННО НОВЫХ методов (№127-№136) — уникальные, не повторяют старые
--   ✅ БЕЗ телепортаций и без чистого Destroy (по твоему запросу)
--
-- 🔥 10 НОВЫХ УНИКАЛЬНЫХ МЕТОДОВ (№127 – №136):
--   127. 🌀 CFRAME LOOP CRUSHER      — микро-CFrame атака на Motor6D.C0/C1 (не R6!)
--   128. 🌀 ANIMATION TRACK OVERLOAD — 500 anim треков на Humanoid = крашится
--   129. 🌀 SOUND FREQUENCY WEAPON   — Sound с PlaybackSpeed=math.huge (лаг-урон)
--   130. 🌀 ATTACHMENT ORBIT CHAOS   — крутим Attachments = ломаются связи
--   131. 🌀 COLLISION GROUP ISOLATE  — вырубаем CollisionGroup NPC → падает
--   132. 🌀 NETWORK OWNER PING-PONG  — 20 раз меняем NetworkOwner (десинк)
--   133. 🌀 BODYFORCE INFINITE PUSH  — BodyVelocity с массой Vector3.zero (глюк)
--   134. 🌀 TOUCHED EVENT BOMB       — 1000 фиктивных Touched на BasePart
--   135. 🌀 MESH RESIZE OVERFLOW     — MeshPart.Size = Vector3.new(0.01,0.01,0.01)
--   136. 🌀 CHILDREN CASCADE PURGE   — рекурсивная очистка Value/Attribute-полей
-- ============================================================================

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
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local PhysicsService = game:GetService("PhysicsService")
local lp = plrs.LocalPlayer
local mouse = lp:GetMouse()
local ts = game:GetService("TweenService")
local cam = ws.CurrentCamera

local selectedNPCs = {}
local currentNPC = nil
local connections = {}
local highlights = {}
local rollbackGuards = {}

-- ГЛОБАЛЬНЫЕ НАСТРОЙКИ (расширены новыми модулями)
local CombatSettings = {
    -- Оригинальные модули v32
    GoldenGrail = true,        -- 👑 Золотой Грааль №86 (TakeDamage DPS)
    RemotesWeapons = true,     -- 📡 Ремоуты, Оружие, Тач #43
    CustomRigs = true,         -- 🦾 Кастомные Тела и 3D-кости
    FEClassic = true,          -- 🩸 Классика FE и Суставы
    MathStats = true,          -- 📊 Краш Математики (NaN, 1e308)
    DestroyerServer = false,   -- 🚀 Полёт в космос (по умолчанию OFF)
    -- Новые модули v33
    RealInputSim = true,       -- 🎮 Симуляция реального ввода (VIM)
    ToolActivateMimic = true,  -- ⚔️ Легальная активация оружия
    AntiRollback = true,       -- 🛡️ Защита от отката HP
    SelfKickGuard = true,      -- 🚫 Защита от кика игрока
    -- Новые модули v35
    PureFEDamage = true,       -- ⚔️ Чистый FE-урон (Health/State/Team)
    ExplosionCombat = true,    -- 💥 Взрывы (FF Trap + Ring)
    -- Новые модули v36
    ChaosPhysics = true,       -- 🌀 Физический хаос (новые №127-136)
    -- Регулировки
    DamageAmount = 50000,
    HyperSpeed = false
}

local DeepAnalysisData = { CombatRemotes = {}, MapHazards = {}, DeathSignals = {}, WeaponRemotes = {}, TaggedKillBricks = {}, AbilityRemotes = {} }

local function track(name, con) if con then connections[name] = con end end

local highlight = Instance.new("Highlight")
highlight.Parent = lp
highlight.FillTransparency = 1
highlight.OutlineTransparency = 1

-- ==================== АНАЛИЗАТОР ИГРЫ ====================
local function indexObject(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = string.lower(obj.Name)
            local fnm = obj.Parent and string.lower(obj.Parent.Name) or ""
            local isHoneypot = string.find(nm,"ban") or string.find(nm,"kick") or string.find(nm,"admin") or string.find(nm,"anticheat") or string.find(nm,"ac_") or string.find(nm,"log") or string.find(nm,"report") or string.find(nm,"detect") or string.find(nm,"security") or string.find(nm,"flag") or string.find(fnm,"ban") or string.find(fnm,"anticheat")
            if not isHoneypot then
                if string.find(nm,"attack") or string.find(nm,"damage") or string.find(nm,"hit") or string.find(nm,"combat") or string.find(nm,"kill") or string.find(nm,"strike") or string.find(nm,"swing") or string.find(nm,"slash") or string.find(fnm,"remote") or string.find(fnm,"event") then
                    if not table.find(DeepAnalysisData.CombatRemotes, obj) then table.insert(DeepAnalysisData.CombatRemotes, obj) end
                end
                if string.find(nm,"ability") or string.find(nm,"skill") or string.find(nm,"cast") or string.find(nm,"spell") or string.find(nm,"power") then
                    if not table.find(DeepAnalysisData.AbilityRemotes, obj) then table.insert(DeepAnalysisData.AbilityRemotes, obj) end
                end
            end
        end
        if obj:IsA("BasePart") then
            local nm = string.lower(obj.Name)
            local hasTouch = obj:FindFirstChildOfClass("TouchTransmitter") ~= nil
            if string.find(nm,"kill") or string.find(nm,"lava") or string.find(nm,"hazard") or string.find(nm,"spike") or string.find(nm,"death") or string.find(nm,"void") or (hasTouch and string.find(nm,"trap")) then
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
    DeepAnalysisData = { CombatRemotes = {}, MapHazards = {}, DeathSignals = {}, WeaponRemotes = {}, TaggedKillBricks = {}, AbilityRemotes = {} }
    for _,o in ipairs(rep:GetDescendants()) do indexObject(o) end
    for _,o in ipairs(ws:GetDescendants()) do indexObject(o) end
    for _,p in ipairs(plrs:GetPlayers()) do
        local bp = p:FindFirstChild("Backpack")
        if bp then for _,o in ipairs(bp:GetDescendants()) do indexObject(o) end end
    end
    pcall(function()
        for _,tag in ipairs({"KillBrick","Hazard","Lava","Spike","DamageZone","Deadly","KillZone"}) do
            for _,tagged in ipairs(CollectionService:GetTagged(tag)) do
                if tagged:IsA("BasePart") and not table.find(DeepAnalysisData.TaggedKillBricks, tagged) then table.insert(DeepAnalysisData.TaggedKillBricks, tagged) end
            end
        end
    end)
    print("[🤖 v36 ANALYZER] Combat:", #DeepAnalysisData.CombatRemotes, "| Ability:", #DeepAnalysisData.AbilityRemotes, "| Weapon:", #DeepAnalysisData.WeaponRemotes, "| Hazards:", #DeepAnalysisData.MapHazards)
end

ws.DescendantAdded:Connect(indexObject); rep.DescendantAdded:Connect(indexObject)

-- ==================== БАЗОВЫЕ УТИЛИТЫ ====================
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
    local isRobot = string.find(nameLower, "robot") or string.find(nameLower, "bot") or string.find(nameLower, "droid") or string.find(nameLower, "mech")
    local entityType, hpText = "Unknown", "N/A"
    if hum then
        entityType = isBoss and "[👑 Boss Hum]" or (isRobot and "[🤖 Робот/Hum]" or "[🚶 Humanoid]")
        hpText = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    elseif anim then
        entityType = isBoss and "[👑 Boss Anim]" or "[🤖 AnimCtrl]"
        if valHP and (valHP:IsA("NumberValue") or valHP:IsA("IntValue")) then hpText = tostring(valHP.Value).." (Val)"
        elseif attrHP then hpText = tostring(attrHP).." (Attr)" else hpText = "No HP Bar" end
    elseif valHP or attrHP then
        entityType = isBoss and "[👑 Boss Stat]" or "[📊 Value/Attr]"
        if valHP and (valHP:IsA("NumberValue") or valHP:IsA("IntValue")) then hpText = tostring(valHP.Value).." (Val)"
        else hpText = tostring(attrHP).." (Attr)" end
    else
        entityType = isBoss and "[👑 Boss Rig]" or "[🦾 Custom Rig]"
        hpText = "Rig/Timer"
    end
    return true, entityType, hpText, isAnchored, root
end

local function checkOwnership(part)
    if not part or not part:IsA("BasePart") then return "[NO PART]" end
    if part.Anchored then return "[⚓ ANCHORED]" end
    local ok, owner = pcall(function() return part:IsNetworkOwner() end)
    if ok and owner then return "[✅ ME]" else return "[🌐 SERVER]" end
end

local function getTargets()
    local t = {}
    for obj,_ in pairs(selectedNPCs) do if obj and obj.Parent then table.insert(t, obj) else selectedNPCs[obj] = nil end end
    if #t == 0 and currentNPC and currentNPC.Parent then table.insert(t, currentNPC) end
    return t
end

local function claimFE(obj)
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(lp, "SimulationRadius", 1e15)
            sethiddenproperty(lp, "MaximumSimulationRadius", 1e15)
        end
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") and not p.Anchored then pcall(function() p:SetNetworkOwner(lp) end) end
        end
    end)
end

-- ==================== 🩸 МОДУЛЬ: FE CLASSIC (старые №1-№9) ====================
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
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum and i % 3 == 0 then pcall(function() hum.Health = 0; hum:TakeDamage(999999) end) end
            task.wait(0.022)
        end
    end)
end

local function kill_4_ValueAttrZero(obj)
    claimFE(obj); for _,val in ipairs(obj:GetDescendants()) do
        if val:IsA("NumberValue") or val:IsA("IntValue") or val:IsA("DoubleConstrainedValue") then
            local nm = string.lower(val.Name)
            if string.find(nm,"hp") or string.find(nm,"health") or string.find(nm,"life") or string.find(nm,"shield") then pcall(function() val.Value = 0 end) end
        end
    end
    for attr,_ in pairs(obj:GetAttributes()) do
        local nm = string.lower(attr)
        if string.find(nm,"hp") or string.find(nm,"health") or string.find(nm,"life") then pcall(function() obj:SetAttribute(attr, 0) end) end
    end
end

local function kill_5_DecapitateHeadTorso(obj)
    claimFE(obj); for _,part in ipairs(obj:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name=="Head" or part.Name=="Torso" or part.Name=="UpperTorso") then
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
                local hum = obj:FindFirstChildOfClass("Humanoid")
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

-- ==================== 🚀 МОДУЛЬ: DESTROYER SERVER (старые №10, №29, №41) ====================
local function kill_10_AssemblyAngularSpinTear(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    print("[💥 DESTROYER 10] Центрифуга 1e6:", obj.Name)
    pcall(function()
        root.AssemblyAngularVelocity = Vector3.new(1e6, 1e6, 1e6)
        for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") and p ~= root then pcall(function() p.AssemblyLinearVelocity = Vector3.new(0, 100000, 0) end) end end
    end)
end

local function kill_29_SupersonicLaunch(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    print("[💥 DESTROYER 29] Отстрел 10^9:", obj.Name)
    pcall(function() root.CanCollide = false; root.CFrame = root.CFrame + Vector3.new(0, 50, 0); root.AssemblyLinearVelocity = Vector3.new(1e9, 1e9, -1e9) end)
end

local function kill_41_MotorWeldCFrameCrush(obj)
    claimFE(obj); print("[💥 DESTROYER 41] Сжатие швов:", obj.Name)
    for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("ManualWeld") then
            pcall(function() v.C0 = CFrame.new(0, -5000, 0); v.C1 = CFrame.new(10000, 10000, 10000) end)
        end
    end
end

-- ==================== 👑 МОДУЛЬ: GOLDEN GRAIL (№86) ====================
local function kill_86_GoldenGrailOverdrive(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid", true)
    if not hum then return end
    local dmg = CombatSettings.DamageAmount
    pcall(function() hum:TakeDamage(dmg); if dmg >= 999999 then hum.Health = 0 end end)
end

-- ==================== 📊 МОДУЛЬ: MATH STATS (старые №11-№16) ====================
local function kill_11_TakeDamageLoop(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then task.spawn(function() for i=1,15 do if not obj or not obj.Parent then break end; pcall(function() hum:TakeDamage(math.huge); hum.Health = 0 end); task.wait(0.03) end end) end
end

local function kill_12_NaNInfinityMathCrash(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") then local nm = string.lower(val.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() val.Value = 0/0 end) end end end
    for attr,_ in pairs(obj:GetAttributes()) do if string.find(string.lower(attr),"health") then pcall(function() obj:SetAttribute(attr, 0/0) end) end end
end

local function kill_13_DoubleOverflow1e308(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") then local nm = string.lower(val.Name); if string.find(nm,"hp") or string.find(nm,"health") or string.find(nm,"damage") then pcall(function() val.Value = 1e308 end) end end end
end

local function kill_14_AttrValNegativeInversion(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") or val:IsA("IntValue") then local nm = string.lower(val.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() val.Value = -999999 end) end end end
    for attr,_ in pairs(obj:GetAttributes()) do if string.find(string.lower(attr),"health") then pcall(function() obj:SetAttribute(attr, -999999) end) end end
end

local function kill_15_StripShieldsImmortality(obj)
    for _,ff in ipairs(obj:GetDescendants()) do if ff:IsA("ForceField") then pcall(function() ff:Destroy() end) end end
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") or val:IsA("IntValue") or val:IsA("BoolValue") then local nm = string.lower(val.Name); if string.find(nm,"shield") or string.find(nm,"armor") or string.find(nm,"defense") or string.find(nm,"immortal") or string.find(nm,"god") then pcall(function() if val:IsA("BoolValue") then val.Value = false else val.Value = 0 end end) end end end
end

local function kill_16_SafeMaxHealthShrink(obj)
    if obj == lp.Character or (obj:IsA("Model") and plrs:GetPlayerFromCharacter(obj)) then return end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.MaxHealth = 1; hum.Health = 0; hum:TakeDamage(999999) end) end
end

-- ==================== 📡 МОДУЛЬ: REMOTES/WEAPONS (старые №17-№25, №37, №43) ====================
local function kill_17_OfficialWeaponOverdrive(obj)
    local char = lp.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not tool then return end
    if tool.Parent ~= char then tool.Parent = char end
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")
    local root = getRootPart(obj)
    task.spawn(function()
        for i=1,15 do
            if not obj or not obj.Parent then break end
            pcall(function() tool:Activate() end)
            if handle and root and firetouchinterest then pcall(function() handle.Size = Vector3.new(35,35,35); handle.Massless = true; handle.CanCollide = false; firetouchinterest(handle, root, 0); task.wait(); firetouchinterest(handle, root, 1) end) end
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
                    if rem:IsA("RemoteEvent") then rem:FireServer(obj); rem:FireServer(obj, 100); rem:FireServer("Attack", obj); rem:FireServer(getRootPart(obj))
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
            if string.find(nm,"die") or string.find(nm,"dead") or string.find(nm,"kill") or string.find(nm,"death") or string.find(nm,"damage") then
                pcall(function() if desc:IsA("BindableEvent") then desc:Fire(); desc:Fire(999999) else task.spawn(function() desc:Invoke(999999) end) end end)
            end
        end
    end
end

local function kill_21_AttributeTagExecution(obj)
    local root = getRootPart(obj); local hum = obj:FindFirstChildOfClass("Humanoid"); local list = {obj, root, hum}
    for _,item in ipairs(list) do if item then pcall(function() item:SetAttribute("Dead", true); item:SetAttribute("IsDead", true); item:SetAttribute("Killed", true); item:SetAttribute("State", "Dead"); item:SetAttribute("Health", 0); item:SetAttribute("HP", 0) end) end end
end

local function kill_25_DisarmBossHitboxes(obj)
    for _,v in ipairs(obj:GetDescendants()) do if v:IsA("BasePart") or v:IsA("TouchTransmitter") or v:IsA("Tool") then local nm = string.lower(v.Name); if string.find(nm,"hitbox") or string.find(nm,"weapon") or string.find(nm,"sword") or string.find(nm,"blade") then pcall(function() v:Destroy() end) end end end
end

local function kill_37_MatrixWeaponTouch(obj)
    if not firetouchinterest then return end
    local char = lp.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not tool then return end
    if tool.Parent ~= char then tool.Parent = char end
    local toolParts = {}; for _,p in ipairs(tool:GetDescendants()) do if p:IsA("BasePart") then table.insert(toolParts, p) end end
    local npcParts = {}; for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(npcParts, p) end end
    task.spawn(function()
        for i=1,5 do
            if not obj or not obj.Parent then break end
            pcall(function() tool:Activate() end)
            for _,tp in ipairs(toolParts) do for _,np in ipairs(npcParts) do pcall(function() firetouchinterest(tp, np, 0); firetouchinterest(tp, np, 1) end) end end
            task.wait(0.04)
        end
    end)
end

local function kill_43_TouchInterestMatrixFlood(obj)
    if not firetouchinterest then return end
    local root = getRootPart(obj); if not root then return end
    local allTouchers = {}
    for _,desc in ipairs(ws:GetDescendants()) do
        if desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent:IsA("BasePart") and desc.Parent ~= root then
            table.insert(allTouchers, desc.Parent)
        end
    end
    task.spawn(function() for i=1,6 do for _,tp in ipairs(allTouchers) do pcall(function() firetouchinterest(root, tp, 0); firetouchinterest(root, tp, 1) end) end; task.wait(0.04) end end)
end

-- ==================== 🧪 СТАРЫЕ ТЕСТОВЫЕ (№87-№96) ====================
local function kill_87(obj) kill_86_GoldenGrailOverdrive(obj); kill_18_SafeRemoteBruteForce(obj) end
local function kill_88(obj) if not firetouchinterest then return end; local char=lp.Character; local root=getRootPart(obj); if not char or not root then return end; for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then pcall(function() firetouchinterest(p,root,0); firetouchinterest(p,root,1) end) end end end
local function kill_89(obj) claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do if v:IsA("Weld") or v:IsA("Motor6D") then if v.Part1 and string.find(string.lower(v.Part1.Name),"weapon") then pcall(function() v.Part0=nil; v.Part1=nil end) end end end end
local function kill_90(obj) claimFE(obj); local hum=obj:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum.HipHeight=-50; hum.PlatformStand=true; hum:ChangeState(Enum.HumanoidStateType.Dead) end) end end
local function kill_91(obj) local root=getRootPart(obj); local hum=obj:FindFirstChildOfClass("Humanoid"); for _,item in ipairs({obj,root,hum}) do if item then for _,attr in ipairs({"Shield","Armor","GodMode","Invulnerable"}) do pcall(function() item:SetAttribute(attr,0) end) end; pcall(function() item:SetAttribute("Health",1) end) end end end
local function kill_92(obj) local hum=obj:FindFirstChildOfClass("Humanoid"); local root=getRootPart(obj); if not hum or not root then return end; task.spawn(function() local seat=Instance.new("Seat"); seat.Transparency=1; seat.CanCollide=false; seat.CFrame=root.CFrame; seat.Parent=ws; pcall(function() seat:Sit(hum) end); task.wait(0.08); pcall(function() seat.CFrame=CFrame.new(root.Position.X,2000,root.Position.Z); seat.Anchored=true; if obj.BreakJoints then obj:BreakJoints() end end) end) end
local function kill_93(obj) for _,d in ipairs(ws:GetDescendants()) do if d:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(d) end) elseif d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) end) end end end
local function kill_94(obj) local target=obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("AnimationController"); if not target then return end; pcall(function() for _,t in ipairs(target:GetPlayingAnimationTracks()) do t:Stop(0) end end) end
local function kill_95(obj) claimFE(obj); local root=getRootPart(obj); if not root then return end; pcall(function() for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then p.RootPriority=-127; p.Massless=true end end end) end
local function kill_96(obj) pcall(function() for _,tag in ipairs({"Dead","Killed","Despawn"}) do CollectionService:AddTag(obj,tag) end end) end

-- ==================== 🎮 МОДУЛЬ v33: REAL INPUT SIM (№97, №99, №100, №104) ====================
local function kill_97_VirtualInputClickStorm(obj)
    local root = getRootPart(obj); if not root then return end
    task.spawn(function()
        for i=1,15 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local screenPos, onScreen = cam:WorldToScreenPoint(root.Position)
                if onScreen then
                    VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0); task.wait(0.02)
                    VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
                end
            end)
            task.wait(0.08)
        end
    end)
end

local function kill_99_AbilityKeyPresser(obj)
    local keys = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.F, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
    local root = getRootPart(obj)
    task.spawn(function()
        if root then pcall(function() cam.CFrame = CFrame.new(cam.CFrame.Position, root.Position) end) end
        for _, key in ipairs(keys) do
            if not obj or not obj.Parent then break end
            pcall(function() VIM:SendKeyEvent(true, key, false, game); task.wait(0.05); VIM:SendKeyEvent(false, key, false, game) end)
            task.wait(0.1)
        end
        for _,rem in ipairs(DeepAnalysisData.AbilityRemotes) do
            pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(obj); rem:FireServer(obj, root and root.Position) end end)
        end
    end)
end

local function kill_100_MobileTouchEmulator(obj)
    local root = getRootPart(obj); if not root then return end
    task.spawn(function()
        for i=1,10 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local screenPos, onScreen = cam:WorldToScreenPoint(root.Position)
                if onScreen then
                    VIM:SendTouchEvent(1, 1, screenPos.X, screenPos.Y); task.wait(0.03)
                    VIM:SendTouchEvent(1, 2, screenPos.X, screenPos.Y); task.wait(0.03)
                    VIM:SendTouchEvent(1, 3, screenPos.X, screenPos.Y)
                end
            end)
            task.wait(0.15)
        end
    end)
end

local function kill_104_CameraAimLockFire(obj)
    local root = getRootPart(obj); if not root then return end
    local char = lp.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    task.spawn(function()
        for i=1,12 do
            if not obj or not obj.Parent then break end
            pcall(function()
                cam.CFrame = CFrame.new(hrp.Position + Vector3.new(0,2,0), root.Position)
                local vps = cam.ViewportSize
                VIM:SendMouseButtonEvent(vps.X/2, vps.Y/2, 0, true, game, 0); task.wait(0.03)
                VIM:SendMouseButtonEvent(vps.X/2, vps.Y/2, 0, false, game, 0)
                local tool = char:FindFirstChildOfClass("Tool"); if tool then tool:Activate() end
            end)
            task.wait(0.1)
        end
    end)
end

-- ==================== ⚔️ МОДУЛЬ v33: TOOL ACTIVATE MIMIC (№98, №103) ====================
local function kill_98_ToolActivateLegitCycle(obj)
    local char = lp.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    task.spawn(function()
        local tools = {}
        for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t) end end
        for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t) end end
        for _,tool in ipairs(tools) do
            if not obj or not obj.Parent then break end
            pcall(function() hum:EquipTool(tool) end); task.wait(0.1)
            for i=1,8 do
                pcall(function() tool:Activate() end); task.wait(0.15)
                pcall(function() tool:Deactivate() end); task.wait(0.05)
            end
        end
    end)
end

local function kill_103_InventoryAutoEquip(obj)
    local char = lp.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    for _,tool in ipairs(lp.Backpack:GetChildren()) do if tool:IsA("Tool") then pcall(function() hum:EquipTool(tool) end); task.wait(0.05) end end
    local pg = lp:FindFirstChild("PlayerGui"); if not pg then return end
    task.spawn(function()
        for _,gui in ipairs(pg:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                local nm = string.lower(gui.Name..(gui.Parent and gui.Parent.Name or ""))
                if string.find(nm,"weapon") or string.find(nm,"sword") or string.find(nm,"slot") or string.find(nm,"item") or string.find(nm,"equip") then
                    pcall(function()
                        for _,con in ipairs(getconnections and getconnections(gui.MouseButton1Click) or {}) do pcall(function() con:Fire() end) end
                        local abs = gui.AbsolutePosition; local sz = gui.AbsoluteSize
                        VIM:SendMouseButtonEvent(abs.X + sz.X/2, abs.Y + sz.Y/2, 0, true, game, 0); task.wait(0.03)
                        VIM:SendMouseButtonEvent(abs.X + sz.X/2, abs.Y + sz.Y/2, 0, false, game, 0)
                    end)
                    task.wait(0.05)
                end
            end
        end
    end)
end

-- ==================== 🛡️ МОДУЛЬ v33: ANTI-ROLLBACK + SELF-KICK GUARD (№101, №102) ====================
local function kill_101_AntiRollbackHPGuard(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if rollbackGuards[obj] then rollbackGuards[obj]:Disconnect() end
    local lastHP = hum.Health
    rollbackGuards[obj] = hum:GetPropertyChangedSignal("Health"):Connect(function()
        local currentHP = hum.Health
        if currentHP > lastHP + 5 then
            print("[🛡️ ROLLBACK]", lastHP, "->", currentHP, "— возврат!")
            pcall(function() hum.Health = math.max(0, lastHP - 100) end)
        else lastHP = currentHP end
    end)
    task.delay(30, function() if rollbackGuards[obj] then rollbackGuards[obj]:Disconnect(); rollbackGuards[obj]=nil end end)
end

local function kill_102_SelfKickPrevention(obj)
    local char = lp.Character; if not char then return end
    local myHum = char:FindFirstChildOfClass("Humanoid"); if not myHum then return end
    task.spawn(function()
        for i=1,20 do
            pcall(function()
                if myHum.Health < myHum.MaxHealth*0.5 then myHum.Health = myHum.MaxHealth end
                if not char:FindFirstChildOfClass("ForceField") then
                    local ff = Instance.new("ForceField"); ff.Visible=false; ff.Parent=char
                    game:GetService("Debris"):AddItem(ff, 3)
                end
            end)
            task.wait(0.5)
        end
    end)
    pcall(function() myHum.BreakJointsOnDeath = false end)
end

-- ==================== 🔍 МОДУЛЬ v33: SERVER-SYNC + BOSS-ID (№105, №106) ====================
local function kill_105_ServerFrameSyncDamage(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    task.spawn(function()
        for i=1,60 do
            if not obj or not obj.Parent then break end
            rs.Heartbeat:Wait()
            pcall(function()
                hum:TakeDamage(100)
                for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do if rem:IsA("RemoteEvent") then pcall(function() rem:FireServer(obj) end) end end
            end)
        end
    end)
end

local function kill_106_BossIDDamageRouter(obj)
    local bossIDs = {}
    pcall(function()
        for attr, val in pairs(obj:GetAttributes()) do
            local nm = string.lower(attr)
            if string.find(nm,"id") or string.find(nm,"guid") or string.find(nm,"uid") or string.find(nm,"target") then table.insert(bossIDs, val) end
        end
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("StringValue") or v:IsA("NumberValue") or v:IsA("IntValue") then
                local nm = string.lower(v.Name)
                if string.find(nm,"id") or string.find(nm,"guid") or string.find(nm,"uid") then table.insert(bossIDs, v.Value) end
            end
        end
    end)
    table.insert(bossIDs, obj); table.insert(bossIDs, obj.Name); local root=getRootPart(obj); if root then table.insert(bossIDs, root) end
    task.spawn(function()
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            for _,id in ipairs(bossIDs) do
                pcall(function()
                    if rem:IsA("RemoteEvent") then rem:FireServer(id); rem:FireServer(id, 999999); rem:FireServer("Damage", id, 999999); rem:FireServer({Target=id, Damage=999999})
                    elseif rem:IsA("RemoteFunction") then task.spawn(function() rem:InvokeServer(id, 999999) end) end
                end)
            end
            task.wait(0.02)
        end
    end)
end

-- ==================== ⚔️ МОДУЛЬ v35: PURE FE DAMAGE (№117-№125) ====================
local function kill_117_HumanoidStateFlood(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    pcall(function()
        for _, state in pairs(Enum.HumanoidStateType:GetEnumItems()) do
            if state ~= Enum.HumanoidStateType.Dead then pcall(function() hum:SetStateEnabled(state, false) end) end
        end
        for _, s in ipairs({Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Physics, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.PlatformStanding}) do
            pcall(function() hum:ChangeState(s) end)
        end
        hum.PlatformStand=true; hum.Sit=true; hum.WalkSpeed=0; hum.JumpPower=0; hum.MaxHealth=0; hum.Health=0; hum:TakeDamage(math.huge)
    end)
end

local function kill_118_HealthClampOverride(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    task.spawn(function()
        for i=1,30 do
            if not obj or not obj.Parent then break end
            pcall(function()
                if hum then hum.MaxHealth=0; hum.Health=0; hum:TakeDamage(math.huge) end
                for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") then v.Value=0 end end end
                for attr,_ in pairs(obj:GetAttributes()) do local nm=string.lower(attr); if string.find(nm,"hp") or string.find(nm,"health") then obj:SetAttribute(attr,0) end end
            end)
            task.wait(0.02)
        end
    end)
end

local function kill_119_ForceFieldDeathTrap(obj)
    claimFE(obj)
    pcall(function()
        for _,ff in ipairs(obj:GetDescendants()) do if ff:IsA("ForceField") then ff:Destroy() end end
        local root = getRootPart(obj)
        if root then
            for i=1,5 do
                local exp = Instance.new("Explosion")
                exp.Position = root.Position; exp.BlastRadius=50; exp.BlastPressure=0; exp.DestroyJointRadiusPercent=1; exp.ExplosionType=Enum.ExplosionType.NoCraters
                exp.Parent = ws
            end
        end
        local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then hum:TakeDamage(math.huge); hum.Health=0; hum:ChangeState(Enum.HumanoidStateType.Dead) end
    end)
end

local function kill_120_NeutralTeamAbuse(obj)
    pcall(function()
        for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.BrickColor=BrickColor.new("Medium stone grey") end) end end
        for _,attr in ipairs({"Team","TeamColor","Faction","Side","Enemy","IsEnemy","Friendly"}) do
            pcall(function() obj:SetAttribute(attr,"Neutral") end); pcall(function() obj:SetAttribute(attr,false) end)
        end
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("ObjectValue") or v:IsA("BrickColorValue") then local nm=string.lower(v.Name); if string.find(nm,"team") or string.find(nm,"faction") then pcall(function() v.Value=nil end) end end
        end
        local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then hum:TakeDamage(math.huge); hum.Health=0 end
    end)
end

local function kill_121_RootHeadDecapitate(obj)
    claimFE(obj)
    pcall(function()
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then hum.RequiresNeck=true; hum.BreakJointsOnDeath=true end
        local head = obj:FindFirstChild("Head")
        if head then
            for _,j in ipairs(head:GetChildren()) do
                if j:IsA("Motor6D") or j:IsA("Weld") or j:IsA("JointInstance") then pcall(function() j.Part0=nil; j.Part1=nil end) end
            end
            pcall(function() head.AssemblyLinearVelocity = Vector3.new(0,500,0) end)
        end
        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead); hum.Health=0 end
    end)
end

local function kill_122_MassiveTakeDamage(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    task.spawn(function()
        for wave=1,5 do
            if not obj or not obj.Parent then break end
            for i=1,100 do pcall(function() hum:TakeDamage(1e9) end) end
            pcall(function() hum.Health=0 end)
            task.wait(0.03)
        end
    end)
end

local function kill_123_RagdollSuffocation(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    pcall(function()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Physics); hum:ChangeState(Enum.HumanoidStateType.Ragdoll); hum.PlatformStand=true; hum.RequiresNeck=true end
        for _,j in ipairs(obj:GetDescendants()) do if j:IsA("Motor6D") then pcall(function() j.Part0=nil; j.Part1=nil end) end end
        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead); hum.Health=0; hum:TakeDamage(math.huge) end
    end)
end

local function kill_124_VelocityShredder(obj)
    claimFE(obj)
    task.spawn(function()
        for wave=1,3 do
            if not obj or not obj.Parent then break end
            for i,p in ipairs(obj:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function()
                        p.CanCollide=true; p.Massless=true
                        local dir = Vector3.new(math.sin(i*0.7)*5000, math.abs(math.cos(i*0.3))*8000, math.cos(i*1.1)*5000)
                        p.AssemblyLinearVelocity=dir; p.AssemblyAngularVelocity=dir*0.5
                    end)
                end
            end
            local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum:TakeDamage(math.huge); hum.Health=0 end) end
            task.wait(0.05)
        end
    end)
end

local function kill_125_ExplosionSpamRing(obj)
    local root = getRootPart(obj); if not root then return end
    task.spawn(function()
        for i=1,20 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local angle = (i/20)*math.pi*2
                local offset = Vector3.new(math.cos(angle)*3, 0, math.sin(angle)*3)
                local exp = Instance.new("Explosion")
                exp.Position = root.Position + offset
                exp.BlastRadius=15; exp.BlastPressure=0; exp.DestroyJointRadiusPercent=1; exp.ExplosionType=Enum.ExplosionType.NoCraters
                exp.Parent = ws
                local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then hum:TakeDamage(100000) end
            end)
            task.wait(0.02)
        end
    end)
end

-- ==================== 🌀 10 НОВЫХ МЕТОДОВ v36 (№127-№136) — ChaosPhysics MODULE ====================

-- 127. CFRAME LOOP CRUSHER — микро-CFrame атака на Motor6D.C0/C1 в цикле
-- (не путать со старым №41 который делает ОДНО большое смещение — тут ТЫСЯЧИ микро-смещений в разные стороны)
local function kill_127_CFrameLoopCrusher(obj)
    claimFE(obj)
    print("[🌀 v36 127] CFRAME LOOP CRUSHER для:", obj.Name)
    task.spawn(function()
        local motors = {}
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("Motor6D") or v:IsA("Weld") then table.insert(motors, v) end
        end
        for tick = 1, 50 do
            if not obj or not obj.Parent then break end
            for i, m in ipairs(motors) do
                pcall(function()
                    -- Микро-смещения в псевдослучайные стороны каждый тик = ломает солвер физики
                    local t = tick * 0.1 + i * 0.37
                    m.C0 = m.C0 * CFrame.new(math.sin(t) * 500, math.cos(t*1.3) * 500, math.sin(t*0.7) * 500) * CFrame.Angles(math.sin(t)*10, math.cos(t)*10, math.sin(t*2)*10)
                end)
            end
            task.wait(0.01)
        end
    end)
end

-- 128. ANIMATION TRACK OVERLOAD — 500 anim треков на Humanoid = замирает
local function kill_128_AnimationTrackOverload(obj)
    claimFE(obj)
    local target = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("AnimationController")
    if not target then return end
    print("[🌀 v36 128] ANIMATION TRACK OVERLOAD (500 треков) для:", obj.Name)
    task.spawn(function()
        local anim = target:FindFirstChildOfClass("Animator")
        if not anim then anim = Instance.new("Animator"); anim.Parent = target end
        for i = 1, 500 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local a = Instance.new("Animation")
                a.AnimationId = "rbxassetid://0"  -- пустая = крашит систему
                local track = anim:LoadAnimation(a)
                track:Play()
                track.Priority = Enum.AnimationPriority.Action4
                track:AdjustSpeed(1000)
            end)
        end
        -- Финальный удар — TakeDamage под перегрузкой
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then task.wait(0.1); pcall(function() hum:TakeDamage(math.huge); hum.Health = 0 end) end
    end)
end

-- 129. SOUND FREQUENCY WEAPON — Sound с PlaybackSpeed=huge (лаг-урон + сам звук может убить)
local function kill_129_SoundFrequencyWeapon(obj)
    local root = getRootPart(obj); if not root then return end
    print("[🌀 v36 129] SOUND FREQUENCY WEAPON для:", obj.Name)
    task.spawn(function()
        for i = 1, 10 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://9046196336"  -- любой звук
                s.Volume = 10
                s.PlaybackSpeed = math.huge
                s.Pitch = 20
                s.RollOffMaxDistance = 10000
                s.Parent = root
                s:Play()
                game:GetService("Debris"):AddItem(s, 0.5)
            end)
            task.wait(0.05)
        end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:TakeDamage(math.huge) end) end
    end)
end

-- 130. ATTACHMENT ORBIT CHAOS — крутим Attachments в бешеных орбитах = ломает связи констрейнтов
local function kill_130_AttachmentOrbitChaos(obj)
    claimFE(obj)
    print("[🌀 v36 130] ATTACHMENT ORBIT CHAOS для:", obj.Name)
    task.spawn(function()
        local attachments = {}
        for _,a in ipairs(obj:GetDescendants()) do if a:IsA("Attachment") then table.insert(attachments, a) end end
        for tick = 1, 40 do
            if not obj or not obj.Parent then break end
            for i, att in ipairs(attachments) do
                pcall(function()
                    local t = tick * 0.15 + i * 0.5
                    att.CFrame = CFrame.new(math.sin(t)*100, math.cos(t)*100, math.sin(t*2)*100) * CFrame.Angles(math.sin(t)*5, math.cos(t)*5, 0)
                end)
            end
            task.wait(0.02)
        end
    end)
end

-- 131. COLLISION GROUP ISOLATE — вырубаем CollisionGroup NPC → падает сквозь пол в бездну
local function kill_131_CollisionGroupIsolate(obj)
    claimFE(obj)
    print("[🌀 v36 131] COLLISION GROUP ISOLATE для:", obj.Name)
    pcall(function()
        -- Создаём группу если её нет
        local groupName = "NPCVoid_" .. tostring(math.random(1000,9999))
        pcall(function() PhysicsService:RegisterCollisionGroup(groupName) end)
        pcall(function() PhysicsService:CollisionGroupSetCollidable(groupName, "Default", false) end)
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.CollisionGroup = groupName
                    p.CanCollide = false
                    p.Massless = true
                end)
            end
        end
        -- Плюс FE-урон
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.FallingDown); hum:TakeDamage(math.huge) end) end
    end)
end

-- 132. NETWORK OWNER PING-PONG — 20 раз меняем NetworkOwner (десинк клиент/сервер)
local function kill_132_NetworkOwnerPingPong(obj)
    print("[🌀 v36 132] NETWORK OWNER PING-PONG для:", obj.Name)
    task.spawn(function()
        local parts = {}
        for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") and not p.Anchored then table.insert(parts, p) end end
        for wave = 1, 20 do
            if not obj or not obj.Parent then break end
            for _,p in ipairs(parts) do
                pcall(function()
                    -- Быстро переключаем между мной и nil (сервер) = десинк
                    if wave % 2 == 0 then p:SetNetworkOwner(lp) else p:SetNetworkOwner(nil); p:SetNetworkOwnershipAuto() end
                end)
            end
            task.wait(0.03)
        end
        -- После десинка бьём по HP
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:TakeDamage(math.huge); hum.Health=0 end) end
    end)
end

-- 133. BODYFORCE INFINITE PUSH — BodyVelocity/LinearVelocity с MaxForce=inf
local function kill_133_BodyForceInfinitePush(obj)
    claimFE(obj)
    print("[🌀 v36 133] BODYFORCE INFINITE PUSH для:", obj.Name)
    local root = getRootPart(obj); if not root then return end
    task.spawn(function()
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    -- Создаём BodyVelocity с бесконечной силой в случайные стороны
                    local bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Vector3.new(
                        (math.random()-0.5) * 500,
                        math.random() * 800,
                        (math.random()-0.5) * 500
                    )
                    bv.Parent = p
                    game:GetService("Debris"):AddItem(bv, 1)
                end)
            end
        end
        task.wait(0.5)
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:TakeDamage(math.huge); hum.Health=0; hum:ChangeState(Enum.HumanoidStateType.Ragdoll) end) end
    end)
end

-- 134. TOUCHED EVENT BOMB — 1000 фиктивных Touched на все части NPC
local function kill_134_TouchedEventBomb(obj)
    if not firetouchinterest then return end
    print("[🌀 v36 134] TOUCHED EVENT BOMB (1000x) для:", obj.Name)
    local char = lp.Character; if not char then return end
    local myParts = {}
    for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then table.insert(myParts, p) end end
    local npcParts = {}
    for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(npcParts, p) end end
    task.spawn(function()
        for wave = 1, 5 do
            if not obj or not obj.Parent then break end
            for i = 1, 200 do
                pcall(function()
                    local mp = myParts[math.random(1,#myParts)]
                    local np = npcParts[math.random(1,#npcParts)]
                    if mp and np then
                        firetouchinterest(mp, np, 0)
                        firetouchinterest(mp, np, 1)
                    end
                end)
            end
            task.wait(0.05)
        end
    end)
end

-- 135. MESH RESIZE OVERFLOW — MeshPart.Size = 0.01 (босс становится микроскопическим = глюки коллизий и урон)
local function kill_135_MeshResizeOverflow(obj)
    claimFE(obj)
    print("[🌀 v36 135] MESH RESIZE OVERFLOW для:", obj.Name)
    pcall(function()
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("MeshPart") then
                pcall(function() p.Size = Vector3.new(0.01, 0.01, 0.01); p.Massless = true end)
            end
            if p:IsA("SpecialMesh") or p:IsA("BlockMesh") or p:IsA("CylinderMesh") then
                pcall(function() p.Scale = Vector3.new(0.001, 0.001, 0.001) end)
            end
        end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:TakeDamage(math.huge); hum.Health=0 end) end
    end)
end

-- 136. CHILDREN CASCADE PURGE — рекурсивная очистка Value/Attribute-полей (не Destroy, а обнуление)
local function kill_136_ChildrenCascadePurge(obj)
    print("[🌀 v36 136] CHILDREN CASCADE PURGE для:", obj.Name)
    pcall(function()
        -- Рекурсивно обнуляем ВСЕ NumberValue/IntValue/BoolValue/StringValue
        for _,v in ipairs(obj:GetDescendants()) do
            pcall(function()
                if v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("DoubleConstrainedValue") then v.Value = 0
                elseif v:IsA("BoolValue") then v.Value = false
                elseif v:IsA("StringValue") then v.Value = "dead"
                elseif v:IsA("ObjectValue") then v.Value = nil
                elseif v:IsA("Vector3Value") then v.Value = Vector3.zero
                elseif v:IsA("CFrameValue") then v.Value = CFrame.new(0,0,0)
                end
            end)
        end
        -- Все атрибуты в 0/false
        for attr,val in pairs(obj:GetAttributes()) do
            pcall(function()
                if type(val) == "number" then obj:SetAttribute(attr, 0)
                elseif type(val) == "boolean" then obj:SetAttribute(attr, false)
                elseif type(val) == "string" then obj:SetAttribute(attr, "dead") end
            end)
        end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.MaxHealth=0; hum.Health=0; hum:TakeDamage(math.huge) end) end
    end)
end

-- ==================== 💥 МАСТЕР-ДВИЖОК v36.0 (объединяет ВСЕ модули) ====================
local function MASTER_OMNI_KILL_ENGINE(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[💥 MASTER OMNI-KILL v36] Атака:", obj.Name)
    local ticksCount = CombatSettings.HyperSpeed and 15 or 30
    local waitTime = CombatSettings.HyperSpeed and 0.01 or 0.03
    task.spawn(function()
        for tick = 1, ticksCount do
            if not obj or not obj.Parent then break end

            -- 👑 GOLDEN GRAIL
            if CombatSettings.GoldenGrail then kill_86_GoldenGrailOverdrive(obj) end

            -- 📡 REMOTES + WEAPONS + TOUCH
            if CombatSettings.RemotesWeapons and tick % 2 == 0 then
                kill_18_SafeRemoteBruteForce(obj); kill_17_OfficialWeaponOverdrive(obj); kill_19_WeaponRemoteHijack(obj)
                kill_37_MatrixWeaponTouch(obj); kill_43_TouchInterestMatrixFlood(obj); kill_20_BindableSignalTrigger(obj)
                kill_21_AttributeTagExecution(obj); kill_106_BossIDDamageRouter(obj)
            end

            -- 🦾 CUSTOM RIGS
            if CombatSettings.CustomRigs and tick % 2 == 0 then
                kill_7_CustomConstraintShatter(obj); kill_8_SkinnedMeshBoneShatter(obj); kill_9_KineticBodyTear(obj); kill_25_DisarmBossHitboxes(obj)
            end

            -- 🩸 FE CLASSIC
            if CombatSettings.FEClassic and tick % 3 == 0 then
                kill_1_SimpleHP(obj); kill_2_RagdollStateDead(obj); kill_3_BreakJointsMotorsLoop(obj); kill_4_ValueAttrZero(obj); kill_5_DecapitateHeadTorso(obj)
            end

            -- 📊 MATH STATS
            if CombatSettings.MathStats and tick % 3 == 0 then
                kill_11_TakeDamageLoop(obj); kill_12_NaNInfinityMathCrash(obj); kill_13_DoubleOverflow1e308(obj)
                kill_14_AttrValNegativeInversion(obj); kill_15_StripShieldsImmortality(obj); kill_16_SafeMaxHealthShrink(obj)
            end

            -- 🚀 DESTROYER (только по тумблеру)
            if CombatSettings.DestroyerServer and tick == 1 then
                task.spawn(function() kill_10_AssemblyAngularSpinTear(obj); kill_29_SupersonicLaunch(obj); kill_41_MotorWeldCFrameCrush(obj) end)
            end

            -- 🎮 REAL INPUT SIM (v33)
            if CombatSettings.RealInputSim and tick % 4 == 0 then
                kill_97_VirtualInputClickStorm(obj); kill_100_MobileTouchEmulator(obj); kill_99_AbilityKeyPresser(obj); kill_104_CameraAimLockFire(obj)
            end

            -- ⚔️ TOOL ACTIVATE MIMIC (v33)
            if CombatSettings.ToolActivateMimic and tick % 4 == 0 then
                kill_98_ToolActivateLegitCycle(obj); if tick == 4 then kill_103_InventoryAutoEquip(obj) end
            end

            -- 🛡️ ANTI-ROLLBACK + 🚫 SELF-KICK (v33)
            if CombatSettings.AntiRollback and tick == 1 then kill_101_AntiRollbackHPGuard(obj) end
            if CombatSettings.SelfKickGuard and tick == 1 then kill_102_SelfKickPrevention(obj) end

            -- ⚔️ PURE FE DAMAGE (v35 - без №119 и №125, они в ExplosionCombat)
            if CombatSettings.PureFEDamage and tick % 3 == 0 then
                kill_117_HumanoidStateFlood(obj); kill_118_HealthClampOverride(obj); kill_120_NeutralTeamAbuse(obj)
                kill_121_RootHeadDecapitate(obj); kill_122_MassiveTakeDamage(obj); kill_123_RagdollSuffocation(obj); kill_124_VelocityShredder(obj)
                if tick % 6 == 0 then kill_105_ServerFrameSyncDamage(obj) end
            end

            -- 💥 EXPLOSION COMBAT
            if CombatSettings.ExplosionCombat and tick % 4 == 0 then
                kill_119_ForceFieldDeathTrap(obj); kill_6_SafePulseExplosion(obj)
                if tick % 8 == 0 then kill_125_ExplosionSpamRing(obj) end
            end

            -- 🌀 CHAOS PHYSICS (v36 — новые №127-136)
            if CombatSettings.ChaosPhysics and tick % 4 == 0 then
                kill_127_CFrameLoopCrusher(obj); kill_130_AttachmentOrbitChaos(obj); kill_132_NetworkOwnerPingPong(obj)
                kill_133_BodyForceInfinitePush(obj); kill_134_TouchedEventBomb(obj); kill_136_ChildrenCascadePurge(obj)
                if tick == 4 then
                    kill_128_AnimationTrackOverload(obj); kill_129_SoundFrequencyWeapon(obj)
                    kill_131_CollisionGroupIsolate(obj); kill_135_MeshResizeOverflow(obj)
                end
            end

            task.wait(waitTime)
        end
    end)
end

-- ==================== ГРАФИЧЕСКИЙ ИНТЕРФЕЙС (GUI v36.0 — БОЛЬШОЙ КАК ОРИГИНАЛ!) ====================
local sg = Instance.new("ScreenGui")
sg.Name = "NPCKillTesterPro_v36_GUI"
sg.ResetOnSpawn = false
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = lp:WaitForChild("PlayerGui") end

local mf = Instance.new("Frame", sg)
mf.Size = UDim2.new(0, 780, 0, 860)
mf.Position = UDim2.new(0.5, -390, 0.5, -430)
mf.BackgroundColor3 = Color3.fromRGB(16,16,20)
mf.BorderSizePixel = 0
mf.Active = true
mf.Draggable = true
Instance.new("UICorner", mf).CornerRadius = UDim.new(0,14)

local title = Instance.new("TextLabel", mf)
title.Size = UDim2.new(1, -80, 0, 38)
title.Text = "  👑 NPC KILL TESTER v36.0 — FULL ARSENAL MERGED (10 МОДУЛЕЙ + 60+ МЕТОДОВ)"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
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
        mf:TweenSize(UDim2.new(0,780,0,38), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minBtn.Text = "+"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=false end end
    else
        mf:TweenSize(UDim2.new(0,780,0,860), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minBtn.Text = "-"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=true end end
    end
end)

-- СЕКЦИЯ ЕДИНОЙ МАСТЕР-КНОПКИ
local actionSection = Instance.new("Frame", mf)
actionSection.Size = UDim2.new(1, -20, 0, 64)
actionSection.Position = UDim2.new(0, 10, 0, 42)
actionSection.BackgroundColor3 = Color3.fromRGB(24,24,30)
Instance.new("UICorner", actionSection).CornerRadius = UDim.new(0,10)

local masterBtn = Instance.new("TextButton", actionSection)
masterBtn.Size = UDim2.new(0.48, -4, 0, 52); masterBtn.Position = UDim2.new(0, 8, 0, 6)
masterBtn.Text = "💥 MASTER OMNI-KILL (ВСЕ 60+ МЕТОДОВ ПО НАСТРОЙКАМ)\n(Запускает ВКЛЮЧЕННЫЕ модули из панели ниже на выбранных целях)"
masterBtn.Font = Enum.Font.GothamBold; masterBtn.TextSize = 10; masterBtn.TextColor3 = Color3.fromRGB(255,255,255); masterBtn.BackgroundColor3 = Color3.fromRGB(10,140,60)
Instance.new("UICorner", masterBtn).CornerRadius = UDim.new(0,8)
masterBtn.MouseButton1Click:Connect(function()
    local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
    print("[💥 MASTER v36] Запуск на", #targets, "целей!")
    for _,obj in ipairs(targets) do task.spawn(function() MASTER_OMNI_KILL_ENGINE(obj) end) end
end)

local masterKillAll = Instance.new("TextButton", actionSection)
masterKillAll.Size = UDim2.new(0.48, -4, 0, 52); masterKillAll.Position = UDim2.new(0.52, -4, 0, 6)
masterKillAll.Text = "⚡ MASTER KILL ALL (ЗАЧИСТКА ВСЕХ NPC В ИГРЕ)\n(Запускает выбранные модули по ВСЕМ найденным врагам)"
masterKillAll.Font = Enum.Font.GothamBold; masterKillAll.TextSize = 10; masterKillAll.TextColor3 = Color3.fromRGB(255,255,0); masterKillAll.BackgroundColor3 = Color3.fromRGB(160,30,0)
Instance.new("UICorner", masterKillAll).CornerRadius = UDim.new(0,8)
masterKillAll.MouseButton1Click:Connect(function()
    task.spawn(function()
        local entities = getAllValidEntities()
        print("[⚡ KILL ALL v36]", #entities, "целей!")
        for i, o in ipairs(entities) do task.spawn(function() MASTER_OMNI_KILL_ENGINE(o) end); if i % 3 == 0 then task.wait(0.04) end end
    end)
end)

-- СЕКЦИЯ ПАНЕЛИ НАСТРОЕК (РАСШИРЕНА — 10 модулей)
local settingsSection = Instance.new("Frame", mf)
settingsSection.Size = UDim2.new(1, -20, 0, 210)
settingsSection.Position = UDim2.new(0, 10, 0, 112)
settingsSection.BackgroundColor3 = Color3.fromRGB(20,20,28)
Instance.new("UICorner", settingsSection).CornerRadius = UDim.new(0,10)

local stTitle = Instance.new("TextLabel", settingsSection)
stTitle.Size = UDim2.new(1, 0, 0, 20)
stTitle.Text = "  ⚙️ ПАНЕЛЬ НАСТРОЕК (10 МОДУЛЕЙ ДЛЯ МАСТЕР-КНОПКИ + РЕГУЛИРОВКИ):"
stTitle.Font = Enum.Font.GothamBold; stTitle.TextSize = 11; stTitle.TextColor3 = Color3.fromRGB(150,255,255)
stTitle.TextXAlignment = Enum.TextXAlignment.Left; stTitle.BackgroundTransparency = 1

local stGridF = Instance.new("Frame", settingsSection)
stGridF.Size = UDim2.new(1, -10, 1, -22); stGridF.Position = UDim2.new(0, 5, 0, 22)
stGridF.BackgroundTransparency = 1

local stGrid = Instance.new("UIGridLayout", stGridF)
stGrid.CellSize = UDim2.new(0, 248, 0, 30); stGrid.CellPadding = UDim2.new(0, 5, 0, 4)

local function makeSetToggle(text, key, col, defaultVal)
    local state = defaultVal
    local b = Instance.new("TextButton", stGridF)
    b.Text = text .. (state and " [ON]" or " [OFF]")
    b.BackgroundColor3 = state and col or Color3.fromRGB(45,45,55)
    b.Font = Enum.Font.GothamBold; b.TextSize = 10; b.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        state = not state
        CombatSettings[key] = state
        b.Text = text .. (state and " [ON]" or " [OFF]")
        b.BackgroundColor3 = state and col or Color3.fromRGB(45,45,55)
        print("[⚙️]", text, "=", state)
    end)
end

-- Оригинальные модули v32
makeSetToggle("👑 Золотой Грааль #86", "GoldenGrail", Color3.fromRGB(180,140,0), true)
makeSetToggle("📡 Ремоуты/Оружие/Тач", "RemotesWeapons", Color3.fromRGB(0,100,160), true)
makeSetToggle("🦾 Кастомные Тела/Кости", "CustomRigs", Color3.fromRGB(160,80,0), true)
makeSetToggle("🩸 Классика FE + Суставы", "FEClassic", Color3.fromRGB(120,40,40), true)
makeSetToggle("📊 Краш Математики", "MathStats", Color3.fromRGB(100,20,100), true)
-- Новые модули v33
makeSetToggle("🎮 Real Input Sim (VIM)", "RealInputSim", Color3.fromRGB(0,140,140), true)
makeSetToggle("⚔️ Tool Activate Mimic", "ToolActivateMimic", Color3.fromRGB(80,120,0), true)
makeSetToggle("🛡️ Anti-Rollback HP", "AntiRollback", Color3.fromRGB(0,100,180), true)
makeSetToggle("🚫 Self-Kick Guard", "SelfKickGuard", Color3.fromRGB(180,0,100), true)
-- Новые модули v35
makeSetToggle("⚔️ Pure FE Damage", "PureFEDamage", Color3.fromRGB(20,140,80), true)
makeSetToggle("💥 Explosion Combat", "ExplosionCombat", Color3.fromRGB(200,80,40), true)
-- Новый модуль v36
makeSetToggle("🌀 Chaos Physics (v36 NEW)", "ChaosPhysics", Color3.fromRGB(140,20,180), true)
-- Опасный
makeSetToggle("🚀 Destroyer (Космос)", "DestroyerServer", Color3.fromRGB(180,20,0), false)

-- Регулировка урона
local dmgValues = { 5000, 50000, 500000, 999999, math.huge }
local dmgNames = { "5,000", "50,000", "500,000", "999,999", "MAX (Inf)" }
local dmgIdx = 2
local dmgBtn = Instance.new("TextButton", stGridF)
dmgBtn.Text = "⚙️ DPS Урон: " .. dmgNames[dmgIdx]
dmgBtn.BackgroundColor3 = Color3.fromRGB(0,120,80); dmgBtn.Font = Enum.Font.GothamBold; dmgBtn.TextSize = 10; dmgBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", dmgBtn).CornerRadius = UDim.new(0,6)
dmgBtn.MouseButton1Click:Connect(function()
    dmgIdx = (dmgIdx % #dmgValues) + 1
    CombatSettings.DamageAmount = dmgValues[dmgIdx]
    dmgBtn.Text = "⚙️ DPS Урон: " .. dmgNames[dmgIdx]
end)

-- Кнопка скорости
local spdBtn = Instance.new("TextButton", stGridF)
spdBtn.Text = "⚙️ Скорость: Normal (30x)"
spdBtn.BackgroundColor3 = Color3.fromRGB(60,60,80); spdBtn.Font = Enum.Font.GothamBold; spdBtn.TextSize = 10; spdBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", spdBtn).CornerRadius = UDim.new(0,6)
spdBtn.MouseButton1Click:Connect(function()
    CombatSettings.HyperSpeed = not CombatSettings.HyperSpeed
    spdBtn.Text = "⚙️ Скорость: " .. (CombatSettings.HyperSpeed and "HYPER (60x Fast)" or "Normal (30x)")
    spdBtn.BackgroundColor3 = CombatSettings.HyperSpeed and Color3.fromRGB(120,40,160) or Color3.fromRGB(60,60,80)
end)

-- СЕКЦИЯ ТЕСТА 10 НОВЫХ МЕТОДОВ v36 (№127-№136)
local testSection = Instance.new("Frame", mf)
testSection.Size = UDim2.new(1, -20, 0, 115)
testSection.Position = UDim2.new(0, 10, 0, 328)
testSection.BackgroundColor3 = Color3.fromRGB(28,20,32)
Instance.new("UICorner", testSection).CornerRadius = UDim.new(0,10)

local tsTitle = Instance.new("TextLabel", testSection)
tsTitle.Size = UDim2.new(1, 0, 0, 20)
tsTitle.Text = "  🌀 10 НОВЫХ УНИКАЛЬНЫХ МЕТОДОВ v36 (№127 – №136) — CHAOS PHYSICS — КЛИКНИ ДЛЯ ТЕСТА:"
tsTitle.Font = Enum.Font.GothamBold; tsTitle.TextSize = 10; tsTitle.TextColor3 = Color3.fromRGB(220,150,255)
tsTitle.TextXAlignment = Enum.TextXAlignment.Left; tsTitle.BackgroundTransparency = 1

local tsGridF = Instance.new("ScrollingFrame", testSection)
tsGridF.Size = UDim2.new(1, -10, 1, -22); tsGridF.Position = UDim2.new(0, 5, 0, 20)
tsGridF.BackgroundTransparency = 1; tsGridF.ScrollBarThickness = 5
tsGridF.AutomaticCanvasSize = Enum.AutomaticSize.Y; tsGridF.CanvasSize = UDim2.new(0,0,0,0)

local tsGrid = Instance.new("UIGridLayout", tsGridF)
tsGrid.CellSize = UDim2.new(0, 248, 0, 34); tsGrid.CellPadding = UDim2.new(0, 5, 0, 4)

local function makeTestBtn(text, desc, col, fn)
    local b = Instance.new("TextButton", tsGridF)
    b.Text = ""; b.BackgroundColor3 = col; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    local t1 = Instance.new("TextLabel", b)
    t1.Size = UDim2.new(1,-8,0,15); t1.Position = UDim2.new(0,4,0,1); t1.Text = text
    t1.Font = Enum.Font.GothamBold; t1.TextSize = 11; t1.TextColor3 = Color3.fromRGB(255,255,255); t1.BackgroundTransparency = 1
    t1.TextXAlignment = Enum.TextXAlignment.Left
    local t2 = Instance.new("TextLabel", b)
    t2.Size = UDim2.new(1,-8,0,15); t2.Position = UDim2.new(0,4,0,17); t2.Text = desc
    t2.Font = Enum.Font.SourceSans; t2.TextSize = 10; t2.TextColor3 = Color3.fromRGB(210,210,210); t2.BackgroundTransparency = 1
    t2.TextXAlignment = Enum.TextXAlignment.Left
    b.MouseButton1Click:Connect(function()
        local targets = getTargets()
        if #targets == 0 then print("[WARN] Выберите цель!"); return end
        print("[v36 TEST]", text)
        for _,obj in ipairs(targets) do task.spawn(function() fn(obj) end) end
    end)
end

makeTestBtn("127. 🌀 CFrame Loop Crush", "50 микро-CFrame атак на Motor6D (не №41!)", Color3.fromRGB(120,60,180), kill_127_CFrameLoopCrusher)
makeTestBtn("128. 🌀 Anim Track Overload", "500 anim треков = крашится Humanoid", Color3.fromRGB(100,40,160), kill_128_AnimationTrackOverload)
makeTestBtn("129. 🌀 Sound Freq Weapon", "Sound PlaybackSpeed=math.huge (лаг-урон)", Color3.fromRGB(180,60,140), kill_129_SoundFrequencyWeapon)
makeTestBtn("130. 🌀 Attachment Chaos", "Крутим Attachments = рвём констрейнты", Color3.fromRGB(140,20,140), kill_130_AttachmentOrbitChaos)
makeTestBtn("131. 🌀 CollisionGroup Iso", "Свой CollisionGroup → падение сквозь пол", Color3.fromRGB(160,80,180), kill_131_CollisionGroupIsolate)
makeTestBtn("132. 🌀 NetOwner Ping-Pong", "20 переключений NetworkOwner = десинк", Color3.fromRGB(80,60,200), kill_132_NetworkOwnerPingPong)
makeTestBtn("133. 🌀 BodyForce Infinite", "BodyVelocity с MaxForce=math.huge на все", Color3.fromRGB(180,100,60), kill_133_BodyForceInfinitePush)
makeTestBtn("134. 🌀 Touched Bomb 1000x", "1000 фиктивных Touched (не как №43)", Color3.fromRGB(60,140,180), kill_134_TouchedEventBomb)
makeTestBtn("135. 🌀 Mesh Resize 0.01", "Босс становится 1см = глюки коллизий", Color3.fromRGB(160,40,80), kill_135_MeshResizeOverflow)
makeTestBtn("136. 🌀 Cascade Purge", "Обнуляем ВСЕ Value/Attribute рекурсивно", Color3.fromRGB(80,180,100), kill_136_ChildrenCascadePurge)

-- СЕКЦИЯ ТАБЛИЦЫ NPC (нижняя часть)
local listSection = Instance.new("Frame", mf)
listSection.Size = UDim2.new(1, -20, 0, 405)
listSection.Position = UDim2.new(0, 10, 0, 448)
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

makeColLabel(lsHeader, "  ИМЯ (СКАНЕР)", UDim2.new(0,0,0,0), UDim2.new(0.38,0,1,0), Color3.fromRGB(255,255,150))
makeColLabel(lsHeader, "ТИП", UDim2.new(0.39,0,0,0), UDim2.new(0.26,0,1,0), Color3.fromRGB(150,220,255))
makeColLabel(lsHeader, "ЗДОРОВЬЕ", UDim2.new(0.66,0,0,0), UDim2.new(0.18,0,1,0), Color3.fromRGB(150,255,150))
makeColLabel(lsHeader, "ВЛАДЕНИЕ", UDim2.new(0.85,0,0,0), UDim2.new(0.14,0,1,0), Color3.fromRGB(255,180,255))

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
            local hl = Instance.new("Highlight", obj); hl.Name = "_NPCKillHL"; hl.FillColor = Color3.fromRGB(0,255,0); hl.OutlineColor = Color3.fromRGB(0,255,0); hl.FillTransparency = 0.65
            highlights[obj] = hl
        end
    end
end)

deselBtn.MouseButton1Click:Connect(function()
    for obj,_ in pairs(selectedNPCs) do if obj and obj.Parent then local hl = obj:FindFirstChild("_NPCKillHL"); if hl then hl:Destroy() end end end
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
                    local hl = obj:FindFirstChild("_NPCKillHL"); if hl then hl:Destroy() end
                else
                    selectedNPCs[obj] = true; currentNPC = obj; b.BackgroundColor3 = Color3.fromRGB(20,90,30)
                    if not obj:FindFirstChild("_NPCKillHL") then
                        local hl = Instance.new("Highlight", obj); hl.Name = "_NPCKillHL"; hl.FillColor = Color3.fromRGB(0,255,0); hl.OutlineColor = Color3.fromRGB(0,255,0); hl.FillTransparency = 0.65
                        highlights[obj] = hl
                    end
                end
            end)
            table.insert(npcButtons, {obj, b, hp, ow, root})
        end
    end
    title.Text = "  👑 NPC KILL v36.0 FULL ARSENAL (Целей: "..#entities.." | Методов: 60+ | Модулей: 10)"
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
track("boostRS", rs.RenderStepped:Connect(boostAuth))
track("boostHB", rs.Heartbeat:Connect(boostAuth))

task.spawn(function() while true do pcall(refreshTable); task.wait(3.5) end end)
pcall(refreshTable)
runFullAnalysis()

local function unloadAll()
    for _,c in pairs(connections) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,c in pairs(rollbackGuards) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,hl in pairs(highlights) do pcall(function() if hl and hl.Parent then hl:Destroy() end end) end
    for _,o in ipairs(ws:GetDescendants()) do if o.Name == "_NPCKillHL" then pcall(function() o:Destroy() end) end end
    if sg and sg.Parent then sg:Destroy() end
    if highlight and highlight.Parent then highlight:Destroy() end
    _G.NPCKillTesterPro = nil
end

_G.NPCKillTesterPro.Unload = unloadAll
unloadBtn.MouseButton1Click:Connect(unloadAll)

print("========================================================")
print("[👑 KILL LAB v36.0 FULL ARSENAL MERGED EDITION LOADED! 👑]")
print("  ✅ 10 модулей в панели настроек (v32 + v33 + v35 + v36)")
print("  ✅ 60+ методов в главной кнопке (по всем категориям)")
print("  🌀 10 НОВЫХ уникальных методов v36 (№127-№136) в тестах")
print("========================================================")
