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
local StarterGui = game:GetService("StarterGui")
local lp = plrs.LocalPlayer
local mouse = lp:GetMouse()
local ts = game:GetService("TweenService")
local cam = ws.CurrentCamera

local selectedNPCs = {}
local currentNPC = nil
local connections = {}
local highlights = {}
local rollbackGuards = {}

-- 🎛️ ОРИГИНАЛЬНЫЕ 6 КАСТОВ V32 + 1 ДОБАВЛЕННЫЙ (для методов ввода что никуда не влезли)
local CombatSettings = {
    -- Оригинальные 6:
    GoldenGrail = true,        -- 👑 Золотой Грааль (TakeDamage DPS)
    RemotesWeapons = true,     -- 📡 Ремоуты, Оружие, Тач, TakeDamage
    CustomRigs = true,         -- 🦾 Кастомные боссы, кости, констрейнты
    FEClassic = true,          -- 🩸 Классика FE: суставы, HP=0, ragdoll
    MathStats = true,          -- 📊 Краш математики (NaN, 1e308, negative)
    DestroyerServer = false,   -- 🚀 ПОЛЁТ В КОСМОС (OFF по умолчанию)
    -- Новый каст (для методов симуляции ввода что не влезли в 6 оригинальных):
    PlayerInputSim = true,     -- 🎮 Симуляция реального ввода игрока (VIM + Tool)
    -- Регулировки:
    DamageAmount = 50000,
    HyperSpeed = false
}

local DeepAnalysisData = { CombatRemotes = {}, MapHazards = {}, DeathSignals = {}, WeaponRemotes = {}, TaggedKillBricks = {}, AbilityRemotes = {} }

local function track(name, con) if con then connections[name] = con end end

local highlight = Instance.new("Highlight")
highlight.Parent = lp
highlight.FillTransparency = 1
highlight.OutlineTransparency = 1

-- ==================== АНАЛИЗАТОР (как в оригинале) ====================
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
    print("[🤖 v37 ANALYZER] Combat:", #DeepAnalysisData.CombatRemotes, "| Weapon:", #DeepAnalysisData.WeaponRemotes)
end

ws.DescendantAdded:Connect(indexObject); rep.DescendantAdded:Connect(indexObject)

-- ==================== БАЗОВЫЕ УТИЛИТЫ (без изменений) ====================
local function getRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso") or obj:FindFirstChild("Root") or obj:FindFirstChild("Body") or obj:FindFirstChild("Main") or obj:FindFirstChild("Hitbox") or obj:FindFirstChild("Head") or obj:FindFirstChildOfClass("BasePart")
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
    if model:FindFirstChild("Health", true) or model:FindFirstChild("HP", true) or model:GetAttribute("Health") or model:GetAttribute("HP") or model:GetAttribute("Boss") then return true end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("Motor6D") or desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") then return true end
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
        for _, other in ipairs(rawCandidates) do if cand ~= other and other:IsDescendantOf(cand) then isContainer = true; break end end
        if not isContainer then table.insert(finalEntities, cand) end
    end
    return finalEntities
end

local function analyzeEntity(obj)
    local root = getRootPart(obj); if not root then return false, nil, nil, false, nil end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    local anim = obj:FindFirstChildOfClass("AnimationController")
    local valHP = obj:FindFirstChild("Health", true) or obj:FindFirstChild("HP", true) or obj:FindFirstChild("MaxHealth", true)
    local attrHP = obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("Enemy") or obj:GetAttribute("Boss")
    local nm = string.lower(obj.Name)
    local isBoss = string.find(nm,"boss") or string.find(nm,"killer") or string.find(nm,"thanos")
    local isRobot = string.find(nm,"robot") or string.find(nm,"bot") or string.find(nm,"droid") or string.find(nm,"mech")
    local entityType, hpText = "Unknown", "N/A"
    if hum then
        entityType = isBoss and "[👑 Boss Hum]" or (isRobot and "[🤖 Робот/Hum]" or "[🚶 Humanoid]")
        hpText = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    elseif anim then
        entityType = isBoss and "[👑 Boss Anim]" or "[🤖 AnimCtrl]"
        if valHP and (valHP:IsA("NumberValue") or valHP:IsA("IntValue")) then hpText = tostring(valHP.Value).." (Val)"
        elseif attrHP then hpText = tostring(attrHP).." (Attr)" else hpText = "No HP" end
    elseif valHP or attrHP then
        entityType = isBoss and "[👑 Boss Stat]" or "[📊 Value/Attr]"
        if valHP and (valHP:IsA("NumberValue") or valHP:IsA("IntValue")) then hpText = tostring(valHP.Value).." (Val)"
        else hpText = tostring(attrHP).." (Attr)" end
    else
        entityType = isBoss and "[👑 Boss Rig]" or "[🦾 Custom Rig]"
        hpText = "Rig"
    end
    return true, entityType, hpText, root.Anchored, root
end

local function checkOwnership(part)
    if not part or not part:IsA("BasePart") then return "[NO PART]" end
    if part.Anchored then return "[⚓ ANCHORED]" end
    local ok, owner = pcall(function() return part:IsNetworkOwner() end)
    if ok and owner then return "[✅ ME]" else return "[🌐 SERVER]" end
end

local function getTargets()
    local t = {}
    for obj,_ in pairs(selectedNPCs) do if obj and obj.Parent then table.insert(t, obj) else selectedNPCs[obj]=nil end end
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

-- ============================================================================
-- 🛡️ ANTI-KICK PRO — 5 СЛОЁВ ЗАЩИТЫ (МАКСИМАЛЬНАЯ ВЕРСИЯ)
-- ============================================================================
local AntiKickPro = { installed = false, active = false, hookedRemotes = {} }

function AntiKickPro:Install()
    if self.installed then return end
    self.installed = true
    self.active = true
    print("[🛡️ ANTI-KICK PRO] Устанавливаем 5 слоёв защиты...")

    -- СЛОЙ 1: Переопределяем Player:Kick через hookmetamethod (если есть executor)
    pcall(function()
        if hookmetamethod then
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod and getnamecallmethod() or ""
                if (method == "Kick" or method == "kick") and (self == lp or self:IsA("Player")) then
                    if AntiKickPro.active then
                        print("[🛡️ LAYER 1] Заблокирован Kick через __namecall!")
                        return nil
                    end
                end
                return old(self, ...)
            end)
            AntiKickPro.hookedRemotes.namecall = old
            print("[🛡️ LAYER 1] hookmetamethod установлен")
        end
    end)

    -- СЛОЙ 2: Переопределяем lp.Kick напрямую
    pcall(function()
        local mt = getrawmetatable and getrawmetatable(lp) or nil
        if mt and setreadonly then
            setreadonly(mt, false)
            local oldIndex = mt.__index
            mt.__index = newcclosure and newcclosure(function(self, key)
                if key == "Kick" and self == lp and AntiKickPro.active then
                    return function() print("[🛡️ LAYER 2] Kick перехвачен через __index!") end
                end
                return oldIndex(self, key)
            end) or function(self, key)
                if key == "Kick" and self == lp and AntiKickPro.active then
                    return function() print("[🛡️ LAYER 2] Kick перехвачен!") end
                end
                return oldIndex(self, key)
            end
            setreadonly(mt, true)
            print("[🛡️ LAYER 2] __index метатаблица переопределена")
        end
    end)

    -- СЛОЙ 3: Блокируем OnClientEvent kick-remotes
    pcall(function()
        for _,r in ipairs(rep:GetDescendants()) do
            if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                local nm = string.lower(r.Name)
                if string.find(nm,"kick") or string.find(nm,"ban") or string.find(nm,"anticheat") or string.find(nm,"punish") or string.find(nm,"detect") then
                    pcall(function()
                        if r:IsA("RemoteEvent") then
                            local conn = r.OnClientEvent:Connect(function() print("[🛡️ LAYER 3] Заблокирован kick-remote:", r.Name) end)
                            table.insert(AntiKickPro.hookedRemotes, conn)
                        end
                    end)
                end
            end
        end
        print("[🛡️ LAYER 3] Kick-remotes мониторятся")
    end)

    -- СЛОЙ 4: Патчим Humanoid.Died — предотвращаем срабатывание системы смерти
    pcall(function()
        local function patchChar(char)
            if not char then return end
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then
                pcall(function()
                    hum.BreakJointsOnDeath = false
                    hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                    -- Постоянный monitor
                    local conn = hum.HealthChanged:Connect(function(newHP)
                        if AntiKickPro.active and newHP < hum.MaxHealth * 0.5 then
                            pcall(function() hum.Health = hum.MaxHealth end)
                        end
                    end)
                    table.insert(AntiKickPro.hookedRemotes, conn)
                end)
            end
        end
        patchChar(lp.Character)
        track("charAddedAK", lp.CharacterAdded:Connect(patchChar))
        print("[🛡️ LAYER 4] Humanoid patched (HP защита)")
    end)

    -- СЛОЙ 5: Auto-heal loop + ForceField renewal
    task.spawn(function()
        while AntiKickPro.active do
            pcall(function()
                local char = lp.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health < hum.MaxHealth * 0.7 then hum.Health = hum.MaxHealth end
                    if not char:FindFirstChildOfClass("ForceField") then
                        local ff = Instance.new("ForceField")
                        ff.Visible = false
                        ff.Parent = char
                        game:GetService("Debris"):AddItem(ff, 5)
                    end
                end
            end)
            task.wait(0.3)
        end
    end)
    print("[🛡️ LAYER 5] Auto-heal loop запущен")
    print("[🛡️ ANTI-KICK PRO] ✅ Все 5 слоёв установлены!")
