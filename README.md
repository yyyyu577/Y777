-- ============================================================================
-- NPC KILL TESTER PRO v40.0 — TEST SECTION SHOWS ONLY NEW METHODS (147+)
--
-- 🎯 ЧТО СДЕЛАНО В v40.0:
--   ✅ Секция тестов теперь показывает ТОЛЬКО новейшие методы (id >= 147)
--   ✅ Старые методы (1-146) остались доступны:
--       • в раскрывающихся подменю кастов (клик по касту → подменю)
--       • в MASTER OMNI-KILL (по настройкам)
--       • в NUCLEAR KILL (все разом)
--   ✅ Всего в реестре 83 метода — все работают, но в тестах только 10
--   ✅ Константа TEST_MIN_ID = 147 — если надо будет тестить старые,
--       просто поменяй эту цифру в коде
--
-- 📦 ЧТО БЫЛО В v39.0 (ПОЛНАЯ ИНВЕНТАРИЗАЦИЯ):
--   ✅ Восстановлены 14 ПРОПУЩЕННЫХ методов из старых версий:
--       №87, №89, №92, №93, №96, №102, №119, №120, №125, №126,
--       №129, №131, №132, №135
--   ✅ Все методы распределены по правильным кастам
--   ✅ Все текущие методы (v38 №147-156) СОХРАНЕНЫ
--   ✅ Все ранее добавленные (v37 №137-146) СОХРАНЕНЫ
--   ✅ ИТОГО: ~83 метода в реестре
--
-- 🎯 ЧТО СДЕЛАНО В v38.0:
--   ✅ ❌ УДАЛЕНЫ методы с кликом по экрану (№97 VIM Click, №100 Mobile Touch,
--        №104 CameraAimLockFire) — они мешали, не работали нормально
--   ✅ Панель настроек ТЕПЕРЬ РАСКРЫВАЕТСЯ (клик на касту → открывается
--        подменю с индивидуальными тумблерами каждого метода внутри!)
--   ✅ Панель настроек и панель тестов БОЛЬШЕ + прокрутка
--   ✅ №137, №138, №139 добавлены в MASTER (были только в тестах)
--   ✅ №140 SkinnedMeshAnnihilate помечен как ⭐ (ты сказал что мощный)
--   ✅ Anti-Kick PRO сохранён (5 слоёв)
--   ✅ Nuclear Kill сохранён
--   ✅ 10 НОВЫХ методов v38 (№147-№156)
--
-- 🆕 10 НОВЫХ МЕТОДОВ v38 (№147 – №156):
--   147. 🦾 MESH ID CORRUPTION       — подмена MeshId босса на пустой
--   148. 📊 STATUS EFFECT INJECT     — впрыск Poison/Burn/Bleed атрибутов
--   149. 📡 REMOTE CHAIN REPLAY      — записываем и повторяем последнюю атаку 30х
--   150. 🩸 HUMANOID DEATH SIMULATE  — эмуляция полного death cycle
--   151. 🦾 PART SHAPE MORPH         — Shape=Ball, всё катится (не размер!)
--   152. 👑 GRAIL SHOTGUN BURST      — 500 TakeDamage за 1 кадр (не waves)
--   153. 📊 MAX HEALTH LADDER        — понижаем MaxHealth ступенями от текущего
--   154. 🦾 CANQUERY DISABLE STORM   — вырубаем CanQuery/CanTouch = нет hitbox
--   155. 📡 TOOL CLONE FLOOD         — клонируем наш Tool 20 раз и Activate
--   156. 🩸 HUMANOID DESCRIPTION KILL — HumanoidDescription с 0 characteristic
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

-- 🎛️ ГЛАВНЫЕ КАСТЫ (тумблеры «весь каст ON/OFF»)
local CastEnabled = {
    GoldenGrail = true,
    RemotesWeapons = true,
    CustomRigs = true,
    FEClassic = true,
    MathStats = true,
    DestroyerServer = false,
    PlayerInputSim = true,
}

-- 🔬 ПОДНАСТРОЙКИ КАЖДОГО МЕТОДА (индивидуальные тумблеры)
-- Формат: [methodId] = true/false
local MethodEnabled = {}
-- Будет заполнено ниже вместе с определением методов

local CombatSettings = {
    DamageAmount = 50000,
    HyperSpeed = false
}

local DeepAnalysisData = { CombatRemotes = {}, MapHazards = {}, WeaponRemotes = {}, AbilityRemotes = {} }
local RemoteHistory = {} -- v38: для №149 Remote Chain Replay

local function track(name, con) if con then connections[name] = con end end

-- 📚 РЕЕСТР ВСЕХ МЕТОДОВ (для UI автогенерации)
-- Формат: {id, cast, name, desc, fn}
local MethodRegistry = {}

local function registerMethod(id, cast, name, desc, fn, defaultEnabled)
    MethodEnabled[id] = defaultEnabled ~= false
    table.insert(MethodRegistry, {id=id, cast=cast, name=name, desc=desc, fn=fn})
end

-- ==================== АНАЛИЗАТОР (с историей ремоутов для №149) ====================
local function indexObject(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = string.lower(obj.Name)
            local fnm = obj.Parent and string.lower(obj.Parent.Name) or ""
            local isHoneypot = string.find(nm,"ban") or string.find(nm,"kick") or string.find(nm,"admin") or string.find(nm,"anticheat") or string.find(nm,"log") or string.find(nm,"report") or string.find(nm,"detect") or string.find(nm,"security") or string.find(fnm,"anticheat")
            if not isHoneypot then
                if string.find(nm,"attack") or string.find(nm,"damage") or string.find(nm,"hit") or string.find(nm,"combat") or string.find(nm,"kill") or string.find(nm,"strike") or string.find(nm,"swing") or string.find(nm,"slash") or string.find(fnm,"remote") or string.find(fnm,"event") then
                    if not table.find(DeepAnalysisData.CombatRemotes, obj) then table.insert(DeepAnalysisData.CombatRemotes, obj) end
                end
                if string.find(nm,"ability") or string.find(nm,"skill") or string.find(nm,"cast") or string.find(nm,"spell") then
                    if not table.find(DeepAnalysisData.AbilityRemotes, obj) then table.insert(DeepAnalysisData.AbilityRemotes, obj) end
                end
            end
        end
        if obj:IsA("Tool") or obj:IsA("HopperBin") then
            for _,rem in ipairs(obj:GetDescendants()) do
                if (rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction")) and not table.find(DeepAnalysisData.WeaponRemotes, rem) then
                    table.insert(DeepAnalysisData.WeaponRemotes, rem)
                end
            end
        end
    end)
end

local function runFullAnalysis()
    DeepAnalysisData = { CombatRemotes = {}, MapHazards = {}, WeaponRemotes = {}, AbilityRemotes = {} }
    for _,o in ipairs(rep:GetDescendants()) do indexObject(o) end
    for _,o in ipairs(ws:GetDescendants()) do indexObject(o) end
    for _,p in ipairs(plrs:GetPlayers()) do
        local bp = p:FindFirstChild("Backpack")
        if bp then for _,o in ipairs(bp:GetDescendants()) do indexObject(o) end end
    end
    print("[🤖 v38 ANALYZER] Combat:", #DeepAnalysisData.CombatRemotes, "| Weapon:", #DeepAnalysisData.WeaponRemotes)
end

ws.DescendantAdded:Connect(indexObject); rep.DescendantAdded:Connect(indexObject)

-- ==================== БАЗОВЫЕ УТИЛИТЫ ====================
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
    if model:FindFirstChild("Health", true) or model:GetAttribute("Health") or model:GetAttribute("HP") or model:GetAttribute("Boss") then return true end
    for _, desc in ipairs(model:GetDescendants()) do if desc:IsA("Motor6D") or desc:IsA("BallSocketConstraint") then return true end end
    return false
end

local function getAllValidEntities()
    local raw = {}
    for _, obj in ipairs(ws:GetDescendants()) do
        if obj:IsA("Model") and obj ~= lp.Character and not plrs:GetPlayerFromCharacter(obj) then
            if isParametricCreature(obj) then table.insert(raw, obj) end
        end
    end
    local final = {}
    for _, c in ipairs(raw) do
        local isChild = false
        for _, o in ipairs(raw) do if c ~= o and o:IsDescendantOf(c) then isChild = true; break end end
        if not isChild then table.insert(final, c) end
    end
    return final
end

local function analyzeEntity(obj)
    local root = getRootPart(obj); if not root then return false, nil, nil, false, nil end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    local valHP = obj:FindFirstChild("Health", true) or obj:FindFirstChild("HP", true)
    local attrHP = obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("Boss")
    local nm = string.lower(obj.Name)
    local isBoss = string.find(nm,"boss") or string.find(nm,"killer")
    local et, hp = "Unknown", "N/A"
    if hum then
        et = isBoss and "[👑 Boss Hum]" or "[🚶 Humanoid]"
        hp = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    elseif valHP then
        et = isBoss and "[👑 Custom Boss]" or "[🦾 Custom]"
        hp = tostring(valHP.Value)
    elseif attrHP then
        et = isBoss and "[👑 Attr Boss]" or "[📊 Attr]"
        hp = tostring(attrHP)
    else
        et = isBoss and "[👑 Rig Boss]" or "[🦾 Rig]"
        hp = "Rig"
    end
    return true, et, hp, root.Anchored, root
end

local function checkOwner(part)
    if not part or not part:IsA("BasePart") then return "[NO]" end
    if part.Anchored then return "[⚓]" end
    local ok, o = pcall(function() return part:IsNetworkOwner() end)
    if ok and o then return "[✅ ME]" else return "[🌐 SRV]" end
end

local function getTargets()
    local t = {}
    for obj,_ in pairs(selectedNPCs) do if obj and obj.Parent then table.insert(t, obj) else selectedNPCs[obj]=nil end end
    if #t == 0 and currentNPC and currentNPC.Parent then table.insert(t, currentNPC) end
    return t
end

local function claimFE(obj)
    pcall(function()
        if sethiddenproperty then sethiddenproperty(lp, "SimulationRadius", 1e15) end
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") and not p.Anchored then pcall(function() p:SetNetworkOwner(lp) end) end
        end
    end)
end

-- ==================== 🛡️ ANTI-KICK PRO 5 СЛОЁВ ====================
local AntiKickPro = { installed = false, active = false, hookedRemotes = {} }

function AntiKickPro:Install()
    if self.installed then return end
    self.installed = true; self.active = true
    print("[🛡️ ANTI-KICK PRO] Установка 5 слоёв...")
    pcall(function()
        if hookmetamethod then
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod and getnamecallmethod() or ""
                if (method == "Kick" or method == "kick") and (self == lp or (typeof(self)=="Instance" and self:IsA("Player"))) then
                    if AntiKickPro.active then print("[🛡️ L1] Kick заблокирован!"); return nil end
                end
                return old(self, ...)
            end)
            print("[🛡️ L1] hookmetamethod OK")
        end
    end)
    pcall(function()
        local mt = getrawmetatable and getrawmetatable(lp) or nil
        if mt and setreadonly then
            setreadonly(mt, false)
            local oldIndex = mt.__index
            mt.__index = newcclosure and newcclosure(function(self, key)
                if key == "Kick" and self == lp and AntiKickPro.active then return function() print("[🛡️ L2] Kick перехвачен!") end end
                return oldIndex(self, key)
            end) or function(self, key)
                if key == "Kick" and self == lp and AntiKickPro.active then return function() print("[🛡️ L2] Kick перехвачен!") end end
                return oldIndex(self, key)
            end
            setreadonly(mt, true); print("[🛡️ L2] __index OK")
        end
    end)
    pcall(function()
        for _,r in ipairs(rep:GetDescendants()) do
            if r:IsA("RemoteEvent") then
                local nm = string.lower(r.Name)
                if string.find(nm,"kick") or string.find(nm,"ban") or string.find(nm,"anticheat") or string.find(nm,"punish") then
                    local conn = r.OnClientEvent:Connect(function() print("[🛡️ L3] Заблокирован:", r.Name) end)
                    table.insert(AntiKickPro.hookedRemotes, conn)
                end
            end
        end
        print("[🛡️ L3] Kick-remotes мониторятся")
    end)
    pcall(function()
        local function patchChar(char)
            if not char then return end
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then pcall(function()
                hum.BreakJointsOnDeath = false
                hum.MaxHealth = math.huge; hum.Health = math.huge
                local conn = hum.HealthChanged:Connect(function(newHP) if AntiKickPro.active and newHP < hum.MaxHealth*0.5 then pcall(function() hum.Health = hum.MaxHealth end) end end)
                table.insert(AntiKickPro.hookedRemotes, conn)
            end) end
        end
        patchChar(lp.Character)
        track("charAK", lp.CharacterAdded:Connect(patchChar))
        print("[🛡️ L4] Humanoid patched")
    end)
    task.spawn(function()
        while AntiKickPro.active do
            pcall(function()
                local char = lp.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health < hum.MaxHealth*0.7 then hum.Health = hum.MaxHealth end
                    if not char:FindFirstChildOfClass("ForceField") then
                        local ff = Instance.new("ForceField"); ff.Visible=false; ff.Parent=char
                        game:GetService("Debris"):AddItem(ff, 5)
                    end
                end
            end)
            task.wait(0.3)
        end
    end)
    print("[🛡️ L5] Auto-heal loop OK")
end

function AntiKickPro:Toggle(state)
    self.active = state
    if state and not self.installed then self:Install() end
    print("[🛡️ ANTI-KICK]", state and "АКТИВЕН" or "OFF")
end

-- ============================================================================
-- 🩸 КАСТ: FE CLASSIC
-- ============================================================================

local function m_1(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.Health=0; h:TakeDamage(999999) end) end end
registerMethod(1, "FEClassic", "1. Simple HP=0", "Прямое обнуление Humanoid.Health", m_1)

local function m_2(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead); h.PlatformStand=true; h.WalkSpeed=0 end) end end
registerMethod(2, "FEClassic", "2. Ragdoll State Dead", "ChangeState(Dead) + PlatformStand", m_2)

local function m_3(obj) claimFE(obj); task.spawn(function() for i=1,20 do if not obj.Parent then break end; pcall(function() if obj.BreakJoints then obj:BreakJoints() end end); for _,v in ipairs(obj:GetDescendants()) do if v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("JointInstance") then pcall(function() v:Destroy() end) end end; task.wait(0.025) end end) end
registerMethod(3, "FEClassic", "3. Break Joints Loop", "BreakJoints x28 итераций", m_3)

local function m_5(obj) claimFE(obj); for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") and (p.Name=="Head" or p.Name=="Torso") then pcall(function() for _,w in ipairs(p:GetChildren()) do if w:IsA("Motor6D") or w:IsA("Weld") then w:Destroy() end end; p.AssemblyLinearVelocity = Vector3.new(0,100000,0) end) end end end
registerMethod(5, "FEClassic", "5. Decapitate Head/Torso", "Отрыв головы + torso", m_5)

local function m_6(obj) claimFE(obj); local r=getRootPart(obj); if not r then return end; pcall(function() local e=Instance.new("Explosion"); e.Position=r.Position; e.BlastRadius=35; e.BlastPressure=0; e.ExplosionType=Enum.ExplosionType.NoCraters; e.Parent=ws end) end
registerMethod(6, "FEClassic", "6. Safe Pulse Explosion", "Explosion с DestroyJoint=0", m_6)

local function m_117(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); if not h then return end; pcall(function() for _,s in pairs(Enum.HumanoidStateType:GetEnumItems()) do if s~=Enum.HumanoidStateType.Dead then pcall(function() h:SetStateEnabled(s,false) end) end end; for _,s in ipairs({Enum.HumanoidStateType.Dead,Enum.HumanoidStateType.Physics,Enum.HumanoidStateType.Ragdoll}) do pcall(function() h:ChangeState(s) end) end; h.MaxHealth=0; h.Health=0 end) end
registerMethod(117, "FEClassic", "117. Humanoid State Flood", "Все death states + disable rest", m_117)

local function m_121(obj) claimFE(obj); pcall(function() local h=obj:FindFirstChildOfClass("Humanoid"); if h then h.RequiresNeck=true end; local hd=obj:FindFirstChild("Head"); if hd then for _,j in ipairs(hd:GetChildren()) do if j:IsA("Motor6D") or j:IsA("Weld") then pcall(function() j.Part0=nil; j.Part1=nil end) end end end; if h then h:ChangeState(Enum.HumanoidStateType.Dead); h.Health=0 end end) end
registerMethod(121, "FEClassic", "121. Root/Head Decapitate", "Разрыв Head-Neck (FE-way)", m_121)

local function m_123(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); pcall(function() if h then h:ChangeState(Enum.HumanoidStateType.Ragdoll); h.PlatformStand=true end; for _,j in ipairs(obj:GetDescendants()) do if j:IsA("Motor6D") then pcall(function() j.Part0=nil; j.Part1=nil end) end end; if h then h.Health=0 end end) end
registerMethod(123, "FEClassic", "123. Ragdoll Suffocation", "Ragdoll + Motor6D разрыв", m_123)

local function m_90(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.HipHeight=-50; h.PlatformStand=true; h:ChangeState(Enum.HumanoidStateType.Dead) end) end end
registerMethod(90, "FEClassic", "90. HipHeight Crash", "HipHeight=-50 → died", m_90)

local function m_137(obj) claimFE(obj); task.spawn(function() local motors={}; for _,v in ipairs(obj:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors,v) end end; for tick=1,40 do if not obj.Parent then break end; for i,m in ipairs(motors) do pcall(function() m.DesiredAngle=math.sin(tick*0.5+i)*1e6; m.MaxVelocity=math.huge end) end; task.wait(0.02) end end) end
registerMethod(137, "FEClassic", "137. Joint Velocity Osc", "Motor6D DesiredAngle колебания", m_137)

local function m_146(obj) pcall(function() for _,d in ipairs(obj:GetDescendants()) do if d:IsA("BindableEvent") then local nm=string.lower(d.Name); if string.find(nm,"died") or string.find(nm,"death") or string.find(nm,"kill") or string.find(nm,"defeat") then pcall(function() d:Fire(); d:Fire(obj); d:Fire(true) end) end end; if d:IsA("RemoteEvent") then local nm=string.lower(d.Name); if string.find(nm,"died") or string.find(nm,"death") then pcall(function() d:FireServer(); d:FireServer(obj) end) end end end end) end
registerMethod(146, "FEClassic", "146. Custom Death Signal", "Файрим все Died/Death events", m_146)

-- 🩸 150. HUMANOID DEATH SIMULATE — полный death cycle эмуляция
local function m_150(obj)
    claimFE(obj)
    local h = obj:FindFirstChildOfClass("Humanoid"); if not h then return end
    print("[🩸 v38 150] Death Cycle Simulate:", obj.Name)
    task.spawn(function()
        -- Точная последовательность как Roblox сам делает при смерти
        pcall(function()
            h.Health = 0
            h:ChangeState(Enum.HumanoidStateType.Dead)
            task.wait(0.05)
            -- Триггерим Died signal напрямую через FireServer если возможно
            if h.Died and h.Died.Fire then pcall(function() h.Died:Fire() end) end
            -- Ломаем шею как это делает Roblox
            local head = obj:FindFirstChild("Head")
            if head then
                local neck = head:FindFirstChild("Neck") or head:FindFirstChildOfClass("Motor6D")
                if neck then pcall(function() neck:Destroy() end) end
            end
            task.wait(0.05)
            -- Активируем DeathSound
            if head then
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxasset://sounds/uuhhh.mp3"; sound.Parent = head; sound:Play()
                game:GetService("Debris"):AddItem(sound, 2)
            end
            -- Финал
            h:TakeDamage(math.huge)
        end)
    end)
end
registerMethod(150, "FEClassic", "150. Death Cycle Sim", "Полная эмуляция death cycle", m_150)

-- 🩸 156. HUMANOID DESCRIPTION KILL — обнуляем через HumanoidDescription
local function m_156(obj)
    claimFE(obj)
    local h = obj:FindFirstChildOfClass("Humanoid"); if not h then return end
    print("[🩸 v38 156] HumanoidDescription Kill:", obj.Name)
    pcall(function()
        local desc = Instance.new("HumanoidDescription")
        desc.HealthScale = 0
        desc.HeightScale = 0.01
        desc.WidthScale = 0.01
        desc.DepthScale = 0.01
        desc.BodyTypeScale = 0
        h:ApplyDescription(desc)
        task.wait(0.1)
        h.Health = 0
    end)
end
registerMethod(156, "FEClassic", "156. HumanoidDesc Kill", "ApplyDescription с 0 scale", m_156)

-- ============================================================================
-- 📡 КАСТ: REMOTES + WEAPONS + TOUCH
-- ============================================================================

local function m_17(obj) local c=lp.Character; if not c then return end; local t=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end; if t.Parent~=c then t.Parent=c end; local h=t:FindFirstChild("Handle"); local r=getRootPart(obj); task.spawn(function() for i=1,15 do if not obj.Parent then break end; pcall(function() t:Activate() end); if h and r and firetouchinterest then pcall(function() h.Size=Vector3.new(35,35,35); h.Massless=true; h.CanCollide=false; firetouchinterest(h,r,0); task.wait(); firetouchinterest(h,r,1) end) end; task.wait(0.03) end; if h then pcall(function() h.Size=Vector3.new(1,4,1) end) end end) end
registerMethod(17, "RemotesWeapons", "17. Weapon Overdrive", "Tool:Activate + hitbox 35 куб", m_17)

local function m_18(obj) if #DeepAnalysisData.CombatRemotes==0 then runFullAnalysis() end; task.spawn(function() for i=1,6 do if not obj.Parent then break end; for _,r in ipairs(DeepAnalysisData.CombatRemotes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer(obj); r:FireServer(obj,100); r:FireServer("Attack",obj) elseif r:IsA("RemoteFunction") then task.spawn(function() r:InvokeServer(obj) end) end end) end; task.wait(0.06) end end) end
registerMethod(18, "RemotesWeapons", "18. Remote Brute Force", "Все combat remotes с разными аргументами", m_18)

local function m_19(obj) if #DeepAnalysisData.WeaponRemotes==0 then runFullAnalysis() end; for _,r in ipairs(DeepAnalysisData.WeaponRemotes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer(obj); r:FireServer(getRootPart(obj),999999); r:FireServer(mouse.Hit.Position,obj) end end) end end
registerMethod(19, "RemotesWeapons", "19. Weapon Remote Hijack", "Все Tool remotes", m_19)

local function m_20(obj) for _,d in ipairs(obj:GetDescendants()) do if d:IsA("BindableEvent") then local nm=string.lower(d.Name); if string.find(nm,"die") or string.find(nm,"damage") then pcall(function() d:Fire() end) end end end end
registerMethod(20, "RemotesWeapons", "20. Bindable Signal Trigger", "Fire все die/damage bindables", m_20)

local function m_21(obj) local r=getRootPart(obj); local h=obj:FindFirstChildOfClass("Humanoid"); for _,it in ipairs({obj,r,h}) do if it then pcall(function() it:SetAttribute("Dead",true); it:SetAttribute("Health",0) end) end end end
registerMethod(21, "RemotesWeapons", "21. Attribute Tag Execution", "SetAttribute Dead=true", m_21)

local function m_25(obj) for _,v in ipairs(obj:GetDescendants()) do if v:IsA("BasePart") then local nm=string.lower(v.Name); if string.find(nm,"hitbox") or string.find(nm,"weapon") then pcall(function() v:Destroy() end) end end end end
registerMethod(25, "RemotesWeapons", "25. Disarm Boss Hitbox", "Уничтожение hitbox/weapon частей", m_25)