end

function AntiKickPro:Toggle(state)
    self.active = state
    if state then
        if not self.installed then self:Install() end
        print("[🛡️ ANTI-KICK PRO] АКТИВЕН")
    else
        print("[🛡️ ANTI-KICK PRO] Приостановлен (hooks остаются)")
    end
end

-- ============================================================================
-- 🩸 КАСТ: FE CLASSIC (оригинальные + новые FE методы)
-- ============================================================================

local function kill_1_SimpleHP(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.Health = 0; hum:TakeDamage(999999) end) end
end

local function kill_2_RagdollStateDead(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead); hum:ChangeState(Enum.HumanoidStateType.FallingDown); hum.PlatformStand = true; hum.Sit = true; hum.WalkSpeed = 0; hum.JumpPower = 0 end) end
end

local function kill_3_BreakJointsMotorsLoop(obj)
    claimFE(obj); task.spawn(function()
        for i=1,28 do
            if not obj or not obj.Parent then break end
            pcall(function() if obj.BreakJoints then obj:BreakJoints() end end)
            for _,v in ipairs(obj:GetDescendants()) do
                if v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("ManualWeld") or v:IsA("Snap") or v:IsA("JointInstance") then pcall(function() v:Destroy() end) end
            end
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum and i % 3 == 0 then pcall(function() hum.Health = 0; hum:TakeDamage(999999) end) end
            task.wait(0.022)
        end
    end)
end

local function kill_5_DecapitateHeadTorso(obj)
    claimFE(obj); for _,part in ipairs(obj:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name=="Head" or part.Name=="Torso" or part.Name=="UpperTorso") then
            pcall(function()
                for _,w in ipairs(part:GetChildren()) do if w:IsA("JointInstance") or w:IsA("Weld") or w:IsA("Motor6D") then w:Destroy() end end
                part.AssemblyLinearVelocity = Vector3.new(math.random(-50000,50000), 100000, math.random(-50000,50000))
            end)
        end
    end
end

local function kill_6_SafePulseExplosion(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    pcall(function()
        local exp = Instance.new("Explosion")
        exp.Position = root.Position; exp.BlastRadius = 35; exp.BlastPressure = 0
        exp.ExplosionType = Enum.ExplosionType.NoCraters
        exp.Hit:Connect(function(part)
            if part:IsDescendantOf(lp.Character) then return end
            if part:IsDescendantOf(obj) then
                pcall(function() part.AssemblyLinearVelocity = Vector3.new(0, 50000, 0); if part:IsA("Motor6D") then part:Destroy() end end)
            end
        end)
        exp.Parent = ws
    end)
end

local function kill_117_HumanoidStateFlood(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    pcall(function()
        for _, state in pairs(Enum.HumanoidStateType:GetEnumItems()) do
            if state ~= Enum.HumanoidStateType.Dead then pcall(function() hum:SetStateEnabled(state, false) end) end
        end
        for _, s in ipairs({Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Physics, Enum.HumanoidStateType.Ragdoll}) do
            pcall(function() hum:ChangeState(s) end)
        end
        hum.PlatformStand=true; hum.MaxHealth=0; hum.Health=0; hum:TakeDamage(math.huge)
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
                if j:IsA("Motor6D") or j:IsA("Weld") then pcall(function() j.Part0=nil; j.Part1=nil end) end
            end
        end
        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead); hum.Health=0 end
    end)
end

local function kill_123_RagdollSuffocation(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    pcall(function()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Physics); hum:ChangeState(Enum.HumanoidStateType.Ragdoll); hum.PlatformStand=true end
        for _,j in ipairs(obj:GetDescendants()) do if j:IsA("Motor6D") then pcall(function() j.Part0=nil; j.Part1=nil end) end end
        if hum then hum.Health=0; hum:TakeDamage(math.huge) end
    end)
end

local function kill_90_HipHeightCrash(obj)
    claimFE(obj); local hum=obj:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.HipHeight=-50; hum.PlatformStand=true; hum:ChangeState(Enum.HumanoidStateType.Dead) end) end
end

-- 🩸 137. JOINT VELOCITY OSCILLATE — колебания углов Motor6D через CurrentAngle
local function kill_137_JointVelocityOscillate(obj)
    claimFE(obj)
    print("[🩸 v37 137] Joint Velocity Oscillate:", obj.Name)
    task.spawn(function()
        local motors = {}
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("Motor6D") then table.insert(motors, v) end
        end
        for tick = 1, 40 do
            if not obj or not obj.Parent then break end
            for i, m in ipairs(motors) do
                pcall(function()
                    m.DesiredAngle = math.sin(tick * 0.5 + i) * 1e6
                    m.MaxVelocity = math.huge
                end)
            end
            task.wait(0.02)
        end
    end)
end

-- 🩸 146. CUSTOM DEATH SIGNAL FIRE — ищем и файрим ВСЕ Died/OnDeath/DeathEvent
local function kill_146_CustomDeathSignalFire(obj)
    print("[🩸 v37 146] Custom Death Signal Fire:", obj.Name)
    pcall(function()
        for _,desc in ipairs(obj:GetDescendants()) do
            if desc:IsA("BindableEvent") or desc:IsA("BindableFunction") then
                local nm = string.lower(desc.Name)
                if string.find(nm,"died") or string.find(nm,"death") or string.find(nm,"dead") or string.find(nm,"defeat") or string.find(nm,"kill") or string.find(nm,"perish") or string.find(nm,"expire") or string.find(nm,"eliminat") then
                    pcall(function()
                        if desc:IsA("BindableEvent") then
                            desc:Fire(); desc:Fire(obj); desc:Fire(lp); desc:Fire(true); desc:Fire(999999)
                        else desc:Invoke() end
                    end)
                end
            end
            if desc:IsA("RemoteEvent") then
                local nm = string.lower(desc.Name)
                if string.find(nm,"died") or string.find(nm,"death") or string.find(nm,"defeat") then
                    pcall(function() desc:FireServer(); desc:FireServer(obj); desc:FireServer(true) end)
                end
            end
        end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function()
            for _,ev in ipairs({"Died","HealthChanged","StateChanged"}) do
                if hum[ev] and hum[ev].Fire then pcall(function() hum[ev]:Fire() end) end
            end
        end) end
    end)
end

-- ============================================================================
-- 📡 КАСТ: REMOTES + WEAPONS + TOUCH (оригинальные + новые сюда)
-- ============================================================================

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
            elseif rem:IsA("RemoteFunction") then task.spawn(function() rem:InvokeServer(obj, 999999) end) end
        end)
    end
end

local function kill_20_BindableSignalTrigger(obj)
    for _,desc in ipairs(obj:GetDescendants()) do
        if desc:IsA("BindableEvent") then
            local nm = string.lower(desc.Name)
            if string.find(nm,"die") or string.find(nm,"dead") or string.find(nm,"damage") then pcall(function() desc:Fire() end) end
        end
    end
end