local function m_37(obj) if not firetouchinterest then return end; local c=lp.Character; if not c then return end; local t=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end; if t.Parent~=c then t.Parent=c end; local tp={}; for _,p in ipairs(t:GetDescendants()) do if p:IsA("BasePart") then table.insert(tp,p) end end; local np={}; for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(np,p) end end; task.spawn(function() for i=1,5 do pcall(function() t:Activate() end); for _,x in ipairs(tp) do for _,y in ipairs(np) do pcall(function() firetouchinterest(x,y,0); firetouchinterest(x,y,1) end) end end; task.wait(0.04) end end) end
registerMethod(37, "RemotesWeapons", "37. Matrix Weapon Touch", "Все Tool parts × NPC parts", m_37)

local function m_43(obj) if not firetouchinterest then return end; local r=getRootPart(obj); if not r then return end; local at={}; for _,d in ipairs(ws:GetDescendants()) do if d:IsA("TouchTransmitter") and d.Parent and d.Parent~=r then table.insert(at,d.Parent) end end; task.spawn(function() for i=1,5 do for _,t in ipairs(at) do pcall(function() firetouchinterest(r,t,0); firetouchinterest(r,t,1) end) end; task.wait(0.05) end end) end
registerMethod(43, "RemotesWeapons", "43. Touch Matrix Flood", "Все TouchTransmitters в мире", m_43)

local function m_88(obj) if not firetouchinterest then return end; local c=lp.Character; local r=getRootPart(obj); if not c or not r then return end; for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() firetouchinterest(p,r,0); firetouchinterest(p,r,1) end) end end end
registerMethod(88, "RemotesWeapons", "88. Multi-Node Touch", "Все части игрока → NPC root", m_88)

local function m_106(obj) local ids={}; pcall(function() for a,v in pairs(obj:GetAttributes()) do if string.find(string.lower(a),"id") then table.insert(ids,v) end end end); table.insert(ids,obj); table.insert(ids,obj.Name); local r=getRootPart(obj); if r then table.insert(ids,r) end; task.spawn(function() for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do for _,id in ipairs(ids) do pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(id); rem:FireServer(id,999999); rem:FireServer({Target=id,Damage=999999}) end end) end; task.wait(0.02) end end) end
registerMethod(106, "RemotesWeapons", "106. Boss-ID Router", "Все возможные ID → все remotes", m_106)

local function m_105(obj) local h=obj:FindFirstChildOfClass("Humanoid"); if not h then return end; task.spawn(function() for i=1,60 do if not obj.Parent then break end; rs.Heartbeat:Wait(); pcall(function() h:TakeDamage(100); for _,r in ipairs(DeepAnalysisData.CombatRemotes) do if r:IsA("RemoteEvent") then pcall(function() r:FireServer(obj) end) end end end) end end) end
registerMethod(105, "RemotesWeapons", "105. Server-Frame Sync", "TakeDamage 100 × 60 в такт heartbeat", m_105)

local function m_134(obj) if not firetouchinterest then return end; local c=lp.Character; if not c then return end; local mp={}; for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then table.insert(mp,p) end end; local np={}; for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(np,p) end end; task.spawn(function() for wave=1,5 do if not obj.Parent then break end; for i=1,200 do pcall(function() local a=mp[math.random(1,#mp)]; local b=np[math.random(1,#np)]; if a and b then firetouchinterest(a,b,0); firetouchinterest(a,b,1) end end) end; task.wait(0.05) end end) end
registerMethod(134, "RemotesWeapons", "134. Touched Bomb 1000x", "Случайные пары × 1000 Touched", m_134)

local function m_139(obj)
    if #DeepAnalysisData.CombatRemotes==0 then runFullAnalysis() end
    local r = getRootPart(obj)
    local formats = { {obj},{obj,999999},{obj.Name},{"Attack",obj},{"Damage",obj,999999},{r},{r,999999},{{Target=obj,Damage=999999}},{obj:FindFirstChildOfClass("Humanoid"),999999},{lp,obj,999999},{lp.UserId,obj},{math.huge},{0/0},{"kill",obj.Name},{obj,1e308},{obj,-999999},{obj,999999,999999,999999},{"instakill",obj},{"execute",obj},{obj,{damage=999999,type="pierce"}} }
    task.spawn(function()
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            for _,fmt in ipairs(formats) do pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(unpack(fmt)) elseif rem:IsA("RemoteFunction") then task.spawn(function() rem:InvokeServer(unpack(fmt)) end) end end) end
            task.wait(0.02)
        end
    end)
end
registerMethod(139, "RemotesWeapons", "139. Remote Fuzz 20fmt", "20 форматов аргументов на remotes", m_139)

local function m_145(obj) local c=lp.Character; if not c then return end; local t=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end; if t.Parent~=c then t.Parent=c end; local h=t:FindFirstChild("Handle"); if not h then return end; local r=getRootPart(obj); if not r then return end; task.spawn(function() local oS=h.Size; for i=1,10 do if not obj.Parent then break end; pcall(function() local mR=c:FindFirstChild("HumanoidRootPart"); if mR then local d=(r.Position-mR.Position).Magnitude+20; h.Size=Vector3.new(5,5,d); h.Massless=true; h.CanCollide=false; h.CFrame=CFrame.new(mR.Position,r.Position)*CFrame.new(0,0,-d/2) end; t:Activate(); if firetouchinterest then firetouchinterest(h,r,0); firetouchinterest(h,r,1) end end); task.wait(0.05) end; pcall(function() h.Size=oS end) end) end
registerMethod(145, "RemotesWeapons", "145. Handle Hitbox Morph", "Handle растянуть до NPC", m_145)

-- 📡 149. REMOTE CHAIN REPLAY — записываем и повторяем remote-вызовы 30x
local function m_149(obj)
    print("[📡 v38 149] Remote Chain Replay:", obj.Name)
    task.spawn(function()
        -- Записываем 2 сек все исходящие через remotes
        local recorded = {}
        local hooks = {}
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            if rem:IsA("RemoteEvent") then
                local orig = rem.FireServer
                local h = rawset and rawset(rem, "FireServer", function(self, ...)
                    table.insert(recorded, {rem=self, args={...}})
                    return orig(self, ...)
                end)
                table.insert(hooks, {rem=rem, orig=orig})
            end
        end
        -- Даём игроку 2 сек чтобы ударить
        task.wait(2)
        -- Восстанавливаем оригинальный FireServer
        for _,h in ipairs(hooks) do pcall(function() rawset(h.rem, "FireServer", nil) end) end
        -- Повторяем всё что записали 30 раз
        print("[📡 149] Записано вызовов:", #recorded, "— повтор 30x")
        for i=1,30 do
            if not obj.Parent then break end
            for _,rec in ipairs(recorded) do
                pcall(function() rec.rem:FireServer(unpack(rec.args)) end)
            end
            task.wait(0.03)
        end
    end)
end
registerMethod(149, "RemotesWeapons", "149. Remote Chain Replay", "Запись 2сек → повтор 30x (ударь сам!)", m_149)

-- 📡 155. TOOL CLONE FLOOD — клонируем Tool 20 раз и активируем все
local function m_155(obj)
    local char = lp.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local origTool = char:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not origTool then return end
    print("[📡 v38 155] Tool Clone Flood x20:", obj.Name)
    task.spawn(function()
        local clones = {}
        for i=1,20 do
            pcall(function()
                local c = origTool:Clone()
                c.Parent = lp.Backpack
                table.insert(clones, c)
            end)
        end
        task.wait(0.1)
        local r = getRootPart(obj)
        for wave=1,5 do
            if not obj.Parent then break end
            for _,c in ipairs(clones) do
                pcall(function()
                    hum:EquipTool(c)
                    c:Activate()
                    local h = c:FindFirstChild("Handle")
                    if h and r and firetouchinterest then firetouchinterest(h, r, 0); firetouchinterest(h, r, 1) end
                end)
            end
            task.wait(0.1)
        end
        -- Cleanup
        for _,c in ipairs(clones) do pcall(function() c:Destroy() end) end
    end)
end
registerMethod(155, "RemotesWeapons", "155. Tool Clone Flood x20", "20 копий Tool → все Activate", m_155)

-- ============================================================================
-- 🦾 КАСТ: CUSTOM RIGS
-- ============================================================================

local function m_7(obj) claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do if v:IsA("WeldConstraint") or v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("AlignPosition") or v:IsA("SpringConstraint") then pcall(function() v:Destroy() end) end end end
registerMethod(7, "CustomRigs", "7. Constraint Shatter", "Уничтожение всех Constraint", m_7)

local function m_8(obj) claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do if v:IsA("Bone") then pcall(function() v.Transform=CFrame.new(math.random(-50,50),math.random(-50,50),math.random(-50,50)) end) end end end
registerMethod(8, "CustomRigs", "8. Skinned Mesh Bone Shatter", "Bones.Transform случайный CFrame", m_8)

local function m_9(obj) claimFE(obj); for i,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.AssemblyLinearVelocity=Vector3.new(math.sin(i*99)*100000,math.cos(i*77)*100000,math.sin(i*33)*100000) end) end end end
registerMethod(9, "CustomRigs", "9. Kinetic Body Tear", "Все parts × разные velocity", m_9)

local function m_94(obj) local t=obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("AnimationController"); if not t then return end; pcall(function() for _,tr in ipairs(t:GetPlayingAnimationTracks()) do tr:Stop(0) end end) end
registerMethod(94, "CustomRigs", "94. Animation Lock", "Stop все animation tracks", m_94)

local function m_95(obj) claimFE(obj); local r=getRootPart(obj); if not r then return end; pcall(function() for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then p.RootPriority=-127; p.Massless=true end end end) end
registerMethod(95, "CustomRigs", "95. RootPriority Zero", "RootPriority=-127 + Massless", m_95)

local function m_124(obj) claimFE(obj); task.spawn(function() for wave=1,3 do if not obj.Parent then break end; for i,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=true; p.Massless=true; local d=Vector3.new(math.sin(i*0.7)*5000,math.abs(math.cos(i*0.3))*8000,math.cos(i*1.1)*5000); p.AssemblyLinearVelocity=d; p.AssemblyAngularVelocity=d*0.5 end) end end; task.wait(0.05) end end) end
registerMethod(124, "CustomRigs", "124. Velocity Shredder", "Разрыв через velocity waves", m_124)

local function m_127(obj) claimFE(obj); task.spawn(function() local motors={}; for _,v in ipairs(obj:GetDescendants()) do if v:IsA("Motor6D") or v:IsA("Weld") then table.insert(motors,v) end end; for tick=1,50 do if not obj.Parent then break end; for i,m in ipairs(motors) do pcall(function() local t=tick*0.1+i*0.37; m.C0=m.C0*CFrame.new(math.sin(t)*500,math.cos(t*1.3)*500,math.sin(t*0.7)*500) end) end; task.wait(0.01) end end) end
registerMethod(127, "CustomRigs", "127. CFrame Loop Crusher", "50 микро-CFrame атак на Motor6D", m_127)

local function m_128(obj) claimFE(obj); local t=obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("AnimationController"); if not t then return end; task.spawn(function() local a=t:FindFirstChildOfClass("Animator"); if not a then a=Instance.new("Animator"); a.Parent=t end; for i=1,500 do if not obj.Parent then break end; pcall(function() local an=Instance.new("Animation"); an.AnimationId="rbxassetid://0"; local tr=a:LoadAnimation(an); tr:Play(); tr:AdjustSpeed(1000) end) end; local h=obj:FindFirstChildOfClass("Humanoid"); if h then task.wait(0.1); pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(128, "CustomRigs", "128. Anim Track Overload", "500 anim треков (крашит рендер)", m_128)

local function m_130(obj) claimFE(obj); task.spawn(function() local atts={}; for _,a in ipairs(obj:GetDescendants()) do if a:IsA("Attachment") then table.insert(atts,a) end end; for tick=1,40 do if not obj.Parent then break end; for i,att in ipairs(atts) do pcall(function() local t=tick*0.15+i*0.5; att.CFrame=CFrame.new(math.sin(t)*100,math.cos(t)*100,math.sin(t*2)*100) end) end; task.wait(0.02) end end) end
registerMethod(130, "CustomRigs", "130. Attachment Orbit Chaos", "Attachments орбитальный хаос", m_130)

local function m_133(obj) claimFE(obj); task.spawn(function() for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then pcall(function() local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.Velocity=Vector3.new((math.random()-0.5)*500,math.random()*800,(math.random()-0.5)*500); bv.Parent=p; game:GetService("Debris"):AddItem(bv,1) end) end end; task.wait(0.5); local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(133, "CustomRigs", "133. BodyForce Infinite Push", "BodyVelocity MaxForce=math.huge", m_133)

-- ⭐ 140. SkinnedMeshAnnihilate — САМЫЙ МОЩНЫЙ (ты сказал что убил босса в другой игре!)
local function m_140(obj)
    claimFE(obj)
    print("[⭐ v37 140] SkinnedMeshAnnihilate (MOST POWERFUL):", obj.Name)
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("WrapLayer") or d:IsA("WrapTarget") then pcall(function() d:Destroy() end) end
            if d:IsA("MeshPart") then pcall(function() d.HasSkinnedMesh=false; d.Size=Vector3.new(0.01,0.01,0.01) end) end
            if d:IsA("Bone") then pcall(function() d.Position=Vector3.new(math.random(-1e6,1e6),math.random(-1e6,1e6),math.random(-1e6,1e6)); d.Transform=CFrame.new(math.random(-9999,9999),math.random(-9999,9999),math.random(-9999,9999)) end) end
        end
        local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge) end) end
    end)
end
registerMethod(140, "CustomRigs", "⭐ 140. SkinnedMesh Annihilate", "MOST POWERFUL — убил босса в другой игре!", m_140)

local function m_144(obj) claimFE(obj); pcall(function() for _,d in ipairs(obj:GetDescendants()) do if d:IsA("ControllerManager") then pcall(function() d.BaseMoveSpeed=0; d.BaseTurnSpeed=0; d.FacingDirection=Vector3.zero end) end; if d:IsA("GroundController") or d:IsA("AirController") or d:IsA("SwimController") or d:IsA("ClimbController") then pcall(function() d.MoveSpeedFactor=0 end) end end; local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Ragdoll); h.Health=0 end) end end) end
registerMethod(144, "CustomRigs", "144. ControllerManager Hijack", "BaseMoveSpeed=0", m_144)

-- 🦾 147. MESH ID CORRUPTION — подмена MeshId босса
local function m_147(obj)
    claimFE(obj)
    print("[🦾 v38 147] MeshId Corruption:", obj.Name)
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("SpecialMesh") then pcall(function() d.MeshId=""; d.TextureId=""; d.Scale=Vector3.new(0,0,0) end)
            elseif d:IsA("MeshPart") then pcall(function() d.MeshId=""; d.TextureID=""; d.Size=Vector3.new(0.01,0.01,0.01) end)
            elseif d:IsA("BlockMesh") or d:IsA("CylinderMesh") then pcall(function() d.Scale=Vector3.new(0,0,0) end) end
        end
        local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge) end) end
    end)
end
registerMethod(147, "CustomRigs", "147. MeshId Corruption", "MeshId='' + Scale=0", m_147)

-- 🦾 151. PART SHAPE MORPH — Shape=Ball всё катится
local function m_151(obj)
    claimFE(obj)
    print("[🦾 v38 151] Part Shape Morph → Ball:", obj.Name)
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("Part") then
                pcall(function()
                    d.Shape = Enum.PartType.Ball
                    d.CanCollide = true
                    d.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 1, 100, 100)
                end)
            end
        end
        local h=obj:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics); h:TakeDamage(math.huge) end) end
    end)
end
registerMethod(151, "CustomRigs", "151. Part Shape → Ball", "Shape=Ball + физика скольжения", m_151)

-- 🦾 154. CANQUERY DISABLE STORM — вырубаем hitboxes
local function m_154(obj)
    claimFE(obj)
    print("[🦾 v38 154] CanQuery Disable Storm:", obj.Name)
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then
                local nm = string.lower(d.Name)
                -- Вырубаем hitboxes/weapons/attacks (не HRP/Torso!)
                if string.find(nm,"hitbox") or string.find(nm,"weapon") or string.find(nm,"attack") or string.find(nm,"damage") or string.find(nm,"claw") or string.find(nm,"fist") or string.find(nm,"blade") then
                    pcall(function() d.CanQuery=false; d.CanTouch=false; d.CanCollide=false; d.Transparency=1 end)
                end
            end
        end
        -- Плюс наносим FE-урон
        local h=obj:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end
    end)
end
registerMethod(154, "CustomRigs", "154. CanQuery Disable Storm", "Вырубить hitboxes/weapons/claws", m_154)

-- ============================================================================
-- 📊 КАСТ: MATH STATS
-- ============================================================================

local function m_4(obj) claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") or string.find(nm,"shield") then pcall(function() v.Value=0 end) end end end; for a,_ in pairs(obj:GetAttributes()) do local nm=string.lower(a); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() obj:SetAttribute(a,0) end) end end end
registerMethod(4, "MathStats", "4. Value/Attr Zero", "Все HP-подобные value → 0", m_4)

local function m_11(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); if h then task.spawn(function() for i=1,15 do if not obj.Parent then break end; pcall(function() h:TakeDamage(math.huge); h.Health=0 end); task.wait(0.03) end end) end end
registerMethod(11, "MathStats", "11. TakeDamage Loop", "TakeDamage(math.huge) × 15", m_11)

local function m_12(obj) for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() v.Value=0/0 end) end end end end
registerMethod(12, "MathStats", "12. NaN Math Crash", "HP = 0/0 (NaN)", m_12)

local function m_13(obj) for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"damage") then pcall(function() v.Value=1e308 end) end end end end
registerMethod(13, "MathStats", "13. Double Overflow 1e308", "HP/Damage = 1e308", m_13)

local function m_14(obj) for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() v.Value=-999999 end) end end end end
registerMethod(14, "MathStats", "14. Negative HP Inversion", "HP = -999999", m_14)

local function m_15(obj) for _,ff in ipairs(obj:GetDescendants()) do if ff:IsA("ForceField") then pcall(function() ff:Destroy() end) end end; for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("BoolValue") then local nm=string.lower(v.Name); if string.find(nm,"shield") or string.find(nm,"armor") or string.find(nm,"god") then pcall(function() if v:IsA("BoolValue") then v.Value=false else v.Value=0 end end) end end end end
registerMethod(15, "MathStats", "15. Strip Shields", "Уничтожение ForceField + shield=0", m_15)

local function m_16(obj) local h=obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.MaxHealth=1; h.Health=0; h:TakeDamage(999999) end) end end
registerMethod(16, "MathStats", "16. MaxHealth Shrink to 1", "MaxHealth=1 → Health=0", m_16)

local function m_91(obj) local r=getRootPart(obj); local h=obj:FindFirstChildOfClass("Humanoid"); for _,it in ipairs({obj,r,h}) do if it then for _,a in ipairs({"Shield","Armor","GodMode","Invulnerable"}) do pcall(function() it:SetAttribute(a,0) end) end end end end
registerMethod(91, "MathStats", "91. Shield Vaporizer", "Shield/Armor/GodMode = 0", m_91)

local function m_118(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); task.spawn(function() for i=1,30 do if not obj.Parent then break end; pcall(function() if h then h.MaxHealth=0; h.Health=0; h:TakeDamage(math.huge) end end); for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() v.Value=0 end) end end end; task.wait(0.02) end end) end
registerMethod(118, "MathStats", "118. Health Clamp Override", "MaxHealth=0 loop x30", m_118)

local function m_122(obj) claimFE(obj); local h=obj:FindFirstChildOfClass("Humanoid"); if not h then return end; task.spawn(function() for wave=1,5 do if not obj.Parent then break end; for i=1,100 do pcall(function() h:TakeDamage(1e9) end) end; pcall(function() h.Health=0 end); task.wait(0.03) end end) end
registerMethod(122, "MathStats", "122. Massive TakeDamage 100x", "100 × TakeDamage(1e9) в 5 волн", m_122)

local function m_136(obj) pcall(function() for _,v in ipairs(obj:GetDescendants()) do pcall(function() if v:IsA("NumberValue") or v:IsA("IntValue") then v.Value=0 elseif v:IsA("BoolValue") then v.Value=false elseif v:IsA("StringValue") then v.Value="dead" elseif v:IsA("Vector3Value") then v.Value=Vector3.zero end end) end; for a,vl in pairs(obj:GetAttributes()) do pcall(function() if type(vl)=="number" then obj:SetAttribute(a,0) elseif type(vl)=="boolean" then obj:SetAttribute(a,false) end end) end end) end
registerMethod(136, "MathStats", "136. Cascade Purge", "Обнуление всех Value/Attribute", m_136)

local function m_138(obj) claimFE(obj); pcall(function() for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"regen") or string.find(nm,"heal") then pcall(function() v.Value=-1e6 end) end end end; for a,_ in pairs(obj:GetAttributes()) do local nm=string.lower(a); if string.find(nm,"regen") or string.find(nm,"heal") then pcall(function() obj:SetAttribute(a,-1e6) end) end end; local h=obj:FindFirstChildOfClass("Humanoid"); if h then local c; c=h.HealthChanged:Connect(function(nh) if nh>0 then pcall(function() h.Health=0; h:TakeDamage(math.huge) end) end end); task.delay(15,function() if c then c:Disconnect() end end) end end) end
registerMethod(138, "MathStats", "138. Health Regen Inversion", "HealthRegen = -1e6 + auto-kill", m_138)

local function m_143(obj) pcall(function() for _,v in ipairs(obj:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"defense") or string.find(nm,"armor") or string.find(nm,"resist") or string.find(nm,"block") then pcall(function() v.Value=0 end) elseif string.find(nm,"damagemulti") or string.find(nm,"multi") then pcall(function() v.Value=1000 end) end end end; for a,_ in pairs(obj:GetAttributes()) do local nm=string.lower(a); if string.find(nm,"defense") or string.find(nm,"armor") then pcall(function() obj:SetAttribute(a,0) end) elseif string.find(nm,"multi") then pcall(function() obj:SetAttribute(a,1000) end) end end end) end
registerMethod(143, "MathStats", "143. Defense Attribute Hijack", "Armor=0, DmgMulti=1000", m_143)

-- 📊 148. STATUS EFFECT INJECT — впрыск Poison/Burn/Bleed
local function m_148(obj)
    print("[📊 v38 148] Status Effect Inject:", obj.Name)
    pcall(function()
        local statuses = {"Poison","Burn","Bleed","Frozen","Stunned","Silenced","Cursed","Weakness","Vulnerable","DoT"}
        for _,st in ipairs(statuses) do
            obj:SetAttribute(st, true)
            obj:SetAttribute(st.."Stacks", 999)
            obj:SetAttribute(st.."Damage", 999999)
            obj:SetAttribute(st.."Duration", math.huge)
        end
        -- Также создаём NumberValues
        for _,st in ipairs(statuses) do
            local v = Instance.new("NumberValue"); v.Name = st; v.Value = 999; v.Parent = obj
            game:GetService("Debris"):AddItem(v, 30)
        end
        -- Loop наносящий DoT
        local h = obj:FindFirstChildOfClass("Humanoid")
        if h then
            task.spawn(function()
                for i=1,30 do
                    if not obj.Parent then break end
                    pcall(function() h:TakeDamage(50000) end)
                    task.wait(0.1)
                end
            end)
        end
    end)
end
registerMethod(148, "MathStats", "148. Status Effect Inject", "Poison/Burn/Bleed × 10 + DoT loop", m_148)

-- 📊 153. MAX HEALTH LADDER — ступенями уменьшаем MaxHealth
local function m_153(obj)
    claimFE(obj)
    local h = obj:FindFirstChildOfClass("Humanoid"); if not h then return end
    print("[📊 v38 153] MaxHealth Ladder:", obj.Name)
    task.spawn(function()
        local currentMax = h.MaxHealth
        for step = 1, 20 do
            if not obj.Parent then break end
            pcall(function()
                currentMax = currentMax * 0.5  -- половина каждый шаг
                h.MaxHealth = math.max(1, currentMax)
                h.Health = math.min(h.Health, h.MaxHealth)
                if step >= 10 then h.MaxHealth = 0; h.Health = 0 end
            end)
            task.wait(0.05)
        end
    end)