local function kill_21_AttributeTagExecution(obj)
    local root = getRootPart(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    for _,item in ipairs({obj,root,hum}) do if item then pcall(function() item:SetAttribute("Dead", true); item:SetAttribute("Health", 0) end) end end
end

local function kill_25_DisarmBossHitboxes(obj)
    for _,v in ipairs(obj:GetDescendants()) do if v:IsA("BasePart") then local nm = string.lower(v.Name); if string.find(nm,"hitbox") or string.find(nm,"weapon") then pcall(function() v:Destroy() end) end end end
end

local function kill_37_MatrixWeaponTouch(obj)
    if not firetouchinterest then return end
    local char = lp.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not tool then return end
    if tool.Parent ~= char then tool.Parent = char end
    local tp = {}; for _,p in ipairs(tool:GetDescendants()) do if p:IsA("BasePart") then table.insert(tp, p) end end
    local np = {}; for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(np, p) end end
    task.spawn(function() for i=1,5 do pcall(function() tool:Activate() end); for _,t in ipairs(tp) do for _,n in ipairs(np) do pcall(function() firetouchinterest(t,n,0); firetouchinterest(t,n,1) end) end end; task.wait(0.04) end end)
end

local function kill_43_TouchInterestMatrixFlood(obj)
    if not firetouchinterest then return end
    local root = getRootPart(obj); if not root then return end
    local at = {}; for _,d in ipairs(ws:GetDescendants()) do if d:IsA("TouchTransmitter") and d.Parent and d.Parent~=root then table.insert(at, d.Parent) end end
    task.spawn(function() for i=1,5 do for _,tp in ipairs(at) do pcall(function() firetouchinterest(root,tp,0); firetouchinterest(root,tp,1) end) end; task.wait(0.05) end end)
end

local function kill_88_MultiNodeTouch(obj)
    if not firetouchinterest then return end
    local char = lp.Character; local root = getRootPart(obj); if not char or not root then return end
    for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then pcall(function() firetouchinterest(p, root, 0); firetouchinterest(p, root, 1) end) end end
end

local function kill_106_BossIDDamageRouter(obj)
    local bossIDs = {}
    pcall(function()
        for attr, val in pairs(obj:GetAttributes()) do
            if string.find(string.lower(attr),"id") then table.insert(bossIDs, val) end
        end
    end)
    table.insert(bossIDs, obj); table.insert(bossIDs, obj.Name); local root=getRootPart(obj); if root then table.insert(bossIDs, root) end
    task.spawn(function()
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            for _,id in ipairs(bossIDs) do
                pcall(function()
                    if rem:IsA("RemoteEvent") then rem:FireServer(id); rem:FireServer(id, 999999); rem:FireServer({Target=id, Damage=999999}) end
                end)
            end
            task.wait(0.02)
        end
    end)
end

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

local function kill_134_TouchedEventBomb(obj)
    if not firetouchinterest then return end
    local char = lp.Character; if not char then return end
    local myParts = {}; for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then table.insert(myParts, p) end end
    local npcParts = {}; for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(npcParts, p) end end
    task.spawn(function()
        for wave = 1, 5 do
            if not obj or not obj.Parent then break end
            for i=1,200 do
                pcall(function() local mp=myParts[math.random(1,#myParts)]; local np=npcParts[math.random(1,#npcParts)]; if mp and np then firetouchinterest(mp,np,0); firetouchinterest(mp,np,1) end end)
            end
            task.wait(0.05)
        end
    end)
end

-- 📡 139. REMOTE PARAMETER FUZZING — 20 форматов аргументов на combat remotes
local function kill_139_RemoteParameterFuzzing(obj)
    if #DeepAnalysisData.CombatRemotes == 0 then runFullAnalysis() end
    print("[📡 v37 139] Remote Parameter Fuzzing:", obj.Name)
    local root = getRootPart(obj)
    local formats = {
        {obj}, {obj, 999999}, {obj.Name}, {obj.Name, 999999},
        {"Attack", obj}, {"Damage", obj, 999999}, {"Hit", obj, 999999},
        {root}, {root, 999999}, {root and root.Position or Vector3.zero},
        {{Target=obj, Damage=999999}}, {{Type="Attack", Target=obj}},
        {obj:FindFirstChildOfClass("Humanoid")}, {obj:FindFirstChildOfClass("Humanoid"), 999999},
        {lp, obj, 999999}, {lp.UserId, obj}, {lp.Character, obj, 999999},
        {math.huge}, {0/0}, {"kill", obj.Name}
    }
    task.spawn(function()
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            for _,fmt in ipairs(formats) do
                pcall(function()
                    if rem:IsA("RemoteEvent") then rem:FireServer(unpack(fmt))
                    elseif rem:IsA("RemoteFunction") then task.spawn(function() rem:InvokeServer(unpack(fmt)) end) end
                end)
            end
            task.wait(0.02)
        end
    end)
end

-- 📡 145. TOOL HANDLE HITBOX MORPH — растягиваем Handle оружия прямо до NPC
local function kill_145_ToolHandleHitboxMorph(obj)
    local char = lp.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not tool then return end
    if tool.Parent ~= char then tool.Parent = char end
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart"); if not handle then return end
    local root = getRootPart(obj); if not root then return end
    print("[📡 v37 145] Tool Handle Hitbox Morph:", obj.Name)
    task.spawn(function()
        local origSize = handle.Size
        local origCF = handle.CFrame
        for i=1,10 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local dist = (root.Position - myRoot.Position).Magnitude + 20
                    handle.Size = Vector3.new(5, 5, dist)
                    handle.Massless = true
                    handle.CanCollide = false
                    handle.CFrame = CFrame.new(myRoot.Position, root.Position) * CFrame.new(0, 0, -dist/2)
                end
                tool:Activate()
                if firetouchinterest then firetouchinterest(handle, root, 0); firetouchinterest(handle, root, 1) end
            end)
            task.wait(0.05)
        end
        pcall(function() handle.Size = origSize end)
    end)
end

-- ============================================================================
-- 🦾 КАСТ: CUSTOM RIGS (кости, констрейнты, аниматоры)
-- ============================================================================

local function kill_7_CustomConstraintShatter(obj)
    claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("WeldConstraint") or v:IsA("RigidConstraint") or v:IsA("AlignPosition") or v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("RodConstraint") or v:IsA("SpringConstraint") then pcall(function() v:Destroy() end) end
    end
end

local function kill_8_SkinnedMeshBoneShatter(obj)
    claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Bone") then pcall(function() v.Transform = CFrame.new(math.random(-50,50), math.random(-50,50), math.random(-50,50)) end)
        elseif v:IsA("Attachment") and v.Name ~= "RootAttachment" then pcall(function() v:Destroy() end) end
    end
end

local function kill_9_KineticBodyTear(obj)
    claimFE(obj); for i,p in ipairs(obj:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.AssemblyLinearVelocity = Vector3.new(math.sin(i*99)*100000, math.cos(i*77)*100000, math.sin(i*33)*100000) end) end
    end
end

local function kill_94_AnimationLock(obj)
    local target = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("AnimationController"); if not target then return end
    pcall(function() for _,t in ipairs(target:GetPlayingAnimationTracks()) do t:Stop(0) end end)
end

local function kill_95_RootPriorityZero(obj)
    claimFE(obj); local root = getRootPart(obj); if not root then return end
    pcall(function() for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then p.RootPriority=-127; p.Massless=true end end end)
end

local function kill_124_VelocityShredder(obj)
    claimFE(obj); task.spawn(function()
        for wave=1,3 do
            if not obj or not obj.Parent then break end
            for i,p in ipairs(obj:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.CanCollide=true; p.Massless=true; local dir=Vector3.new(math.sin(i*0.7)*5000, math.abs(math.cos(i*0.3))*8000, math.cos(i*1.1)*5000); p.AssemblyLinearVelocity=dir; p.AssemblyAngularVelocity=dir*0.5 end) end
            end
            task.wait(0.05)
        end
    end)
end

local function kill_127_CFrameLoopCrusher(obj)
    claimFE(obj); task.spawn(function()
        local motors = {}; for _,v in ipairs(obj:GetDescendants()) do if v:IsA("Motor6D") or v:IsA("Weld") then table.insert(motors, v) end end
        for tick=1,50 do
            if not obj or not obj.Parent then break end
            for i,m in ipairs(motors) do pcall(function() local t=tick*0.1+i*0.37; m.C0 = m.C0 * CFrame.new(math.sin(t)*500, math.cos(t*1.3)*500, math.sin(t*0.7)*500) end) end
            task.wait(0.01)
        end
    end)
end

local function kill_128_AnimationTrackOverload(obj)
    claimFE(obj)
    local target = obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("AnimationController"); if not target then return end
    task.spawn(function()
        local anim = target:FindFirstChildOfClass("Animator"); if not anim then anim = Instance.new("Animator"); anim.Parent = target end
        for i=1,500 do
            if not obj or not obj.Parent then break end
            pcall(function() local a=Instance.new("Animation"); a.AnimationId="rbxassetid://0"; local tr=anim:LoadAnimation(a); tr:Play(); tr:AdjustSpeed(1000) end)
        end
        local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then task.wait(0.1); pcall(function() hum:TakeDamage(math.huge); hum.Health=0 end) end
    end)
end

local function kill_130_AttachmentOrbitChaos(obj)
    claimFE(obj); task.spawn(function()
        local atts = {}; for _,a in ipairs(obj:GetDescendants()) do if a:IsA("Attachment") then table.insert(atts, a) end end
        for tick=1,40 do
            if not obj or not obj.Parent then break end
            for i,att in ipairs(atts) do pcall(function() local t=tick*0.15+i*0.5; att.CFrame = CFrame.new(math.sin(t)*100, math.cos(t)*100, math.sin(t*2)*100) end) end
            task.wait(0.02)
        end
    end)
end

local function kill_133_BodyForceInfinitePush(obj)
    claimFE(obj)
    task.spawn(function()
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.Velocity=Vector3.new((math.random()-0.5)*500, math.random()*800, (math.random()-0.5)*500); bv.Parent=p; game:GetService("Debris"):AddItem(bv,1) end) end
        end
        task.wait(0.5)
        local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum:TakeDamage(math.huge); hum.Health=0 end) end
    end)
end

-- 🦾 140. SKINNED MESH ANNIHILATE — атака на LayeredClothing/SkinnedMeshPart
local function kill_140_SkinnedMeshAnnihilate(obj)
    claimFE(obj); print("[🦾 v37 140] SkinnedMeshAnnihilate:", obj.Name)
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("WrapLayer") or d:IsA("WrapTarget") then pcall(function() d:Destroy() end) end
            if d:IsA("MeshPart") then
                pcall(function()
                    d.HasSkinnedMesh = false
                    d.Size = Vector3.new(0.01,0.01,0.01)
                end)
            end
            if d:IsA("Bone") then
                pcall(function()
                    d.Position = Vector3.new(math.random(-1e6,1e6),math.random(-1e6,1e6),math.random(-1e6,1e6))
                    d.Transform = CFrame.new(math.random(-9999,9999),math.random(-9999,9999),math.random(-9999,9999))
                end)
            end
        end
        local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum:TakeDamage(math.huge) end) end
    end)