end
registerMethod(153, "MathStats", "153. MaxHealth Ladder", "MaxHealth ×0.5 × 20 шагов", m_153)

-- ============================================================================
-- 👑 КАСТ: GOLDEN GRAIL
-- ============================================================================

local function m_86(obj) local h=obj:FindFirstChildOfClass("Humanoid"); if not h then return end; local d=CombatSettings.DamageAmount; pcall(function() h:TakeDamage(d); if d>=999999 then h.Health=0 end end) end
registerMethod(86, "GoldenGrail", "86. Golden Grail Overdrive", "Настраиваемый TakeDamage", m_86)

local function m_141(obj) local h=obj:FindFirstChildOfClass("Humanoid"); if not h then return end; task.spawn(function() for wave=1,10 do if not obj.Parent then break end; local d=CombatSettings.DamageAmount*wave; pcall(function() h:TakeDamage(d); if wave>=8 then h.Health=0 end end); task.wait(0.05) end end) end
registerMethod(141, "GoldenGrail", "141. Grail Wave Stacking", "10 нарастающих волн урона", m_141)

-- 👑 152. GRAIL SHOTGUN BURST — 500 TakeDamage за 1 кадр
local function m_152(obj)
    local h = obj:FindFirstChildOfClass("Humanoid"); if not h then return end
    print("[👑 v38 152] Grail Shotgun Burst 500x:", obj.Name)
    task.spawn(function()
        local dmg = CombatSettings.DamageAmount
        for i=1,500 do pcall(function() h:TakeDamage(dmg) end) end
        pcall(function() h.Health = 0 end)
    end)
end
registerMethod(152, "GoldenGrail", "152. Grail Shotgun 500x", "500 × TakeDamage за 1 кадр", m_152)

-- ============================================================================
-- 🎮 КАСТ: PLAYER INPUT SIM (❌ удалены методы с кликом по экрану!)
-- ============================================================================

-- ❌ УДАЛЕНО: m_97 (VIM Click Storm — мешал)
-- ❌ УДАЛЕНО: m_100 (Mobile Touch Emulator — мешал)
-- ❌ УДАЛЕНО: m_104 (Camera Aim Lock + Fire — мешал)

local function m_98(obj) local c=lp.Character; if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end; task.spawn(function() local tools={}; for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end; for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end; for _,t in ipairs(tools) do if not obj.Parent then break end; pcall(function() h:EquipTool(t) end); task.wait(0.1); for i=1,8 do pcall(function() t:Activate() end); task.wait(0.15); pcall(function() t:Deactivate() end); task.wait(0.05) end end end) end
registerMethod(98, "PlayerInputSim", "98. Tool Activate Legit", "Cycle равномерных Activate/Deactivate", m_98)

local function m_99(obj) local keys={Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R,Enum.KeyCode.F,Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Z,Enum.KeyCode.X,Enum.KeyCode.C,Enum.KeyCode.V}; task.spawn(function() for _,key in ipairs(keys) do pcall(function() VIM:SendKeyEvent(true,key,false,game); task.wait(0.05); VIM:SendKeyEvent(false,key,false,game) end); task.wait(0.1) end end) end
registerMethod(99, "PlayerInputSim", "99. Ability Key Presser", "Нажатие Q/E/R/F/1/2/3/4", m_99)

local function m_103(obj) local c=lp.Character; if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then pcall(function() h:EquipTool(t) end); task.wait(0.05) end end end
registerMethod(103, "PlayerInputSim", "103. Inventory Auto-Equip", "Взять все Tools из бэкпака", m_103)

local function m_142(obj) if not fireproximityprompt then return end; task.spawn(function() for wave=1,5 do if not obj.Parent then break end; for _,pp in ipairs(obj:GetDescendants()) do if pp:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(pp) end) end end; local r=getRootPart(obj); if r then for _,pp in ipairs(ws:GetDescendants()) do if pp:IsA("ProximityPrompt") and pp.Parent and pp.Parent:IsA("BasePart") and (pp.Parent.Position-r.Position).Magnitude<30 then pcall(function() fireproximityprompt(pp) end) end end end; task.wait(0.1) end end) end
registerMethod(142, "PlayerInputSim", "142. Proximity PP Abuse", "Триггер всех PP на боссе", m_142)

-- ============================================================================
-- 🔄 ВОССТАНОВЛЕННЫЕ МЕТОДЫ v39.0 (14 пропущенных из v32-v36)
-- ============================================================================

-- 👑 87. GRAIL OVERDRIVE COMPOSITE — TakeDamage 999K + брутфорс remote-эхо
local function m_87(obj)
    local h = obj:FindFirstChildOfClass("Humanoid")
    if h then pcall(function() h:TakeDamage(999999); h.Health = 0 end) end
    -- Плюс эхо через combat remotes
    task.spawn(function()
        for _,r in ipairs(DeepAnalysisData.CombatRemotes) do
            pcall(function() if r:IsA("RemoteEvent") then r:FireServer(obj); r:FireServer(obj,999999) end end)
        end
    end)
end
registerMethod(87, "GoldenGrail", "87. Grail Overdrive Composite", "TakeDamage 999K + эхо ремоутов", m_87)

-- 📡 89. CUSTOM WELD DETACH — бесшумный отрыв Weld связанных с оружием
local function m_89(obj)
    claimFE(obj)
    print("[📡 89] Custom Weld Detach:", obj.Name)
    for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("Motor6D") or v:IsA("WeldConstraint") then
            if v.Part1 and (string.find(string.lower(v.Part1.Name), "weapon") or string.find(string.lower(v.Part1.Name), "sword") or string.find(string.lower(v.Part1.Name), "blade") or string.find(string.lower(v.Part1.Name), "gun") or string.find(string.lower(v.Part1.Name), "hitbox")) then
                pcall(function() v.Part0 = nil; v.Part1 = nil end)
            end
        end
    end
end
registerMethod(89, "RemotesWeapons", "89. Custom Weld Detach", "Отрыв Weld оружия (Part0=nil)", m_89)

-- 🩸 92. SEAT SKY FREEZE — сидение и заморозка NPC на Y=2000
local function m_92(obj)
    local h = obj:FindFirstChildOfClass("Humanoid"); local r = getRootPart(obj)
    if not h or not r then return end
    print("[🩸 92] Seat Sky Freeze:", obj.Name)
    task.spawn(function()
        local seat = Instance.new("Seat")
        seat.Name = "_SkyFreezeSeat"; seat.Transparency = 1; seat.CanCollide = false
        seat.CFrame = r.CFrame; seat.Parent = ws
        pcall(function() seat:Sit(h) end); task.wait(0.08)
        pcall(function()
            seat.CFrame = CFrame.new(r.Position.X, 2000, r.Position.Z)
            seat.Anchored = true
            if obj.BreakJoints then obj:BreakJoints() end
        end)
        game:GetService("Debris"):AddItem(seat, 15)
    end)
end
registerMethod(92, "FEClassic", "92. Seat Sky Freeze", "Посадить в Seat и заморозить в небе", m_92)

-- 🎮 93. PROXIMITY DUNGEON OVERLOAD — овердрайв всех ProximityPrompt и ClickDetector
local function m_93(obj)
    print("[🎮 93] Proximity Dungeon Overload")
    for _,d in ipairs(ws:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            pcall(function() if fireproximityprompt then fireproximityprompt(d) end end)
        elseif d:IsA("ClickDetector") then
            pcall(function() if fireclickdetector then fireclickdetector(d) end end)
        end
    end
end
registerMethod(93, "PlayerInputSim", "93. Dungeon PP/Click Overload", "Все PP + ClickDetector в мире", m_93)

-- 📊 96. UNIVERSAL TAG EXECUTION — массовое присвоение death-тегов
local function m_96(obj)
    print("[📊 96] Universal Tag Execution:", obj.Name)
    pcall(function()
        local tags = {"Dead","Killed","KillBrick","Lava","Spike","Despawn","Garbage","Remove","Destroy","Deadly","DamageZone","Hazard","Trap","Death","Void"}
        for _,tag in ipairs(tags) do
            pcall(function() CollectionService:AddTag(obj, tag) end)
            local r = getRootPart(obj); if r then pcall(function() CollectionService:AddTag(r, tag) end) end
            for _,p in ipairs(obj:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() CollectionService:AddTag(p, tag) end) end
            end
        end
    end)
end
registerMethod(96, "MathStats", "96. Universal Death Tag", "Все death-теги на NPC (KillBrick/Lava/etc)", m_96)

-- 🛡️ 102. SELF-KICK PREVENTION — простая защита от кика (без хуков)
local function m_102(obj)
    local char = lp.Character; if not char then return end
    local myHum = char:FindFirstChildOfClass("Humanoid"); if not myHum then return end
    print("[🛡️ 102] Self-Kick Prevention (base)")
    task.spawn(function()
        for i=1,20 do
            pcall(function()
                if myHum.Health < myHum.MaxHealth * 0.5 then myHum.Health = myHum.MaxHealth end
                if not char:FindFirstChildOfClass("ForceField") then
                    local ff = Instance.new("ForceField"); ff.Visible = false; ff.Parent = char
                    game:GetService("Debris"):AddItem(ff, 3)
                end
            end)
            task.wait(0.5)
        end
    end)
    pcall(function() myHum.BreakJointsOnDeath = false end)
end
registerMethod(102, "PlayerInputSim", "102. Self-Kick Prevention (Base)", "Базовая защита игрока (не хук, доп. к Anti-Kick PRO)", m_102)

-- 💥 119. FORCEFIELD DEATH TRAP — 5 Explosion с DestroyJointRadiusPercent=1
local function m_119(obj)
    claimFE(obj)
    print("[💥 119] ForceField Death Trap:", obj.Name)
    pcall(function()
        for _,ff in ipairs(obj:GetDescendants()) do if ff:IsA("ForceField") then ff:Destroy() end end
        local r = getRootPart(obj)
        if r then
            for i=1,5 do
                local exp = Instance.new("Explosion")
                exp.Position = r.Position; exp.BlastRadius = 50; exp.BlastPressure = 0
                exp.DestroyJointRadiusPercent = 1; exp.ExplosionType = Enum.ExplosionType.NoCraters
                exp.Parent = ws
            end
        end
        local h = obj:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0; h:ChangeState(Enum.HumanoidStateType.Dead) end) end
    end)
end
registerMethod(119, "FEClassic", "119. FF Death Trap (5 Explosions)", "5 Explosion с DestroyJoint=1", m_119)

-- 📊 120. NEUTRAL TEAM ABUSE — сброс команды NPC для нашего оружия
local function m_120(obj)
    print("[📊 120] Neutral Team Abuse:", obj.Name)
    pcall(function()
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.BrickColor = BrickColor.new("Medium stone grey") end) end
        end
        for _,attr in ipairs({"Team","TeamColor","Faction","Side","Enemy","IsEnemy","Friendly","Alliance"}) do
            pcall(function() obj:SetAttribute(attr, "Neutral") end)
            pcall(function() obj:SetAttribute(attr, false) end)
        end
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("ObjectValue") or v:IsA("BrickColorValue") or v:IsA("StringValue") then
                local nm = string.lower(v.Name)
                if string.find(nm,"team") or string.find(nm,"faction") then pcall(function() if v:IsA("StringValue") then v.Value = "Neutral" else v.Value = nil end end) end
            end
        end
        local h = obj:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
registerMethod(120, "MathStats", "120. Neutral Team Abuse", "Смена TeamColor+Faction → уязвим", m_120)

-- 💥 125. EXPLOSION SPAM RING — 20 взрывов кольцом вокруг NPC
local function m_125(obj)
    local r = getRootPart(obj); if not r then return end
    print("[💥 125] Explosion Spam Ring 20x:", obj.Name)
    task.spawn(function()
        for i=1,20 do
            if not obj.Parent then break end
            pcall(function()
                local angle = (i/20) * math.pi * 2
                local offset = Vector3.new(math.cos(angle)*3, 0, math.sin(angle)*3)
                local exp = Instance.new("Explosion")
                exp.Position = r.Position + offset
                exp.BlastRadius = 15; exp.BlastPressure = 0
                exp.DestroyJointRadiusPercent = 1; exp.ExplosionType = Enum.ExplosionType.NoCraters
                exp.Parent = ws
                local h = obj:FindFirstChildOfClass("Humanoid")
                if h then h:TakeDamage(100000) end
            end)
            task.wait(0.02)
        end
    end)
end
registerMethod(125, "FEClassic", "125. Explosion Ring 20x", "20 Explosion кольцом вокруг NPC", m_125)

-- 🔥 126. ULTIMATE FE COMBO — комбо всех FE методов подряд
local function m_126(obj)
    print("[🔥 126] Ultimate FE Combo:", obj.Name)
    task.spawn(function()
        m_120(obj); task.wait(0.02)
        m_118(obj); task.wait(0.02)
        m_117(obj); task.wait(0.02)
        m_121(obj); task.wait(0.02)
        m_123(obj); task.wait(0.02)
        m_122(obj); task.wait(0.03)
        m_119(obj); task.wait(0.03)
        m_124(obj); task.wait(0.03)
        m_125(obj)
    end)
end
registerMethod(126, "FEClassic", "126. 🔥 Ultimate FE Combo", "Все FE методы подряд с задержками", m_126)

-- 🦾 129. SOUND FREQUENCY WEAPON — Sound с PlaybackSpeed=math.huge
local function m_129(obj)
    local r = getRootPart(obj); if not r then return end
    print("[🦾 129] Sound Frequency Weapon:", obj.Name)
    task.spawn(function()
        for i=1,10 do
            if not obj.Parent then break end
            pcall(function()
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://9046196336"
                s.Volume = 10; s.PlaybackSpeed = math.huge; s.Pitch = 20
                s.RollOffMaxDistance = 10000
                s.Parent = r; s:Play()
                game:GetService("Debris"):AddItem(s, 0.5)
            end)
            task.wait(0.05)
        end
        local h = obj:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge) end) end
    end)
end
registerMethod(129, "CustomRigs", "129. Sound Freq Weapon", "Sound PlaybackSpeed=huge (лаг-урон)", m_129)

-- 🦾 131. COLLISION GROUP ISOLATE — свой CollisionGroup → падение сквозь пол
local function m_131(obj)
    claimFE(obj)
    print("[🦾 131] Collision Group Isolate:", obj.Name)
    pcall(function()
        local groupName = "NPCVoid_" .. tostring(math.random(1000,9999))
        pcall(function() PhysicsService:RegisterCollisionGroup(groupName) end)
        pcall(function() PhysicsService:CollisionGroupSetCollidable(groupName, "Default", false) end)
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function() p.CollisionGroup = groupName; p.CanCollide = false; p.Massless = true end)
            end
        end
        local h = obj:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.FallingDown); h:TakeDamage(math.huge) end) end
    end)
end
registerMethod(131, "CustomRigs", "131. CollisionGroup Isolate", "Свой CollisionGroup → провал сквозь пол", m_131)

-- 🦾 132. NETWORK OWNER PING-PONG — 20 переключений NetworkOwner = десинк
local function m_132(obj)
    print("[🦾 132] NetworkOwner Ping-Pong:", obj.Name)
    task.spawn(function()
        local parts = {}
        for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") and not p.Anchored then table.insert(parts, p) end end
        for wave=1,20 do
            if not obj.Parent then break end
            for _,p in ipairs(parts) do
                pcall(function()
                    if wave % 2 == 0 then p:SetNetworkOwner(lp)
                    else p:SetNetworkOwner(nil); p:SetNetworkOwnershipAuto() end
                end)
            end
            task.wait(0.03)
        end
        local h = obj:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
registerMethod(132, "CustomRigs", "132. NetworkOwner Ping-Pong", "20× переключений NetOwner (десинк)", m_132)

-- 🦾 135. MESH RESIZE OVERFLOW — NPC в 1 см = глюки коллизий и урон
local function m_135(obj)
    claimFE(obj)
    print("[🦾 135] Mesh Resize Overflow:", obj.Name)
    pcall(function()
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("MeshPart") then
                pcall(function() p.Size = Vector3.new(0.01, 0.01, 0.01); p.Massless = true end)
            end
            if p:IsA("SpecialMesh") or p:IsA("BlockMesh") or p:IsA("CylinderMesh") then
                pcall(function() p.Scale = Vector3.new(0.001, 0.001, 0.001) end)
            end
        end
        local h = obj:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
registerMethod(135, "CustomRigs", "135. Mesh Resize Overflow", "Все parts → 1см (глюки hitbox)", m_135)

-- ============================================================================
-- 🚀 КАСТ: DESTROYER SERVER
-- ============================================================================

local function m_10(obj) claimFE(obj); local r=getRootPart(obj); if not r then return end; pcall(function() r.AssemblyAngularVelocity=Vector3.new(1e6,1e6,1e6) end) end
registerMethod(10, "DestroyerServer", "10. Angular Spin 1e6", "Центрифуга AssemblyAngular", m_10, false)

local function m_29(obj) claimFE(obj); local r=getRootPart(obj); if not r then return end; pcall(function() r.CanCollide=false; r.CFrame=r.CFrame+Vector3.new(0,50,0); r.AssemblyLinearVelocity=Vector3.new(1e9,1e9,-1e9) end) end
registerMethod(29, "DestroyerServer", "29. Supersonic Launch 1e9", "Отстрел с 10^9 скоростью", m_29, false)

local function m_41(obj) claimFE(obj); for _,v in ipairs(obj:GetDescendants()) do if v:IsA("Motor6D") or v:IsA("Weld") then pcall(function() v.C0=CFrame.new(0,-5000,0); v.C1=CFrame.new(10000,10000,10000) end) end end end
registerMethod(41, "DestroyerServer", "41. Motor CFrame Crush", "C0/C1 гигантские смещения", m_41, false)

-- Anti-rollback helper
local function antiRollback(obj)
    local h=obj:FindFirstChildOfClass("Humanoid"); if not h then return end
    if rollbackGuards[obj] then rollbackGuards[obj]:Disconnect() end
    local lastHP=h.Health
    rollbackGuards[obj]=h:GetPropertyChangedSignal("Health"):Connect(function() local cur=h.Health; if cur>lastHP+5 then pcall(function() h.Health=math.max(0,lastHP-100) end) else lastHP=cur end end)
    task.delay(30,function() if rollbackGuards[obj] then rollbackGuards[obj]:Disconnect(); rollbackGuards[obj]=nil end end)
end

-- ============================================================================
-- 💥 МАСТЕР-ДВИЖОК v38 (учитывает индивидуальные тумблеры методов!)
-- ============================================================================
local function MASTER_OMNI_KILL_ENGINE(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[💥 MASTER v38] Атака:", obj.Name)
    task.spawn(function() antiRollback(obj) end)

    local ticksCount = CombatSettings.HyperSpeed and 15 or 30
    local waitTime = CombatSettings.HyperSpeed and 0.01 or 0.03

    task.spawn(function()
        for tick = 1, ticksCount do
            if not obj or not obj.Parent then break end
            -- Проходим по всем методам, проверяя КАСТ и ИНДИВИДУАЛЬНЫЙ тумблер
            for _, method in ipairs(MethodRegistry) do
                if CastEnabled[method.cast] and MethodEnabled[method.id] then
                    -- Некоторые методы тяжёлые → запускать реже
                    local heavy = (method.id == 128 or method.id == 149 or method.id == 155 or method.id == 145 or method.id == 105)
                    if not heavy or tick == 1 or tick % 8 == 0 then
                        pcall(function() method.fn(obj) end)
                    end
                end
            end
            task.wait(waitTime)
        end
    end)
end

-- ============================================================================
-- 🔥 NUCLEAR — ВСЕ МЕТОДЫ БЕЗ УЧЁТА НАСТРОЕК
-- ============================================================================
local function NUCLEAR_KILL_ENGINE(obj)
    if not obj or not obj.Parent then return end
    claimFE(obj)
    print("[🔥🔥🔥 NUCLEAR] Все", #MethodRegistry, "методов по:", obj.Name)
    task.spawn(function() antiRollback(obj) end)
    task.spawn(function()
        for wave=1,3 do
            if not obj.Parent then break end
            print("[🔥 WAVE", wave, "/3]")
            for _, method in ipairs(MethodRegistry) do
                task.spawn(function() pcall(function() method.fn(obj) end) end)
            end
            task.wait(0.5)
        end
    end)
end

-- ============================================================================
-- 🎨 GUI v38 — БОЛЬШИЕ ПАНЕЛИ + РАСКРЫВАЮЩИЕСЯ КАСТЫ
-- ============================================================================
local sg = Instance.new("ScreenGui")
sg.Name = "NPCKillTesterPro_v38_GUI"
sg.ResetOnSpawn = false
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = lp:WaitForChild("PlayerGui") end

local mf = Instance.new("Frame", sg)
mf.Size = UDim2.new(0, 820, 0, 920)
mf.Position = UDim2.new(0.5, -410, 0.5, -460)
mf.BackgroundColor3 = Color3.fromRGB(16,16,20)
mf.BorderSizePixel = 0
mf.Active = true; mf.Draggable = true
Instance.new("UICorner", mf).CornerRadius = UDim.new(0,14)

local title = Instance.new("TextLabel", mf)
title.Size = UDim2.new(1, -80, 0, 38)
title.Text = "  👑 NPC KILL v40.0 — TESTS ONLY №147+ (старые в кастах ↓ и MASTER)"
title.TextColor3 = Color3.fromRGB(255,255,255); title.Font = Enum.Font.GothamBold; title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left; title.BackgroundColor3 = Color3.fromRGB(10,10,12)
Instance.new("UICorner", title).CornerRadius = UDim.new(0,14)

local minBtn = Instance.new("TextButton", mf); minBtn.Size = UDim2.new(0,36,0,36); minBtn.Position = UDim2.new(1,-74,0,1)
minBtn.Text = "-"; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 20; minBtn.TextColor3 = Color3.fromRGB(255,255,255); minBtn.BackgroundColor3 = Color3.fromRGB(35,35,45)
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0,10)

local unloadBtn = Instance.new("TextButton", mf); unloadBtn.Size = UDim2.new(0,36,0,36); unloadBtn.Position = UDim2.new(1,-37,0,1)
unloadBtn.Text = "X"; unloadBtn.Font = Enum.Font.GothamBold; unloadBtn.TextSize = 16; unloadBtn.TextColor3 = Color3.fromRGB(255,180,180); unloadBtn.BackgroundColor3 = Color3.fromRGB(90,25,25)
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0,10)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        mf:TweenSize(UDim2.new(0,820,0,38), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true); minBtn.Text = "+"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=false end end
    else
        mf:TweenSize(UDim2.new(0,820,0,920), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true); minBtn.Text = "-"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=true end end
    end
end)

-- 🎯 СЕКЦИЯ 3 ГЛАВНЫХ КНОПОК
local actionSection = Instance.new("Frame", mf)
actionSection.Size = UDim2.new(1, -20, 0, 92); actionSection.Position = UDim2.new(0, 10, 0, 42)
actionSection.BackgroundColor3 = Color3.fromRGB(24,24,30)
Instance.new("UICorner", actionSection).CornerRadius = UDim.new(0,10)

local masterBtn = Instance.new("TextButton", actionSection)
masterBtn.Size = UDim2.new(0.31, -4, 0, 80); masterBtn.Position = UDim2.new(0, 8, 0, 6)
masterBtn.Text = "💥 MASTER\nOMNI-KILL\n(по настройкам ↓)"
masterBtn.Font = Enum.Font.GothamBold; masterBtn.TextSize = 12; masterBtn.TextColor3 = Color3.fromRGB(255,255,255); masterBtn.BackgroundColor3 = Color3.fromRGB(10,140,60)
Instance.new("UICorner", masterBtn).CornerRadius = UDim.new(0,8)
masterBtn.MouseButton1Click:Connect(function()
    local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
    for _,obj in ipairs(targets) do task.spawn(function() MASTER_OMNI_KILL_ENGINE(obj) end) end
end)

local masterKillAll = Instance.new("TextButton", actionSection)
masterKillAll.Size = UDim2.new(0.31, -4, 0, 80); masterKillAll.Position = UDim2.new(0.33, 0, 0, 6)
masterKillAll.Text = "⚡ MASTER\nKILL ALL\n(все NPC — по настр.)"
masterKillAll.Font = Enum.Font.GothamBold; masterKillAll.TextSize = 12; masterKillAll.TextColor3 = Color3.fromRGB(255,255,0); masterKillAll.BackgroundColor3 = Color3.fromRGB(160,30,0)
Instance.new("UICorner", masterKillAll).CornerRadius = UDim.new(0,8)
masterKillAll.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ents = getAllValidEntities()
        for i,o in ipairs(ents) do task.spawn(function() MASTER_OMNI_KILL_ENGINE(o) end); if i%3==0 then task.wait(0.04) end end
    end)