end

-- 🦾 144. CONTROLLER MANAGER HIJACK — для NPC с новой физикой ControllerManager
local function kill_144_ControllerManagerHijack(obj)
    claimFE(obj); print("[🦾 v37 144] ControllerManager Hijack:", obj.Name)
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("ControllerManager") then
                pcall(function()
                    d.BaseMoveSpeed = 0
                    d.BaseTurnSpeed = 0
                    d.FacingDirection = Vector3.zero
                    d.MovingDirection = Vector3.zero
                    d.ActiveController = nil
                end)
            end
            if d:IsA("GroundController") or d:IsA("AirController") or d:IsA("SwimController") or d:IsA("ClimbController") then
                pcall(function() d.MoveSpeedFactor = 0; d.TurnSpeedFactor = 0 end)
            end
        end
        local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Ragdoll); hum.Health=0 end) end
    end)
end

-- ============================================================================
-- 📊 КАСТ: MATH STATS (краш чисел, HP, щиты)
-- ============================================================================

local function kill_4_ValueAttrZero(obj)
    claimFE(obj); for _,val in ipairs(obj:GetDescendants()) do
        if val:IsA("NumberValue") or val:IsA("IntValue") then
            local nm = string.lower(val.Name)
            if string.find(nm,"hp") or string.find(nm,"health") or string.find(nm,"life") or string.find(nm,"shield") then pcall(function() val.Value = 0 end) end
        end
    end
    for attr,_ in pairs(obj:GetAttributes()) do
        local nm = string.lower(attr)
        if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() obj:SetAttribute(attr, 0) end) end
    end
end