end)

local nuclearBtn = Instance.new("TextButton", actionSection)
nuclearBtn.Size = UDim2.new(0.34, -4, 0, 80); nuclearBtn.Position = UDim2.new(0.66, 0, 0, 6)
nuclearBtn.Text = "🔥 NUCLEAR KILL 🔥\nВСЕ "..#MethodRegistry.." МЕТОДОВ РАЗОМ\n(игнорирует настройки)"
nuclearBtn.Font = Enum.Font.GothamBold; nuclearBtn.TextSize = 12; nuclearBtn.TextColor3 = Color3.fromRGB(255,255,255); nuclearBtn.BackgroundColor3 = Color3.fromRGB(200,20,20)
Instance.new("UICorner", nuclearBtn).CornerRadius = UDim.new(0,8)
nuclearBtn.MouseButton1Click:Connect(function()
    local targets = getTargets()
    if #targets == 0 then targets = getAllValidEntities() end
    print("[🔥 NUCLEAR] Атака по", #targets, "целей!")
    for _,obj in ipairs(targets) do task.spawn(function() NUCLEAR_KILL_ENGINE(obj) end) end
end)

-- ⚙️ БОЛЬШАЯ ПАНЕЛЬ НАСТРОЕК С РАСКРЫВАЮЩИМИСЯ КАСТАМИ + ПРОКРУТКА
local settingsSection = Instance.new("Frame", mf)
settingsSection.Size = UDim2.new(1, -20, 0, 260)
settingsSection.Position = UDim2.new(0, 10, 0, 140)
settingsSection.BackgroundColor3 = Color3.fromRGB(20,20,28)
Instance.new("UICorner", settingsSection).CornerRadius = UDim.new(0,10)

local stTitle = Instance.new("TextLabel", settingsSection)
stTitle.Size = UDim2.new(1, 0, 0, 22)
stTitle.Text = "  ⚙️ НАСТРОЙКИ — КЛИКНИ НА КАСТ ЧТОБЫ РАСКРЫТЬ ПОДМЕНЮ МЕТОДОВ ▼"
stTitle.Font = Enum.Font.GothamBold; stTitle.TextSize = 11; stTitle.TextColor3 = Color3.fromRGB(150,255,255)
stTitle.TextXAlignment = Enum.TextXAlignment.Left; stTitle.BackgroundTransparency = 1

local settingsScroll = Instance.new("ScrollingFrame", settingsSection)
settingsScroll.Size = UDim2.new(1, -10, 1, -26); settingsScroll.Position = UDim2.new(0, 5, 0, 24)
settingsScroll.BackgroundTransparency = 1; settingsScroll.ScrollBarThickness = 6
settingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
settingsScroll.CanvasSize = UDim2.new(0,0,0,0)

local settingsList = Instance.new("UIListLayout", settingsScroll)
settingsList.Padding = UDim.new(0, 3); settingsList.SortOrder = Enum.SortOrder.LayoutOrder

-- Цвета и иконки для кастов
local CastInfo = {
    {key="GoldenGrail",    icon="👑", label="Золотой Грааль (TakeDamage DPS)", color=Color3.fromRGB(180,140,0)},
    {key="RemotesWeapons", icon="📡", label="Ремоуты / Оружие / Тач",         color=Color3.fromRGB(0,100,160)},
    {key="CustomRigs",     icon="🦾", label="Кастомные Тела / Кости",          color=Color3.fromRGB(160,80,0)},
    {key="FEClassic",      icon="🩸", label="Классика FE + Суставы",           color=Color3.fromRGB(120,40,40)},
    {key="MathStats",      icon="📊", label="Краш Математики",                  color=Color3.fromRGB(100,20,100)},
    {key="PlayerInputSim", icon="🎮", label="Player Input Sim (Tool/Keys/PP)",  color=Color3.fromRGB(0,140,140)},
    {key="DestroyerServer",icon="🚀", label="Destroyer Server (Космос)",       color=Color3.fromRGB(180,20,0)},
}

-- Функция создания раскрывающегося каста
local function createExpandableCast(info, order)
    local container = Instance.new("Frame", settingsScroll)
    container.Size = UDim2.new(1, -12, 0, 32)
    container.BackgroundTransparency = 1
    container.LayoutOrder = order
    container.AutomaticSize = Enum.AutomaticSize.Y

    -- Заголовок каста (клик для раскрытия)
    local header = Instance.new("TextButton", container)
    header.Size = UDim2.new(1, 0, 0, 32)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.Text = ""
    header.BackgroundColor3 = CastEnabled[info.key] and info.color or Color3.fromRGB(45,45,55)
    header.AutoButtonColor = false
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 6)

    -- Стрелка раскрытия
    local arrow = Instance.new("TextLabel", header)
    arrow.Size = UDim2.new(0, 30, 1, 0); arrow.Position = UDim2.new(0, 5, 0, 0)
    arrow.Text = "▶"; arrow.Font = Enum.Font.GothamBold; arrow.TextSize = 14
    arrow.TextColor3 = Color3.fromRGB(255,255,255); arrow.BackgroundTransparency = 1

    -- Название каста
    local castLabel = Instance.new("TextLabel", header)
    castLabel.Size = UDim2.new(1, -180, 1, 0); castLabel.Position = UDim2.new(0, 35, 0, 0)
    castLabel.Text = info.icon .. "  " .. info.label
    castLabel.Font = Enum.Font.GothamBold; castLabel.TextSize = 12
    castLabel.TextColor3 = Color3.fromRGB(255,255,255); castLabel.BackgroundTransparency = 1
    castLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Кнопка ON/OFF всего каста
    local castToggle = Instance.new("TextButton", header)
    castToggle.Size = UDim2.new(0, 90, 0, 22); castToggle.Position = UDim2.new(1, -100, 0, 5)
    castToggle.Text = CastEnabled[info.key] and "CAST: ON" or "CAST: OFF"
    castToggle.Font = Enum.Font.GothamBold; castToggle.TextSize = 10
    castToggle.TextColor3 = Color3.fromRGB(255,255,255)
    castToggle.BackgroundColor3 = CastEnabled[info.key] and Color3.fromRGB(40,120,40) or Color3.fromRGB(120,40,40)
    Instance.new("UICorner", castToggle).CornerRadius = UDim.new(0, 4)
    castToggle.MouseButton1Click:Connect(function()
        CastEnabled[info.key] = not CastEnabled[info.key]
        castToggle.Text = CastEnabled[info.key] and "CAST: ON" or "CAST: OFF"
        castToggle.BackgroundColor3 = CastEnabled[info.key] and Color3.fromRGB(40,120,40) or Color3.fromRGB(120,40,40)
        header.BackgroundColor3 = CastEnabled[info.key] and info.color or Color3.fromRGB(45,45,55)
    end)

    -- Подменю (изначально скрыто)
    local submenu = Instance.new("Frame", container)
    submenu.Size = UDim2.new(1, -20, 0, 0)
    submenu.Position = UDim2.new(0, 20, 0, 36)
    submenu.BackgroundColor3 = Color3.fromRGB(28,28,36)
    submenu.Visible = false
    submenu.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", submenu).CornerRadius = UDim.new(0, 6)

    local submenuList = Instance.new("UIListLayout", submenu)
    submenuList.Padding = UDim.new(0, 2); submenuList.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", submenu)
    pad.PaddingLeft = UDim.new(0, 5); pad.PaddingRight = UDim.new(0, 5); pad.PaddingTop = UDim.new(0, 5); pad.PaddingBottom = UDim.new(0, 5)

    -- Заполняем подменю всеми методами этого каста
    for i, method in ipairs(MethodRegistry) do
        if method.cast == info.key then
            local mBtn = Instance.new("TextButton", submenu)
            mBtn.Size = UDim2.new(1, -10, 0, 26)
            mBtn.Text = ""
            mBtn.BackgroundColor3 = MethodEnabled[method.id] and Color3.fromRGB(40,80,50) or Color3.fromRGB(50,40,40)
            mBtn.AutoButtonColor = false
            Instance.new("UICorner", mBtn).CornerRadius = UDim.new(0, 4)

            local statusLbl = Instance.new("TextLabel", mBtn)
            statusLbl.Size = UDim2.new(0, 30, 1, 0); statusLbl.Position = UDim2.new(0, 5, 0, 0)
            statusLbl.Text = MethodEnabled[method.id] and "✅" or "❌"
            statusLbl.Font = Enum.Font.GothamBold; statusLbl.TextSize = 12
            statusLbl.TextColor3 = Color3.fromRGB(255,255,255); statusLbl.BackgroundTransparency = 1

            local nameLbl = Instance.new("TextLabel", mBtn)
            nameLbl.Size = UDim2.new(0.5, -40, 1, 0); nameLbl.Position = UDim2.new(0, 40, 0, 0)
            nameLbl.Text = method.name
            nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 10
            nameLbl.TextColor3 = Color3.fromRGB(255,255,255); nameLbl.BackgroundTransparency = 1
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left

            local descLbl = Instance.new("TextLabel", mBtn)
            descLbl.Size = UDim2.new(0.5, -50, 1, 0); descLbl.Position = UDim2.new(0.5, 0, 0, 0)
            descLbl.Text = method.desc
            descLbl.Font = Enum.Font.SourceSans; descLbl.TextSize = 10
            descLbl.TextColor3 = Color3.fromRGB(200,200,220); descLbl.BackgroundTransparency = 1
            descLbl.TextXAlignment = Enum.TextXAlignment.Left

            mBtn.MouseButton1Click:Connect(function()
                MethodEnabled[method.id] = not MethodEnabled[method.id]
                statusLbl.Text = MethodEnabled[method.id] and "✅" or "❌"
                mBtn.BackgroundColor3 = MethodEnabled[method.id] and Color3.fromRGB(40,80,50) or Color3.fromRGB(50,40,40)
                print("[⚙️ SUB]", method.name, "=", MethodEnabled[method.id])
            end)
        end
    end

    -- Клик по header раскрывает/сворачивает подменю
    header.MouseButton1Click:Connect(function()
        submenu.Visible = not submenu.Visible
        arrow.Text = submenu.Visible and "▼" or "▶"
    end)
end

-- Создаём все касты
for i, info in ipairs(CastInfo) do
    createExpandableCast(info, i)
end

-- 🛡️ Anti-Kick тумблер + регулировки (в отдельном месте — под скроллом)
local extraSettings = Instance.new("Frame", mf)
extraSettings.Size = UDim2.new(1, -20, 0, 40)
extraSettings.Position = UDim2.new(0, 10, 0, 406)
extraSettings.BackgroundColor3 = Color3.fromRGB(22,22,30)
Instance.new("UICorner", extraSettings).CornerRadius = UDim.new(0,10)

local extraGrid = Instance.new("UIGridLayout", extraSettings)
extraGrid.CellSize = UDim2.new(0, 260, 0, 32); extraGrid.CellPadding = UDim2.new(0, 5, 0, 2)
local extraPad = Instance.new("UIPadding", extraSettings)
extraPad.PaddingLeft = UDim.new(0, 5); extraPad.PaddingTop = UDim.new(0, 4)

local akBtn = Instance.new("TextButton", extraSettings)
akBtn.Text = "🛡️ Anti-Kick PRO 5 слоёв [OFF]"
akBtn.BackgroundColor3 = Color3.fromRGB(45,45,55); akBtn.Font = Enum.Font.GothamBold; akBtn.TextSize = 11
akBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", akBtn).CornerRadius = UDim.new(0,6)
local akState = false
akBtn.MouseButton1Click:Connect(function()
    akState = not akState
    AntiKickPro:Toggle(akState)
    akBtn.Text = "🛡️ Anti-Kick PRO 5 слоёв " .. (akState and "[ON]" or "[OFF]")
    akBtn.BackgroundColor3 = akState and Color3.fromRGB(0,180,120) or Color3.fromRGB(45,45,55)
end)

local dmgValues = { 5000, 50000, 500000, 999999, math.huge }
local dmgNames = { "5,000", "50,000", "500,000", "999,999", "MAX Inf" }
local dmgIdx = 2
local dmgBtn = Instance.new("TextButton", extraSettings)
dmgBtn.Text = "⚙️ DPS Урон: " .. dmgNames[dmgIdx]
dmgBtn.BackgroundColor3 = Color3.fromRGB(0,120,80); dmgBtn.Font = Enum.Font.GothamBold; dmgBtn.TextSize = 11
dmgBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", dmgBtn).CornerRadius = UDim.new(0,6)
dmgBtn.MouseButton1Click:Connect(function()
    dmgIdx = (dmgIdx % #dmgValues) + 1
    CombatSettings.DamageAmount = dmgValues[dmgIdx]
    dmgBtn.Text = "⚙️ DPS Урон: " .. dmgNames[dmgIdx]
end)

local spdBtn = Instance.new("TextButton", extraSettings)
spdBtn.Text = "⚙️ Скорость: Normal (30x)"
spdBtn.BackgroundColor3 = Color3.fromRGB(60,60,80); spdBtn.Font = Enum.Font.GothamBold; spdBtn.TextSize = 11
spdBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", spdBtn).CornerRadius = UDim.new(0,6)
spdBtn.MouseButton1Click:Connect(function()
    CombatSettings.HyperSpeed = not CombatSettings.HyperSpeed
    spdBtn.Text = "⚙️ Скорость: " .. (CombatSettings.HyperSpeed and "HYPER (60x)" or "Normal (30x)")
    spdBtn.BackgroundColor3 = CombatSettings.HyperSpeed and Color3.fromRGB(120,40,160) or Color3.fromRGB(60,60,80)
end)

-- 🧪 СЕКЦИЯ ТЕСТА — ТОЛЬКО НОВЕЙШИЕ МЕТОДЫ (id >= 147) — ДЛЯ ПРОВЕРКИ!
-- Все остальные методы доступны в раскрывающихся кастах ↑ и в MASTER/NUCLEAR кнопках
local TEST_MIN_ID = 147  -- ← показываем только методы №147 и выше

local testMethods = {}
for _, method in ipairs(MethodRegistry) do
    if method.id >= TEST_MIN_ID then table.insert(testMethods, method) end
end

local testSection = Instance.new("Frame", mf)
testSection.Size = UDim2.new(1, -20, 0, 155)
testSection.Position = UDim2.new(0, 10, 0, 454)
testSection.BackgroundColor3 = Color3.fromRGB(28,20,32)
Instance.new("UICorner", testSection).CornerRadius = UDim.new(0,10)

local tsTitle = Instance.new("TextLabel", testSection)
tsTitle.Size = UDim2.new(1, 0, 0, 22)
tsTitle.Text = "  🧪 ТЕСТ "..#testMethods.." НОВЕЙШИХ МЕТОДОВ (№"..TEST_MIN_ID.."+) — старые уже в кастах ↑ и в MASTER:"
tsTitle.Font = Enum.Font.GothamBold; tsTitle.TextSize = 11; tsTitle.TextColor3 = Color3.fromRGB(255,200,100)
tsTitle.TextXAlignment = Enum.TextXAlignment.Left; tsTitle.BackgroundTransparency = 1

local tsGridF = Instance.new("ScrollingFrame", testSection)
tsGridF.Size = UDim2.new(1, -10, 1, -26); tsGridF.Position = UDim2.new(0, 5, 0, 24)
tsGridF.BackgroundTransparency = 1; tsGridF.ScrollBarThickness = 6
tsGridF.AutomaticCanvasSize = Enum.AutomaticSize.Y; tsGridF.CanvasSize = UDim2.new(0,0,0,0)

local tsGrid = Instance.new("UIGridLayout", tsGridF)
tsGrid.CellSize = UDim2.new(0, 258, 0, 34); tsGrid.CellPadding = UDim2.new(0, 5, 0, 4)

for _, method in ipairs(testMethods) do
    local b = Instance.new("TextButton", tsGridF)
    b.Text = ""; b.BackgroundColor3 = Color3.fromRGB(35,35,45); b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    local castInfo
    for _,c in ipairs(CastInfo) do if c.key == method.cast then castInfo = c; break end end
    if castInfo then b.BackgroundColor3 = castInfo.color end
    local t1 = Instance.new("TextLabel", b)
    t1.Size = UDim2.new(1,-8,0,16); t1.Position = UDim2.new(0,4,0,1); t1.Text = method.name
    t1.Font = Enum.Font.GothamBold; t1.TextSize = 11; t1.TextColor3 = Color3.fromRGB(255,255,255); t1.BackgroundTransparency = 1
    t1.TextXAlignment = Enum.TextXAlignment.Left
    local t2 = Instance.new("TextLabel", b)
    t2.Size = UDim2.new(1,-8,0,15); t2.Position = UDim2.new(0,4,0,17); t2.Text = method.desc
    t2.Font = Enum.Font.SourceSans; t2.TextSize = 10; t2.TextColor3 = Color3.fromRGB(230,230,240); t2.BackgroundTransparency = 1
    t2.TextXAlignment = Enum.TextXAlignment.Left
    b.MouseButton1Click:Connect(function()
        local targets = getTargets(); if #targets == 0 then print("[WARN] Выберите цель!"); return end
        print("[TEST]", method.name)
        for _,obj in ipairs(targets) do task.spawn(function() pcall(function() method.fn(obj) end) end) end
    end)
end

-- 📋 ТАБЛИЦА NPC (низ)
local listSection = Instance.new("Frame", mf)
listSection.Size = UDim2.new(1, -20, 0, 305)
listSection.Position = UDim2.new(0, 10, 0, 614)
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

makeColLabel(lsHeader, "  ИМЯ", UDim2.new(0,0,0,0), UDim2.new(0.38,0,1,0), Color3.fromRGB(255,255,150))
makeColLabel(lsHeader, "ТИП", UDim2.new(0.39,0,0,0), UDim2.new(0.26,0,1,0), Color3.fromRGB(150,220,255))
makeColLabel(lsHeader, "HP", UDim2.new(0.66,0,0,0), UDim2.new(0.18,0,1,0), Color3.fromRGB(150,255,150))
makeColLabel(lsHeader, "OWNER", UDim2.new(0.85,0,0,0), UDim2.new(0.14,0,1,0), Color3.fromRGB(255,180,255))

local selAllBtn = Instance.new("TextButton", lsHeader)
selAllBtn.Size = UDim2.new(0,80,0,22); selAllBtn.Position = UDim2.new(1,-170,0,5)
selAllBtn.Text = "✅ Все"; selAllBtn.Font = Enum.Font.SourceSansBold; selAllBtn.TextSize = 11
selAllBtn.BackgroundColor3 = Color3.fromRGB(40,90,40); selAllBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", selAllBtn).CornerRadius = UDim.new(0,4)

local deselBtn = Instance.new("TextButton", lsHeader)
deselBtn.Size = UDim2.new(0,80,0,22); deselBtn.Position = UDim2.new(1,-85,0,5)
deselBtn.Text = "❌ Сброс"; deselBtn.Font = Enum.Font.SourceSansBold; deselBtn.TextSize = 11
deselBtn.BackgroundColor3 = Color3.fromRGB(90,40,40); deselBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", deselBtn).CornerRadius = UDim.new(0,4)

local npcS = Instance.new("ScrollingFrame", listSection)
npcS.Size = UDim2.new(1,-10,1,-40); npcS.Position = UDim2.new(0,5,0,36)
npcS.BackgroundTransparency = 1; npcS.ScrollBarThickness = 5; npcS.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", npcS).Padding = UDim.new(0,3)

selAllBtn.MouseButton1Click:Connect(function()
    for _,obj in ipairs(getAllValidEntities()) do
        selectedNPCs[obj] = true
        if not obj:FindFirstChild("_NPCKillHL") then
            local hl = Instance.new("Highlight", obj); hl.Name = "_NPCKillHL"; hl.FillColor = Color3.fromRGB(0,255,0); hl.FillTransparency = 0.65
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
        local valid, et, hpText, _, root = analyzeEntity(obj)
        if valid and root then
            local b = Instance.new("TextButton", npcS)
            b.Size = UDim2.new(1,-6,0,26); b.Text = ""
            b.BackgroundColor3 = selectedNPCs[obj] and Color3.fromRGB(20,90,30) or Color3.fromRGB(32,32,42)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
            makeColLabel(b, "  "..obj.Name, UDim2.new(0,0,0,0), UDim2.new(0.38,0,1,0), Color3.fromRGB(255,255,255))
            makeColLabel(b, et, UDim2.new(0.39,0,0,0), UDim2.new(0.26,0,1,0), Color3.fromRGB(180,220,255))
            local hp = makeColLabel(b, hpText, UDim2.new(0.66,0,0,0), UDim2.new(0.18,0,1,0), Color3.fromRGB(150,255,150))
            local ow = makeColLabel(b, checkOwner(root), UDim2.new(0.85,0,0,0), UDim2.new(0.14,0,1,0), Color3.fromRGB(200,200,200))
            b.MouseButton1Click:Connect(function()
                if selectedNPCs[obj] then
                    selectedNPCs[obj] = nil; b.BackgroundColor3 = Color3.fromRGB(32,32,42)
                    local hl = obj:FindFirstChild("_NPCKillHL"); if hl then hl:Destroy() end
                else
                    selectedNPCs[obj] = true; currentNPC = obj; b.BackgroundColor3 = Color3.fromRGB(20,90,30)
                    if not obj:FindFirstChild("_NPCKillHL") then
                        local hl = Instance.new("Highlight", obj); hl.Name = "_NPCKillHL"; hl.FillColor = Color3.fromRGB(0,255,0); hl.FillTransparency = 0.65
                        highlights[obj] = hl
                    end
                end
            end)
            table.insert(npcButtons, {obj, b, hp, ow, root})
        end
    end
    title.Text = "  👑 KILL v38.0 (Целей: "..#entities.." | Методов: "..#MethodRegistry..")"
end

task.spawn(function()
    while true do
        task.wait(0.5)
        for _,data in ipairs(npcButtons) do
            local obj, b, hpLbl, owLbl, root = unpack(data)
            if obj and obj.Parent and b and b.Parent and root and root.Parent then
                b.BackgroundColor3 = selectedNPCs[obj] and Color3.fromRGB(20,90,30) or Color3.fromRGB(32,32,42)
                local valid, _, hpText = analyzeEntity(obj)
                if valid then hpLbl.Text = hpText end
                owLbl.Text = checkOwner(root)
            end
        end
    end
end)

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
    _G.NPCKillTesterPro = nil
end

_G.NPCKillTesterPro.Unload = unloadAll
unloadBtn.MouseButton1Click:Connect(unloadAll)

print("==========================================================")
print("[👑 KILL v40.0 LOADED — "..#MethodRegistry.." методов, "..#CastInfo.." кастов]")
print("  🧪 В секции тестов: только новейшие "..#testMethods.." методов (№"..TEST_MIN_ID.."+)")
print("  📂 Остальные "..(#MethodRegistry - #testMethods).." методов в раскрывающихся кастах ↑")
print("  💥 MASTER OMNI-KILL — все методы по настройкам")
print("  🔥 NUCLEAR KILL — все "..#MethodRegistry.." методов разом")
print("  🛡️ Anti-Kick PRO 5 слоёв — не забудь включить!")
print("==========================================================")