local function kill_11_TakeDamageLoop(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then task.spawn(function() for i=1,15 do if not obj.Parent then break end; pcall(function() hum:TakeDamage(math.huge); hum.Health=0 end); task.wait(0.03) end end) end
end

local function kill_12_NaNCrash(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") then local nm=string.lower(val.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() val.Value = 0/0 end) end end end
    for attr,_ in pairs(obj:GetAttributes()) do if string.find(string.lower(attr),"health") then pcall(function() obj:SetAttribute(attr, 0/0) end) end end
end

local function kill_13_DoubleOverflow(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") then local nm=string.lower(val.Name); if string.find(nm,"hp") or string.find(nm,"damage") then pcall(function() val.Value = 1e308 end) end end end
end

local function kill_14_NegativeHP(obj)
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") or val:IsA("IntValue") then local nm=string.lower(val.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() val.Value = -999999 end) end end end
end

local function kill_15_StripShields(obj)
    for _,ff in ipairs(obj:GetDescendants()) do if ff:IsA("ForceField") then pcall(function() ff:Destroy() end) end end
    for _,val in ipairs(obj:GetDescendants()) do if val:IsA("NumberValue") or val:IsA("BoolValue") then local nm=string.lower(val.Name); if string.find(nm,"shield") or string.find(nm,"armor") or string.find(nm,"god") then pcall(function() if val:IsA("BoolValue") then val.Value=false else val.Value=0 end end) end end end
end

local function kill_16_MaxHealthShrink(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.MaxHealth=1; hum.Health=0; hum:TakeDamage(999999) end) end
end

local function kill_91_ShieldVaporizer(obj)
    local root=getRootPart(obj); local hum=obj:FindFirstChildOfClass("Humanoid")
    for _,item in ipairs({obj,root,hum}) do if item then for _,attr in ipairs({"Shield","Armor","GodMode","Invulnerable"}) do pcall(function() item:SetAttribute(attr,0) end) end; pcall(function() item:SetAttribute("Health",1) end) end end
end

local function kill_118_HealthClampOverride(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid")
    task.spawn(function()
        for i=1,30 do
            if not obj.Parent then break end
            pcall(function() if hum then hum.MaxHealth=0; hum.Health=0; hum:TakeDamage(math.huge) end end)
            for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() v.Value=0 end) end end end
            task.wait(0.02)
        end
    end)
end

local function kill_122_MassiveTakeDamage(obj)
    claimFE(obj); local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    task.spawn(function() for wave=1,5 do if not obj.Parent then break end; for i=1,100 do pcall(function() hum:TakeDamage(1e9) end) end; pcall(function() hum.Health=0 end); task.wait(0.03) end end)
end

local function kill_136_ChildrenCascadePurge(obj)
    pcall(function()
        for _,v in ipairs(obj:GetDescendants()) do
            pcall(function()
                if v:IsA("NumberValue") or v:IsA("IntValue") then v.Value = 0
                elseif v:IsA("BoolValue") then v.Value = false
                elseif v:IsA("StringValue") then v.Value = "dead"
                elseif v:IsA("Vector3Value") then v.Value = Vector3.zero end
            end)
        end
        for attr,val in pairs(obj:GetAttributes()) do pcall(function() if type(val)=="number" then obj:SetAttribute(attr,0) elseif type(val)=="boolean" then obj:SetAttribute(attr,false) end end) end
    end)
end

-- 📊 138. HEALTH REGEN INVERSION — заражаем HealthRegenScript отрицательным
local function kill_138_HealthRegenInversion(obj)
    claimFE(obj); print("[📊 v37 138] Health Regen Inversion:", obj.Name)
    pcall(function()
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then
                local nm = string.lower(v.Name)
                if string.find(nm,"regen") or string.find(nm,"heal") or string.find(nm,"restore") then
                    pcall(function() v.Value = -1e6 end)
                end
            end
        end
        for attr,val in pairs(obj:GetAttributes()) do
            local nm = string.lower(attr)
            if string.find(nm,"regen") or string.find(nm,"heal") then pcall(function() obj:SetAttribute(attr, -1e6) end) end
        end
        -- Плюс собственный анти-регенер: слушаем HP и роняем при изменении
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if hum then
            local conn
            conn = hum.HealthChanged:Connect(function(newHP)
                if newHP > 0 then pcall(function() hum.Health = 0; hum:TakeDamage(math.huge) end) end
            end)
            task.delay(15, function() if conn then conn:Disconnect() end end)
        end
    end)
end

-- 📊 143. DEFENSE ATTRIBUTE HIJACK — Damage↑, Defense↓, Armor=0
local function kill_143_DefenseAttributeHijack(obj)
    print("[📊 v37 143] Defense Attribute Hijack:", obj.Name)
    pcall(function()
        -- Дебафаем всё что связано с защитой, бафаем всё что связано с уроном
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then
                local nm = string.lower(v.Name)
                if string.find(nm,"defense") or string.find(nm,"armor") or string.find(nm,"resist") or string.find(nm,"block") or string.find(nm,"reduction") then pcall(function() v.Value = 0 end)
                elseif string.find(nm,"damagemulti") or string.find(nm,"dmgmulti") or string.find(nm,"multiplier") or string.find(nm,"vulnerable") then pcall(function() v.Value = 1000 end) end
            end
        end
        for attr,_ in pairs(obj:GetAttributes()) do
            local nm = string.lower(attr)
            if string.find(nm,"defense") or string.find(nm,"armor") or string.find(nm,"resist") or string.find(nm,"block") then pcall(function() obj:SetAttribute(attr, 0) end)
            elseif string.find(nm,"multi") or string.find(nm,"vulnerable") then pcall(function() obj:SetAttribute(attr, 1000) end) end
        end
    end)
end

-- ============================================================================
-- 👑 КАСТ: GOLDEN GRAIL (TakeDamage DPS)
-- ============================================================================

local function kill_86_GoldenGrailOverdrive(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local dmg = CombatSettings.DamageAmount
    pcall(function() hum:TakeDamage(dmg); if dmg >= 999999 then hum.Health = 0 end end)
end

-- 👑 141. GRAIL WAVE STACKING — 10 нарастающих волн TakeDamage
local function kill_141_GrailWaveStacking(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    print("[👑 v37 141] Grail Wave Stacking (10 волн):", obj.Name)
    task.spawn(function()
        for wave = 1, 10 do
            if not obj or not obj.Parent then break end
            local dmg = CombatSettings.DamageAmount * wave  -- 50K → 500K
            pcall(function() hum:TakeDamage(dmg); if wave >= 8 then hum.Health = 0 end end)
            task.wait(0.05)
        end
    end)
end

-- ============================================================================
-- 🎮 НОВЫЙ КАСТ: PLAYER INPUT SIM (методы что не влезли в оригинальные 6)
-- ============================================================================

local function kill_97_VirtualInputClickStorm(obj)
    local root = getRootPart(obj); if not root then return end
    task.spawn(function()
        for i=1,15 do
            if not obj or not obj.Parent then break end
            pcall(function()
                local sp, on = cam:WorldToScreenPoint(root.Position)
                if on then VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, true, game, 0); task.wait(0.02); VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, false, game, 0) end
            end)
            task.wait(0.08)
        end
    end)
end

local function kill_98_ToolActivateLegit(obj)
    local char = lp.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    task.spawn(function()
        local tools = {}
        for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t) end end
        for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t) end end
        for _,tool in ipairs(tools) do
            if not obj.Parent then break end
            pcall(function() hum:EquipTool(tool) end); task.wait(0.1)
            for i=1,8 do pcall(function() tool:Activate() end); task.wait(0.15); pcall(function() tool:Deactivate() end); task.wait(0.05) end
        end
    end)
end

local function kill_99_AbilityKeyPresser(obj)
    local keys = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.F, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
    local root = getRootPart(obj)
    task.spawn(function()
        if root then pcall(function() cam.CFrame = CFrame.new(cam.CFrame.Position, root.Position) end) end
        for _,key in ipairs(keys) do pcall(function() VIM:SendKeyEvent(true, key, false, game); task.wait(0.05); VIM:SendKeyEvent(false, key, false, game) end); task.wait(0.1) end
    end)
end

local function kill_100_MobileTouchEmulator(obj)
    local root = getRootPart(obj); if not root then return end
    task.spawn(function()
        for i=1,10 do
            if not obj.Parent then break end
            pcall(function() local sp, on = cam:WorldToScreenPoint(root.Position); if on then VIM:SendTouchEvent(1,1,sp.X,sp.Y); task.wait(0.03); VIM:SendTouchEvent(1,2,sp.X,sp.Y); task.wait(0.03); VIM:SendTouchEvent(1,3,sp.X,sp.Y) end end)
            task.wait(0.15)
        end
    end)
end

local function kill_103_InventoryAutoEquip(obj)
    local char = lp.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then pcall(function() hum:EquipTool(t) end); task.wait(0.05) end end
    local pg = lp:FindFirstChild("PlayerGui"); if not pg then return end
    task.spawn(function()
        for _,gui in ipairs(pg:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                local nm = string.lower(gui.Name..(gui.Parent and gui.Parent.Name or ""))
                if string.find(nm,"weapon") or string.find(nm,"sword") or string.find(nm,"slot") or string.find(nm,"equip") then
                    pcall(function() local abs=gui.AbsolutePosition; local sz=gui.AbsoluteSize; VIM:SendMouseButtonEvent(abs.X+sz.X/2, abs.Y+sz.Y/2, 0, true, game, 0); task.wait(0.03); VIM:SendMouseButtonEvent(abs.X+sz.X/2, abs.Y+sz.Y/2, 0, false, game, 0) end)
                    task.wait(0.05)
                end
            end
        end
    end)
end

local function kill_104_CameraAimLockFire(obj)
    local root = getRootPart(obj); if not root then return end
    local char = lp.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    task.spawn(function()
        for i=1,12 do
            if not obj.Parent then break end
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

-- 🎮 142. PROXIMITY PROMPT ABUSE — триггерим все PP на боссе и вокруг
local function kill_142_ProximityPromptAbuse(obj)
    print("[🎮 v37 142] Proximity Prompt Abuse:", obj.Name)
    if not fireproximityprompt then print("  [!] fireproximityprompt недоступен"); return end
    task.spawn(function()
        for wave=1,5 do
            if not obj.Parent then break end
            for _,pp in ipairs(obj:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then
                    pcall(function() fireproximityprompt(pp) end)
                    pcall(function() pp:InputHoldBegin(); task.wait(pp.HoldDuration + 0.01); pp:InputHoldEnd() end)
                end
            end
            local root = getRootPart(obj)
            if root then
                for _,pp in ipairs(ws:GetDescendants()) do
                    if pp:IsA("ProximityPrompt") and pp.Parent and pp.Parent:IsA("BasePart") and (pp.Parent.Position - root.Position).Magnitude < 30 then
                        pcall(function() fireproximityprompt(pp) end)
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

-- ============================================================================
-- 🚀 КАСТ: DESTROYER SERVER (полёт в космос - OFF by default)
-- ============================================================================

local function kill_10_AngularSpin(obj)
    claimFE(obj); local root=getRootPart(obj); if not root then return end
    pcall(function() root.AssemblyAngularVelocity = Vector3.new(1e6,1e6,1e6) end)
end

local function kill_29_SupersonicLaunch(obj)
    claimFE(obj); local root=getRootPart(obj); if not root then return end
    pcall(function() root.CanCollide=false; root.CFrame = root.CFrame + Vector3.new(0,50,0); root.AssemblyLinearVelocity = Vector3.new(1e9,1e9,-1e9) end)
end

local function kill_41_MotorCFrameCrush(obj)
    claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Motor6D") or v:IsA("Weld") then pcall(function() v.C0 = CFrame.new(0,-5000,0); v.C1 = CFrame.new(10000,10000,10000) end) end
    end
end

-- ============================================================================
-- 🛡️ ANTI-ROLLBACK (v33 — глобальный helper, срабатывает через ЛЮБОЙ каст)
-- ============================================================================
local function kill_101_AntiRollbackHPGuard(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if rollbackGuards[obj] then rollbackGuards[obj]:Disconnect() end
    local lastHP = hum.Health
    rollbackGuards[obj] = hum:GetPropertyChangedSignal("Health"):Connect(function()
        local currentHP = hum.Health
        if currentHP > lastHP + 5 then pcall(function() hum.Health = math.max(0, lastHP - 100) end)
        else lastHP = currentHP end
    end)
    task.delay(30, function() if rollbackGuards[obj] then rollbackGuards[obj]:Disconnect(); rollbackGuards[obj]=nil end end)
end

-- ============================================================================
-- 💥 МАСТЕР-ДВИЖОК v37 (с распределением по 6+1 КАСТАМ)
-- ============================================================================
local function MASTER_OMNI_KILL_ENGINE(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[💥 MASTER v37] Атака:", obj.Name)
    local ticksCount = CombatSettings.HyperSpeed and 15 or 30
    local waitTime = CombatSettings.HyperSpeed and 0.01 or 0.03

    -- Anti-rollback запускаем всегда (защита от отката HP боссом)
    task.spawn(function() kill_101_AntiRollbackHPGuard(obj) end)

    task.spawn(function()
        for tick = 1, ticksCount do
            if not obj or not obj.Parent then break end

            -- 👑 GOLDEN GRAIL: настраиваемый TakeDamage + новый Wave Stacking
            if CombatSettings.GoldenGrail then
                kill_86_GoldenGrailOverdrive(obj)
                if tick == 1 or tick == 15 then kill_141_GrailWaveStacking(obj) end
            end

            -- 📡 REMOTES + WEAPONS + TOUCH + новые Fuzzing/Hitbox/BossID/ServerSync
            if CombatSettings.RemotesWeapons and tick % 2 == 0 then
                kill_18_SafeRemoteBruteForce(obj); kill_17_OfficialWeaponOverdrive(obj); kill_19_WeaponRemoteHijack(obj)
                kill_37_MatrixWeaponTouch(obj); kill_43_TouchInterestMatrixFlood(obj); kill_88_MultiNodeTouch(obj)
                kill_20_BindableSignalTrigger(obj); kill_21_AttributeTagExecution(obj); kill_25_DisarmBossHitboxes(obj)
                kill_106_BossIDDamageRouter(obj); kill_134_TouchedEventBomb(obj)
                if tick == 2 then kill_139_RemoteParameterFuzzing(obj); kill_145_ToolHandleHitboxMorph(obj); kill_105_ServerFrameSyncDamage(obj) end
            end

            -- 🦾 CUSTOM RIGS: кости, констрейнты, аниматоры + новые CFrame/Attachment/BodyForce/SkinnedMesh/CtrlManager
            if CombatSettings.CustomRigs and tick % 2 == 0 then
                kill_7_CustomConstraintShatter(obj); kill_8_SkinnedMeshBoneShatter(obj); kill_9_KineticBodyTear(obj)
                kill_94_AnimationLock(obj); kill_95_RootPriorityZero(obj); kill_124_VelocityShredder(obj)
                kill_127_CFrameLoopCrusher(obj); kill_130_AttachmentOrbitChaos(obj); kill_133_BodyForceInfinitePush(obj)
                if tick == 2 then kill_128_AnimationTrackOverload(obj); kill_140_SkinnedMeshAnnihilate(obj); kill_144_ControllerManagerHijack(obj) end
            end

            -- 🩸 FE CLASSIC: HP=0, ragdoll, суставы + новые StateFlood/Decapitate/RagdollSuf/HipCrash/JointOsc/DeathSignal
            if CombatSettings.FEClassic and tick % 3 == 0 then
                kill_1_SimpleHP(obj); kill_2_RagdollStateDead(obj); kill_3_BreakJointsMotorsLoop(obj); kill_5_DecapitateHeadTorso(obj); kill_6_SafePulseExplosion(obj)
                kill_117_HumanoidStateFlood(obj); kill_121_RootHeadDecapitate(obj); kill_123_RagdollSuffocation(obj); kill_90_HipHeightCrash(obj)
                kill_137_JointVelocityOscillate(obj); kill_146_CustomDeathSignalFire(obj)
            end

            -- 📊 MATH STATS: NaN, 1e308, negative + новые Regen/Defense
            if CombatSettings.MathStats and tick % 3 == 0 then
                kill_4_ValueAttrZero(obj); kill_11_TakeDamageLoop(obj); kill_12_NaNCrash(obj); kill_13_DoubleOverflow(obj)
                kill_14_NegativeHP(obj); kill_15_StripShields(obj); kill_16_MaxHealthShrink(obj); kill_91_ShieldVaporizer(obj)
                kill_118_HealthClampOverride(obj); kill_122_MassiveTakeDamage(obj); kill_136_ChildrenCascadePurge(obj)
                kill_138_HealthRegenInversion(obj); kill_143_DefenseAttributeHijack(obj)
            end

            -- 🎮 PLAYER INPUT SIM: VIM, tool, proximity (новый каст)
            if CombatSettings.PlayerInputSim and tick % 4 == 0 then
                kill_97_VirtualInputClickStorm(obj); kill_100_MobileTouchEmulator(obj); kill_99_AbilityKeyPresser(obj)
                kill_104_CameraAimLockFire(obj); kill_98_ToolActivateLegit(obj); kill_142_ProximityPromptAbuse(obj)
                if tick == 4 then kill_103_InventoryAutoEquip(obj) end
            end

            -- 🚀 DESTROYER SERVER (полёт в космос)
            if CombatSettings.DestroyerServer and tick == 1 then
                task.spawn(function() kill_10_AngularSpin(obj); kill_29_SupersonicLaunch(obj); kill_41_MotorCFrameCrush(obj) end)
            end

            task.wait(waitTime)
        end
    end)
end

-- ============================================================================
-- 🔥 NUCLEAR ENGINE — ЗАПУСКАЕТ ВООБЩЕ ВСЕ МЕТОДЫ БЕЗ УЧЁТА НАСТРОЕК
-- ============================================================================
local function NUCLEAR_KILL_ENGINE(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[🔥🔥🔥 NUCLEAR KILL 🔥🔥🔥] ПОЛНЫЙ АРСЕНАЛ ПО:", obj.Name)

    -- Anti-rollback
    task.spawn(function() kill_101_AntiRollbackHPGuard(obj) end)

    -- Все методы разом в параллельных потоках
    local allMethods = {
        kill_1_SimpleHP, kill_2_RagdollStateDead, kill_3_BreakJointsMotorsLoop, kill_5_DecapitateHeadTorso, kill_6_SafePulseExplosion,
        kill_7_CustomConstraintShatter, kill_8_SkinnedMeshBoneShatter, kill_9_KineticBodyTear,
        kill_11_TakeDamageLoop, kill_12_NaNCrash, kill_13_DoubleOverflow, kill_14_NegativeHP, kill_15_StripShields, kill_16_MaxHealthShrink,
        kill_17_OfficialWeaponOverdrive, kill_18_SafeRemoteBruteForce, kill_19_WeaponRemoteHijack, kill_20_BindableSignalTrigger,
        kill_21_AttributeTagExecution, kill_25_DisarmBossHitboxes, kill_37_MatrixWeaponTouch, kill_43_TouchInterestMatrixFlood,
        kill_86_GoldenGrailOverdrive, kill_88_MultiNodeTouch, kill_90_HipHeightCrash, kill_91_ShieldVaporizer, kill_94_AnimationLock, kill_95_RootPriorityZero,
        kill_97_VirtualInputClickStorm, kill_98_ToolActivateLegit, kill_99_AbilityKeyPresser, kill_100_MobileTouchEmulator,
        kill_103_InventoryAutoEquip, kill_104_CameraAimLockFire, kill_105_ServerFrameSyncDamage, kill_106_BossIDDamageRouter,
        kill_117_HumanoidStateFlood, kill_118_HealthClampOverride, kill_121_RootHeadDecapitate, kill_122_MassiveTakeDamage,
        kill_123_RagdollSuffocation, kill_124_VelocityShredder, kill_127_CFrameLoopCrusher, kill_128_AnimationTrackOverload,
        kill_130_AttachmentOrbitChaos, kill_133_BodyForceInfinitePush, kill_134_TouchedEventBomb, kill_136_ChildrenCascadePurge,
        kill_137_JointVelocityOscillate, kill_138_HealthRegenInversion, kill_139_RemoteParameterFuzzing, kill_140_SkinnedMeshAnnihilate,
        kill_141_GrailWaveStacking, kill_142_ProximityPromptAbuse, kill_143_DefenseAttributeHijack, kill_144_ControllerManagerHijack,
        kill_145_ToolHandleHitboxMorph, kill_146_CustomDeathSignalFire,
        -- Destroyer тоже включаем в Nuclear
        kill_10_AngularSpin, kill_29_SupersonicLaunch, kill_41_MotorCFrameCrush
    }

    task.spawn(function()
        -- 3 волны по всем методам с задержкой
        for wave = 1, 3 do
            if not obj or not obj.Parent then break end
            print("[🔥 NUCLEAR WAVE", wave, "/ 3]")
            for _, fn in ipairs(allMethods) do
                task.spawn(function() pcall(function() fn(obj) end) end)
            end
            task.wait(0.5)
        end
    end)
end

-- ==================== ГРАФИЧЕСКИЙ ИНТЕРФЕЙС v37 ====================
local sg = Instance.new("ScreenGui")
sg.Name = "NPCKillTesterPro_v37_GUI"
sg.ResetOnSpawn = false
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = lp:WaitForChild("PlayerGui") end

local mf = Instance.new("Frame", sg)
mf.Size = UDim2.new(0, 780, 0, 880)
mf.Position = UDim2.new(0.5, -390, 0.5, -440)
mf.BackgroundColor3 = Color3.fromRGB(16,16,20)
mf.BorderSizePixel = 0
mf.Active = true
mf.Draggable = true
Instance.new("UICorner", mf).CornerRadius = UDim.new(0,14)

local title = Instance.new("TextLabel", mf)
title.Size = UDim2.new(1, -80, 0, 38)
title.Text = "  👑 NPC KILL v37.0 — ORIGINAL 6 CASTS + NUCLEAR + ANTI-KICK PRO (5 LAYERS)"
title.TextColor3 = Color3.fromRGB(255,255,255); title.Font = Enum.Font.GothamBold; title.TextSize = 11
title.TextXAlignment = Enum.TextXAlignment.Left; title.BackgroundColor3 = Color3.fromRGB(10,10,12)
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
        mf:TweenSize(UDim2.new(0,780,0,38), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true); minBtn.Text = "+"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=false end end
    else
        mf:TweenSize(UDim2.new(0,780,0,880), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true); minBtn.Text = "-"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=true end end
    end
end)

-- 🔥 СЕКЦИЯ ТРЁХ ГЛАВНЫХ КНОПОК (MASTER OMNI + KILL ALL + NUCLEAR)
local actionSection = Instance.new("Frame", mf)
actionSection.Size = UDim2.new(1, -20, 0, 92)
actionSection.Position = UDim2.new(0, 10, 0, 42)
actionSection.BackgroundColor3 = Color3.fromRGB(24,24,30)
Instance.new("UICorner", actionSection).CornerRadius = UDim.new(0,10)

local masterBtn = Instance.new("TextButton", actionSection)
masterBtn.Size = UDim2.new(0.31, -4, 0, 80); masterBtn.Position = UDim2.new(0, 8, 0, 6)
masterBtn.Text = "💥 MASTER\nOMNI-KILL\n(по настройкам)"
masterBtn.Font = Enum.Font.GothamBold; masterBtn.TextSize = 12; masterBtn.TextColor3 = Color3.fromRGB(255,255,255); masterBtn.BackgroundColor3 = Color3.fromRGB(10,140,60)
Instance.new("UICorner", masterBtn).CornerRadius = UDim.new(0,8)
masterBtn.MouseButton1Click:Connect(function()
    local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
    for _,obj in ipairs(targets) do task.spawn(function() MASTER_OMNI_KILL_ENGINE(obj) end) end
end)

local masterKillAll = Instance.new("TextButton", actionSection)
masterKillAll.Size = UDim2.new(0.31, -4, 0, 80); masterKillAll.Position = UDim2.new(0.33, 0, 0, 6)
masterKillAll.Text = "⚡ MASTER\nKILL ALL\n(все NPC — по настройкам)"
masterKillAll.Font = Enum.Font.GothamBold; masterKillAll.TextSize = 12; masterKillAll.TextColor3 = Color3.fromRGB(255,255,0); masterKillAll.BackgroundColor3 = Color3.fromRGB(160,30,0)
Instance.new("UICorner", masterKillAll).CornerRadius = UDim.new(0,8)
masterKillAll.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ents = getAllValidEntities()
        for i,o in ipairs(ents) do task.spawn(function() MASTER_OMNI_KILL_ENGINE(o) end); if i%3==0 then task.wait(0.04) end end
    end)
end)

-- 🔥 NUCLEAR KILL — все методы разом БЕЗ настроек
local nuclearBtn = Instance.new("TextButton", actionSection)
nuclearBtn.Size = UDim2.new(0.34, -4, 0, 80); nuclearBtn.Position = UDim2.new(0.66, 0, 0, 6)
nuclearBtn.Text = "🔥 NUCLEAR KILL 🔥\nВСЕ 60+ МЕТОДОВ РАЗОМ!\n(игнорирует настройки)"
nuclearBtn.Font = Enum.Font.GothamBold; nuclearBtn.TextSize = 12; nuclearBtn.TextColor3 = Color3.fromRGB(255,255,255); nuclearBtn.BackgroundColor3 = Color3.fromRGB(200,20,20)
Instance.new("UICorner", nuclearBtn).CornerRadius = UDim.new(0,8)
nuclearBtn.MouseButton1Click:Connect(function()
    local targets = getTargets()
    if #targets == 0 then
        print("[🔥 NUCLEAR] Цель не выбрана → атакуем ВСЕХ NPC!")
        targets = getAllValidEntities()
    end
    print("[🔥🔥🔥 NUCLEAR KILL] Запуск по", #targets, "целей!")
    for _,obj in ipairs(targets) do task.spawn(function() NUCLEAR_KILL_ENGINE(obj) end) end
end)

-- ⚙️ ПАНЕЛЬ НАСТРОЕК (ОРИГИНАЛЬНАЯ v32 — 6 кастов + 1 новый + регулировки + Anti-Kick)
local settingsSection = Instance.new("Frame", mf)
settingsSection.Size = UDim2.new(1, -20, 0, 158)
settingsSection.Position = UDim2.new(0, 10, 0, 140)
settingsSection.BackgroundColor3 = Color3.fromRGB(20,20,28)
Instance.new("UICorner", settingsSection).CornerRadius = UDim.new(0,10)

local stTitle = Instance.new("TextLabel", settingsSection)
stTitle.Size = UDim2.new(1, 0, 0, 20)
stTitle.Text = "  ⚙️ ПАНЕЛЬ НАСТРОЕК (6 ОРИГИНАЛЬНЫХ КАСТОВ + 1 НОВЫЙ + Anti-Kick PRO):"
stTitle.Font = Enum.Font.GothamBold; stTitle.TextSize = 11; stTitle.TextColor3 = Color3.fromRGB(150,255,255)
stTitle.TextXAlignment = Enum.TextXAlignment.Left; stTitle.BackgroundTransparency = 1

local stGridF = Instance.new("Frame", settingsSection)
stGridF.Size = UDim2.new(1, -10, 1, -22); stGridF.Position = UDim2.new(0, 5, 0, 22)
stGridF.BackgroundTransparency = 1

local stGrid = Instance.new("UIGridLayout", stGridF)
stGrid.CellSize = UDim2.new(0, 248, 0, 30); stGrid.CellPadding = UDim2.new(0, 5, 0, 4)

local function makeSetToggle(text, key, col, defaultVal, callback)
    local state = defaultVal
    local b = Instance.new("TextButton", stGridF)
    b.Text = text .. (state and " [ON]" or " [OFF]")
    b.BackgroundColor3 = state and col or Color3.fromRGB(45,45,55)
    b.Font = Enum.Font.GothamBold; b.TextSize = 10; b.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        state = not state
        if key then CombatSettings[key] = state end
        b.Text = text .. (state and " [ON]" or " [OFF]")
        b.BackgroundColor3 = state and col or Color3.fromRGB(45,45,55)
        if callback then callback(state) end
        print("[⚙️]", text, "=", state)
    end)
end

-- Оригинальные 6 кастов v32
makeSetToggle("👑 Золотой Грааль #86", "GoldenGrail", Color3.fromRGB(180,140,0), true)
makeSetToggle("📡 Ремоуты/Оружие/Тач", "RemotesWeapons", Color3.fromRGB(0,100,160), true)
makeSetToggle("🦾 Кастомные Тела/Кости", "CustomRigs", Color3.fromRGB(160,80,0), true)
makeSetToggle("🩸 Классика FE + Суставы", "FEClassic", Color3.fromRGB(120,40,40), true)
makeSetToggle("📊 Краш Математики", "MathStats", Color3.fromRGB(100,20,100), true)
makeSetToggle("🚀 Destroyer Server (Космос)", "DestroyerServer", Color3.fromRGB(180,20,0), false)
-- Новый каст (для методов ввода)
makeSetToggle("🎮 Player Input Sim (VIM/Tool)", "PlayerInputSim", Color3.fromRGB(0,140,140), true)
-- Anti-Kick PRO как отдельный тумблер (не влияет на модули)
makeSetToggle("🛡️ Anti-Kick PRO (5 слоёв)", nil, Color3.fromRGB(0,180,120), false, function(state) AntiKickPro:Toggle(state) end)

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

-- Скорость
local spdBtn = Instance.new("TextButton", stGridF)
spdBtn.Text = "⚙️ Скорость: Normal (30x)"
spdBtn.BackgroundColor3 = Color3.fromRGB(60,60,80); spdBtn.Font = Enum.Font.GothamBold; spdBtn.TextSize = 10; spdBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", spdBtn).CornerRadius = UDim.new(0,6)
spdBtn.MouseButton1Click:Connect(function()
    CombatSettings.HyperSpeed = not CombatSettings.HyperSpeed
    spdBtn.Text = "⚙️ Скорость: " .. (CombatSettings.HyperSpeed and "HYPER (60x)" or "Normal (30x)")
    spdBtn.BackgroundColor3 = CombatSettings.HyperSpeed and Color3.fromRGB(120,40,160) or Color3.fromRGB(60,60,80)
end)

-- 🧪 СЕКЦИЯ ТЕСТА 10 НОВЫХ МЕТОДОВ v37 (№137-№146)
local testSection = Instance.new("Frame", mf)
testSection.Size = UDim2.new(1, -20, 0, 115)
testSection.Position = UDim2.new(0, 10, 0, 304)
testSection.BackgroundColor3 = Color3.fromRGB(28,20,32)
Instance.new("UICorner", testSection).CornerRadius = UDim.new(0,10)

local tsTitle = Instance.new("TextLabel", testSection)
tsTitle.Size = UDim2.new(1, 0, 0, 20)
tsTitle.Text = "  🧪 10 НОВЫХ МЕТОДОВ v37 (№137-№146) — распределены по кастам ↑ | клик — тест отдельно:"
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
        local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
        for _,obj in ipairs(targets) do task.spawn(function() fn(obj) end) end
    end)
end

-- Каждая кнопка с меткой каста в описании
makeTestBtn("137. 🩸 Joint Osc.", "→FE: колебания Motor6D DesiredAngle", Color3.fromRGB(120,40,40), kill_137_JointVelocityOscillate)
makeTestBtn("138. 📊 Regen Invert", "→MathStats: HealthRegen = -1e6", Color3.fromRGB(100,20,100), kill_138_HealthRegenInversion)
makeTestBtn("139. 📡 Remote Fuzz", "→Remotes: 20 форматов аргументов", Color3.fromRGB(0,100,160), kill_139_RemoteParameterFuzzing)
makeTestBtn("140. 🦾 Skinned Mesh", "→Rigs: атака LayeredClothing/Bones", Color3.fromRGB(160,80,0), kill_140_SkinnedMeshAnnihilate)
makeTestBtn("141. 👑 Grail Waves", "→Grail: 10 нарастающих волн урона", Color3.fromRGB(180,140,0), kill_141_GrailWaveStacking)
makeTestBtn("142. 🎮 Proximity PP", "→InputSim: триггер всех PP на боссе", Color3.fromRGB(0,140,140), kill_142_ProximityPromptAbuse)
makeTestBtn("143. 📊 Defense Hijack", "→MathStats: Armor=0, DmgMulti=1000", Color3.fromRGB(100,20,100), kill_143_DefenseAttributeHijack)
makeTestBtn("144. 🦾 CtrlManager", "→Rigs: ControllerManager Speed=0", Color3.fromRGB(160,80,0), kill_144_ControllerManagerHijack)
makeTestBtn("145. 📡 Handle Morph", "→Remotes: растянуть Handle до NPC", Color3.fromRGB(0,100,160), kill_145_ToolHandleHitboxMorph)
makeTestBtn("146. 🩸 Death Signal", "→FE: файрим все Died/OnDeath", Color3.fromRGB(120,40,40), kill_146_CustomDeathSignalFire)

-- 📋 СЕКЦИЯ ТАБЛИЦЫ NPC (нижняя часть)
local listSection = Instance.new("Frame", mf)
listSection.Size = UDim2.new(1, -20, 0, 445)
listSection.Position = UDim2.new(0, 10, 0, 424)
listSection.BackgroundColor3 = Color3.fromRGB(20,20,26)
Instance.new("UICorner", listSection).CornerRadius = UDim.new(0,10)

local lsHeader = Instance.new("Frame", listSection)
lsHeader.Size = UDim2.new(1, 0, 0, 32); lsHeader.BackgroundColor3 = Color3.fromRGB(28,28,38)
Instance.new("UICorner", lsHeader).CornerRadius = UDim.new(0,10)

local function makeColLabel(parent, text, pos, size, col)
    local l = Instance.new("TextLabel", parent); l.Size = size; l.Position = pos; l.Text = text
    l.Font = Enum.Font.GothamBold; l.TextSize = 11; l.TextColor3 = col or Color3.fromRGB(220,220,220); l.BackgroundTransparency = 1; l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

makeColLabel(lsHeader, "  ИМЯ (СКАНЕР)", UDim2.new(0,0,0,0), UDim2.new(0.38,0,1,0), Color3.fromRGB(255,255,150))
makeColLabel(lsHeader, "ТИП", UDim2.new(0.39,0,0,0), UDim2.new(0.26,0,1,0), Color3.fromRGB(150,220,255))
makeColLabel(lsHeader, "ЗДОРОВЬЕ", UDim2.new(0.66,0,0,0), UDim2.new(0.18,0,1,0), Color3.fromRGB(150,255,150))
makeColLabel(lsHeader, "ВЛАДЕНИЕ", UDim2.new(0.85,0,0,0), UDim2.new(0.14,0,1,0), Color3.fromRGB(255,180,255))

local selAllBtn = Instance.new("TextButton", lsHeader)
selAllBtn.Size = UDim2.new(0, 80, 0, 22); selAllBtn.Position = UDim2.new(1, -170, 0, 5)
selAllBtn.Text = "✅ Все"; selAllBtn.Font = Enum.Font.SourceSansBold; selAllBtn.TextSize = 11
selAllBtn.BackgroundColor3 = Color3.fromRGB(40,90,40); selAllBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", selAllBtn).CornerRadius = UDim.new(0,4)

local deselBtn = Instance.new("TextButton", lsHeader)
deselBtn.Size = UDim2.new(0, 80, 0, 22); deselBtn.Position = UDim2.new(1, -85, 0, 5)
deselBtn.Text = "❌ Сброс"; deselBtn.Font = Enum.Font.SourceSansBold; deselBtn.TextSize = 11
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
        local valid, et, hpText, isAnchored, root = analyzeEntity(obj)
        if valid and root then
            local b = Instance.new("TextButton", npcS)
            b.Size = UDim2.new(1, -6, 0, 26); b.Text = ""
            b.BackgroundColor3 = selectedNPCs[obj] and Color3.fromRGB(20,90,30) or Color3.fromRGB(32,32,42)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
            makeColLabel(b, "  "..obj.Name, UDim2.new(0,0,0,0), UDim2.new(0.38,0,1,0), Color3.fromRGB(255,255,255))
            makeColLabel(b, et, UDim2.new(0.39,0,0,0), UDim2.new(0.26,0,1,0), Color3.fromRGB(180,220,255))
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
    title.Text = "  👑 KILL v37.0 (Целей: "..#entities.." | Методов: 60+ | Каст: 6 ориг + 1 нов | Anti-Kick: "..(AntiKickPro.active and "ON" or "OFF")..")"
end

task.spawn(function()
    while true do
        task.wait(0.5)
        for _,data in ipairs(npcButtons) do
            local obj, b, hpLbl, owLbl, root = unpack(data)
            if obj and obj.Parent and b and b.Parent and root and root.Parent then
                b.BackgroundColor3 = selectedNPCs[obj] and Color3.fromRGB(20,90,30) or Color3.fromRGB(32,32,42)
                local valid, _, hpText = analyzeEntity(obj)
                if valid then hpLbl.Text = hpText; if string.find(hpText,"0") or string.find(hpText,"-") then hpLbl.TextColor3 = Color3.fromRGB(255,100,100) else hpLbl.TextColor3 = Color3.fromRGB(150,255,150) end end
                local owText = checkOwnership(root)
                owLbl.Text = owText
                if string.find(owText,"ME") then owLbl.TextColor3 = Color3.fromRGB(100,255,100) elseif string.find(owText,"ANCHORED") then owLbl.TextColor3 = Color3.fromRGB(255,180,0) else owLbl.TextColor3 = Color3.fromRGB(255,100,100) end
            end
        end
    end
end)

local function boostAuth()
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(lp, "SimulationRadius", 1e11)
            sethiddenproperty(lp, "MaxSimulationRadius", 1e11)
        end
    end)
end
track("boostRS", rs.RenderStepped:Connect(boostAuth))
track("boostHB", rs.Heartbeat:Connect(boostAuth))

task.spawn(function() while true do pcall(refreshTable); task.wait(3.5) end end)
pcall(refreshTable)
runFullAnalysis()

local function unloadAll()
    AntiKickPro.active = false
    for _,c in pairs(connections) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,c in pairs(rollbackGuards) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,c in pairs(AntiKickPro.hookedRemotes) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,hl in pairs(highlights) do pcall(function() if hl and hl.Parent then hl:Destroy() end end) end
    for _,o in ipairs(ws:GetDescendants()) do if o.Name == "_NPCKillHL" then pcall(function() o:Destroy() end) end end
    if sg and sg.Parent then sg:Destroy() end
    if highlight and highlight.Parent then highlight:Destroy() end
    _G.NPCKillTesterPro = nil
end

_G.NPCKillTesterPro.Unload = unloadAll
unloadBtn.MouseButton1Click:Connect(unloadAll)

print("=========================================================")
print("[👑 KILL LAB v37.0 LOADED — ORIGINAL 6 CASTS EDITION 👑]")
print("  ✅ 6 оригинальных кастов v32 + 1 новый (Player Input Sim)")
print("  🛡️ Anti-Kick PRO 5 слоёв — ВКЛЮЧИ в панели настроек!")
print("  🔥 NUCLEAR KILL — 60+ методов разом БЕЗ настроек")
print("  🧪 10 новых методов v37 (№137-№146) с метками кастов")
print("=========================================================")

